//
//  ListMarkerAlignmentTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 19/10/2026.
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

/// Tests for the alignment of the numbers and bullets of list items with the first line of their
/// items, if that line has an image which is taller than the text (such as a formula). The system
/// lays out the cells of the tables, which the HTML importer creates for lists, at their top.
@MainActor
final class ListMarkerAlignmentTests: XCTestCase {

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

  /// A generator which draws every formula as a (fake) image of 40 x 40 points, which reaches 10
  /// points below the baseline: a formula that is much taller than a line of text.
  private func makeGenerator(align: Bool = true) throws -> MathAttributedStringGenerator {
    let folder = try XCTUnwrap(Resources.katexFolder)
    let renderer = try XCTUnwrap(MathRenderer(katexFolder: folder))
    let image = MathImage(pngData: try self.blackPNG(width: 120, height: 120),
                          size: CGSize(width: 40, height: 40),
                          depth: 10,
                          scale: 3)
    renderer.store(image, for: MathFormula(tex: "\\frac{a}{b}", display: false), fontSize: 16,
                   config: MathConfig())
    return MathAttributedStringGenerator(fontSize: 16, mathRenderer: renderer, alignListMarkers: align)
  }

  private func generate(_ markdown: String, align: Bool = true) async throws -> NSAttributedString {
    return try await self.makeGenerator(align: align)
                        .generateAsync(doc: LaTeXMarkdownParser.standard.parse(markdown))
  }

