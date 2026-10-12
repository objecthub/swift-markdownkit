//
//  MermaidTests.swift
//  MarkdownKitTests
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

#if os(macOS) || os(iOS)

import XCTest
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif
@testable import MarkdownKit

/// Tests for the support of Mermaid diagrams: finding diagrams in documents, the generated HTML,
/// the cache of `MermaidRenderer`, the placeholders in attributed strings, and (on macOS and
/// iOS) rendering diagrams in a web view.
final class MermaidTests: XCTestCase {

  private let flowchart = "graph TD\n  A[Start] --> B{Choice}\n  B -->|yes| C[Done]\n  B -->|no| A\n"
  private let sequence = "sequenceDiagram\n  Alice->>Bob: Hello\n  Bob-->>Alice: Hi\n"
  private let broken = "flowchart TD\n  A --> --> B ((\n"

  private func parse(_ markdown: String) -> Block {
    return ExtendedMarkdownParser.standard.parse(markdown)
  }

  /// A renderer for tests that put images into its cache by hand. The script is never run.
  private func makeRenderer(maxCachedDiagrams: Int = MermaidRenderer.defaultMaxCachedDiagrams,
                            maxCacheBytes: Int = MermaidRenderer.defaultMaxCacheBytes) throws -> MermaidRenderer {
    let url = try XCTUnwrap(MarkdownKitResources.bundle?.url(forResource: "mermaid.min",
                                                              withExtension: "js"))
    return try XCTUnwrap(MermaidRenderer(mermaidJSURL: url,
                                         maxCachedDiagrams: maxCachedDiagrams,
                                         maxCacheBytes: maxCacheBytes))
  }

  /// A fake rendering result whose PNG data is `bytes` bytes large.
  private func makeImage(bytes: Int) -> MermaidImage {
    return MermaidImage(pngData: Data(count: bytes), size: CGSize(width: 10, height: 10), scale: 2)
  }

  /// A PNG of the given size (in pixels) which is filled with one color.
  private func makePNG(width: Int, height: Int) throws -> Data {
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
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }

  /// A fake rendering result which is `width` x `height` points large.
  private func makeImage(width: Int, height: Int, scale: CGFloat = 2) throws -> MermaidImage {
    return MermaidImage(pngData: try self.makePNG(width: width * Int(scale), height: height * Int(scale)),
                        size: CGSize(width: width, height: height),
                        scale: scale)
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

  // MARK: Finding diagrams

  func testInfoStringDecidesWhetherCodeIsADiagram() {
    XCTAssertTrue(Block.isMermaid(info: "mermaid"))
    XCTAssertTrue(Block.isMermaid(info: "mermaid  theme=dark"))
    XCTAssertTrue(Block.isMermaid(info: "mermaid\ttitle"))
    XCTAssertFalse(Block.isMermaid(info: "Mermaid"))
    XCTAssertFalse(Block.isMermaid(info: "mermaids"))
    XCTAssertFalse(Block.isMermaid(info: "swift mermaid"))
    XCTAssertFalse(Block.isMermaid(info: ""))
    XCTAssertFalse(Block.isMermaid(info: nil))
  }

  func testSourcesAreCollectedFromNestedBlocksInDocumentOrder() {
    let markdown = """
      ```mermaid
      graph A
      ```

      > ```mermaid
      > graph B
      > ```

      - item

        ```mermaid
        graph C
        ```

      ```swift
      let x = 1
      ```

      ```mermaid extra words
      graph D
      ```

      ```mermaid
      graph A
      ```

      """
    XCTAssertEqual(self.parse(markdown).mermaidSources,
                   ["graph A\n", "graph B\n", "graph C\n", "graph D\n"])
    XCTAssertEqual(self.parse("no diagram\n\n```swift\nmermaid\n```\n").mermaidSources, [])
  }

  func testSourcesAreCollectedFromDefinitionLists() {
    let markdown = "Term\n: ```mermaid\n  graph T\n  ```\n"
    let doc = FullMarkdownParser.standard.parse(markdown)
    XCTAssertEqual(doc.mermaidSources, ["graph T\n"])
  }

  // MARK: Configuration

  func testDarkVariantOnlyChangesLightThemes() {
    XCTAssertEqual(MermaidConfig.default.darkVariant, MermaidConfig.dark)
    var neutral = MermaidConfig(theme: .neutral, scale: 3, maxWidth: 400)
    XCTAssertEqual(neutral.darkVariant.theme, .dark)
    XCTAssertEqual(neutral.darkVariant.scale, 3)
    XCTAssertEqual(neutral.darkVariant.maxWidth, 400)
    neutral.theme = .base
    XCTAssertEqual(neutral.darkVariant, neutral)
    XCTAssertEqual(MermaidConfig.dark.darkVariant, MermaidConfig.dark)
  }

  func testRenderKeyIgnoresPlacementAndTimeout() {
    let base = MermaidConfig()
    var other = base
    other.maxWidth = 200
    other.timeout = 3
    XCTAssertNotEqual(base, other)
    XCTAssertEqual(base.renderKey, other.renderKey)
    other.theme = .forest
    XCTAssertNotEqual(base.renderKey, other.renderKey)
    other = base
    other.scale = 3
    XCTAssertNotEqual(base.renderKey, other.renderKey)
  }

  // MARK: Generated HTML

  private func html(_ markdown: String, version: AttributedStringGenerator.Version,
                    mermaid: MermaidConfig? = nil,
                    renderer: MermaidRenderer? = nil) -> String {
    let generator = AttributedStringGenerator(version: version, mermaid: mermaid,
                                              mermaidRenderer: renderer)
    return generator.htmlGenerator.generate(doc: self.parse(markdown))
  }

  func testDiagramsAreOffByDefault() {
    XCTAssertNil(AttributedStringGenerator().mermaidConfig)
    XCTAssertNil(AttributedStringGenerator.standard.mermaidConfig)
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      let html = self.html("```mermaid\ngraph TD\n  A --> B\n```\n", version: version)
      XCTAssertFalse(html.contains("class=\"mermaid\""), "\(version): \(html)")
      XCTAssertTrue(html.contains("graph TD"), "\(version)")
      XCTAssertTrue(html.contains("<code"), "\(version)")
      XCTAssertTrue(html.contains("--&gt;"), "\(version)")
    }
  }

