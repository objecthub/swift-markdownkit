//
//  MathRenderer.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 17/10/2026.
//  Copyright © 2026 Matthias Zenger. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if canImport(WebKit) && (os(macOS) || os(iOS))

import Foundation

///
/// `MathRenderer` typesets LaTeX formulas with KaTeX and draws them into images. KaTeX runs in a
/// headless web view, which is created when the first formula is rendered, renders many formulas
/// at a time, and is released when it has not been used for a while. The images (black on a
/// transparent background; the colour is applied when a formula is shown) are cached.
///
/// ``MathAttributedStringGenerator`` uses a renderer to show formulas in attributed strings. You
/// can use a renderer directly if you need the images of formulas:
///
/// ```swift
/// let results = await MathRenderer.shared?.render([MathFormula(tex: "x^2", display: false)])
/// ```
///
/// Formulas can only be rendered on macOS and iOS.
///
public final class MathRenderer: @unchecked Sendable {

  /// The default for the time in seconds after which the web view is released if no formula is
  /// being rendered: a minute.
  public static let defaultIdleTime: TimeInterval = 60

  /// The default for the maximal number of cached results: 2,000.
  public static let defaultMaxCachedFormulas = 2_000

  /// The default for the maximal total size of the cached images: 32 MB.
  public static let defaultMaxCacheBytes = 32 * 1024 * 1024

  /// The renderer with the version of KaTeX that comes with MarkdownKit. It is `nil` if the
  /// resources of KaTeX cannot be found. The web view that does the work is only created when the
  /// first formula is rendered.
  public static let shared: MathRenderer? = {
    guard let folder = Resources.katexFolder else {
      return nil
    }
    return MathRenderer(katexFolder: folder)
  }()

  /// Key of the cache.
  struct Key: Hashable, Sendable {
    let formula: MathFormula
    let fontSize: Float
    let render: MathConfig.RenderKey
  }

  /// A cache for rendered formulas and for formulas that KaTeX rejected. It holds at most
  /// `maxEntries` entries and `maxBytes` bytes of image data; if there are more, the entries which
  /// have not been used for the longest time are dropped first. The newest entry always stays.
  private final class Cache: @unchecked Sendable {

    private struct Entry {
      var image: MathImage?
      var failure: MathError?
      var bytes: Int
      var stamp: UInt64
    }

    private let lock = NSLock()
    private let maxEntries: Int
    private let maxBytes: Int
    private var entries: [Key : Entry] = [:]
    private var totalBytes = 0
    private var clock: UInt64 = 0

    init(maxEntries: Int, maxBytes: Int) {
      self.maxEntries = max(1, maxEntries)
      self.maxBytes = max(1, maxBytes)
    }

    func image(for key: Key) -> MathImage? {
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      guard var entry = self.entries[key], let image = entry.image else {
        return nil
      }
      self.clock += 1
      entry.stamp = self.clock
      self.entries[key] = entry
      return image
    }

    func failure(for key: Key) -> MathError? {
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      guard var entry = self.entries[key], let failure = entry.failure else {
        return nil
      }
      self.clock += 1
      entry.stamp = self.clock
      self.entries[key] = entry
      return failure
    }

    func store(_ image: MathImage, for key: Key) {
      self.put(Entry(image: image, failure: nil, bytes: image.pngData.count, stamp: 0), for: key)
    }

    func storeFailure(_ failure: MathError, for key: Key) {
      self.put(Entry(image: nil, failure: failure, bytes: 0, stamp: 0), for: key)
    }

    private func put(_ entry: Entry, for key: Key) {
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      var entry = entry
      self.clock += 1
      entry.stamp = self.clock
      if let old = self.entries[key] {
        self.totalBytes -= old.bytes
      }
      self.entries[key] = entry
      self.totalBytes += entry.bytes
      while self.entries.count > 1 && (self.entries.count > self.maxEntries ||
                                       self.totalBytes > self.maxBytes) {
        guard let oldest = self.entries.min(by: { $0.value.stamp < $1.value.stamp }) else {
          break
        }
        self.totalBytes -= oldest.value.bytes
        self.entries[oldest.key] = nil
      }
    }

