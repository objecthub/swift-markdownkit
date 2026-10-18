//
//  MathContext.swift
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

import Foundation

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

#if canImport(WebKit) && (os(macOS) || os(iOS))
import CoreGraphics
import ImageIO
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import UniformTypeIdentifiers
#endif

extension NSAttributedString.Key {

  /// The attribute of the attachment of a formula that ``MathAttributedStringGenerator`` creates.
  /// Its value is the formula as it was written in the Markdown text, including the dollar signs,
  /// as a `String`. It is there for clients which want to turn the attributed string back into
  /// text, for example when the user copies it.
  public static let mathSource = NSAttributedString.Key("MarkdownKit.mathSource")
}

///
/// The results of rendering the formulas of a document (via some "prepare" method): the images
/// of the formulas that were rendered, and the errors of the formulas which KaTeX rejected. An
/// HTML generator that was given them (see `MathContext.pin(_:)`) does not depend on the cache
/// of the ``MathRenderer``, which may drop some of them in the meantime.
///
struct MathFormulaResults: Sendable {

  /// The images of the formulas.
  var images: [MathFormula : MathImage] = [:]

  /// The errors of the formulas which KaTeX rejected.
  var failures: [MathFormula : MathError] = [:]

  /// True if at least one formula was rendered while the results were collected, i.e. if it was
  /// not in the cache of the renderer.
  var rendered = false
}

///
/// Keeps track of the formulas which an HTML generator has put into the HTML. The system's HTML
/// importer cannot place images with a given size and baseline, so the HTML contains a piece of
/// text instead of an image. Once the HTML has been turned into an attributed string,
/// `replacePlaceholders(in:)` replaces each of these pieces of text with an `NSTextAttachment`
/// whose image has the colour of the text around it.
///
/// Each context uses a random token for its placeholders, so placeholders cannot be forged by
/// the text of a Markdown document.
///
public final class MathContext: @unchecked Sendable {

  private struct Entry {
    let token: String
    let formula: MathFormula
    let image: MathImage
    let source: String
    let block: Bool
  }

  private let lock = NSLock()
  private let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
  private var entries: [Entry] = []
  private var pinnedImages: [MathFormula : MathImage] = [:]
  private var pinnedFailures: [MathFormula : MathError] = [:]

  /// The configuration of the generator that created this context.
  let config: MathConfig

  /// The renderer whose cache is consulted for formulas that were not pinned.
  let renderer: MathRenderer?

  /// The font size in points for which the images were rendered.
  let fontSize: Float

  /// The CSS colour of the text of the generator: the colour of formulas whose text has none.
  let fontColor: String

  init(config: MathConfig, renderer: MathRenderer?, fontSize: Float, fontColor: String) {
    self.config = config
    self.renderer = renderer
    self.fontSize = fontSize
    self.fontColor = fontColor
  }
  
  /// Creates the context for an HTML generator of `generator`.
  convenience init(for generator: AttributedStringGenerator) {
    let math = generator as? MathAttributedStringGenerator
    self.init(config: math?.mathConfig ?? MathConfig(),
              renderer: math?.formulaRenderer,
              fontSize: generator.fontSize,
              fontColor: generator.fontColor)
  }
  
  /// Remembers the results of rendering the formulas of a document. The HTML generator uses
  /// them before it looks into the cache of the renderer, whose entries may have been dropped
  /// since the formulas were rendered if the document has many formulas.
  func pin(_ results: MathFormulaResults) {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    self.pinnedImages.merge(results.images) { _, new in new }
    self.pinnedFailures.merge(results.failures) { _, new in new }
  }

  /// The image of a formula: the pinned one, or the one in the cache of the renderer.
  func image(for formula: MathFormula) -> MathImage? {
    self.lock.lock()
    let pinned = self.pinnedImages[formula]
    self.lock.unlock()
    if let pinned {
      return pinned
    }
    #if canImport(WebKit) && (os(macOS) || os(iOS))
    return self.renderer?.cachedImage(for: formula, fontSize: self.fontSize, config: self.config)
    #else
    return nil
    #endif
  }

  /// The error with which KaTeX rejected a formula.
  func failure(for formula: MathFormula) -> MathError? {
    self.lock.lock()
    let pinned = self.pinnedFailures[formula]
    self.lock.unlock()
    if let pinned {
      return pinned
    }
    #if canImport(WebKit) && (os(macOS) || os(iOS))
    return self.renderer?.cachedFailure(for: formula, fontSize: self.fontSize, config: self.config)
    #else
    return nil
    #endif
  }

  /// True if no formula was placed into the HTML.
  var isEmpty: Bool {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    return self.entries.isEmpty
  }

  /// Returns a text which stands for the image of `formula`. `source` is the formula as it was
  /// written; `block` is true if the formula is a paragraph of its own.
  func placeholder(for formula: MathFormula,
                   image: MathImage,
                   source: String,
                   block: Bool) -> String {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    // The characters are in a private use area; the token ends in a character that cannot be
    // part of the nonce or the index so that no token is a prefix of another.
    let token = "\u{E000}MKM\(self.nonce)\(self.entries.count)\u{E001}"
    self.entries.append(Entry(token: token,
                              formula: formula,
                              image: image,
                              source: source,
                              block: block))
    return token
  }