  func testDiagramWhichHasNotBeenRenderedIsShownAsCode() throws {
    let renderer = try self.makeRenderer()
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      let html = self.html("```mermaid\ngraph TD\n  A --> B\n```\n", version: version,
                           mermaid: .default, renderer: renderer)
      XCTAssertFalse(html.contains("class=\"mermaid\""), "\(version)")
      XCTAssertFalse(html.contains("MKD"), "\(version)")
      XCTAssertTrue(html.contains("<code"), "\(version)")
      XCTAssertTrue(html.contains("codebox"), "\(version)")
    }
  }

  func testHtmlOfOtherDocumentsIsNotAffectedByDiagrams() throws {
    let renderer = try self.makeRenderer()
    let markdown = "# Title\n\nSome *text*.\n\n```swift\nlet x = 1\n```\n\n    indented\n\n> quote\n"
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      XCTAssertEqual(self.html(markdown, version: version),
                     self.html(markdown, version: version, mermaid: .default, renderer: renderer))
    }
  }

  func testRenderedDiagramIsReplacedByAPlaceholder() throws {
    let renderer = try self.makeRenderer()
    let source = "graph TD\n  A --> B\n"
    renderer.store(try self.makeImage(width: 100, height: 50), for: source, config: .default)
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      let html = self.html("before\n\n```mermaid\n\(source)```\n\nafter\n", version: version,
                           mermaid: .default, renderer: renderer)
      XCTAssertTrue(html.contains("MKD"), "\(version): \(html)")
      XCTAssertFalse(html.contains("graph TD"), "\(version)")
      XCTAssertFalse(html.contains("<code"), "\(version)")
      XCTAssertTrue(html.contains("text-align: center"), "\(version)")
    }
  }

  func testRejectedDiagramIsShownAsCodeWithANote() throws {
    let renderer = try self.makeRenderer()
    renderer.storeFailure(.syntaxError("Parse error on line 2:\n  A --> <b>"),
                          for: self.broken, config: .default)
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      let html = self.html("```mermaid\n\(self.broken)```\n", version: version,
                           mermaid: .default, renderer: renderer)
      XCTAssertTrue(html.contains("Diagram could not be rendered: Parse error on line 2:"),
                    "\(version): \(html)")
      // Only the first line of the message is shown, and the message is escaped
      XCTAssertFalse(html.contains("<b>"), "\(version)")
      XCTAssertTrue(html.contains("flowchart TD"), "\(version)")
    }
  }

  // MARK: Placeholders in attributed strings

  @MainActor
  func testPlaceholderBecomesAnAttachment() throws {
    let renderer = try self.makeRenderer()
    let source = "graph TD\n  A --> B\n"
    let image = try self.makeImage(width: 120, height: 60)
    renderer.store(image, for: source, config: .default)
    let generator = AttributedStringGenerator(mermaid: .default, mermaidRenderer: renderer)
    let doc = self.parse("Before the diagram\n\n```mermaid\n\(source)```\n\nAfter the diagram\n")
    let result = try XCTUnwrap(generator.generate(doc: doc))
    let found = self.attachments(in: result)
    XCTAssertEqual(found.count, 1)
    let attachment = try XCTUnwrap(found.first?.attachment)
    XCTAssertEqual(attachment.bounds.size, CGSize(width: 120, height: 60))
    // The data of the attachment is the PNG (macOS encodes it again)
    let data = try XCTUnwrap(attachment.contents ?? attachment.fileWrapper?.regularFileContents)
    let decoded = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    XCTAssertEqual(CGImageSourceGetCount(decoded), 1)
    let pixels = try XCTUnwrap(CGImageSourceCreateImageAtIndex(decoded, 0, nil))
    XCTAssertEqual(pixels.width, 240)
    XCTAssertEqual(pixels.height, 120)
    XCTAssertNotNil(attachment.image)
    XCTAssertTrue(result.string.contains("Before the diagram"))
    XCTAssertTrue(result.string.contains("After the diagram"))
    XCTAssertFalse(result.string.contains("graph TD"))
    XCTAssertFalse(result.string.contains("MKD"))
    XCTAssertFalse(result.string.contains("\u{E000}"))
    // The diagram is centered like the paragraph it replaces
    let style = result.attribute(.paragraphStyle, at: found[0].range.location,
                                 effectiveRange: nil) as? NSParagraphStyle
    XCTAssertEqual(style?.alignment, .center)
  }

  @MainActor
  func testWideDiagramsAreScaledDownToMaxWidth() throws {
    let renderer = try self.makeRenderer()
    let source = "graph TD\n  A --> B\n"
    let config = MermaidConfig(maxWidth: 300)
    renderer.store(try self.makeImage(width: 600, height: 200), for: source, config: config)
    let generator = AttributedStringGenerator(mermaid: config, mermaidRenderer: renderer)
    let result = try XCTUnwrap(generator.generate(doc: self.parse("```mermaid\n\(source)```\n")))
    let attachment = try XCTUnwrap(self.attachments(in: result).first?.attachment)
    XCTAssertEqual(attachment.bounds.size.width, 300, accuracy: 0.001)
    XCTAssertEqual(attachment.bounds.size.height, 100, accuracy: 0.001)
  }

  @MainActor
  func testDiagramsAdaptToTheWidthOfTheTextView() throws {
    let renderer = try self.makeRenderer()
    let source = "graph TD\n  A --> B\n"
    renderer.store(try self.makeImage(width: 600, height: 300), for: source, config: .default)
    let generator = AttributedStringGenerator(mermaid: .default, mermaidRenderer: renderer)
    let result = try XCTUnwrap(generator.generate(doc: self.parse("```mermaid\n\(source)```\n")))
    let attachment = try XCTUnwrap(self.attachments(in: result).first?.attachment)
    // It keeps its size if there is enough room, but never gets scaled up
    for width in [600.0, 800.0, 10_000.0] {
      let bounds = attachment.attachmentBounds(for: nil,
                                               proposedLineFragment: CGRect(x: 0, y: 0, width: width, height: 20),
                                               glyphPosition: .zero,
                                               characterIndex: 0)
      XCTAssertEqual(bounds, CGRect(x: 0, y: 0, width: 600, height: 300), "width \(width)")
    }
    // It gets scaled down (keeping its aspect ratio) if there is not
    let narrow = attachment.attachmentBounds(for: nil,
                                             proposedLineFragment: CGRect(x: 0, y: 0, width: 200, height: 20),
                                             glyphPosition: .zero,
                                             characterIndex: 0)
    XCTAssertEqual(narrow, CGRect(x: 0, y: 0, width: 200, height: 100))
  }

  #if os(macOS)
  @MainActor
  func testTextViewShowsDiagramsScaledToItsWidth() throws {
    let renderer = try self.makeRenderer()
    let source = "graph TD\n  A --> B\n"
    renderer.store(try self.makeImage(width: 600, height: 300), for: source, config: .default)
    let generator = AttributedStringGenerator(mermaid: .default, mermaidRenderer: renderer)
    let result = try XCTUnwrap(generator.generate(doc: self.parse("```mermaid\n\(source)```\n")))
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
    textView.drawsBackground = true
    textView.backgroundColor = .white
    textView.textContainerInset = .zero
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.containerSize = NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude)
    textView.textStorage?.setAttributedString(result)
    let layoutManager = try XCTUnwrap(textView.layoutManager)
    let container = try XCTUnwrap(textView.textContainer)
    layoutManager.ensureLayout(for: container)
    // The diagram is 600x300 points, but only 300 points fit: it is shown at 300x150
    let used = layoutManager.usedRect(for: container)
    XCTAssertLessThanOrEqual(used.width, 300.5)
    XCTAssertGreaterThanOrEqual(used.height, 150)
    XCTAssertLessThan(used.height, 200)
    // The image is drawn (it is filled with one color)
    let bitmap = try XCTUnwrap(textView.bitmapImageRepForCachingDisplay(in: textView.bounds))
    textView.cacheDisplay(in: textView.bounds, to: bitmap)
    let color = try XCTUnwrap(bitmap.colorAt(x: 150, y: Int(used.height / 2))?.usingColorSpace(.deviceRGB))
    XCTAssertGreaterThan(color.blueComponent, 0.7)
    XCTAssertLessThan(color.redComponent, 0.35)
  }
  #endif

  @MainActor
  func testSeveralDiagramsKeepTheirOrder() throws {
    let renderer = try self.makeRenderer()
    let first = "graph TD\n  A --> B\n"
    let second = "graph LR\n  X --> Y\n"
    renderer.store(try self.makeImage(width: 100, height: 40), for: first, config: .default)
    renderer.store(try self.makeImage(width: 200, height: 80), for: second, config: .default)
    let generator = AttributedStringGenerator(mermaid: .default, mermaidRenderer: renderer)
    let markdown = "```mermaid\n\(second)```\n\ntext in between\n\n```mermaid\n\(first)```\n\n```mermaid\n\(second)```\n"
    let result = try XCTUnwrap(generator.generate(doc: self.parse(markdown)))
    let widths = self.attachments(in: result).map { $0.attachment.bounds.width }
    XCTAssertEqual(widths, [200, 100, 200])
    XCTAssertTrue(result.string.contains("text in between"))
  }

  @MainActor
  func testTextCannotForgeAPlaceholder() throws {
    let renderer = try self.makeRenderer()
    let source = "graph TD\n  A --> B\n"
    renderer.store(try self.makeImage(width: 100, height: 40), for: source, config: .default)
    let generator = AttributedStringGenerator(mermaid: .default, mermaidRenderer: renderer)
    let forged = "\u{E000}MKD00000000000000000000000000000000\u{E001}"
    let markdown = "\(forged)0 and \(forged)1\n\n```mermaid\n\(source)```\n"
    let result = try XCTUnwrap(generator.generate(doc: self.parse(markdown)))
    XCTAssertEqual(self.attachments(in: result).count, 1)
    XCTAssertTrue(result.string.contains(forged + "0"))
  }

  @MainActor
  func testDiagramsAreOnlyShownIfEnabled() throws {
    let renderer = try self.makeRenderer()
    let source = "graph TD\n  A --> B\n"
    renderer.store(try self.makeImage(width: 100, height: 40), for: source, config: .default)
    let generator = AttributedStringGenerator(mermaid: nil, mermaidRenderer: renderer)
    let result = try XCTUnwrap(generator.generate(doc: self.parse("```mermaid\n\(source)```\n")))
    XCTAssertEqual(self.attachments(in: result).count, 0)
    XCTAssertTrue(result.string.contains("graph TD"))
  }

  @MainActor
  func testDiagramsOfOtherConfigurationsAreNotUsed() throws {
    let renderer = try self.makeRenderer()
    let source = "graph TD\n  A --> B\n"
    renderer.store(try self.makeImage(width: 100, height: 40), for: source, config: .default)
    let generator = AttributedStringGenerator(mermaid: .dark, mermaidRenderer: renderer)
    let result = try XCTUnwrap(generator.generate(doc: self.parse("```mermaid\n\(source)```\n")))
    XCTAssertEqual(self.attachments(in: result).count, 0)
    XCTAssertTrue(result.string.contains("graph TD"))
  }

  // MARK: Cache

  func testCacheKeepsImagesAndFailuresApart() throws {
    let renderer = try self.makeRenderer()
    let image = try self.makeImage(width: 10, height: 10)
    XCTAssertNil(renderer.cachedImage(for: "a"))
    renderer.store(image, for: "a", config: .default)
    renderer.storeFailure(.syntaxError("no"), for: "b", config: .default)
    XCTAssertEqual(renderer.cachedImage(for: "a"), image)
    XCTAssertNil(renderer.cachedImage(for: "a", config: .dark))
    XCTAssertNil(renderer.cachedFailure(for: "a"))
    XCTAssertEqual(renderer.cachedFailure(for: "b"), .syntaxError("no"))
    XCTAssertNil(renderer.cachedImage(for: "b"))
    // A rendered image replaces an error
    renderer.store(image, for: "b", config: .default)
    XCTAssertNil(renderer.cachedFailure(for: "b"))
    renderer.clearCache()
    XCTAssertNil(renderer.cachedImage(for: "a"))
    XCTAssertNil(renderer.cachedImage(for: "b"))
  }

  func testCacheIsBounded() throws {
    let renderer = try self.makeRenderer()
    let image = try self.makeImage(width: 4, height: 4)
    for index in 0..<300 {
      renderer.store(image, for: "diagram \(index)", config: .default)
    }
    XCTAssertNil(renderer.cachedImage(for: "diagram 0"))
    XCTAssertNotNil(renderer.cachedImage(for: "diagram 299"))
  }

  func testCacheLimitsAreDocumentedDefaults() throws {
    XCTAssertEqual(MermaidRenderer.defaultMaxCachedDiagrams, 128)
    XCTAssertEqual(MermaidRenderer.defaultMaxCacheBytes, 64 * 1024 * 1024)
  }

  func testCacheDropsTheEntriesWhichWereUsedLeastRecently() throws {
    let renderer = try self.makeRenderer(maxCachedDiagrams: 3)
    for name in ["a", "b", "c"] {
      renderer.store(self.makeImage(bytes: 10), for: name, config: .default)
    }
    XCTAssertEqual(renderer.cachedDiagramCount, 3)
    // Looking up "a" makes "b" the entry that has not been used for the longest time
    XCTAssertNotNil(renderer.cachedImage(for: "a"))
    renderer.store(self.makeImage(bytes: 10), for: "d", config: .default)
    XCTAssertEqual(renderer.cachedDiagramCount, 3)
    XCTAssertNotNil(renderer.cachedImage(for: "a"))
    XCTAssertNil(renderer.cachedImage(for: "b"))
    XCTAssertNotNil(renderer.cachedImage(for: "c"))
    XCTAssertNotNil(renderer.cachedImage(for: "d"))
    // Errors are entries too, and are used like images
    renderer.storeFailure(.syntaxError("x"), for: "e", config: .default)
    XCTAssertNil(renderer.cachedImage(for: "a"))
    XCTAssertEqual(renderer.cachedFailure(for: "e"), .syntaxError("x"))
    XCTAssertEqual(renderer.cachedDiagramCount, 3)
    // Configurations of a diagram are different entries
    renderer.store(self.makeImage(bytes: 10), for: "c", config: .dark)
    XCTAssertEqual(renderer.cachedDiagramCount, 3)
  }

  func testCacheDropsImagesWhenItGetsTooLarge() throws {
    let renderer = try self.makeRenderer(maxCacheBytes: 2500)
    for name in ["a", "b"] {
      renderer.store(self.makeImage(bytes: 1000), for: name, config: .default)
    }
    XCTAssertEqual(renderer.cachedByteCount, 2000)
    renderer.store(self.makeImage(bytes: 1000), for: "c", config: .default)
    XCTAssertEqual(renderer.cachedByteCount, 2000)
    XCTAssertEqual(renderer.cachedDiagramCount, 2)
    XCTAssertNil(renderer.cachedImage(for: "a"))
    XCTAssertNotNil(renderer.cachedImage(for: "b"))
    // The newest image stays, even if it is larger than the limit; everything else goes
    renderer.store(self.makeImage(bytes: 5000), for: "big", config: .default)
    XCTAssertEqual(renderer.cachedDiagramCount, 1)
    XCTAssertEqual(renderer.cachedByteCount, 5000)
    XCTAssertNotNil(renderer.cachedImage(for: "big"))
    renderer.clearCache()
    XCTAssertEqual(renderer.cachedDiagramCount, 0)
    XCTAssertEqual(renderer.cachedByteCount, 0)
  }

  func testCacheLimitsHaveAMinimum() throws {
    let renderer = try self.makeRenderer(maxCachedDiagrams: 0, maxCacheBytes: -5)
    renderer.store(self.makeImage(bytes: 10), for: "a", config: .default)
    XCTAssertNotNil(renderer.cachedImage(for: "a"))
    renderer.store(self.makeImage(bytes: 10), for: "b", config: .default)
    XCTAssertNil(renderer.cachedImage(for: "a"))
    XCTAssertNotNil(renderer.cachedImage(for: "b"))
    XCTAssertEqual(renderer.cachedDiagramCount, 1)
  }

  func testReplacingAnEntryDoesNotCountItTwice() throws {
    let renderer = try self.makeRenderer(maxCachedDiagrams: 2)
    renderer.storeFailure(.syntaxError("x"), for: "a", config: .default)
    renderer.store(self.makeImage(bytes: 10), for: "a", config: .default)
    renderer.store(self.makeImage(bytes: 20), for: "a", config: .default)
    XCTAssertEqual(renderer.cachedDiagramCount, 1)
    XCTAssertEqual(renderer.cachedByteCount, 20)
    XCTAssertNil(renderer.cachedFailure(for: "a"))
    renderer.store(self.makeImage(bytes: 10), for: "b", config: .default)
    // Both fit: before, the first diagram was counted twice and dropped too early
    XCTAssertNotNil(renderer.cachedImage(for: "a"))
    XCTAssertNotNil(renderer.cachedImage(for: "b"))
    XCTAssertEqual(renderer.cachedByteCount, 30)
  }

  func testErrorsAreDescribed() {
    XCTAssertEqual(MermaidError.timedOut, MermaidError.timedOut)
    XCTAssertNotEqual(MermaidError.syntaxError("a"), MermaidError.syntaxError("b"))
    for error in [MermaidError.unsupportedPlatform, .resourcesMissing, .syntaxError("x"),
                  .timedOut, .cancelled, .renderingFailed("y")] {
      XCTAssertFalse((error.errorDescription ?? "").isEmpty)
    }
    XCTAssertEqual(MermaidError.syntaxError("first\nsecond").summary, "first")
  }

  // MARK: Rendering in a web view

  #if canImport(WebKit)

  /// The size in pixels and the alpha value of the top left pixel of a PNG.
  private func inspect(png: Data) throws -> (width: Int, height: Int, cornerAlpha: UInt8, opaqueShare: Double) {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    let width = image.width, height = image.height
    let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let pixels = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: width * height * 4)
    var opaque = 0
    for index in 0..<(width * height) where pixels[index * 4 + 3] > 0 {
      opaque += 1
    }
    return (width, height, pixels[3], Double(opaque) / Double(width * height))
  }

  func testSharedRendererIsAvailable() {
    XCTAssertNotNil(MermaidRenderer.shared)
  }

  func testRendersADiagramToATransparentPNG() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    renderer.clearCache()
    let image = try await renderer.render(self.flowchart)
    XCTAssertEqual(image.scale, 2)
    XCTAssertGreaterThan(image.size.width, 20)
    XCTAssertGreaterThan(image.size.height, 20)
    XCTAssertLessThanOrEqual(image.size.width, 800)
    let png = try self.inspect(png: image.pngData)
    XCTAssertEqual(png.width, Int((image.size.width * 2).rounded(.up)))
    XCTAssertEqual(png.height, Int((image.size.height * 2).rounded(.up)))
    XCTAssertEqual(png.cornerAlpha, 0, "the background is not transparent")
    XCTAssertGreaterThan(png.opaqueShare, 0.02, "the image seems to be empty")
    XCTAssertLessThan(png.opaqueShare, 0.9)
    // The image is cached
    XCTAssertEqual(renderer.cachedImage(for: self.flowchart), image)
    let again = try await renderer.render(self.flowchart)
    XCTAssertEqual(again, image)
  }

  func testRendersDifferentKindsOfDiagrams() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    let diagrams = [
      self.sequence,
      "pie title Pets\n  \"Dogs\" : 386\n  \"Cats\" : 85\n",
      "classDiagram\n  Animal <|-- Duck\n  Animal : +int age\n",
      "stateDiagram-v2\n  [*] --> Still\n  Still --> [*]\n",
      "mindmap\n  root((Ideas))\n    A\n    B\n",
    ]
    for diagram in diagrams {
      let image = try await renderer.render(diagram)
      XCTAssertGreaterThan(image.size.width, 20, diagram)
      XCTAssertGreaterThan(image.size.height, 20, diagram)
      XCTAssertGreaterThan(try self.inspect(png: image.pngData).opaqueShare, 0.01, diagram)
    }
  }

  func testConfigurationChangesTheImage() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    let light = try await renderer.render(self.flowchart, config: .default)
    let dark = try await renderer.render(self.flowchart, config: .dark)
    XCTAssertNotEqual(light.pngData, dark.pngData)
    let larger = try await renderer.render(self.flowchart, config: MermaidConfig(scale: 3))
    XCTAssertEqual(larger.scale, 3)
    XCTAssertEqual(try self.inspect(png: larger.pngData).width,
                   Int((larger.size.width * 3).rounded(.up)))
    XCTAssertEqual(larger.size, light.size)
    // A narrow page scales a wide diagram down
    let wide = "graph LR\n" + (0..<12).map { "  N\($0)[A fairly long label \($0)] --> N\($0 + 1)[Next]\n" }.joined()
    let natural = try await renderer.render(wide, config: MermaidConfig(width: 1600))
    let narrow = try await renderer.render(wide, config: MermaidConfig(width: 400))
    XCTAssertGreaterThan(natural.size.width, 400)
    XCTAssertLessThanOrEqual(narrow.size.width, 400)
  }

  func testInvalidSyntaxIsReportedAndRemembered() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    renderer.clearCache()
    do {
      _ = try await renderer.render(self.broken)
      XCTFail("expected an error")
    } catch let error as MermaidError {
      guard case .syntaxError(let message) = error else {
        return XCTFail("unexpected error \(error)")
      }
      XCTAssertFalse(message.isEmpty)
      XCTAssertEqual(renderer.cachedFailure(for: self.broken), error)
    }
    // The renderer keeps working, and the error is returned without rendering again
    _ = try await renderer.render(self.flowchart)
    do {
      _ = try await renderer.render(self.broken)
      XCTFail("expected an error")
    } catch let error as MermaidError {
      if case .syntaxError = error {} else {
        XCTFail("unexpected error \(error)")
      }
    }
  }

  @MainActor
  func testScriptIsCachedUnlessDisabled() async throws {
    let url = try XCTUnwrap(MarkdownKitResources.bundle?.url(forResource: "mermaid.min",
                                                              withExtension: "js"))
    // Caching is the default
    let caching = MermaidWebSession(scriptURL: url)
    XCTAssertFalse(caching.hasCachedScript)
    let first = try await caching.render(source: self.flowchart, config: .default)
    XCTAssertTrue(caching.hasCachedScript)
    // A new page, which needs the script again, still works
    let second = try await caching.render(source: self.flowchart, config: MermaidConfig(width: 640))
    XCTAssertTrue(caching.hasCachedScript)
    XCTAssertEqual(first.size, second.size)
    // Without caching, nothing is kept
    let direct = MermaidWebSession(scriptURL: url, cachesScript: false)
    let image = try await direct.render(source: self.flowchart, config: .default)
    XCTAssertFalse(direct.hasCachedScript)
    let again = try await direct.render(source: self.flowchart, config: MermaidConfig(width: 640))
    XCTAssertFalse(direct.hasCachedScript)
    XCTAssertEqual(image.size, first.size)
    XCTAssertEqual(again.size, second.size)
    // A renderer passes the option on
    let renderer = try XCTUnwrap(MermaidRenderer(mermaidJSURL: url, cachesScript: false))
    let rendered = try await renderer.render(self.flowchart)
    XCTAssertEqual(rendered.size, first.size)
  }

  @MainActor
  func testWebPageIsReleasedWhenItIsIdle() async throws {
    let url = try XCTUnwrap(MarkdownKitResources.bundle?.url(forResource: "mermaid.min",
                                                              withExtension: "js"))
    // By default, the page is kept for a while
    let normal = MermaidWebSession(scriptURL: url)
    XCTAssertFalse(normal.hasPage)
    _ = try await normal.render(source: self.flowchart, config: .default)
    XCTAssertTrue(normal.hasPage)
    // With an idle time of 0, it is released as soon as nothing is waiting for it
    let immediate = MermaidWebSession(scriptURL: url, idleTime: 0)
    _ = try await immediate.render(source: self.flowchart, config: .default)
    XCTAssertFalse(immediate.hasPage)
    _ = try await immediate.render(source: self.sequence, config: .default)
    XCTAssertFalse(immediate.hasPage)
    // Requests which wait for each other share the page
    let (flowchart, sequence) = (self.flowchart, self.sequence)
    let config = MermaidConfig(width: 700)
    async let first = immediate.render(source: flowchart, config: config)
    async let second = immediate.render(source: sequence, config: config)
    async let third = immediate.render(source: "graph LR\n  P --> Q\n", config: config)
    let images = try await [first, second, third]
    XCTAssertEqual(images.count, 3)
    XCTAssertFalse(immediate.hasPage)
    // A short idle time releases the page when it was not used in the meantime
    let short = MermaidWebSession(scriptURL: url, idleTime: 0.8)
    _ = try await short.render(source: self.flowchart, config: .default)
    XCTAssertTrue(short.hasPage)
    try await Task.sleep(nanoseconds: 400_000_000)
    _ = try await short.render(source: self.sequence, config: .default)
    try await Task.sleep(nanoseconds: 400_000_000)
    XCTAssertTrue(short.hasPage, "the page was used again, so the time starts anew")
    try await Task.sleep(nanoseconds: 1_200_000_000)
    XCTAssertFalse(short.hasPage)
    // The next diagram gets a new page
    _ = try await short.render(source: self.flowchart, config: .default)
    XCTAssertTrue(short.hasPage)
    // An infinite idle time keeps the page
    let forever = MermaidWebSession(scriptURL: url, idleTime: .infinity)
    _ = try await forever.render(source: self.flowchart, config: .default)
    try await Task.sleep(nanoseconds: 300_000_000)
    XCTAssertTrue(forever.hasPage)
    // A renderer passes the option on
    let renderer = try XCTUnwrap(MermaidRenderer(mermaidJSURL: url, idleTime: 0))
    let rendered = try await renderer.render(self.flowchart)
    XCTAssertGreaterThan(rendered.size.width, 20)
    XCTAssertEqual(MermaidRenderer.defaultIdleTime, 60)
  }

  @MainActor
  func testMissingScriptIsReported() async throws {
    let missing = URL(fileURLWithPath: "/nonexistent/mermaid-\(UUID().uuidString).js")
    for caching in [true, false] {
      let session = MermaidWebSession(scriptURL: missing, cachesScript: caching)
      do {
        _ = try await session.render(source: self.flowchart, config: .default)
        XCTFail("expected an error")
      } catch {
        XCTAssertEqual(error as? MermaidError, .resourcesMissing)
      }
      XCTAssertFalse(session.hasCachedScript)
    }
    XCTAssertNil(MermaidRenderer(mermaidJSURL: missing))
    XCTAssertNil(MermaidRenderer(mermaidJSURL: missing, cachesScript: false))
  }

  func testDiagramTextIsNeverTreatedAsJavaScript() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    let source = "graph TD\n  A[\"it's a `tick` and ${1+1} and a \\\\ slash\"] --> B\n"
    let image = try await renderer.render(source)
    XCTAssertGreaterThan(image.size.width, 20)
  }

  func testConcurrentRequestsAreProcessedOneAfterTheOther() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    renderer.clearCache()
    let sources = (0..<6).map { "graph TD\n  A\($0) --> B\($0)\n" }
    let images = try await withThrowingTaskGroup(of: (Int, MermaidImage).self) { group in
      for (index, source) in sources.enumerated() {
        group.addTask {
          return (index, try await renderer.render(source))
        }
      }
      var result: [Int: MermaidImage] = [:]
      for try await (index, image) in group {
        result[index] = image
      }
      return result
    }
    XCTAssertEqual(images.count, 6)
    for source in sources {
      XCTAssertNotNil(renderer.cachedImage(for: source))
    }
  }

  func testCancellationIsReported() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    let source = "graph TD\n  Cancelled --> Task\n"
    let task = Task {
      // Returns at once because the task has been cancelled
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      return try await renderer.render(source)
    }
    task.cancel()
    do {
      _ = try await task.value
      XCTFail("expected cancellation")
    } catch {
      XCTAssertEqual(error as? MermaidError, .cancelled)
    }
    XCTAssertNil(renderer.cachedImage(for: source))
  }

  func testDiagramThatTakesTooLongTimesOut() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    let config = MermaidConfig(timeout: 0.0005)
    do {
      _ = try await renderer.render("graph TD\n  Timeout --> Test\n", config: config)
      XCTFail("expected a timeout")
    } catch {
      XCTAssertEqual(error as? MermaidError, .timedOut)
    }
    // The renderer recovers
    let image = try await renderer.render(self.flowchart)
    XCTAssertGreaterThan(image.size.width, 20)
  }

  func testDiagramsCannotLoadFromTheNetworkOrFiles() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    // The server never gets a request: the content blocker rejects it. The diagram is still
    // rendered, with a missing image.
    let sources = [
      "flowchart TD\n  A@{ img: \"http://127.0.0.1:1/x.png\", label: \"x\", pos: \"b\", w: 60, h: 60, constraint: \"on\" } --> B\n",
      "%%{init: {\"themeCSS\": \"@import url('http://127.0.0.1:1/x.css'); .node {fill: red}\"}}%%\ngraph TD\n  A --> B\n",
    ]
    for source in sources {
      do {
        let image = try await renderer.render(source)
        XCTAssertGreaterThan(image.size.width, 10)
      } catch let error as MermaidError {
        // Mermaid versions may reject the syntax; any error is fine as long as it is not a hang
        if case .timedOut = error {
          XCTFail("rendering timed out")
        }
      }
    }
  }

  // MARK: Generating attributed strings

  func testGenerateAsyncRendersDiagramsAndShowsInvalidOnesAsCode() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    renderer.clearCache()
    let generator = AttributedStringGenerator(mermaid: .default)
    let markdown = "Intro text\n\n```mermaid\n\(self.flowchart)```\n\nMiddle text\n\n```mermaid\n\(self.broken)```\n\nOutro text\n"
    let result = try await generator.generateAsync(doc: self.parse(markdown))
    let found = self.attachments(in: result)
    XCTAssertEqual(found.count, 1)
    let size = try XCTUnwrap(found.first).attachment.bounds.size
    XCTAssertGreaterThan(size.width, 20)
    for text in ["Intro text", "Middle text", "Outro text", "Diagram could not be rendered",
                 "flowchart TD"] {
      XCTAssertTrue(result.string.contains(text), text)
    }
    XCTAssertFalse(result.string.contains("graph TD"))
    XCTAssertFalse(result.string.contains("\u{E000}"))
  }

  func testGenerateAsyncDoesNotRenderDiagramsUnlessEnabled() async throws {
    let generator = AttributedStringGenerator()
    let result = try await generator.generateAsync(
                   doc: self.parse("```mermaid\n\(self.flowchart)```\n"))
    XCTAssertEqual(self.attachments(in: result).count, 0)
    XCTAssertTrue(result.string.contains("graph TD"))
  }

  func testGenerateAsyncWithCompletionHandler() async throws {
    let generator = AttributedStringGenerator(mermaid: .default)
    let doc = self.parse("```mermaid\n\(self.sequence)```\n\ntail\n")
    let count: Int = try await withCheckedThrowingContinuation { continuation in
      generator.generateAsync(doc: doc) { result in
        switch result {
          case .success(let string):
            continuation.resume(returning: self.attachments(in: string).count)
          case .failure(let error):
            continuation.resume(throwing: error)
        }
      }
    }
    XCTAssertEqual(count, 1)
  }

  @available(macOS 14.0, iOS 17.0, *)
  @MainActor
  func testMarkdownTextRendersDiagramsInTheBackground() async throws {
    XCTAssertNil(MarkdownText.defaultPreparer(.trusted, mermaid: nil))
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    renderer.clearCache()
    let doc = self.parse("```mermaid\n\(self.sequence)```\n")
    let generate = MarkdownText.defaultGenerator(.trusted, mermaid: .default)
    let prepare = try XCTUnwrap(MarkdownText.defaultPreparer(.trusted, mermaid: .default))
    // First the text shows the code; once the diagram has been rendered, it shows the diagram
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(generate(doc, .light))).count, 0)
    let changed = await prepare(doc, .light)
    XCTAssertTrue(changed)
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(generate(doc, .light))).count, 1)
    // Dark mode needs another rendering (it uses the dark theme)
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(generate(doc, .dark))).count, 0)
    let changedForDarkMode = await prepare(doc, .dark)
    XCTAssertTrue(changedForDarkMode)
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(generate(doc, .dark))).count, 1)
    let unchanged = await prepare(doc, .dark)
    XCTAssertFalse(unchanged)
    // Without `mermaid:` diagrams stay code
    let plain = MarkdownText.defaultGenerator(.trusted)
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(plain(doc, .light))).count, 0)
  }

  func testGenerateAsyncOfBlocksAndBlock() async throws {
    let generator = AttributedStringGenerator(mermaid: .default)
    let doc = self.parse("```mermaid\n\(self.sequence)```\n")
    guard case .document(let blocks) = doc else {
      return XCTFail("not a document")
    }
    let fromBlocks = try await generator.generateAsync(blocks: blocks)
    XCTAssertEqual(self.attachments(in: fromBlocks).count, 1)
    let fromBlock = try await generator.generateAsync(block: try XCTUnwrap(blocks.first))
    XCTAssertEqual(self.attachments(in: fromBlock).count, 1)
  }

  @MainActor
  func testPrepareDiagramsMakesSynchronousGenerationShowThem() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    renderer.clearCache()
    let generator = AttributedStringGenerator(mermaid: .default)
    let doc = self.parse("```mermaid\n\(self.flowchart)```\n")
    // Not rendered yet
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(generator.generate(doc: doc))).count, 0)
    let rendered = await generator.prepareDiagrams(in: doc)
    XCTAssertTrue(rendered)
    XCTAssertEqual(self.attachments(in: try XCTUnwrap(generator.generate(doc: doc))).count, 1)
    // Nothing is left to be done
    let renderedAgain = await generator.prepareDiagrams(in: doc)
    XCTAssertFalse(renderedAgain)
  }

  @MainActor
  func testPrepareDiagramsDoesNothingIfDisabled() async throws {
    let renderer = try XCTUnwrap(MermaidRenderer.shared)
    renderer.clearCache()
    let doc = self.parse("```mermaid\n\(self.flowchart)```\n")
    let rendered = await AttributedStringGenerator().prepareDiagrams(in: doc)
    XCTAssertFalse(rendered)
    XCTAssertNil(renderer.cachedImage(for: self.flowchart))
  }

  #endif
}

#endif