    func clear() {
      self.lock.lock()
      self.entries = [:]
      self.totalBytes = 0
      self.lock.unlock()
    }

    var count: Int {
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      return self.entries.count
    }
  }

  private let cache: Cache
  private let session: MathWebSession

  /// Creates a renderer which uses KaTeX from the folder `katexFolder`, which contains the files
  /// `katex.min.js` and `katex.min.css`, and the folder `fonts` of KaTeX.
  ///
  /// - Parameters:
  ///   - katexFolder: The folder with the files of KaTeX.
  ///   - idleTime: The time in seconds after which the web view is released if no formula is being
  ///               rendered. That frees the memory of the web view and of its web content
  ///               process; the next formula needs a new web view, which takes a moment. 0 (or
  ///               less) releases the web view as soon as no request is waiting for it,
  ///               `.infinity` never releases it. The default is `defaultIdleTime`.
  ///   - maxCachedFormulas: The maximal number of cached results (images, and formulas which KaTeX
  ///               rejected). When there are more, the ones which were used least recently are
  ///               dropped. At least 1; the default is `defaultMaxCachedFormulas`.
  ///               `MathAttributedStringGenerator.generate(doc:)` only shows the formulas that
  ///               are in the cache, so it should be at least the number of formulas of the
  ///               largest document that is displayed with it; `generateAsync` does not depend
  ///               on the size of the cache.
  ///   - maxCacheBytes: The maximal total size of the cached PNG images in bytes (an image is
  ///               about 10 KB). When it is exceeded, the images which were used least recently
  ///               are dropped. At least 1; the default is `defaultMaxCacheBytes`.
  /// - Returns: A renderer, or `nil` if the files of KaTeX cannot be read.
  public convenience init?(katexFolder: URL,
                           idleTime: TimeInterval = MathRenderer.defaultIdleTime,
                           maxCachedFormulas: Int = MathRenderer.defaultMaxCachedFormulas,
                           maxCacheBytes: Int = MathRenderer.defaultMaxCacheBytes) {
    self.init(katexFolder: katexFolder,
              idleTime: idleTime,
              maxCachedFormulas: maxCachedFormulas,
              maxCacheBytes: maxCacheBytes,
              transparency: .automatic)
  }

  /// Creates a renderer whose images get their transparency in the way that `transparency` says.
  /// The tests use it for trying the method which is only needed with older systems.
  init?(katexFolder: URL,
        idleTime: TimeInterval,
        maxCachedFormulas: Int,
        maxCacheBytes: Int,
        transparency: MathWebSession.Transparency) {
    guard FileManager.default.isReadableFile(atPath:
            katexFolder.appendingPathComponent("katex.min.js").path),
          FileManager.default.isReadableFile(atPath:
            katexFolder.appendingPathComponent("katex.min.css").path) else {
      return nil
    }
    self.cache = Cache(maxEntries: maxCachedFormulas, maxBytes: maxCacheBytes)
    self.session = MathWebSession(katexFolder: katexFolder,
                                  idleTime: idleTime,
                                  transparency: transparency)
  }

  /// Returns the image of the formula if it has been rendered before for the same font size and
  /// configuration (apart from the properties that only matter for showing the formula).
  public func cachedImage(for formula: MathFormula,
                          fontSize: Float = 14,
                          config: MathConfig = MathConfig())
                -> MathImage? {
    return self.cache.image(for: Key(formula: formula, fontSize: fontSize, render: config.renderKey))
  }

  /// Returns the error if KaTeX has rejected the formula before. Errors which do not depend on
  /// the formula (timeouts, cancellation, ...) are not remembered.
  public func cachedFailure(for formula: MathFormula,
                            fontSize: Float = 14,
                            config: MathConfig = MathConfig())
                -> MathError? {
    return self.cache.failure(for: Key(formula: formula, fontSize: fontSize, render: config.renderKey))
  }

  /// Removes all cached images and errors.
  public func clearCache() {
    self.cache.clear()
  }

