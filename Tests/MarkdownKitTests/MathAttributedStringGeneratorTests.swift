//
//  MathAttributedStringGeneratorTests.swift
//  MarkdownKitTests
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

#if os(macOS) || os(iOS)

import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import MarkdownKit

/// Tests for showing formulas in attributed strings: the placeholders in the HTML, their
/// replacement with attachments (position, size, colour), and, with a web view, the whole path
/// from Markdown to attachments.
final class MathAttributedStringGeneratorTests: XCTestCase {

  private func parse(_ markdown: String) -> Block {
    return MathMarkdownParser.standard.parse(markdown)
  }

  /// A renderer for tests that put images into its cache by hand.
  private func makeRenderer(maxCachedFormulas: Int = MathRenderer.defaultMaxCachedFormulas) throws -> MathRenderer {
    let folder = try XCTUnwrap(Resources.katexFolder)
    return try XCTUnwrap(MathRenderer(katexFolder: folder, maxCachedFormulas: maxCachedFormulas))
  }

  /// A PNG which is filled with black.
  private func blackPNG(width: Int, height: Int) throws -> Data {
    let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try XCTUnwrap(context.makeImage())
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
                                      data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }

  /// A fake rendering result which is `width` x `height` points large.
  private func makeImage(width: Int = 40, height: Int = 20, depth: CGFloat = 6, scale: CGFloat = 3) throws -> MathImage {
    return MathImage(pngData: try self.blackPNG(width: width * Int(scale), height: height * Int(scale)),
                     size: CGSize(width: width, height: height),
                     depth: depth,
                     scale: scale)
  }

  /// Puts a fake image for each formula into the cache of `renderer`.
  private func store(_ formulas: [MathFormula], in renderer: MathRenderer, fontSize: Float = 14,
                     config: MathConfig = MathConfig(), image: MathImage? = nil) throws {
    let image = try image ?? self.makeImage()
    for formula in formulas {
      renderer.store(image, for: formula, fontSize: fontSize, config: config)
    }
  }

  private func attachments(in string: NSAttributedString) -> [(range: NSRange, attachment: NSTextAttachment)] {
    var result: [(NSRange, NSTextAttachment)] = []
    string.enumerateAttribute(.attachment,
                              in: NSRange(location: 0, length: string.length)) { value, range, _ in
      if let attachment = value as? NSTextAttachment {
        result.append((range, attachment))
      }
    }
    return result
  }

