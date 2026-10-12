//
//  MermaidRenderer.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 12/10/2026.
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

import Foundation

///
/// A rendered Mermaid diagram: a PNG image with transparent background.
///
public struct MermaidImage: Equatable, Sendable {

  /// The PNG data of the image.
  public let pngData: Data

  /// The size of the diagram in points. The image has `scale` times as many pixels.
  public let size: CGSize

  /// The number of pixels per point.
  public let scale: CGFloat

  public init(pngData: Data, size: CGSize, scale: CGFloat) {
    self.pngData = pngData
    self.size = size
    self.scale = scale
  }
}

///
/// Turns [Mermaid](https://mermaid.js.org) diagram descriptions into images.
///
/// Mermaid is a JavaScript library which needs a web browser's DOM and layout engine to
/// measure text. In contrast to `SyntaxHighlighter` (which runs Highlight.js in
/// JavaScriptCore), `MermaidRenderer` therefore loads the bundled `mermaid.min.js` into a
/// headless `WKWebView`. This is only available on macOS and iOS. The web view is created when
/// the first diagram is rendered, is used for all following diagrams, and is released when it
/// has been idle for a while. Its content cannot access the network, and it has no connection to
/// the rest of the application.
///
/// Rendering is asynchronous. Images are cached, so rendering a diagram a second time (with the
/// same configuration) is immediate; `AttributedStringGenerator` only looks at that cache when
/// it generates attributed strings synchronously (see `AttributedStringGenerator.prepareDiagrams`).
///
/// A `MermaidRenderer` is `Sendable`. It can be used from any thread or task; the requests are
/// processed one after the other.
///
/// Example:
/// ```swift
/// if let renderer = MermaidRenderer.shared {
///   let image = try await renderer.render("graph LR\n  A --> B")
///   try image.pngData.write(to: url)
/// }
/// ```
///
public final class MermaidRenderer: @unchecked Sendable {

  /// The shared `MermaidRenderer`, using the `mermaid.min.js` which ships with this package.
  /// Returns `nil` if that resource cannot be found, or if the platform does not support
  /// rendering diagrams (everything but macOS and iOS).
  ///
  /// - Note: The renderer is created lazily on first access. The web view that does the work
  ///   is only created when the first diagram is rendered.
  public static let shared: MermaidRenderer? = {
  #if canImport(WebKit) && (os(macOS) || os(iOS))
    guard let url = Resources.bundle?.url(forResource: "mermaid.min",
                                                     withExtension: "js") else {
      return nil
    }
    return MermaidRenderer(mermaidJSURL: url)
  #else
    return nil
  #endif
  }()

  /// Key of the cache.
  private struct Key: Hashable, Sendable {
    let source: String
    let render: MermaidConfig.RenderKey
  }

  /// A cache for rendered diagrams, and for diagrams which Mermaid rejected. It holds at most
  /// `maxEntries` entries (images and errors) and `maxBytes` bytes of image data; if there are
  /// more, the entries which have not been used for the longest time are dropped first (an
  /// entry is used when it is added and when it is looked up). The newest entry always stays,
  /// even if it alone is larger than `maxBytes`.
  private final class Cache: @unchecked Sendable {

    private struct Entry {
      var image: MermaidImage?
      var failure: MermaidError?
      var lastUse: UInt64
    }

    private let lock = NSLock()
    private let maxEntries: Int
    private let maxBytes: Int
    private var entries: [Key: Entry] = [:]
    private var bytes = 0
    private var clock: UInt64 = 0

    init(maxEntries: Int, maxBytes: Int) {
      self.maxEntries = max(1, maxEntries)
      self.maxBytes = max(1, maxBytes)
    }

    /// The number of entries (images and errors).
    var count: Int {
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      return self.entries.count
    }

    /// The size of the images in bytes.
    var byteCount: Int {
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      return self.bytes
    }

    func image(for key: Key) -> MermaidImage? {
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      guard var entry = self.entries[key], let image = entry.image else {
        return nil
      }
      self.clock += 1
      entry.lastUse = self.clock
      self.entries[key] = entry
      return image
    }

    func failure(for key: Key) -> MermaidError? {
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      guard var entry = self.entries[key], let failure = entry.failure else {
        return nil
      }
      self.clock += 1
      entry.lastUse = self.clock
      self.entries[key] = entry
      return failure
    }

