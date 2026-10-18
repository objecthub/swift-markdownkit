//
//  MarkdownImageUtil.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 18/10/2026.
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
#if os(macOS)
import AppKit
/// The image type of the platform: `NSImage` on macOS and `UIImage` on iOS.
public typealias HRImage = NSImage
#else
import UIKit
/// The image type of the platform: `NSImage` on macOS and `UIImage` on iOS.
public typealias HRImage = UIImage
#endif

///
/// `MarkdownImageUtil` draws Mermaid diagrams and mathematical formulas into images, without any
/// Markdown: given the source of a diagram or the LaTeX of a formula, it returns an `NSImage`
/// (macOS) or a `UIImage` (iOS), which can be shown in any view or saved to a file. It is
/// the place to start if you need these images outside of a Markdown document; the images are the
/// same as those in the attributed strings of ``AttributedStringGenerator`` and
/// ``MathAttributedStringGenerator``.
///
/// ```swift
/// let util = MarkdownImageUtil.standard
/// let diagram = try await util.mermaidImage("graph LR\n  A --> B")
/// let formula = try await util.mathImage("\\sum_{i=1}^n i = \\frac{n(n+1)}{2}",
///                                        display: true, fontSize: 16, color: .systemBlue)
/// ```
///
/// Rendering takes a moment, so the methods are asynchronous: each has a variant for Swift
/// concurrency, which throws a ``MermaidError`` or a ``MathError`` if the image cannot be drawn,
/// and a variant with a completion handler. The diagrams and formulas are drawn by a
/// ``MermaidRenderer`` and a ``MathRenderer``, which cache their results (see there). This
/// utility is available on macOS and iOS; WebKit draws the images.
///
public struct MarkdownImageUtil: Sendable {

  /// The utility which draws diagrams and formulas with the shared renderers
  /// (``MermaidRenderer/shared`` and ``MathRenderer/shared``).
  public static let standard = MarkdownImageUtil()

  /// The renderer that draws diagrams. If `nil`, ``MermaidRenderer/shared`` is used.
  public let mermaidRenderer: MermaidRenderer?

  /// The renderer that draws formulas. If `nil`, ``MathRenderer/shared`` is used.
  public let mathRenderer: MathRenderer?

  /// Creates a utility that draws diagrams and formulas with the given renderers. A renderer
  /// of your own lets you choose the limits of its cache and the time after which its web view is
  /// released.
  ///
  /// - Parameters:
  ///   - mermaidRenderer: The renderer for diagrams, or `nil` to use the shared one.
  ///   - mathRenderer: The renderer for formulas, or `nil` to use the shared one.
  public init(mermaidRenderer: MermaidRenderer? = nil, mathRenderer: MathRenderer? = nil) {
    self.mermaidRenderer = mermaidRenderer
    self.mathRenderer = mathRenderer
  }

  // MARK: Mermaid diagrams

  /// Draws a Mermaid diagram and returns its image. The image is as large in points as it is in
  /// an attributed string; its resolution is the `scale` of the configuration. If the diagram
  /// has been drawn before, the cached image is used.
  ///
  /// - Parameters:
  ///   - source: The Mermaid diagram description, for example `"graph TD\n  A --> B"`.
  ///   - config: The configuration for the diagram: theme, width, scale, and more. The default
  ///             draws a diagram for a light background; use ``MermaidConfig/dark`` for a dark one.
  /// - Returns: The image of the diagram, on a transparent background.
  /// - Throws: A ``MermaidError``; `.syntaxError` if Mermaid does not understand the diagram.
  public func mermaidImage(_ source: String,
                           config: MermaidConfig = .default) async throws -> sending HRImage {
    guard let renderer = self.mermaidRenderer ?? MermaidRenderer.shared else {
      throw MermaidError.resourcesMissing
    }
    let diagram = try await renderer.render(source, config: config)
    guard let image = Self.makeImage(png: diagram.pngData, size: diagram.size,
                                     scale: diagram.scale) else {
      throw MermaidError.renderingFailed("the image of the diagram could not be created")
    }
    return image
  }

  /// Draws a Mermaid diagram without blocking the calling thread and reports the image via a
  /// completion handler. This is the variant of ``mermaidImage(_:config:)`` for code which does
  /// not use Swift concurrency.
  ///
  /// `completionHandler` is called exactly once, asynchronously (also if the image is cached
  /// already), and always on the main thread.
  public func mermaidImage(_ source: String,
                           config: MermaidConfig = .default,
                           completionHandler:
                             @escaping (Result<HRImage, MermaidError>) -> Void) {
    let deliver = ImageHandler(completionHandler)
    Task {
      do {
        deliver(.success(try await self.mermaidImage(source, config: config)))
      } catch {
        deliver(.failure(error as? MermaidError ?? .renderingFailed("\(error)")))
      }
    }
  }

  // MARK: Formulas