  /// The colour of the opaque pixel of a PNG (red, green, blue, alpha, 0 to 255).
  private func inkColor(of png: Data) throws -> [UInt8] {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try data.withUnsafeMutableBytes { buffer in
      let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width,
                                            height: image.height, bitsPerComponent: 8,
                                            bytesPerRow: image.width * 4,
                                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    var best = 0
    for index in stride(from: 0, to: data.count, by: 4) where data[index + 3] > data[best + 3] {
      best = index
    }
    return Array(data[best..<(best + 4)])
  }

  private func data(of attachment: NSTextAttachment) throws -> Data {
    return try XCTUnwrap(attachment.contents ?? attachment.fileWrapper?.regularFileContents)
  }

  private func formula(_ tex: String, display: Bool = false) -> MathFormula {
    return MathFormula(tex: tex, display: display)
  }

  // MARK: Placeholders and fallbacks

  func testPlainGeneratorShowsFormulasAsCode() throws {
    let doc = self.parse("Text $x^2$ more\n\n$$\ny^3\n$$\n")
    let result = try XCTUnwrap(AttributedStringGenerator().generate(doc: doc))
    XCTAssertEqual(self.attachments(in: result).count, 0)
    XCTAssertTrue(result.string.contains("$x^2$"))
    XCTAssertTrue(result.string.contains("y^3"))
  }

  @MainActor
  func testTheImageOfAFormulaHasItsLatexAsAccessibilityLabel() throws {
    let renderer = try self.makeRenderer()
    try self.store([self.formula("x^2")], in: renderer)
    let generator = MathAttributedStringGenerator(mathRenderer: renderer)
    let result = try XCTUnwrap(generator.generate(doc: self.parse("Text $x^2$ more")))
    let image = try XCTUnwrap(self.attachments(in: result).first?.attachment.image)
    #if os(macOS)
    XCTAssertEqual(image.accessibilityDescription, "x^2")
    #else
    XCTAssertEqual(image.accessibilityLabel, "x^2")
    #endif
  }

  func testFormulasWhichHaveNotBeenRenderedAreShownAsCode() throws {
    let generator = MathAttributedStringGenerator(mathRenderer: try self.makeRenderer())
    let doc = self.parse("Text $x^2$ more\n\n$$\ny^3\n$$\n")
    let result = try XCTUnwrap(generator.generate(doc: doc))
    XCTAssertEqual(self.attachments(in: result).count, 0)
    XCTAssertTrue(result.string.contains("$x^2$"))
    XCTAssertTrue(result.string.contains("y^3"))
    XCTAssertFalse(result.string.contains("\u{E000}"))
    // Placeholders are only created for formulas with an image
    XCTAssertFalse(generator.htmlGenerator().generate(doc: doc).contains("MKM"))
  }

  func testRenderedFormulasAreReplacedByPlaceholdersInTheHtml() throws {
    let renderer = try self.makeRenderer()
    try self.store([self.formula("x^2"), self.formula("y^3", display: true)], in: renderer)
    let doc = self.parse("Text $x^2$ more $z$\n\n$$\ny^3\n$$\n")
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      let generator = MathAttributedStringGenerator(version: version, mathRenderer: renderer)
      let html = generator.htmlGenerator().generate(doc: doc)
      XCTAssertEqual(html.components(separatedBy: "MKM").count - 1, 2, "\(version)")
      XCTAssertTrue(html.contains("<code>$z$</code>"), "\(version)")
      XCTAssertFalse(html.contains("x^2"), "\(version)")
      // An inline placeholder is in a box with the width of the image (the importer sizes the
      // columns of tables by it), a block is not
      XCTAssertTrue(html.contains("<span style=\"display: inline-block; width: 40px;\">\u{E000}MKM"),
                    "\(version)")
      XCTAssertTrue(html.contains("<p style=\"text-align: center;\">\u{E000}MKM"), "\(version)")
    }
  }

  func testPinnedResultsAreUsedBeforeTheCache() throws {
    // The cache of the renderer is empty
    let generator = MathAttributedStringGenerator(mathRenderer: try self.makeRenderer())
    let doc = self.parse("Text $x^2$ more $z$\n\n$$\nq\n$$\n")
    var results = MathFormulaResults()
    results.images[self.formula("x^2")] = try self.makeImage()
    results.failures[self.formula("q", display: true)] = .syntaxError("KaTeX parse error: Oops\nmore")
    let htmlGenerator = generator.htmlGenerator()
    (htmlGenerator as? MathContextProviding)?.math.pin(results)
    let html = htmlGenerator.generate(doc: doc)
    XCTAssertEqual(html.components(separatedBy: "MKM").count - 1, 1)
    XCTAssertTrue(html.contains("Formula could not be rendered: KaTeX parse error: Oops"))
    XCTAssertFalse(html.contains("more</i>"))
    XCTAssertTrue(html.contains("<code>$z$</code>"))
  }

  // MARK: Attachments