    func store(_ image: MermaidImage, for key: Key) {
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      self.replace(key, with: Entry(image: image, failure: nil, lastUse: 0))
      self.bytes += image.pngData.count
      self.evict()
    }

    func storeFailure(_ error: MermaidError, for key: Key) {
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      self.replace(key, with: Entry(image: nil, failure: error, lastUse: 0))
      self.evict()
    }

    func clear() {
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      self.entries.removeAll()
      self.bytes = 0
    }

    /// Sets the entry for `key`, taking the size of an entry that is replaced into account.
    /// The caller holds the lock and adds the size of a new image.
    private func replace(_ key: Key, with entry: Entry) {
      if let old = self.entries[key], let image = old.image {
        self.bytes -= image.pngData.count
      }
      self.clock += 1
      var entry = entry
      entry.lastUse = self.clock
      self.entries[key] = entry
    }

    /// Drops the entries which have not been used for the longest time until the limits are
    /// met. The caller holds the lock.
    private func evict() {
      while self.entries.count > 1 &&
            (self.entries.count > self.maxEntries || self.bytes > self.maxBytes),
            let oldest = self.entries.min(by: { $0.value.lastUse < $1.value.lastUse }) {
        self.entries.removeValue(forKey: oldest.key)
        if let image = oldest.value.image {
          self.bytes -= image.pngData.count
        }
      }
    }
  }

  /// The default for `idleTime`: 60 seconds.
  public static let defaultIdleTime: TimeInterval = 60

  /// The default for `maxCachedDiagrams`: 128 diagrams.
  public static let defaultMaxCachedDiagrams = 128

  /// The default for `maxCacheBytes`: 64 MiB.
  public static let defaultMaxCacheBytes = 64 * 1024 * 1024

  private let cache: Cache

  #if canImport(WebKit) && (os(macOS) || os(iOS))
  private let session: MermaidWebSession
  #endif

  /// Creates a renderer which uses the Mermaid JavaScript library at `mermaidJSURL` (an
  /// "IIFE" build such as `mermaid.min.js`, which defines the global `mermaid`).
  ///
  /// - Parameters:
  ///   - mermaidJSURL: The location of the JavaScript library.
  ///   - cachesScript: If `true` (the default), the library is read once and kept in memory
  ///                   (about 3.6 MB for `mermaid.min.js`) for as long as the renderer exists.
  ///                   This makes creating the web view, which happens for the first diagram
  ///                   and again after the web view was released or failed, a little faster.
  ///                   If `false`, the file is read every time a web view is created, and
  ///                   nothing is kept in memory.
  ///   - idleTime: The time in seconds after which the web view is released if no diagram
  ///                   is being rendered. That frees the memory of the web view and of its web
  ///                   content process; the next diagram needs a new web view, which makes it
  ///                   take a few hundred milliseconds longer. 0 (or less) releases the web view
  ///                   as soon as no request is waiting for it, `.infinity` never releases it.
  ///                   The default is `defaultIdleTime`.
  ///   - maxCachedDiagrams: The maximal number of results that are cached, i.e. rendered
  ///                   diagrams and diagrams which Mermaid rejected. When there are more, the
  ///                   ones which were used least recently are dropped. At least 1; the default
  ///                   is `defaultMaxCachedDiagrams`. Diagrams are only shown by
  ///                   `AttributedStringGenerator` while they are in the cache, so it should be
  ///                   at least the number of diagrams in the largest document; the diagrams
  ///                   of a document that does not fit are not all shown.
  ///   - maxCacheBytes: The maximal total size of the cached PNG images in bytes (a diagram
  ///                   typically takes between 10 and 200 KB). When it is exceeded, the images
  ///                   which were used least recently are dropped; the last diagram that was
  ///                   added is kept even if it is larger. At least 1; the default is
  ///                   `defaultMaxCacheBytes`.
  /// - Returns: A renderer, or `nil` if the file cannot be read or the platform does not
  ///            support rendering diagrams.
  public init?(mermaidJSURL: URL,
               cachesScript: Bool = true,
               idleTime: TimeInterval = MermaidRenderer.defaultIdleTime,
               maxCachedDiagrams: Int = MermaidRenderer.defaultMaxCachedDiagrams,
               maxCacheBytes: Int = MermaidRenderer.defaultMaxCacheBytes) {
    self.cache = Cache(maxEntries: maxCachedDiagrams, maxBytes: maxCacheBytes)
  #if canImport(WebKit) && (os(macOS) || os(iOS))
    guard FileManager.default.isReadableFile(atPath: mermaidJSURL.path) else {
      return nil
    }
    self.session = MermaidWebSession(scriptURL: mermaidJSURL,
                                     cachesScript: cachesScript,
                                     idleTime: idleTime)
  #else
    return nil
  #endif
  }

