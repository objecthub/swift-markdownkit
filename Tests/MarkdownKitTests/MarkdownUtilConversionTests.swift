//
//  MarkdownUtilConversionTests.swift
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
@testable import MarkdownKit

/// Tests for the methods of `MarkdownUtil` which convert a Markdown document into text, ANSI text,
/// HTML, RTF and RTFD.
final class MarkdownUtilConversionTests: XCTestCase {

  private func parse(_ markdown: String) -> Block {
    return MarkdownDialect.fullLaTeX.parser.parse(markdown)
  }

  // MARK: Text, ANSI text and HTML

  func testTextIsFormattedForTheWidth() {
    let doc = self.parse("# Title\n\nThis paragraph is long enough to need more than one line of text.")
    let text = MarkdownUtil.standard.text(doc, width: 30)
    XCTAssertTrue(text.contains("Title"))
    XCTAssertTrue(text.contains("paragraph"))
    XCTAssertGreaterThan(text.split(separator: "\n").count, 2)
    for line in text.split(separator: "\n") {
      XCTAssertLessThanOrEqual(line.count, 30, "\(line)")
    }
    XCTAssertEqual(MarkdownUtil.standard.text(doc), StringGenerator(numColumns: 80).generate(doc: doc))
  }

  func testTextShowsFormulasAndDiagramsAsTheyWereWritten() {
    let doc = self.parse("Area: $\\pi r^2$ and \\(x\\)\n\n```mermaid\ngraph TD; A-->B\n```\n")
    let text = MarkdownUtil.standard.text(doc)
    XCTAssertTrue(text.contains("$\\pi r^2$"), text)
    XCTAssertTrue(text.contains("graph TD; A-->B"), text)
  }

  func testAnsiTextHasEscapeCodes() {
    let doc = self.parse("Some **bold** text.")
    let result = MarkdownUtil.standard.ansi(doc, width: 40)
    XCTAssertTrue(result.contains("\u{1B}["), result)
    XCTAssertTrue(result.contains("bold"), result)
    XCTAssertFalse(MarkdownUtil.standard.text(doc).contains("\u{1B}["))
  }

  func testHtmlTypesetsFormulasAsMathML() {
    let doc = self.parse("Area: $\\pi r^2$\n\n$$\n\\frac{a}{b}\n$$\n")
    let result = MarkdownUtil.standard.html(doc)
    XCTAssertTrue(result.contains("<math"), result)
    XCTAssertFalse(result.contains("katex-html"), result)
    XCTAssertEqual(result, MathHtmlGenerator(math: .mathml).generate(doc: doc))
  }

  func testHtmlCanWriteFormulasWithDelimiters() {
    let doc = self.parse("Area: $\\pi r^2$")
    let result = MarkdownUtil.standard.html(doc, math: .delimiters)
    XCTAssertFalse(result.contains("<math"), result)
    XCTAssertTrue(result.contains("\\pi r^2"), result)
  }

  func testHtmlSafeModeOmitsRawHtml() {
    let doc = self.parse("Text <script>alert(1)</script> and <b>bold</b>.\n\n[link](javascript:alert(1))")
    let unsafe = MarkdownUtil.standard.html(doc)
    XCTAssertTrue(unsafe.contains("<script>"), unsafe)
    let safe = MarkdownUtil.standard.html(doc, safeMode: true)
    XCTAssertFalse(safe.contains("<script>"), safe)
    XCTAssertFalse(safe.contains("javascript:"), safe)
  }

  // MARK: RTF