  func testInlineFormulaIsAnAttachmentOnTheBaseline() throws {
    let renderer = try self.makeRenderer()
    try self.store([self.formula("x^2")], in: renderer)
    let generator = MathAttributedStringGenerator(mathRenderer: renderer)
    let result = try XCTUnwrap(generator.generate(doc: self.parse("Text $x^2$ more")))
    let found = self.attachments(in: result)
    XCTAssertEqual(found.count, 1)
    let attachment = try XCTUnwrap(found.first?.attachment)
    // The lower edge of the image is as far below the baseline as the formula reaches
    XCTAssertEqual(attachment.bounds, CGRect(x: 0, y: -6, width: 40, height: 20))
    XCTAssertNotNil(attachment.image)
    XCTAssertEqual(result.attribute(.mathSource, at: found[0].range.location, effectiveRange: nil) as? String,
                   "$x^2$")
    XCTAssertTrue(result.string.hasPrefix("Text "))
    XCTAssertTrue(result.string.contains(" more"))
    XCTAssertFalse(result.string.contains("x^2"))
    XCTAssertFalse(result.string.contains("\u{E000}"))
    // The data of the attachment is a PNG with the pixels of the image
    let decoded = try XCTUnwrap(CGImageSourceCreateWithData(try self.data(of: attachment) as CFData, nil))
    let pixels = try XCTUnwrap(CGImageSourceCreateImageAtIndex(decoded, 0, nil))
    XCTAssertEqual(pixels.width, 120)
    XCTAssertEqual(pixels.height, 60)
    // The line is not stretched by the line height multiple of the paragraph for the formula
    // (which is the only difference to a paragraph without a formula)
    let style = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    XCTAssertEqual(Double(style?.lineHeightMultiple ?? 0), 1.1, accuracy: 0.001)
  }

  func testFormulasAreScaledDownToTheWidthOfTheLine() throws {
    let renderer = try self.makeRenderer()
    try self.store([self.formula("x^2")], in: renderer)
    let generator = MathAttributedStringGenerator(mathRenderer: renderer)
    let result = try XCTUnwrap(generator.generate(doc: self.parse("Text $x^2$ more")))
    let attachment = try XCTUnwrap(self.attachments(in: result).first?.attachment)
    let wide = attachment.attachmentBounds(for: nil, proposedLineFragment: CGRect(x: 0, y: 0, width: 300, height: 20),
                                           glyphPosition: .zero, characterIndex: 5)
    XCTAssertEqual(wide, CGRect(x: 0, y: -6, width: 40, height: 20))
    let narrow = attachment.attachmentBounds(for: nil, proposedLineFragment: CGRect(x: 0, y: 0, width: 20, height: 20),
                                             glyphPosition: .zero, characterIndex: 5)
    XCTAssertEqual(narrow, CGRect(x: 0, y: -3, width: 20, height: 10))
  }

  func testMaxWidthScalesFormulasDown() throws {
    let renderer = try self.makeRenderer()
    let config = MathConfig(maxWidth: 20)
    try self.store([self.formula("x^2")], in: renderer, config: config)
    let generator = MathAttributedStringGenerator(mathRenderer: renderer)
    XCTAssertEqual(generator.mathConfig, MathConfig())
    let limited = MathAttributedStringGenerator(math: config, mathRenderer: renderer)
    let result = try XCTUnwrap(limited.generate(doc: self.parse("Text $x^2$ more")))
    let attachment = try XCTUnwrap(self.attachments(in: result).first?.attachment)
    XCTAssertEqual(attachment.bounds, CGRect(x: 0, y: -3, width: 20, height: 10))
  }