  /// A text view that shows `string` at the given width, as the system lays it out.
  private func layout(of string: NSAttributedString, width: CGFloat) throws
                     -> (storage: NSTextStorage, layout: NSLayoutManager, apply: (CGFloat) -> Void) {
    #if os(macOS)
    let view = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 600))
    view.textContainer?.lineFragmentPadding = 0
    view.textContainer?.widthTracksTextView = false
    view.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
    view.textStorage?.setAttributedString(string)
    let layout = try XCTUnwrap(view.layoutManager)
    layout.ensureLayout(for: try XCTUnwrap(view.textContainer))
    let apply: (CGFloat) -> Void = { width in
      view.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
      layout.ensureLayout(for: view.textContainer!)
    }
    return (try XCTUnwrap(view.textStorage), layout, apply)
    #else
    let view = UITextView(frame: CGRect(x: 0, y: 0, width: width, height: 600))
    view.textContainerInset = .zero
    view.textContainer.lineFragmentPadding = 0
    view.attributedText = string
    let layout = view.layoutManager
    layout.ensureLayout(for: view.textContainer)
    let apply: (CGFloat) -> Void = { width in
      view.frame = CGRect(x: 0, y: 0, width: width, height: 600)
      view.layoutIfNeeded()
      layout.ensureLayout(for: view.textContainer)
    }
    return (view.textStorage, layout, apply)
    #endif
  }

  /// The distance of the baseline of the line with the first occurrence of `text` from the top.
  private func baseline(of text: String, in storage: NSTextStorage, _ layout: NSLayoutManager) throws -> CGFloat {
    let range = (storage.string as NSString).range(of: text)
    XCTAssertNotEqual(range.location, NSNotFound, text)
    let glyph = layout.glyphIndexForCharacter(at: range.location)
    let line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
    return line.minY + layout.location(forGlyphAt: glyph).y
  }

  /// How far the markers (the text of the paragraphs of a table cell, in the order of the
  /// string) are lowered.
  private func offsets(in string: NSAttributedString) -> [(marker: String, lowered: CGFloat)] {
    return ListMarkers.pairs(in: string).map { pair in
      let offset = (string.attribute(.baselineOffset, at: pair.marker.location, effectiveRange: nil) as? NSNumber)?.doubleValue ?? 0
      return ((string.string as NSString).substring(with: pair.marker), CGFloat(-offset))
    }
  }

  // MARK: The options

  func testAlignmentIsOffUnlessAskedFor() async throws {
    XCTAssertFalse(AttributedStringGenerator().alignListMarkers)
    XCTAssertFalse(MathAttributedStringGenerator().alignListMarkers)
    XCTAssertTrue(MathAttributedStringGenerator(alignListMarkers: true).alignListMarkers)
    XCTAssertTrue(AttributedStringGenerator(alignListMarkers: true).alignListMarkers)
    let doc = "1. The value \\(\\frac{a}{b}\\) is a fraction.\n- A bullet \\(\\frac{a}{b}\\) here\n"
    let off = try await self.generate(doc, align: false)
    XCTAssertEqual(self.offsets(in: off).count, 2)
    XCTAssertEqual(self.offsets(in: off).map { $0.lowered }, [0, 0])
    let on = try await self.generate(doc, align: true)
    XCTAssertTrue(self.offsets(in: on).allSatisfy { $0.lowered > 8 })
  }

  func testMarkdownTextAlignsMarkersOnlyIfAskedFor() {
    let doc = LaTeXMarkdownParser.standard.parse("1. Text\n")
    XCTAssertFalse(MarkdownText(doc).alignListMarkers)
    XCTAssertFalse(MarkdownText(string: "1. Text").alignListMarkers)
    XCTAssertTrue(MarkdownText(doc, alignListMarkers: true).alignListMarkers)
    XCTAssertTrue(MarkdownText(string: "1. Text", alignListMarkers: true).alignListMarkers)
    XCTAssertTrue(MarkdownText(doc, generator: nil, alignListMarkers: true).alignListMarkers)
    XCTAssertTrue(MarkdownText(string: "1. Text", generator: nil, alignListMarkers: true).alignListMarkers)
  }

  // MARK: Static alignment (the generator assumes the width of the text)

  func testTheNumberOfAnItemWithATallFormulaInItsFirstLineIsOnTheBaseline() async throws {
    let string = try await self.generate("1. The value \\(\\frac{a}{b}\\) is a fraction.\n2. Plain item.\n")
    let offsets = self.offsets(in: string)
    XCTAssertEqual(offsets.map { $0.marker }, ["1.", "2."])
    // The formula reaches 30 points above the baseline, the text about 15
    XCTAssertGreaterThan(offsets[0].lowered, 8)
    XCTAssertEqual(offsets[1].lowered, 0)
    let (storage, layout, _) = try self.layout(of: string, width: 800)
    // A marker that is not aligned is above the text, the alignment is as exact as the text
    // system of the platform lays out the line of the formula (measured with a text view)
    XCTAssertEqual(try self.baseline(of: "1.", in: storage, layout),
                   try self.baseline(of: "The value", in: storage, layout), accuracy: 2.0)
    #if os(macOS)
    // (A text view that is not on a screen lays out the lines of a plain item differently on iOS)
    XCTAssertEqual(try self.baseline(of: "2.", in: storage, layout),
                   try self.baseline(of: "Plain item", in: storage, layout), accuracy: 0.5)
    #endif
  }

  func testWithoutTheOffsetTheNumberIsAboveTheBaseline() async throws {
    let string = NSMutableAttributedString(attributedString:
      try await self.generate("1. The value \\(\\frac{a}{b}\\) is a fraction.\n"))
    string.removeAttribute(.baselineOffset, range: NSRange(location: 0, length: string.length))
    let (storage, layout, _) = try self.layout(of: string, width: 800)
    XCTAssertGreaterThan(try self.baseline(of: "The value", in: storage, layout) -
                         (try self.baseline(of: "1.", in: storage, layout)), 8)
  }

  func testBulletsAndCheckboxesAreAlignedToo() async throws {
    let string = try await self.generate("- A bullet \\(\\frac{a}{b}\\) here\n- Plain bullet\n\n- [ ] A task \\(\\frac{a}{b}\\) here\n")
    let offsets = self.offsets(in: string)
    XCTAssertEqual(offsets.map { $0.marker }, ["•", "•", "☐"])
    XCTAssertGreaterThan(offsets[0].lowered, 8)
    XCTAssertEqual(offsets[1].lowered, 0)
    XCTAssertGreaterThan(offsets[2].lowered, 8)
  }

  func testMarkersOfPlainListsAreNotChanged() async throws {
    let string = try await self.generate("1. First\n2. Second\n\n- One\n- Two\n\nA formula \\(\\frac{a}{b}\\) outside of a list.\n")
    XCTAssertEqual(self.offsets(in: string).map { $0.lowered }, [0, 0, 0, 0])
  }

  func testAnItemWhichIsOnlyAFormulaDoesNotMoveTheMarker() async throws {
    // A paragraph with nothing but an image has no baseline to align with
    let string = try await self.generate("1. \\(\\frac{a}{b}\\)\n2. Plain\n")
    XCTAssertEqual(self.offsets(in: string).map { $0.lowered }, [0, 0])
  }

  func testAFormulaFarFromTheStartOfTheItemIsAssumedOnALaterLine() async throws {
    let text = String(repeating: "word ", count: 60)
    let string = try await self.generate("1. \(text)\\(\\frac{a}{b}\\) end.\n")
    #if os(macOS)
    XCTAssertEqual(self.offsets(in: string).map { $0.lowered }, [0])
    #else
    // iOS makes all lines of a paragraph with a tall image taller, also those without the image:
    // the first line of the text is lower than the marker, whatever line the image is on
    let (storage, layout, _) = try self.layout(of: string, width: 800)
    XCTAssertEqual(try self.baseline(of: "1.", in: storage, layout),
                   try self.baseline(of: "word", in: storage, layout), accuracy: 2.0)
    #endif
  }

  func testStaticAlignmentDoesNotAddUp() async throws {
    let string = try await self.generate("1. The value \\(\\frac{a}{b}\\) is a fraction.\n")
    let once = self.offsets(in: string).map { $0.lowered }
    XCTAssertEqual(self.offsets(in: ListMarkers.aligned(string)).map { $0.lowered }, once)
  }

  func testTheTextIsNotChanged() async throws {
    let string = try await self.generate("1. The value \\(\\frac{a}{b}\\) is a fraction.\n2. Plain item.\n")
    XCTAssertTrue(string.string.contains("1.\n"), string.string)
    XCTAssertTrue(string.string.contains("The value"), string.string)
    XCTAssertTrue(string.string.contains("Plain item."), string.string)
    XCTAssertFalse(string.string.contains("\u{E000}"), string.string)
  }

  // MARK: Dynamic alignment (a text view measures its layout)

  func testAViewAlignsMarkersExactlyAndFollowsItsWidth() async throws {
    // Without the static offsets, so that the view starts from the unaligned state
    let string = NSMutableAttributedString(attributedString:
      try await self.generate("1. The sum of the first numbers is \\(\\frac{a}{b}\\) and more.\n2. Plain item.\n"))
    string.removeAttribute(.baselineOffset, range: NSRange(location: 0, length: string.length))
    let (storage, layout, apply) = try self.layout(of: string, width: 800)
    // The formula is on the first line
    XCTAssertTrue(ListMarkers.align(storage, layoutManager: layout))
    layout.ensureLayout(forCharacterRange: NSRange(location: 0, length: storage.length))
    XCTAssertEqual(try self.baseline(of: "1.", in: storage, layout),
                   try self.baseline(of: "The sum", in: storage, layout), accuracy: 0.5)
    XCTAssertGreaterThan(self.offsets(in: storage)[0].lowered, 8)
    XCTAssertFalse(ListMarkers.align(storage, layoutManager: layout), "nothing to do the second time")
    // At a narrow width, the formula is on the second line: the marker moves back
    apply(260)
    XCTAssertTrue(ListMarkers.align(storage, layoutManager: layout))
    layout.ensureLayout(forCharacterRange: NSRange(location: 0, length: storage.length))
    XCTAssertEqual(try self.baseline(of: "1.", in: storage, layout),
                   try self.baseline(of: "The sum", in: storage, layout), accuracy: 0.5)
    #if os(macOS)
    XCTAssertEqual(self.offsets(in: storage)[0].lowered, 0)
    #endif
    // and forth again
    apply(800)
    XCTAssertTrue(ListMarkers.align(storage, layoutManager: layout))
    layout.ensureLayout(forCharacterRange: NSRange(location: 0, length: storage.length))
    XCTAssertEqual(try self.baseline(of: "1.", in: storage, layout),
                   try self.baseline(of: "The sum", in: storage, layout), accuracy: 0.5)
  }

  func testAViewAlignsAnItemWhichStartsWithAFormula() async throws {
    let string = NSMutableAttributedString(attributedString:
      try await self.generate("- \\(\\frac{a}{b}\\) starts the item\n- Plain bullet\n"))
    string.removeAttribute(.baselineOffset, range: NSRange(location: 0, length: string.length))
    let (storage, layout, _) = try self.layout(of: string, width: 800)
    XCTAssertTrue(ListMarkers.align(storage, layoutManager: layout))
    layout.ensureLayout(forCharacterRange: NSRange(location: 0, length: storage.length))
    XCTAssertEqual(try self.baseline(of: "•", in: storage, layout),
                   try self.baseline(of: "starts", in: storage, layout), accuracy: 0.5)
  }

  func testAViewWithoutListsHasNothingToAlign() throws {
    let string = NSAttributedString(string: "Just text.\n")
    let (storage, layout, _) = try self.layout(of: string, width: 400)
    XCTAssertFalse(ListMarkers.align(storage, layoutManager: layout))
  }

  // MARK: RTFD

  func testTheMarkersOfAnRtfdDocumentAreOnTheBaseline() async throws {
    // The option of the generator is not needed for an export
    let string = try await self.generate("1. The sum of the first numbers is \\(\\frac{a}{b}\\) and more.\n2. Plain item.\n", align: false)
    let prepared = string.preparedForRTFD()
    let document = try prepared.fileWrapper(from: NSRange(location: 0, length: prepared.length),
                                            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
    #if os(macOS)
    let readBack = try XCTUnwrap(NSAttributedString(rtfd: try XCTUnwrap(document.serializedRepresentation),
                                                    documentAttributes: nil))
    let (storage, layout, _) = try self.layout(of: readBack, width: 800)
    // The viewer lays out an image that was lowered by the baseline offset differently than a
    // text view does, with the whole height above the baseline
    XCTAssertEqual(try self.baseline(of: "1.", in: storage, layout),
                   try self.baseline(of: "The sum", in: storage, layout), accuracy: 1.0)
    #else
    XCTAssertNotNil(document.fileWrappers?["TXT.rtf"])
    #endif
  }
}

#endif
