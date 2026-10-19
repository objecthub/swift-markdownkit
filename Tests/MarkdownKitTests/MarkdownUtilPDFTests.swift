//
//  MarkdownUtilPDFTests.swift
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
import PDFKit
import ImageIO
import UniformTypeIdentifiers
@testable import MarkdownKit

/// Tests for `MarkdownUtil.pdf(_:title:author:pageSize:margins:renderingOptions:)`.
@MainActor
final class MarkdownUtilPDFTests: XCTestCase {

  private let options = AttributedStringGenerator.RenderingOptions(remoteImages: .none)

  private func parse(_ markdown: String) -> Block {
    return MarkdownDialect.fullLaTeX.parser.parse(markdown)
  }

  /// Creates the PDF document for `markdown`.
  private func makePDF(_ markdown: String,
                       title: String? = nil,
                       author: String? = nil,
                       pageSize: CGSize = MarkdownUtil.usLetter,
                       margins: MarkdownUtil.Insets = MarkdownUtil.Insets(72),
                       util: MarkdownUtil = .standard) async throws -> (document: PDFDocument, data: Data) {
    let data = try await util.pdf(self.parse(markdown), title: title, author: author,
                                  pageSize: pageSize, margins: margins, renderingOptions: self.options)
    return (try XCTUnwrap(PDFDocument(data: data)), data)
  }