  func testBlockFormulaIsACenteredParagraphWithSpacing() throws {
    let renderer = try self.makeRenderer()
    try self.store([self.formula("\\frac{a}{b}", display: true)], in: renderer)
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      let generator = MathAttributedStringGenerator(version: version, mathRenderer: renderer)
      let result = try XCTUnwrap(generator.generate(doc: self.parse("Before\n\n$$\n\\frac{a}{b}\n$$\n\nAfter")))
      let found = self.attachments(in: result)
      XCTAssertEqual(found.count, 1, "\(version)")
      let attachment = try XCTUnwrap(found.first?.attachment)
      // A formula that is a paragraph of its own has no baseline offset
      XCTAssertEqual(attachment.bounds, CGRect(x: 0, y: 0, width: 40, height: 20), "\(version)")
      XCTAssertEqual(result.attribute(.mathSource, at: found[0].range.location, effectiveRange: nil) as? String,
                     "$$\n\\frac{a}{b}\n$$", "\(version)")
      let style = try XCTUnwrap(result.attribute(.paragraphStyle, at: found[0].range.location,
                                                 effectiveRange: nil) as? NSParagraphStyle)
      XCTAssertEqual(style.alignment, .center, "\(version)")
      XCTAssertEqual(style.lineHeightMultiple, 0, "\(version)")
      // At least 8 points to the text above and below, taking its paragraph spacing into account
      let above = try XCTUnwrap(result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
      XCTAssertGreaterThanOrEqual(above.paragraphSpacing + style.paragraphSpacingBefore, 8, "\(version)")
      let belowLocation = (result.string as NSString).range(of: "After").location
      let below = try XCTUnwrap(result.attribute(.paragraphStyle, at: belowLocation, effectiveRange: nil)
                                  as? NSParagraphStyle)
      XCTAssertGreaterThanOrEqual(style.paragraphSpacing + below.paragraphSpacingBefore, 8, "\(version)")
      XCTAssertTrue(result.string.contains("Before"), "\(version)")
      XCTAssertTrue(result.string.contains("After"), "\(version)")
    }
  }

  func testSpacingIsConfigurable() throws {
    let renderer = try self.makeRenderer()
    let config = MathConfig(spacing: 30)
    try self.store([self.formula("y", display: true)], in: renderer, config: config)
    let generator = MathAttributedStringGenerator(math: config, mathRenderer: renderer)
    let result = try XCTUnwrap(generator.generate(doc: self.parse("Before\n\n$$y$$\n\nAfter")))
    let found = try XCTUnwrap(self.attachments(in: result).first)
    let style = try XCTUnwrap(result.attribute(.paragraphStyle, at: found.range.location, effectiveRange: nil)
                                as? NSParagraphStyle)
    // 30 points to the text above and below, taking its paragraph spacing into account
    let above = try XCTUnwrap(result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
    XCTAssertGreaterThanOrEqual(above.paragraphSpacing + style.paragraphSpacingBefore, 30)
    let belowLocation = (result.string as NSString).range(of: "After").location
    let below = try XCTUnwrap(result.attribute(.paragraphStyle, at: belowLocation, effectiveRange: nil)
                                as? NSParagraphStyle)
    XCTAssertGreaterThanOrEqual(style.paragraphSpacing + below.paragraphSpacingBefore, 30)
  }

  func testFormulasWithTheDelimitersOfLaTeXAreShownLikeTheOthers() throws {
    let renderer = try self.makeRenderer()
    try self.store([self.formula("x"), self.formula("y", display: true),
                    self.formula("z", display: true)], in: renderer)
    let doc = LaTeXMarkdownParser.standard.parse("Text \\(x\\) and \\[y\\] more\n\n\\[\nz\n\\]\n")
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      let generator = MathAttributedStringGenerator(version: version, mathRenderer: renderer)
      let result = try XCTUnwrap(generator.generate(doc: doc))
      let found = self.attachments(in: result)
      XCTAssertEqual(found.count, 3, "\(version)")
      XCTAssertEqual(found.map { result.attribute(.mathSource, at: $0.range.location, effectiveRange: nil) as? String },
                     ["\\(x\\)", "\\[y\\]", "$$\nz\n$$"], "\(version)")
      XCTAssertFalse(result.string.contains("\\("), "\(version)")
    }
  }