  #if !(canImport(WebKit) && (os(macOS) || os(iOS)))

  /// There are no images of formulas on this platform.
  func replacePlaceholders(in string: NSAttributedString) -> NSAttributedString {
    return string
  }

  #else

  /// A colour with red, green, blue and alpha in the sRGB colour space.
  private struct RGBA: Hashable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    static let black = RGBA(red: 0, green: 0, blue: 0, alpha: 1)

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
      self.red = red
      self.green = green
      self.blue = blue
      self.alpha = alpha
    }

    init?(_ color: HRColor) {
      guard let converted = color.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                    intent: .defaultIntent,
                                                    options: nil),
            let components = converted.components,
            components.count >= 4 else {
        return nil
      }
      self.init(red: components[0], green: components[1], blue: components[2], alpha: components[3])
    }
  }

  private struct BakeKey: Hashable {
    let formula: MathFormula
    let color: RGBA
    let block: Bool
  }

  /// The PNG data of a formula in some colour, and the image for the attachment.
  private struct Baked {
    let png: Data
    #if os(macOS)
    let image: NSImage?
    #else
    let image: UIImage?
    #endif
  }

  ///
  /// The attachment which shows a formula. Its `bounds` are the size of the formula, with the
  /// baseline of the formula on the baseline of the text. In addition, a formula that is wider
  /// than the line it is on is scaled down to the width of the line whenever the text is laid
  /// out (the text view can be resized later; a text view does not scale attachments by
  /// itself).
  ///
  private final class MathTextAttachment: NSTextAttachment {

    /// The size in points at which the formula is shown if there is enough room.
    var formulaSize: CGSize = .zero

    /// The distance in points from the lower edge of the formula up to its baseline, or, for a
    /// formula that is a paragraph of its own, 0.
    var depth: CGFloat = 0

    /// Returns the bounds of the formula, scaled down so that it is at most `width` points wide.
    func fittedBounds(width: CGFloat) -> CGRect {
      var factor: CGFloat = 1
      if self.formulaSize.width > 0, width > 0, self.formulaSize.width > width {
        factor = width / self.formulaSize.width
      }
      return CGRect(x: 0,
                    y: -self.depth * factor,
                    width: self.formulaSize.width * factor,
                    height: self.formulaSize.height * factor)
    }

    override func attachmentBounds(for textContainer: NSTextContainer?,
                                   proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint,
                                   characterIndex charIndex: Int) -> CGRect {
      guard self.formulaSize.width > 0 else {
        return super.attachmentBounds(for: textContainer,
                                      proposedLineFragment: lineFrag,
                                      glyphPosition: position,
                                      characterIndex: charIndex)
      }
      return self.fittedBounds(width: lineFrag.width)
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    override func attachmentBounds(for attributes: [NSAttributedString.Key : Any],
                                   location: any NSTextLocation,
                                   textContainer: NSTextContainer?,
                                   proposedLineFragment: CGRect,
                                   position: CGPoint) -> CGRect {
      guard self.formulaSize.width > 0 else {
        return super.attachmentBounds(for: attributes,
                                      location: location,
                                      textContainer: textContainer,
                                      proposedLineFragment: proposedLineFragment,
                                      position: position)
      }
      return self.fittedBounds(width: proposedLineFragment.width)
    }
  }

  /// Returns a copy of `string` in which each placeholder is replaced by an attachment with the
  /// image of its formula, in the colour of the text of the placeholder and scaled to its font
  /// size. The attachment gets the other attributes of the placeholder text, such as the paragraph
  /// style or a link.
  func replacePlaceholders(in string: NSAttributedString) -> NSAttributedString {
    self.lock.lock()
    let entries = self.entries
    self.lock.unlock()
    guard !entries.isEmpty else {
      return string
    }
    let fallback = HRColor.from(cssColor: self.fontColor).flatMap { RGBA($0) } ?? .black
    var baked: [BakeKey : Baked] = [:]
    let result = NSMutableAttributedString(attributedString: string)
    for entry in entries {
      let range = (result.string as NSString).range(of: entry.token)
      guard range.location != NSNotFound else {
        continue
      }
      var attributes = result.attributes(at: range.location, effectiveRange: nil)
      attributes[.attachment] = nil
      // The colour of the text around the formula, and the size of its font relative to the
      // font size for which the formula was drawn (headings are larger, and so is text if the
      // text size multiplier asks for it)
      let color = (attributes[.foregroundColor] as? HRColor).flatMap { RGBA($0) } ?? fallback
      var scale: CGFloat = 1
      if let font = attributes[.font] as? HRFont, self.fontSize > 0 {
        scale = font.pointSize / CGFloat(self.fontSize)
      }
      // The line height multiple of the text (`AttributedStringGenerator.lineSpacing`) would
      // also scale the height of a formula that is a paragraph of its own
      if entry.block,
         let style = attributes[.paragraphStyle] as? NSParagraphStyle,
         style.lineHeightMultiple != 0,
         let copy = style.mutableCopy() as? NSMutableParagraphStyle {
        copy.lineHeightMultiple = 0
        attributes[.paragraphStyle] = copy
      }
      let key = BakeKey(formula: entry.formula, color: color, block: entry.block)
      let image: Baked
      if let known = baked[key] {
        image = known
      } else {
        image = self.bake(entry.image, color: color, accessibility: entry.formula.tex)
        baked[key] = image
      }
      let replacement = NSMutableAttributedString(
                          attachment: self.attachment(for: entry, baked: image, scale: scale))
      let all = NSRange(location: 0, length: replacement.length)
      replacement.addAttributes(attributes, range: all)
      replacement.addAttribute(.mathSource, value: entry.source, range: all)
      result.replaceCharacters(in: range, with: replacement)
      if entry.block {
        self.addSpacing(to: result, aroundParagraphAt: range.location)
      }
    }
    return result
  }

  /// Makes sure that there is at least `spacing` points between the paragraph at `location`
  /// and the paragraphs above and below it. The paragraph spacing of the neighbors counts, like
  /// the margins of paragraphs in a web page do. The system's HTML importer does not provide
  /// this: it ignores the top margin of a paragraph.
  private func addSpacing(to text: NSMutableAttributedString, aroundParagraphAt location: Int) {
    let spacing = self.config.spacing
    let paragraph = (text.string as NSString).paragraphRange(for: NSRange(location: location,
                                                                          length: 1))
    func style(at index: Int) -> NSParagraphStyle? {
      return text.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle
    }
    let current = style(at: paragraph.location)
    let result = (current?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
    if paragraph.location > 0 {
      let above = style(at: paragraph.location - 1)?.paragraphSpacing ?? 0
      result.paragraphSpacingBefore = max(result.paragraphSpacingBefore, spacing - above)
    }
    if paragraph.upperBound < text.length {
      let below = style(at: paragraph.upperBound)?.paragraphSpacingBefore ?? 0
      result.paragraphSpacing = max(result.paragraphSpacing, spacing - below)
    }
    text.addAttribute(.paragraphStyle, value: result, range: paragraph)
  }

  /// Creates the attachment for a formula.
  private func attachment(for entry: Entry, baked: Baked, scale: CGFloat) -> NSTextAttachment {
    var factor = scale > 0 ? scale : 1
    if let maxWidth = self.config.maxWidth,
       maxWidth > 0,
       entry.image.size.width * factor > maxWidth {
      factor = maxWidth / entry.image.size.width
    }
    let size = CGSize(width: entry.image.size.width * factor,
                      height: entry.image.size.height * factor)
    // The data makes the attachment survive copy and paste and archiving
    let attachment = MathTextAttachment(data: baked.png, ofType: UTType.png.identifier)
    attachment.formulaSize = size
    // A formula within a line sits on the baseline of the text; a paragraph of its own does not
    attachment.depth = entry.block ? 0 : entry.image.depth * factor
    attachment.image = baked.image
    attachment.bounds = CGRect(x: 0, y: -attachment.depth, width: size.width, height: size.height)
    return attachment
  }

  /// Gives the black image of a formula the given colour. A text view cannot do this: a template
  /// image is only tinted by iOS, not by macOS. The result is the PNG data (for the attachment)
  /// and the image that is shown.
  private func bake(_ image: MathImage, color: RGBA, accessibility: String) -> Baked {
    var data = image.pngData
    if color != .black, let colored = MathContext.tint(png: image.pngData, color: color) {
      data = colored
    }
    #if os(macOS)
    let platformImage = NSImage(data: data)
    platformImage?.size = image.size
    platformImage?.accessibilityDescription = accessibility
    #else
    let platformImage = UIImage(data: data, scale: image.scale)
    platformImage?.accessibilityLabel = accessibility
    #endif
    return Baked(png: data, image: platformImage)
  }

  /// Returns the PNG data of a copy of the black image `png` which has the colour `color`.
  /// The image is a mask: black pixels with the alpha value of the formula. Drawing a colour with
  /// the blend mode "source in" keeps the alpha values and replaces the colour.
  private static func tint(png: Data, color: RGBA) -> Data? {
    guard let source = CGImageSourceCreateWithData(png as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil,
                                  width: image.width,
                                  height: image.height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
      return nil
    }
    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    context.draw(image, in: rect)
    context.setBlendMode(.sourceIn)
    context.setFillColor(CGColor(srgbRed: color.red, green: color.green, blue: color.blue,
                                 alpha: color.alpha))
    context.fill(rect)
    guard let tinted = context.makeImage() else {
      return nil
    }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output,
                                                             UTType.png.identifier as CFString,
                                                             1,
                                                             nil) else {
      return nil
    }
    CGImageDestinationAddImage(destination, tinted, nil)
    guard CGImageDestinationFinalize(destination) else {
      return nil
    }
    return output as Data
  }

  #endif
}

#endif