  /// The number of cached results: rendered formulas and formulas which KaTeX rejected.
  public var cachedFormulaCount: Int {
    return self.cache.count
  }

  /// Stores an image in the cache, like the renderer would. The tests use this for images which
  /// were not drawn by a web view.
  func store(_ image: MathImage,
             for formula: MathFormula,
             fontSize: Float,
             config: MathConfig) {
    self.cache.store(image, for: Key(formula: formula,
                                     fontSize: fontSize,
                                     render: config.renderKey))
  }

  /// Renders the formulas which are not in the cache yet, and returns the results for all of them.
  /// The formulas are drawn together, which is much faster than rendering them one by one: a
  /// document with a hundred formulas takes a fraction of a second.
  ///
  /// The images are cached (as far as there is room), and formulas which KaTeX rejects are
  /// remembered as well, so the next call does not render them again. Failures that are not a
  /// property of the formula, such as timeouts, are not remembered.
  ///
  /// - Parameters:
  ///   - formulas: The formulas to render.
  ///   - fontSize: The font size in points of the text in which the formulas are shown. A
  ///               formula is rendered with it and scaled when it is shown in a different size.
  ///   - config: The configuration for the rendering.
  /// - Returns: The image or the error for each formula.
  public func render(_ formulas: [MathFormula],
                     fontSize: Float = 14,
                     config: MathConfig = MathConfig()) async
                -> [MathFormula : Result<MathImage, MathError>] {
    return await self.renderFormulas(formulas, fontSize: fontSize, config: config).results
  }

  /// Like `render(_:fontSize:config:)`; also tells whether at least one image was drawn (as
  /// opposed to found in the cache).
  func renderFormulas(_ formulas: [MathFormula], fontSize: Float, config: MathConfig) async
        -> (results: [MathFormula : Result<MathImage, MathError>], rendered: Bool) {
    var results: [MathFormula : Result<MathImage, MathError>] = [:]
    var missing: [MathFormula] = []
    for formula in formulas where results[formula] == nil && !missing.contains(formula) {
      let key = Key(formula: formula, fontSize: fontSize, render: config.renderKey)
      if let image = self.cache.image(for: key) {
        results[formula] = .success(image)
      } else if let failure = self.cache.failure(for: key) {
        results[formula] = .failure(failure)
      } else {
        missing.append(formula)
      }
    }
    guard !missing.isEmpty else {
      return (results, false)
    }
    if Task.isCancelled {
      for formula in missing {
        results[formula] = .failure(.cancelled)
      }
      return (results, false)
    }
    var rendered = false
    let outcomes = await self.session.render(missing, fontSize: fontSize, config: config)
    for (formula, outcome) in zip(missing, outcomes) {
      let key = Key(formula: formula, fontSize: fontSize, render: config.renderKey)
      switch outcome {
        case .success(let image):
          self.cache.store(image, for: key)
          rendered = true
        case .failure(let error):
          switch error {
            case .syntaxError, .tooLong:
              self.cache.storeFailure(error, for: key)
            default:
              break
          }
      }
      results[formula] = outcome
    }
    return (results, rendered)
  }

  /// Renders the formulas without blocking the calling thread and reports the results via a
  /// completion handler. This is the variant of `render(_:fontSize:config:)` for code which does
  /// not use Swift concurrency.
  ///
  /// `completionHandler` is called exactly once, asynchronously (also if all formulas are cached
  /// already), and always on the main thread.
  public func render(_ formulas: [MathFormula],
                     fontSize: Float = 14,
                     config: MathConfig = MathConfig(),
                     completionHandler:
                       @escaping @Sendable ([MathFormula : Result<MathImage, MathError>]) -> Void) {
    Task {
      let results = await self.render(formulas, fontSize: fontSize, config: config)
      await MainActor.run {
        completionHandler(results)
      }
    }
  }
}

#else

/// `MathRenderer` draws formulas into images with a web view. This is only possible on macOS and
/// iOS: on other platforms, there is no shared renderer.
public final class MathRenderer: Sendable {

  /// There is no renderer on this platform.
  public static let shared: MathRenderer? = nil
}

#endif