  func testFormulasHaveTheColorOfTheirText() throws {
    let renderer = try self.makeRenderer()
    try self.store([self.formula("x"), self.formula("y")], in: renderer)
    let doc = self.parse("Text $x$ and a [link $y$](http://example.org)")
    for (css, expected) in [("#cc0000", [204, 0, 0, 255]), ("#000000", [0, 0, 0, 255]),
                            ("#3366ff", [51, 102, 255, 255])] as [(String, [UInt8])] {
      let generator = MathAttributedStringGenerator(fontColor: css, mathRenderer: renderer)
      let result = try XCTUnwrap(generator.generate(doc: doc))
      let found = self.attachments(in: result)
      XCTAssertEqual(found.count, 2, css)
      // The formula within the text has the color of the text
      XCTAssertEqual(try self.inkColor(of: self.data(of: found[0].attachment)), expected, css)
      // The formula within the link has the color of the link, which the importer chooses
      let linkColor = try XCTUnwrap(result.attribute(.foregroundColor, at: found[1].range.location,
                                                     effectiveRange: nil) as? HRColor, css)
      let space = CGColorSpace(name: CGColorSpace.sRGB)!
      let components = try XCTUnwrap(linkColor.cgColor.converted(to: space, intent: .defaultIntent, options: nil)?
                                                 .components)
      let linkExpected = components.prefix(3).map { UInt8(($0 * 255).rounded()) } + [255]
      XCTAssertEqual(try self.inkColor(of: self.data(of: found[1].attachment)), linkExpected, css)
      XCTAssertNotEqual(linkExpected, expected)
      XCTAssertNotNil(result.attribute(.link, at: found[1].range.location, effectiveRange: nil))
    }
  }

  func testFormulasAreScaledWithTheFontOfTheirText() throws {
    let renderer = try self.makeRenderer()
    try self.store([self.formula("x")], in: renderer)
    let generator = MathAttributedStringGenerator(mathRenderer: renderer)
    let result = try XCTUnwrap(generator.generate(doc: self.parse("# Heading $x$\n\nText $x$")))
    let found = self.attachments(in: result)
    XCTAssertEqual(found.count, 2)
    var heights: [CGFloat] = []
    for (range, attachment) in found {
      let font = try XCTUnwrap(result.attribute(.font, at: range.location, effectiveRange: nil) as? HRFont)
      XCTAssertEqual(attachment.bounds.height, 20 * font.pointSize / 14, accuracy: 0.001)
      XCTAssertEqual(attachment.bounds.width, 40 * font.pointSize / 14, accuracy: 0.001)
      XCTAssertEqual(attachment.bounds.origin.y, -6 * font.pointSize / 14, accuracy: 0.001)
      heights.append(attachment.bounds.height)
    }
    // The heading is larger than the text
    XCTAssertGreaterThan(heights[0], heights[1] * 1.3)
    XCTAssertEqual(heights[1], 20, accuracy: 0.001)
  }

  func testTextSizeMultiplierScalesFormulas() throws {
    let renderer = try self.makeRenderer()
    try self.store([self.formula("x")], in: renderer)
    let doc = self.parse("Text $x$")
    let normal = MathAttributedStringGenerator(mathRenderer: renderer)
    let bigger = MathAttributedStringGenerator(
      mathRenderer: renderer,
      renderingOptions: AttributedStringGenerator.RenderingOptions(textSizeMultiplier: 2))
    let one = try XCTUnwrap(self.attachments(in: try XCTUnwrap(normal.generate(doc: doc))).first)
    let two = try XCTUnwrap(self.attachments(in: try XCTUnwrap(bigger.generate(doc: doc))).first)
    XCTAssertGreaterThan(two.attachment.bounds.height, one.attachment.bounds.height * 1.5)
    XCTAssertEqual(two.attachment.bounds.width / two.attachment.bounds.height, 2, accuracy: 0.001)
  }

