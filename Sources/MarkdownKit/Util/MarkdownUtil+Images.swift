//
//  MarkdownUtil+Images.swift
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

// The methods which draw diagrams and formulas into images (macOS and iOS: WebKit draws them).

extension MarkdownUtil {

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

  // MARK: Insets

  /// The widths in points of the space between the content of an image and its edges, for each
  /// edge.
  public struct Insets: Sendable, Equatable {

    /// Insets of width 0 on all edges.
    public static let none = Insets(0)

    /// The width of the inset at the upper edge.
    public var top: CGFloat

    /// The width of the inset at the left edge.
    public var left: CGFloat

    /// The width of the inset at the lower edge.
    public var bottom: CGFloat

    /// The width of the inset at the right edge.
    public var right: CGFloat

    /// Creates insets with the given widths in points.
    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
      self.top = top
      self.left = left
      self.bottom = bottom
      self.right = right
    }

    /// Creates insets which have the same width on all edges.
    public init(_ width: CGFloat) {
      self.init(top: width, left: width, bottom: width, right: width)
    }

    /// Creates insets with the same width at the left and the right edge, and the same width at
    /// the upper and the lower edge.
    public init(horizontal: CGFloat, vertical: CGFloat) {
      self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
  }

  /// Returns a copy of an image whose content has transparent space of exactly the given widths
  /// between it and the edges (the insets): the transparent area around the content of the image
  /// is removed, wherever it is wider than the inset asks for, and transparent space is added
  /// where it is narrower, for each edge individually. The images that Mermaid and KaTeX draw are
  /// not all alike in the space around their content; this gives them uniform insets, for
  /// example for showing them in a document.
  ///
  /// ```swift
  /// let image = try await util.mermaidImage("graph LR\n  A --> B")
  /// let padded = MarkdownUtil.image(image, withInsets: .init(horizontal: 8, vertical: 4))
  /// ```
  ///
  /// The content of an image is the area which has pixels that are not transparent: those with an
  /// alpha value of at most `transparentAlpha` count as transparent. The resolution of the image
  /// is not changed (`scale`), and the widths of the insets are rounded to whole pixels. The image
  /// has to be a bitmap image. The result is a new image: the setup of a formula for aligning it
  /// with text (see ``mathImage(_:display:fontSize:color:config:)``) is not carried over, as the
  /// baseline moves with the insets.
  ///
  /// - Parameters:
  ///   - image: An image with a transparent background.
  ///   - insets: The widths of the space around the content in points.
  ///   - transparentAlpha: The pixels whose alpha value (0 to 255) is at most this value count as
  ///                       transparent. The default, 4, ignores the faint edges that antialiasing
  ///                       creates; 0 counts every pixel that is not completely transparent.
  /// - Returns: The image with the insets, or `nil` if the image has no content (it is completely
  ///            transparent) or is not a bitmap image.
  public static func image(_ image: HRImage,
                           withInsets insets: Insets,
                           transparentAlpha: UInt8 = 4) -> HRImage? {
    guard let (bitmap, scale) = Self.bitmap(of: image) else {
      return nil
    }
    func pixels(_ points: CGFloat) -> Int {
      return max(0, Int((points * scale).rounded()))
    }
    guard let result = bitmap.withInsets(top: pixels(insets.top),
                                         left: pixels(insets.left),
                                         bottom: pixels(insets.bottom),
                                         right: pixels(insets.right),
                                         transparentAlpha: transparentAlpha) else {
      return nil
    }
    #if os(macOS)
    let size = NSSize(width: CGFloat(result.width) / scale, height: CGFloat(result.height) / scale)
    let copy = NSImage(cgImage: result, size: size)
    // The size of the representation is the size in points, as it is for the images which are
    // created from PNG data (see `makeImage`)
    for representation in copy.representations {
      representation.size = size
    }
    return copy
    #else
    return UIImage(cgImage: result, scale: scale, orientation: .up)
    #endif
  }

  /// The bitmap of an image, and the number of its pixels per point. Returns `nil` if the image
  /// has no bitmap.
  private static func bitmap(of image: HRImage) -> (bitmap: CGImage, scale: CGFloat)? {
    #if os(macOS)
    // The representation with the most pixels
    let representations = image.representations.compactMap { $0 as? NSBitmapImageRep }
    var cgImage = representations.max { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }?.cgImage
    if cgImage == nil {
      var rect = CGRect(origin: .zero, size: image.size)
      cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
    guard let cgImage, image.size.width > 0 else {
      return nil
    }
    return (cgImage, CGFloat(cgImage.width) / image.size.width)
    #else
    var source = image
    if image.imageOrientation != .up {
      // Draw the image as it is shown
      let format = UIGraphicsImageRendererFormat()
      format.scale = image.scale
      format.opaque = false
      source = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
        image.draw(at: .zero)
      }
    }
    guard let cgImage = source.cgImage else {
      return nil
    }
    return (cgImage, source.scale)
    #endif
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