  /// Returns the image of the diagram if it has been rendered before with the same
  /// configuration (apart from `maxWidth` and `timeout`).
  public func cachedImage(for source: String,
                          config: MermaidConfig = .default) -> MermaidImage? {
    return self.cache.image(for: Key(source: source, render: config.renderKey))
  }

  /// Returns the error if Mermaid has rejected the diagram before. Errors which do not depend
  /// on the diagram (timeouts, cancellation, ...) are not remembered.
  public func cachedFailure(for source: String,
                            config: MermaidConfig = .default) -> MermaidError? {
    return self.cache.failure(for: Key(source: source, render: config.renderKey))
  }

  /// Removes all cached images and errors.
  public func clearCache() {
    self.cache.clear()
  }

  /// The number of cached results: rendered diagrams and diagrams which Mermaid rejected.
  public var cachedDiagramCount: Int {
    return self.cache.count
  }

  /// The total size in bytes of the cached PNG images.
  public var cachedByteCount: Int {
    return self.cache.byteCount
  }

  /// Adds an image to the cache, as if the diagram had been rendered. Used by tests.
  internal func store(_ image: MermaidImage, for source: String, config: MermaidConfig) {
    self.cache.store(image, for: Key(source: source, render: config.renderKey))
  }

  /// Adds an error to the cache, as if Mermaid had rejected the diagram. Used by tests.
  internal func storeFailure(_ error: MermaidError, for source: String, config: MermaidConfig) {
    self.cache.storeFailure(error, for: Key(source: source, render: config.renderKey))
  }

  /// Renders a diagram and returns its image. If the diagram has been rendered before, the
  /// cached image is returned at once. Code which does not use Swift concurrency can use
  /// `render(_:config:completionHandler:)`.
  ///
  /// - Parameters:
  ///   - source: The Mermaid diagram description (e.g. `"graph TD\n  A --> B"`).
  ///   - config: The configuration for the rendering.
  /// - Throws: A `MermaidError`.
  public func render(_ source: String,
                     config: MermaidConfig = .default) async throws -> MermaidImage {
    let key = Key(source: source, render: config.renderKey)
    if let image = self.cache.image(for: key) {
      return image
    }
    if let failure = self.cache.failure(for: key) {
      throw failure
    }
    if Task.isCancelled {
      throw MermaidError.cancelled
    }
  #if canImport(WebKit) && (os(macOS) || os(iOS))
    do {
      let image = try await self.session.render(source: source, config: config)
      self.cache.store(image, for: key)
      return image
    } catch let error as MermaidError {
      if case .syntaxError = error {
        self.cache.storeFailure(error, for: key)
      }
      throw error
    }
  #else
    throw MermaidError.unsupportedPlatform
  #endif
  }

  /// Renders a diagram without blocking the calling thread and reports the result via a
  /// completion handler. This is the variant of `render(_:config:)` for code which does not
  /// use Swift concurrency; see there for details.
  ///
  /// `completionHandler` is called exactly once, asynchronously (also if the image is cached
  /// already, or if diagrams are not supported on this platform), and always on the main
  /// thread, so it is safe to update the user interface or state which is confined to the main
  /// thread from it.
  ///
  /// - Parameters:
  ///   - source: The Mermaid diagram description (e.g. `"graph TD\n  A --> B"`).
  ///   - config: The configuration for the rendering.
  ///   - completionHandler: Called with the image or with a `MermaidError`.
  public func render(_ source: String,
                     config: MermaidConfig = .default,
                     completionHandler: @escaping (Result<MermaidImage, MermaidError>) -> Void) {
    // The completion handler is not used by anybody else
    nonisolated(unsafe) let handler = completionHandler
    Task {
      let result: Result<MermaidImage, MermaidError>
      do {
        result = .success(try await self.render(source, config: config))
      } catch let error as MermaidError {
        result = .failure(error)
      } catch {
        result = .failure(.renderingFailed(error.localizedDescription))
      }
      DispatchQueue.main.async {
        handler(result)
      }
    }
  }
}