  func testFormulasInListsQuotesAndTables() throws {
    let renderer = try self.makeRenderer()
    try self.store([self.formula("a_1"), self.formula("b^2", display: true), self.formula("\\alpha"),
                    self.formula("x^2"), self.formula("\\sqrt{2}"), self.formula("c", display: true)],
                   in: renderer)
    let doc = self.parse("""
      - item with $a_1$
      - item with $$b^2$$ inline

      > quote with $\\alpha$

      | f | g |
      |---|---|
      | $x^2$ | $\\sqrt{2}$ |

      1. $$
         c
         $$
      """)
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      let generator = MathAttributedStringGenerator(version: version, mathRenderer: renderer)
      let result = try XCTUnwrap(generator.generate(doc: doc))
      XCTAssertEqual(self.attachments(in: result).count, 6, "\(version)")
      XCTAssertFalse(result.string.contains("\u{E000}"), "\(version)")
      XCTAssertTrue(result.string.contains("item with"), "\(version)")
      XCTAssertTrue(result.string.contains("quote with"), "\(version)")
    }
  }

  func testTextCannotForgeAPlaceholder() throws {
    let renderer = try self.makeRenderer()
    try self.store([self.formula("x")], in: renderer)
    let generator = MathAttributedStringGenerator(mathRenderer: renderer)
    let result = try XCTUnwrap(generator.generate(doc: self.parse("MKM0 and \u{E000}MKM0\u{E001} $x$")))
    XCTAssertEqual(self.attachments(in: result).count, 1)
    XCTAssertTrue(result.string.contains("MKM0 and"))
  }

  func testGeneratorsWithoutFormulasAreUnaffected() throws {
    let renderer = try self.makeRenderer()
    let doc = self.parse("# Title\n\nSome *text* with `code`.\n\n- a\n- b\n")
    let math = try XCTUnwrap(MathAttributedStringGenerator(mathRenderer: renderer).generate(doc: doc))
    let plain = try XCTUnwrap(AttributedStringGenerator().generate(doc: doc))
    XCTAssertEqual(math.string, plain.string)
    XCTAssertEqual(math.length, plain.length)
  }

  func testPreparationIsNeededIfFormulasCanBeRendered() throws {
    let generator = MathAttributedStringGenerator(mathRenderer: try self.makeRenderer())
    XCTAssertTrue(generator.needsPreparation)
    XCTAssertTrue(generator.formulaRenderer === generator.mathRenderer)
    XCTAssertFalse(AttributedStringGenerator().needsPreparation)
  }

  // MARK: Rendering in a web view

  #if canImport(WebKit)

  func testGenerateAsyncRendersFormulas() async throws {
    let generator = MathAttributedStringGenerator(fontSize: 16, fontColor: "#cc0000",
                                                  mathRenderer: try self.makeRenderer())
    let doc = self.parse("""
      Euler: $e^{i\\pi}+1=0$ and $\\frac{a}{b}$.

      $$
      \\int_0^1 x^2\\,dx = \\frac13
      $$

      Broken: $\\frac{$ and $5.
      """)
    let result = try await generator.generateAsync(doc: doc)
    let found = self.attachments(in: result)
    XCTAssertEqual(found.count, 3)
    for (range, attachment) in found {
      XCTAssertGreaterThan(attachment.bounds.width, 8)
      XCTAssertGreaterThan(attachment.bounds.height, 8)
      XCTAssertEqual(try self.inkColor(of: self.data(of: attachment)), [204, 0, 0, 255])
      XCTAssertNotNil(result.attribute(.mathSource, at: range.location, effectiveRange: nil))
    }
    // The inline formulas are on the baseline of the text, and the block formula is not
    XCTAssertLessThan(found[0].attachment.bounds.origin.y, 0)
    XCTAssertEqual(found[2].attachment.bounds.origin.y, 0)
    // A formula which KaTeX rejects stays as it is
    XCTAssertTrue(result.string.contains("$\\frac{$"))
    XCTAssertTrue(result.string.contains("$5."))
    XCTAssertFalse(result.string.contains("\u{E000}"))
  }

  func testGenerateAsyncShowsAllFormulasWhateverTheSizeOfTheCache() async throws {
    let renderer = try self.makeRenderer(maxCachedFormulas: 2)
    let generator = MathAttributedStringGenerator(mathRenderer: renderer)
    let doc = self.parse((0..<8).map { "Formula $n_{\($0)}$" }.joined(separator: "\n\n"))
    let result = try await generator.generateAsync(doc: doc)
    XCTAssertEqual(self.attachments(in: result).count, 8)
    XCTAssertEqual(renderer.cachedFormulaCount, 2)
  }

  func testBlockFormulaWhichKaTeXRejectsIsShownAsCodeWithANote() async throws {
    let generator = MathAttributedStringGenerator(mathRenderer: try self.makeRenderer())
    let result = try await generator.generateAsync(doc: self.parse("```math\n\\frac{\n```\n"))
    XCTAssertEqual(self.attachments(in: result).count, 0)
    XCTAssertTrue(result.string.contains("Formula could not be rendered: KaTeX parse error"))
    XCTAssertTrue(result.string.contains("\\frac{"))
  }

  func testGenerateAsyncWithCompletionHandler() async throws {
    let generator = MathAttributedStringGenerator(mathRenderer: try self.makeRenderer())
    let doc = self.parse("A $x^2$ and $$y^2$$")
    let expectation = expectation(description: "completion handler")
    nonisolated(unsafe) var count = 0
    generator.generateAsync(doc: doc) { result in
      if case .success(let string) = result {
        count = self.attachments(in: string).count
      }
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 60)
    XCTAssertEqual(count, 2)
  }

  func testPrepareMathMakesTheSynchronousMethodsShowFormulas() async throws {
    let generator = MathAttributedStringGenerator(mathRenderer: try self.makeRenderer())
    let doc = self.parse("A $x^2$ and\n\n$$\ny^2\n$$\n")
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(generator.generate(doc: doc))).count, 0)
    let rendered = await generator.prepareMath(in: doc)
    XCTAssertTrue(rendered)
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(generator.generate(doc: doc))).count, 2)
    // Nothing is left to do the second time
    let again = await generator.prepareMath(in: doc)
    XCTAssertFalse(again)
    guard case .document(let blocks) = doc else {
      return XCTFail("document expected")
    }
    let blocksAgain = await generator.prepareMath(in: blocks)
    XCTAssertFalse(blocksAgain)
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(generator.generate(blocks: blocks))).count, 2)
  }

  func testPrepareMathWithCompletionHandler() async throws {
    let generator = MathAttributedStringGenerator(mathRenderer: try self.makeRenderer())
    let doc = self.parse("A $x^2$")
    let expectation = expectation(description: "completion handler")
    nonisolated(unsafe) var rendered = false
    nonisolated(unsafe) var onMainThread = false
    generator.prepareMath(in: doc) { result in
      rendered = result
      onMainThread = Thread.isMainThread
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 60)
    XCTAssertTrue(rendered)
    XCTAssertTrue(onMainThread)
  }

  func testFormulasRenderedForOneFontSizeAreNotUsedForAnother() async throws {
    let renderer = try self.makeRenderer()
    let doc = self.parse("A $x^2$")
    let small = MathAttributedStringGenerator(fontSize: 12, mathRenderer: renderer)
    let large = MathAttributedStringGenerator(fontSize: 24, mathRenderer: renderer)
    _ = await small.prepareMath(in: doc)
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(small.generate(doc: doc))).count, 1)
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(large.generate(doc: doc))).count, 0)
    let smallImage = try XCTUnwrap(self.attachments(in: try XCTUnwrap(small.generate(doc: doc))).first)
    _ = await large.prepareMath(in: doc)
    let largeImage = try XCTUnwrap(self.attachments(in: try XCTUnwrap(large.generate(doc: doc))).first)
    XCTAssertEqual(largeImage.attachment.bounds.height / smallImage.attachment.bounds.height, 2, accuracy: 0.4)
  }

  #endif
}

#endif