  /// The text of every page.
  private func pages(of document: PDFDocument) -> [String] {
    return (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
  }

  // MARK: Format

  func testADocumentIsAPdfWithTheTextOnAPageOfTheRightSize() async throws {
    let (document, data) = try await self.makePDF("# Title\n\nSome *emphasized* and **strong** text.\n")
    XCTAssertTrue(String(decoding: data.prefix(5), as: UTF8.self) == "%PDF-")
    XCTAssertEqual(document.pageCount, 1)
    let page = try XCTUnwrap(document.page(at: 0))
    XCTAssertEqual(page.bounds(for: .mediaBox).size, MarkdownUtil.usLetter)
    let text = self.pages(of: document).joined()
    XCTAssertTrue(text.contains("Title"), text)
    XCTAssertTrue(text.contains("Some emphasized and strong text."), text)
  }

  func testPageSizeTitleAndAuthor() async throws {
    let (document, _) = try await self.makePDF("Text", title: "A Title", author: "Someone",
                                               pageSize: MarkdownUtil.a4)
    let page = try XCTUnwrap(document.page(at: 0))
    XCTAssertEqual(page.bounds(for: .mediaBox).size, MarkdownUtil.a4)
    XCTAssertEqual(document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, "A Title")
    XCTAssertEqual(document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String, "Someone")
    let (plain, _) = try await self.makePDF("Text")
    XCTAssertNil(plain.documentAttributes?[PDFDocumentAttribute.titleAttribute])
    XCTAssertNil(plain.documentAttributes?[PDFDocumentAttribute.authorAttribute])
  }

  func testALongDocumentHasSeveralPagesAndAllOfItsText() async throws {
    let markdown = (1...150).map { "Paragraph number \($0) of the document." }.joined(separator: "\n\n")
    let (document, _) = try await self.makePDF(markdown)
    XCTAssertGreaterThan(document.pageCount, 2)
    let text = self.pages(of: document).joined(separator: "\n")
    for number in [1, 2, 75, 149, 150] {
      XCTAssertTrue(text.contains("Paragraph number \(number) of the document."), "\(number)")
    }
  }

  func testMarginsLimitTheText() async throws {
    let markdown = (1...120).map { "Paragraph number \($0) of the document." }.joined(separator: "\n\n")
    let (normal, _) = try await self.makePDF(markdown)
    let (wide, _) = try await self.makePDF(markdown, margins: MarkdownUtil.Insets(top: 72, left: 150,
                                                                                  bottom: 200, right: 150))
    XCTAssertGreaterThan(wide.pageCount, normal.pageCount)
  }

  func testAPageWithoutRoomForTextIsAnError() async throws {
    do {
      _ = try await MarkdownUtil.standard.pdf(self.parse("Text"), pageSize: CGSize(width: 100, height: 100),
                                              margins: MarkdownUtil.Insets(50),
                                              renderingOptions: self.options)
      XCTFail("no error")
    } catch let error as MarkdownUtil.PDFError {
      XCTAssertEqual(error, .noRoomForText)
      XCTAssertNotNil(error.errorDescription)
    }
  }

  func testAnEmptyDocumentIsOneEmptyPage() async throws {
    let (document, _) = try await self.makePDF("")
    XCTAssertEqual(document.pageCount, 1)
  }

  func testTheTextSizeMultiplierChangesTheNumberOfPages() async throws {
    let markdown = (1...40).map { "Paragraph number \($0) of the document." }.joined(separator: "\n\n")
    let small = try await MarkdownUtil.standard.pdf(self.parse(markdown), renderingOptions: self.options)
    let bigOptions = AttributedStringGenerator.RenderingOptions(remoteImages: .none, textSizeMultiplier: 2)
    let big = try await MarkdownUtil.standard.pdf(self.parse(markdown), renderingOptions: bigOptions)
    XCTAssertGreaterThan(try XCTUnwrap(PDFDocument(data: big)).pageCount,
                         try XCTUnwrap(PDFDocument(data: small)).pageCount)
  }

  /// The size of the font of the first occurrence of `text` on the first page.
  private func fontSize(of text: String, in data: Data) throws -> CGFloat {
    let page = try XCTUnwrap(PDFDocument(data: data)?.page(at: 0))
    let string = try XCTUnwrap(page.attributedString)
    let range = (string.string as NSString).range(of: text)
    XCTAssertNotEqual(range.location, NSNotFound, text)
    let font = try XCTUnwrap(string.attribute(.font, at: range.location, effectiveRange: nil) as? HRFont)
    return font.pointSize
  }

  func testTheTextIsSmallerThanInTheOtherFormats() async throws {
    let doc = self.parse("# Heading\n\nParagraph text.\n\n- List text\n\nCode: `inline`\n")
    let data = try await MarkdownUtil.standard.pdf(doc, renderingOptions: self.options)
    // The text is smaller by the scale of PDF documents: 14 points for text, 20 for a heading, 13 for code
    let scale = CGFloat(MarkdownUtil.pdfTextScale)
    XCTAssertLessThan(scale, 1)
    XCTAssertEqual(try self.fontSize(of: "Paragraph", in: data), 14 * scale, accuracy: 0.3)
    XCTAssertEqual(try self.fontSize(of: "List text", in: data), 14 * scale, accuracy: 0.3)
    XCTAssertEqual(try self.fontSize(of: "Heading", in: data), 20 * scale, accuracy: 0.3)
    XCTAssertEqual(try self.fontSize(of: "inline", in: data), 13 * scale, accuracy: 0.3)
    // The multiplier of the rendering options scales it further
    let bigger = try await MarkdownUtil.standard.pdf(
                   doc, renderingOptions: .init(remoteImages: .none, textSizeMultiplier: 1 / Double(scale)))
    XCTAssertEqual(try self.fontSize(of: "Paragraph", in: bigger), 14, accuracy: 0.3)
    XCTAssertEqual(try self.fontSize(of: "Heading", in: bigger), 20, accuracy: 0.3)
  }

  func testTheStyleOfTheUtilityDeterminesTheTextSize() async throws {
    let doc = self.parse("# Heading\n\nParagraph text.\n\nCode: `inline`\n")
    var style = AttributedStringGenerator.Style.light
    style.fontSize = 20
    style.codeFontSize = 16
    let data = try await MarkdownUtil(style: style).pdf(doc, renderingOptions: self.options)
    let scale = CGFloat(MarkdownUtil.pdfTextScale)
    XCTAssertEqual(try self.fontSize(of: "Paragraph", in: data), 20 * scale, accuracy: 0.3)
    XCTAssertEqual(try self.fontSize(of: "inline", in: data), 16 * scale, accuracy: 0.3)
    // Headings are larger than the text by the same steps as before
    XCTAssertEqual(try self.fontSize(of: "Heading", in: data), 26 * scale, accuracy: 0.3)
  }


  func testDiagramsAreScaledWithTheText() throws {
    let script = try XCTUnwrap(Resources.bundle?.url(forResource: "mermaid.min", withExtension: "js"))
    let renderer = try XCTUnwrap(MermaidRenderer(mermaidJSURL: script))
    let config = MermaidConfig(maxWidth: 400)
    let source = "graph TD\n  A --> B\n"
    // A fake diagram of 100 x 50 points
    let image = MermaidImage(pngData: try self.tinyPNG(width: 200, height: 100, dpi: 144),
                             size: CGSize(width: 100, height: 50), scale: 2)
    renderer.store(image, for: source, config: config)
    let generator = AttributedStringGenerator(mermaid: config, mermaidRenderer: renderer)
    let string = try XCTUnwrap(generator.generate(doc: self.parse("Text\n\n```mermaid\n\(source)```\n")))
    func sizes() -> [CGSize] {
      var result: [CGSize] = []
      string.enumerateAttribute(.attachment, in: NSRange(location: 0, length: string.length)) { value, _, _ in
        if let attachment = value as? NSTextAttachment {
          result.append(attachment.bounds.size)
        }
      }
      return result
    }
    XCTAssertEqual(sizes(), [CGSize(width: 100, height: 50)])
    MarkdownUtil.scalingDiagrams(in: string, by: 0.8)
    XCTAssertEqual(sizes(), [CGSize(width: 80, height: 40)])
  }

  func testAllDiagramsAreScaledAlike() async throws {
    let script = try XCTUnwrap(Resources.bundle?.url(forResource: "mermaid.min", withExtension: "js"))
    let renderer = try XCTUnwrap(MermaidRenderer(mermaidJSURL: script))
    let config = MermaidConfig(maxWidth: nil)
    let wide = "graph LR\n  A --> B\n"
    let high = "sequenceDiagram\n  A->>B: Hi\n"
    renderer.store(MermaidImage(pngData: try self.tinyPNG(width: 1500, height: 300, dpi: 144),
                                size: CGSize(width: 750, height: 150), scale: 2), for: wide, config: config)
    renderer.store(MermaidImage(pngData: try self.tinyPNG(width: 1000, height: 600, dpi: 144),
                                size: CGSize(width: 500, height: 300), scale: 2), for: high, config: config)
    let util = MarkdownUtil(mermaidRenderer: renderer)
    let doc = self.parse("```mermaid\n\(wide)```\n\n```mermaid\n\(high)```\n")
    func sizes(_ string: NSAttributedString) -> [CGSize] {
      var result: [CGSize] = []
      string.enumerateAttribute(.attachment, in: NSRange(location: 0, length: string.length)) { value, _, _ in
        if let attachment = value as? NSTextAttachment {
          result.append(attachment.bounds.size)
        }
      }
      return result
    }
    // A page of text of 468 points: diagrams for 800 points are scaled by 0.585, whatever their sizes
    let narrow = sizes(try await util.pdfAttributedString(doc, textWidth: 468, renderingOptions: self.options))
    XCTAssertEqual(narrow.count, 2)
    XCTAssertEqual(narrow[0].width, 750 * 0.585, accuracy: 0.01)
    XCTAssertEqual(narrow[0].height, 150 * 0.585, accuracy: 0.01)
    XCTAssertEqual(narrow[1].width, 500 * 0.585, accuracy: 0.01)
    XCTAssertEqual(narrow[1].height, 300 * 0.585, accuracy: 0.01)
    // A diagram is never made larger than it is
    let large = sizes(try await util.pdfAttributedString(doc, textWidth: 1000, renderingOptions: self.options))
    XCTAssertEqual(large, [CGSize(width: 750, height: 150), CGSize(width: 500, height: 300)])
  }

  /// A PNG which is filled with one color.
  private func tinyPNG(width: Int, height: Int, dpi: Double) throws -> Data {
    let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try XCTUnwrap(context.makeImage())
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
                                      data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image,
                               [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }

  func testScalingTheTextSizeKeepsTheOtherOptions() {
    let base = URL(fileURLWithPath: "/tmp")
    let options = AttributedStringGenerator.RenderingOptions(baseUrl: base, timeout: 7, localImages: .none,
                                                             remoteImages: .within(base), safeMode: true,
                                                             textSizeMultiplier: 2)
    let scaled = options.scalingText(by: 0.5)
    XCTAssertEqual(scaled.textSizeMultiplier, 1)
    XCTAssertEqual(AttributedStringGenerator.RenderingOptions().scalingText(by: 0.8).textSizeMultiplier, 0.8)
    XCTAssertEqual(scaled.baseUrl, base)
    XCTAssertEqual(scaled.timeout, 7)
    XCTAssertEqual(scaled.localImages, .none)
    XCTAssertEqual(scaled.remoteImages, .within(base))
    XCTAssertTrue(scaled.safeMode)
    XCTAssertEqual(scaled.imageExtensions, options.imageExtensions)
  }

  // MARK: Page breaks

  /// A page of 400 x 200 points with a text height of 160 points: there are only a few lines on a
  /// page, so every page has a break in the middle of something.
  private let shortPage = CGSize(width: 400, height: 200)
  private let shortMargins = MarkdownUtil.Insets(20)

  func testListItemsAreNotSplitAcrossPages() async throws {
    let filler = String(repeating: "word ", count: 24)
    let markdown = (1...30).map { "\($0). Item \($0) \(filler) end\($0)" }.joined(separator: "\n")
    let (document, _) = try await self.makePDF(markdown, pageSize: self.shortPage, margins: self.shortMargins)
    XCTAssertGreaterThan(document.pageCount, 5)
    let pages = self.pages(of: document)
    for number in 1...30 {
      let page = try XCTUnwrap(pages.first { $0.contains("Item \(number) ") }, "\(number)")
      XCTAssertTrue(page.contains("end\(number)"), "item \(number) is split: \(page)")
    }
  }

  func testCodeBlocksAreNotSplitAcrossPages() async throws {
    var markdown = ""
    for number in 1...12 {
      markdown += "A paragraph before block \(number).\n\n```\nfirst\(number)\nsecond\nthird\nfourth\nlast\(number)\n```\n\n"
    }
    let (document, _) = try await self.makePDF(markdown, pageSize: self.shortPage, margins: self.shortMargins)
    XCTAssertGreaterThan(document.pageCount, 5)
    let pages = self.pages(of: document)
    for number in 1...12 {
      let page = try XCTUnwrap(pages.first { $0.contains("first\(number)\n") || $0.contains("first\(number)\r") },
                               "\(number)")
      XCTAssertTrue(page.contains("last\(number)"), "block \(number) is split: \(page)")
    }
  }

  func testHeadingsAreNotTheLastLineOfAPage() async throws {
    let filler = String(repeating: "word ", count: 30)
    let markdown = (1...40).map { "## Heading \($0)\n\nText \($0) \(filler)" }.joined(separator: "\n\n")
    let (document, _) = try await self.makePDF(markdown, pageSize: self.shortPage, margins: self.shortMargins)
    XCTAssertGreaterThan(document.pageCount, 10)
    let pages = self.pages(of: document)
    for (index, page) in pages.enumerated() where index < pages.count - 1 {
      let last = page.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).last.map(String.init) ?? ""
      XCTAssertFalse(last.hasPrefix("Heading "), "page \(index + 1) ends with '\(last)'")
    }
  }

  func testNoLineIsLost() async throws {
    // Whatever the page breaks are, the text of all lines is on some page
    let filler = String(repeating: "word ", count: 24)
    let markdown = (1...20).map { "- Item \($0) \(filler) end\($0)" }.joined(separator: "\n")
      + "\n\n```\ncode1\ncode2\n```\n\n| A | B |\n| - | - |\n| cell1 | cell2 |\n"
    let (document, _) = try await self.makePDF(markdown, pageSize: self.shortPage, margins: self.shortMargins)
    let text = self.pages(of: document).joined(separator: "\n")
    for number in 1...20 {
      XCTAssertTrue(text.contains("end\(number)"), "\(number)")
    }
    for word in ["code1", "code2", "cell1", "cell2"] {
      XCTAssertTrue(text.contains(word), word)
    }
  }

  // MARK: Page sizes and margins from text

  func testPageSizesFromNamesAndNumbers() {
    XCTAssertEqual(MarkdownUtil.pageSize("a4"), MarkdownUtil.a4)
    XCTAssertEqual(MarkdownUtil.pageSize(" A4 "), MarkdownUtil.a4)
    XCTAssertEqual(MarkdownUtil.pageSize("letter"), MarkdownUtil.usLetter)
    XCTAssertEqual(MarkdownUtil.pageSize("US-Letter"), MarkdownUtil.usLetter)
    XCTAssertEqual(MarkdownUtil.pageSize("200x300"), CGSize(width: 200, height: 300))
    XCTAssertEqual(MarkdownUtil.pageSize("200pt x 300pt"), CGSize(width: 200, height: 300))
    XCTAssertEqual(MarkdownUtil.pageSize("8.5x11in"), CGSize(width: 612, height: 792))
    XCTAssertEqual(MarkdownUtil.pageSize("8.5inx11in"), CGSize(width: 612, height: 792))
    let a4 = try? XCTUnwrap(MarkdownUtil.pageSize("210x297mm"))
    XCTAssertEqual(a4?.width ?? 0, 595.28, accuracy: 0.01)
    XCTAssertEqual(a4?.height ?? 0, 841.89, accuracy: 0.01)
    XCTAssertEqual(MarkdownUtil.pageSize("21x29.7cm")?.width ?? 0, 595.28, accuracy: 0.01)
    XCTAssertEqual(MarkdownUtil.pageSize("100mmx2in")?.height ?? 0, 144, accuracy: 0.01)
  }

  func testPageSizesWhichAreNotSizes() {
    for text in ["", "a5", "foo", "200", "200x", "x300", "0x300", "200x0", "-200x300", "200x300x400",
                 "200 300", "twox3", "200x300km", "nanx3"] {
      XCTAssertNil(MarkdownUtil.pageSize(text), text)
    }
  }

  func testMarginsFromText() {
    typealias Insets = MarkdownUtil.Insets
    XCTAssertEqual(Insets("72"), Insets(72))
    XCTAssertEqual(Insets("0"), Insets.none)
    XCTAssertEqual(Insets("1in"), Insets(72))
    XCTAssertEqual(Insets("10 20"), Insets(horizontal: 20, vertical: 10))
    XCTAssertEqual(Insets("10, 20"), Insets(horizontal: 20, vertical: 10))
    // As in CSS: top, right, bottom, left
    XCTAssertEqual(Insets("10 20 30 40"), Insets(top: 10, left: 40, bottom: 30, right: 20))
    XCTAssertEqual(Insets("10pt,20pt,30pt,40pt"), Insets(top: 10, left: 40, bottom: 30, right: 20))
    XCTAssertEqual(Insets("1in 0.5in 1in 2in"), Insets(top: 72, left: 144, bottom: 72, right: 36))
    XCTAssertEqual(Insets("20mm")?.top ?? 0, 56.69, accuracy: 0.01)
    XCTAssertEqual(Insets("2cm 1in")?.left ?? 0, 72, accuracy: 0.01)
    XCTAssertEqual(Insets("2cm 1in")?.top ?? 0, 56.69, accuracy: 0.01)
    XCTAssertEqual(Insets("  72  ,  36 ")?.left, 36)
  }

  func testMarginsWhichAreNotMargins() {
    for text in ["", " ", ",", "abc", "1 2 3", "1 2 3 4 5", "-1", "1 -2", "1,abc", "10km", "nan", "inf"] {
      XCTAssertNil(MarkdownUtil.Insets(text), text)
    }
  }

  // MARK: Links

  /// The links of a page: the URL and the text under the rectangle of the link.
  private func links(of page: PDFPage) -> [(url: URL, text: String)] {
    return page.annotations.compactMap { annotation in
      guard let url = annotation.url ?? (annotation.action as? PDFActionURL)?.url else {
        return nil
      }
      return (url, page.selection(for: annotation.bounds)?.string ?? "")
    }
  }

  func testLinksAreClickable() async throws {
    let (document, _) = try await self.makePDF(
      "A [link text](https://example.org/page) and <https://example.com/auto> in a paragraph.")
    let links = self.links(of: try XCTUnwrap(document.page(at: 0)))
    XCTAssertEqual(links.count, 2)
    let page = try XCTUnwrap(links.first { $0.url.absoluteString == "https://example.org/page" })
    XCTAssertTrue(page.text.contains("link text"), page.text)
    let auto = try XCTUnwrap(links.first { $0.url.absoluteString == "https://example.com/auto" })
    XCTAssertTrue(auto.text.contains("example.com/auto"), auto.text)
  }

  func testALinkOverSeveralLinesHasARectangleForEachLine() async throws {
    let words = (1...30).map { "word\($0)" }.joined(separator: " ")
    let (document, _) = try await self.makePDF("Before [\(words)](https://example.org/long) after.",
                                               pageSize: CGSize(width: 300, height: 400),
                                               margins: MarkdownUtil.Insets(30))
    let links = self.links(of: try XCTUnwrap(document.page(at: 0)))
    XCTAssertGreaterThan(links.count, 2)
    XCTAssertTrue(links.allSatisfy { $0.url.absoluteString == "https://example.org/long" })
    let text = links.map { $0.text }.joined(separator: " ")
    XCTAssertTrue(text.contains("word1"), text)
    XCTAssertTrue(text.contains("word30"), text)
    XCTAssertFalse(text.contains("Before"), text)
    XCTAssertFalse(text.contains("after"), text)
  }

  func testLinksAreOnTheirPages() async throws {
    let markdown = (1...60).map { number in
      number == 45 ? "Paragraph \(number) with the [target link](https://example.org/target)."
                   : "Paragraph \(number) of the document."
    }.joined(separator: "\n\n")
    let (document, _) = try await self.makePDF(markdown, pageSize: self.shortPage, margins: self.shortMargins)
    XCTAssertGreaterThan(document.pageCount, 5)
    var found = 0
    for index in 0..<document.pageCount {
      let page = try XCTUnwrap(document.page(at: index))
      let links = self.links(of: page)
      if (page.string ?? "").contains("target link") {
        XCTAssertEqual(links.count, 1, "page \(index + 1)")
        XCTAssertTrue(links.first?.text.contains("target link") ?? false, links.first?.text ?? "")
        found += 1
      } else {
        XCTAssertTrue(links.isEmpty, "page \(index + 1)")
      }
    }
    XCTAssertEqual(found, 1)
  }

  func testLinksInListsAndTablesAreClickable() async throws {
    let (document, _) = try await self.makePDF("""
      - An item with [a list link](https://example.org/list)

      | Name | Link |
      | ---- | ---- |
      | cell | [a table link](https://example.org/table) |
      """)
    let links = self.links(of: try XCTUnwrap(document.page(at: 0)))
    XCTAssertEqual(Set(links.map { $0.url.absoluteString }),
                   ["https://example.org/list", "https://example.org/table"])
    XCTAssertTrue(try XCTUnwrap(links.first { $0.url.lastPathComponent == "list" }).text.contains("a list link"))
    XCTAssertTrue(try XCTUnwrap(links.first { $0.url.lastPathComponent == "table" }).text.contains("a table link"))
  }

  func testLinkRectanglesAreWithinThePage() async throws {
    let (document, _) = try await self.makePDF("Text with a [link](https://example.org/a).",
                                               margins: MarkdownUtil.Insets(100))
    let page = try XCTUnwrap(document.page(at: 0))
    let box = page.bounds(for: .mediaBox).insetBy(dx: 100, dy: 100)
    let annotations = page.annotations.filter { $0.url != nil || $0.action is PDFActionURL }
    XCTAssertEqual(annotations.count, 1)
    for annotation in annotations {
      XCTAssertTrue(box.insetBy(dx: -1, dy: -1).contains(annotation.bounds), "\(annotation.bounds)")
    }
  }

  func testTextWithoutLinksHasNoLinkAnnotations() async throws {
    let (document, _) = try await self.makePDF("Plain text, `code` and **strong**.")
    XCTAssertTrue(self.links(of: try XCTUnwrap(document.page(at: 0))).isEmpty)
  }

  func testLinksToAPlaceInTheSameDocumentAreNotClickable() async throws {
    let (document, _) = try await self.makePDF("A [reference](#somewhere) and a [link](https://example.org/x).")
    let links = self.links(of: try XCTUnwrap(document.page(at: 0)))
    XCTAssertEqual(links.map { $0.url.absoluteString }, ["https://example.org/x"])
  }

  // MARK: Colors

  func testDocumentsHaveTheExplicitColorsOfTheLightStyleWhateverTheAppearance() {
    let generator = MarkdownUtil.standard.documentGenerator(maxImageWidth: 400, diagramMaxWidth: 400,
                                                            renderingOptions: self.options)
    let light = AttributedStringGenerator.Style.light
    XCTAssertEqual(generator.fontColor, "#000000")
    XCTAssertEqual(generator.fontColor, light.fontColor)
    XCTAssertEqual(generator.codeFontColor, light.codeFontColor)
    XCTAssertEqual(generator.codeBlockFontColor, light.codeBlockFontColor)
    XCTAssertEqual(generator.codeBlockBackground, light.codeBlockBackground)
    XCTAssertEqual([generator.h1Color, generator.h2Color, generator.h3Color, generator.h4Color],
                   [light.h1Color, light.h2Color, light.h3Color, light.h4Color])
    XCTAssertEqual(generator.docStyle, AttributedStringGenerator(style: light).docStyle)
  }

  // MARK: Images

  #if canImport(WebKit)

  func testFormulasAndDiagramsAreImages() async throws {
    let katex = try XCTUnwrap(Resources.katexFolder)
    let math = try XCTUnwrap(MathRenderer(katexFolder: katex))
    let script = try XCTUnwrap(Resources.bundle?.url(forResource: "mermaid.min", withExtension: "js"))
    let mermaid = try XCTUnwrap(MermaidRenderer(mermaidJSURL: script))
    let util = MarkdownUtil(mermaidRenderer: mermaid, mathRenderer: math)
    let markdown = """
      A formula $\\frac{a}{b}$ within a line.

      1. The sum of the first numbers is \\(\\frac{a}{b}\\) and more.

      ```mermaid
      graph TD
        A --> B
      ```
      """
    let (document, data) = try await self.makePDF(markdown, util: util)
    let raw = String(decoding: data, as: UTF8.self)
    XCTAssertTrue(raw.contains("/Subtype /Image") || raw.contains("/Subtype/Image"), "no image")
    // The LaTeX and the code of the diagram are not text
    let text = self.pages(of: document).joined()
    XCTAssertTrue(text.contains("A formula"), text)
    XCTAssertFalse(text.contains("frac"), text)
    XCTAssertFalse(text.contains("graph TD"), text)
  }

  #endif
}

#endif