  func testRtfIsAnRtfDocumentWithTheProperties() async throws {
    let doc = self.parse("# Title\n\nSome *emphasized* text with $x^2$ and a [link](https://example.org/).")
    let data = try await MarkdownUtil.standard.rtf(doc, title: "A Title", author: "Someone",
                                                   renderingOptions: .init(remoteImages: .none))
    let rtf = String(decoding: data, as: UTF8.self)
    XCTAssertTrue(rtf.hasPrefix("{\\rtf"), rtf)
    XCTAssertTrue(rtf.contains("Title"), rtf)
    #if os(macOS)
    // iOS does not write the properties of a document
    XCTAssertTrue(rtf.contains("A Title"), rtf)
    XCTAssertTrue(rtf.contains("Someone"), rtf)
    #endif
    // The formula is shown as it was written, since RTF has no images
    XCTAssertTrue(rtf.contains("$x^2$"), rtf)
    XCTAssertFalse(rtf.contains("NeXTGraphic"), rtf)
    // The text can be read back
    let text = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                      documentAttributes: nil)
    XCTAssertTrue(text.string.contains("Some emphasized text"), text.string)
  }

  func testRtfWithoutPropertiesHasNoTitleAndNoAuthor() async throws {
    let data = try await MarkdownUtil.standard.rtf(self.parse("Text"), renderingOptions: .init(remoteImages: .none))
    let rtf = String(decoding: data, as: UTF8.self)
    XCTAssertFalse(rtf.contains("\\title"), rtf)
    XCTAssertFalse(rtf.contains("\\author"), rtf)
  }

  func testRtfResolvesRelativeImagePathsAgainstTheImageBaseUrl() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MarkdownUtilConversionTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: directory)
    }
    try self.png().write(to: directory.appendingPathComponent("in.png"))
    let doc = self.parse("Before ![zebra](in.png) after")
    let options = AttributedStringGenerator.RenderingOptions(localImages: .within(directory),
                                                             remoteImages: .none)
    // The image is not allowed without a base: its alternative text is shown instead
    let without = String(decoding: try await MarkdownUtil.standard.rtf(doc, renderingOptions: options),
                         as: UTF8.self)
    XCTAssertTrue(without.contains("zebra"), without)
    let with = String(decoding: try await MarkdownUtil.standard.rtf(doc, imageBaseUrl: directory,
                                                                    renderingOptions: options),
                      as: UTF8.self)
    XCTAssertFalse(with.contains("zebra"), with)
    XCTAssertTrue(with.contains("Before"), with)
  }

  /// A PNG of one pixel.
  private func png() -> Data {
    return Data(base64Encoded:
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
  }

  // MARK: RTFD

  #if canImport(WebKit)

  private func makeUtil() throws -> MarkdownUtil {
    let katex = try XCTUnwrap(Resources.katexFolder)
    let math = try XCTUnwrap(MathRenderer(katexFolder: katex))
    let script = try XCTUnwrap(Resources.bundle?.url(forResource: "mermaid.min", withExtension: "js"))
    let mermaid = try XCTUnwrap(MermaidRenderer(mermaidJSURL: script))
    return MarkdownUtil(mermaidRenderer: mermaid, mathRenderer: math)
  }

  /// The resolution in dots per inch, and the size in pixels of a PNG.
  private func resolution(of png: Data) throws -> (dpi: Double, width: Int, height: Int) {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
    let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    return (try XCTUnwrap(properties[kCGImagePropertyDPIWidth] as? Double),
            try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int),
            try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? Int))
  }

  func testRtfdContainsFormulasAndDiagramsAsImages() async throws {
    let util = try self.makeUtil()
    let doc = self.parse("""
      A formula $\\frac{a}{b}$ within a line, and one with \\(x^2\\).

      $$
      \\int_0^1 x\\,dx
      $$

      ```mermaid
      graph TD
        A --> B
      ```
      """)
    let document = try await util.rtfd(doc, title: "Test", author: "Tester",
                                       renderingOptions: .init(remoteImages: .none))
    XCTAssertTrue(document.isDirectory)
    let files = try XCTUnwrap(document.fileWrappers)
    XCTAssertEqual(Set(files.keys), ["TXT.rtf", "Formula 1.png", "Formula 2.png", "Formula 3.png", "Image 1.png"])
    for name in ["Formula 1.png", "Formula 2.png", "Formula 3.png", "Image 1.png"] {
      let png = try XCTUnwrap(files[name]?.regularFileContents, name)
      let (dpi, width, height) = try self.resolution(of: png)
      XCTAssertGreaterThan(width, 8, name)
      XCTAssertGreaterThan(height, 8, name)
      // The images are drawn with several pixels per point
      XCTAssertGreaterThan(dpi, 100, name)
    }
    let rtf = String(decoding: try XCTUnwrap(files["TXT.rtf"]?.regularFileContents), as: UTF8.self)
    XCTAssertTrue(rtf.contains("A formula"), rtf)
    #if os(macOS)
    XCTAssertTrue(rtf.contains("Tester"), rtf)
    #endif
    // The inline formulas sit on the baseline of the text, not on its bottom
    XCTAssertTrue(rtf.contains("\\dn"), rtf)
    XCTAssertFalse(rtf.contains("\u{E000}"), rtf)
  }

  func testRtfdLimitsTheWidthOfImages() async throws {
    let util = try self.makeUtil()
    let doc = self.parse("$$\n" + (1...30).map { "a_{\($0)}" }.joined(separator: " + ") + "\n$$\n")
    let document = try await util.rtfd(doc, maxImageWidth: 120,
                                       renderingOptions: .init(remoteImages: .none))
    let png = try XCTUnwrap(try XCTUnwrap(document.fileWrappers?["Formula 1.png"]).regularFileContents)
    let (dpi, width, _) = try self.resolution(of: png)
    // The size in points of an image results from its resolution
    XCTAssertLessThanOrEqual(Double(width) * 72 / dpi, 120.5)
    XCTAssertGreaterThan(Double(width) * 72 / dpi, 60)
  }

  func testRtfdUsesTheConfigurationOfFormulas() async throws {
    let util = try self.makeUtil()
    let doc = self.parse("A formula $\\w$.")
    let options = AttributedStringGenerator.RenderingOptions(remoteImages: .none)
    func width(of document: FileWrapper) throws -> Double {
      let png = try XCTUnwrap(try XCTUnwrap(document.fileWrappers?["Formula 1.png"]).regularFileContents)
      return Double(try self.resolution(of: png).width)
    }
    // The macro of the configuration decides what the formula shows
    let short = MathConfig(katex: KaTeXOptions(macros: ["\\w": "x"]))
    let long = MathConfig(katex: KaTeXOptions(macros: ["\\w": "x x x x x x x x x x"]))
    let narrow = try width(of: try await util.rtfd(doc, math: short, renderingOptions: options))
    let wide = try width(of: try await util.rtfd(doc, math: long, renderingOptions: options))
    XCTAssertGreaterThan(wide, narrow * 5)
    // The scale of the configuration is the number of pixels per point
    let small = try await util.rtfd(doc, math: MathConfig(katex: short.katex, scale: 1), renderingOptions: options)
    let large = try await util.rtfd(doc, math: MathConfig(katex: short.katex, scale: 3), renderingOptions: options)
    XCTAssertEqual(try width(of: large) / width(of: small), 3, accuracy: 0.2)
  }

  func testRtfdUsesTheConfigurationOfDiagrams() async throws {
    let util = try self.makeUtil()
    let doc = self.parse("```mermaid\ngraph TD\n  A --> B\n```\n")
    let options = AttributedStringGenerator.RenderingOptions(remoteImages: .none)
    func width(of document: FileWrapper) throws -> Double {
      let png = try XCTUnwrap(try XCTUnwrap(document.fileWrappers?["Image 1.png"]).regularFileContents)
      return Double(try self.resolution(of: png).width)
    }
    let standard = try await util.rtfd(doc, renderingOptions: options)
    let small = try await util.rtfd(doc, mermaid: MermaidConfig(scale: 1), renderingOptions: options)
    // The default scale is 2
    XCTAssertEqual(try width(of: standard) / width(of: small), 2, accuracy: 0.1)
  }

  func testRtfdDrawsOnlyWhatHasAConfiguration() async throws {
    let util = try self.makeUtil()
    let doc = self.parse("A formula $x^2$.\n\n```mermaid\ngraph TD\n  A --> B\n```\n")
    let options = AttributedStringGenerator.RenderingOptions(remoteImages: .none)
    func files(_ document: FileWrapper) throws -> Set<String> {
      return Set(try XCTUnwrap(document.fileWrappers).keys)
    }
    let both = try await util.rtfd(doc, renderingOptions: options)
    XCTAssertEqual(try files(both), ["TXT.rtf", "Formula 1.png", "Image 1.png"])
    let diagramsOnly = try await util.rtfd(doc, math: nil, renderingOptions: options)
    XCTAssertEqual(try files(diagramsOnly), ["TXT.rtf", "Image 1.png"])
    let formulasOnly = try await util.rtfd(doc, mermaid: nil, renderingOptions: options)
    XCTAssertEqual(try files(formulasOnly), ["TXT.rtf", "Formula 1.png"])
    // The diagram and the formula stay text
    let neither = try await util.rtfd(doc, mermaid: nil, math: nil, renderingOptions: options)
    XCTAssertEqual(try files(neither), ["TXT.rtf"])
    let rtf = String(decoding: try XCTUnwrap(try XCTUnwrap(neither.fileWrappers?["TXT.rtf"]).regularFileContents),
                     as: UTF8.self)
    XCTAssertTrue(rtf.contains("$x^2$"), rtf)
    XCTAssertTrue(rtf.contains("A --> B"), rtf)
  }

  func testRtfdResolvesRelativeImagePathsAgainstTheImageBaseUrl() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MarkdownUtilConversionTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: directory)
    }
    try self.png().write(to: directory.appendingPathComponent("in.png"))
    let util = try self.makeUtil()
    let doc = self.parse("Before ![zebra](in.png) after")
    let options = AttributedStringGenerator.RenderingOptions(localImages: .within(directory),
                                                             remoteImages: .none)
    let without = try await util.rtfd(doc, renderingOptions: options)
    XCTAssertEqual(Set(try XCTUnwrap(without.fileWrappers).keys), ["TXT.rtf"])
    let with = try await util.rtfd(doc, imageBaseUrl: directory, renderingOptions: options)
    XCTAssertEqual(try XCTUnwrap(with.fileWrappers).count, 2)
  }

  func testRtfdWithoutImagesIsADocumentWithText() async throws {
    let util = try self.makeUtil()
    let document = try await util.rtfd(self.parse("Just *text*."),
                                       renderingOptions: .init(remoteImages: .none))
    let files = try XCTUnwrap(document.fileWrappers)
    XCTAssertEqual(Set(files.keys), ["TXT.rtf"])
  }

  #endif
}

#endif