  /// Draws a formula and returns its image, in the given color. The image is as large in points as
  /// it is in an attributed string whose text has the font size `fontSize`; its resolution is the
  /// `scale` of the configuration. If the formula has been drawn before, the cached image is used.
  ///
  /// The image is set up for aligning it with text: on macOS, its `alignmentRect` starts at the
  /// baseline of the formula, and on iOS, its `baselineOffsetFromBottom` is the distance from the
  /// lower edge to the baseline. Use ``MathRenderer/render(_:display:fontSize:config:)`` if you
  /// need the metrics of the image, such as the `depth` of the baseline.
  ///
  /// - Parameters:
  ///   - tex: The LaTeX of the formula, without dollar signs.
  ///   - display: True for display math, which is centered and uses larger operators; false for a
  ///              formula within a line of text.
  ///   - fontSize: The font size in points of the text in which the formula is shown.
  ///   - color: The color of the formula, black by default.
  ///   - config: The configuration for the formula: macros, scale, and more.
  /// - Returns: The image of the formula, on a transparent background.
  /// - Throws: A ``MathError``; `.syntaxError` if KaTeX does not understand the formula.
  public func mathImage(_ tex: String,
                        display: Bool = false,
                        fontSize: Float = 14,
                        color: HRColor? = nil,
                        config: MathConfig = MathConfig()) async throws -> sending HRImage {
    guard let renderer = self.mathRenderer ?? MathRenderer.shared else {
      throw MathError.resourcesMissing
    }
    let formula = try await renderer.render(tex, display: display, fontSize: fontSize, config: config)
    var png = formula.pngData
    if let color, let tinted = MathContext.tintedPNG(png, color: color) {
      png = tinted
    }
    guard let image = Self.makeImage(png: png, size: formula.size, scale: formula.scale,
                                     baselineDepth: formula.depth) else {
      throw MathError.renderingFailed("the image of the formula could not be created")
    }
    return image
  }

  /// Draws a formula without blocking the calling thread and reports the image via a completion
  /// handler. This is the variant of ``mathImage(_:display:fontSize:color:config:)`` for code
  /// which does not use Swift concurrency.
  ///
  /// `completionHandler` is called exactly once, asynchronously (also if the image is cached
  /// already), and always on the main thread.
  public func mathImage(_ tex: String,
                        display: Bool = false,
                        fontSize: Float = 14,
                        color: HRColor? = nil,
                        config: MathConfig = MathConfig(),
                        completionHandler: @escaping (Result<HRImage, MathError>) -> Void) {
    let deliver = ImageHandler(completionHandler)
    let color = Unchecked(color)
    Task {
      do {
        deliver(.success(try await self.mathImage(tex, display: display, fontSize: fontSize,
                                                  color: color.value, config: config)))
      } catch {
        deliver(.failure(error as? MathError ?? .renderingFailed("\(error)")))
      }
    }
  }

  // MARK: Images

  /// Creates the image of the platform from PNG data. `size` is the size in points, `scale` the
  /// number of pixels per point, and `baselineDepth` the distance in points from the lower edge up
  /// to the baseline of a formula.
  ///
  /// The PNG has `size` times `scale` pixels, so each of the two determines the other: macOS sets
  /// the size of the image (and does not need the scale), iOS sets the scale of the image (and does
  /// not need the size, which is the number of pixels divided by the scale).
  private static func makeImage(png: Data, size: CGSize, scale: CGFloat,
                                baselineDepth: CGFloat? = nil) -> HRImage? {
    #if os(macOS)
    guard let image = NSImage(data: png) else {
      return nil
    }
    // The PNG has a resolution of 72 dots per inch times `scale`, which gives the image its
    // size in points; make sure of it, so `scale` is not needed here
    image.size = size
    if let baselineDepth {
      image.alignmentRect = NSRect(x: 0, y: baselineDepth,
                                   width: size.width, height: max(0, size.height - baselineDepth))
    }
    return image
    #else
    // The size of the image in points is the number of pixels of the PNG divided by `scale`, which
    // is `size`: the renderers draw `size` times `scale` pixels. So `size` is not used here.
    guard let image = UIImage(data: png, scale: scale) else {
      return nil
    }
    if let baselineDepth {
      return image.withBaselineOffset(fromBottom: baselineDepth)
    }
    return image
    #endif
  }

  /// Delivers the result of a completion handler on the main thread. Images are not `Sendable`,
  /// but the image of a result is created by the call and used by nobody else.
  private struct ImageHandler<Failure: Error>: @unchecked Sendable {
    private let handler: (Result<HRImage, Failure>) -> Void

    init(_ handler: @escaping (Result<HRImage, Failure>) -> Void) {
      self.handler = handler
    }

    func callAsFunction(_ result: Result<HRImage, Failure>) {
      let result = Unchecked(result)
      DispatchQueue.main.async {
        self.handler(result.value)
      }
    }
  }

  /// Passes a value to another thread, for values which are not `Sendable` but which nobody else
  /// uses.
  private struct Unchecked<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
      self.value = value
    }
  }
}

#endif
