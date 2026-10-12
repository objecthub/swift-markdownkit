//
//  MarkdownASTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 26/02/2022.
//  Copyright © 2022 Google LLC.
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

import XCTest
import MarkdownKit
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

class MarkdownASTests: XCTestCase {
  
  private func generateHtml(imageBaseUrl: URL? = nil, _ str: String) -> String {
    return AttributedStringGenerator(imageBaseUrl: imageBaseUrl)
             .htmlGenerator
             .generate(doc: MarkdownParser.standard.parse(str))
             .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
  }
  
  func testSimpleNestedLists() {
    XCTAssertEqual(
      generateHtml("- Apple\n\t- Banana"),
      """
      <table class="ult"><tbody>
      <tr class="crow"><td class="lbullet"><b>•</b></td><td class="citem">Apple
      <table class="uln"><tbody>
      <tr class="srow"><td class="lbullet"><b>•</b></td><td class="sitem">Banana</td></tr>
      </tbody></table>
      </td></tr>
      </tbody></table><p class="spc"></p>
      """)
    XCTAssertEqual(
      AttributedStringGenerator(options: [.tightLists])
               .htmlGenerator
               .generate(doc: MarkdownParser.standard.parse("- Apple\n\t- Banana"))
               .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
      """
      <table class="ult"><tbody>
      <tr class="crow"><td class="lbullet"><b>•</b></td><td class="citem">Apple
      <table class="uln"><tbody>
      <tr class="srow"><td class="lbullet"><b>•</b></td><td class="sitem">Banana</td></tr>
      </tbody></table>
      </td></tr>
      </tbody></table><p class="spc"></p>
      """)
  }
  
  func testBlockquotesAreSingleCells() {
    // The text views clip the first lines of a quote (at some positions in the document) if a
    // quote consists of empty cells next to its text cell. The bar is the border of the cell.
    XCTAssertEqual(generateHtml("> foo"),
                   "<table class=\"blockquote\"><tbody><tr><td class=\"quote\"><p>foo</p>\n" +
                   "</td></tr></tbody></table><p class=\"spc\"></p>")
    let nested = generateHtml("> foo\n>\n> > bar")
    XCTAssertTrue(nested.hasPrefix("<table class=\"blockquote\"><tbody><tr><td class=\"quote\">"),
                  nested)
    XCTAssertEqual(nested.components(separatedBy: "<td").count - 1, 2, nested)
    XCTAssertFalse(nested.contains("<td />") || nested.contains("<tr style"), nested)
    let generator = AttributedStringGenerator(blockquoteColor: "#123456")
    XCTAssertTrue(generator.docStyle.contains("td.quote"), generator.docStyle)
    XCTAssertTrue(generator.quoteStyle.contains("border-left: 0.2em solid #123456"),
                  generator.quoteStyle)
  }

  // MARK: Space above level 1 and level 2 headings

  private let h1Spacer = "<p class=\"h1gap\"></p>\n"
  private let h2Spacer = "<p class=\"h2gap\"></p>\n"

  func testHeadingsAfterOtherContentGetASpacer() {
    let generator = AttributedStringGenerator()
    func html(_ markdown: String) -> String {
      return generator.htmlGenerator.generate(doc: MarkdownParser.standard.parse(markdown))
    }
    XCTAssertEqual(html("text\n\n# One\n\n# Two\n\n## Three\n"),
                   "<p>text</p>\n" + h1Spacer + "<h1>One</h1>\n" + h1Spacer + "<h1>Two</h1>\n" +
                   h2Spacer + "<h2>Three</h2>\n")
    // Not at the beginning of the document, not for other levels
    XCTAssertEqual(html("# One\n\ntext\n"), "<h1>One</h1>\n<p>text</p>\n")
    XCTAssertEqual(html("## One\n\ntext\n"), "<h2>One</h2>\n<p>text</p>\n")
    XCTAssertEqual(html("text\n\n### Three\n\n#### Four\n\n##### Five\n"),
                   "<p>text</p>\n<h3>Three</h3>\n<h4>Four</h4>\n<h5>Five</h5>\n")
    // Nor at the beginning of other containers
    XCTAssertFalse(html("> # Quote\n> text\n").contains("h1gap"))
    XCTAssertFalse(html("> ## Quote\n> text\n").contains("h2gap"))
    XCTAssertTrue(html("> text\n>\n> # Quote\n").contains("h1gap"))
    XCTAssertTrue(html("> text\n>\n> ## Quote\n").contains("h2gap"))
    // A heading after a reference definition is still the first thing that is shown
    XCTAssertFalse(html("[a]: http://example.com\n\n# One\n").contains("h1gap"))
    XCTAssertFalse(html("[a]: http://example.com\n\n## One\n").contains("h2gap"))
    // The same for the other version of the generator
    let older = AttributedStringGenerator(version: .preOS26)
    let olderHtml = older.htmlGenerator.generate(doc: MarkdownParser.standard.parse("text\n\n# One\n\n## Two\n"))
    XCTAssertTrue(olderHtml.contains(h1Spacer + "<h1>"))
    XCTAssertTrue(olderHtml.contains(h2Spacer + "<h2>"))
  }

  func testStyleOfTheSpacersAboveHeadings() {
    let generator = AttributedStringGenerator()
    XCTAssertEqual(generator.h1GapStyle, "font-size: 8px; margin: 0em; padding: 0em;")
    XCTAssertEqual(generator.h2GapStyle, "font-size: 4px; margin: 0em; padding: 0em;")
    XCTAssertTrue(generator.docStyle.contains(
                    "p.h1gap          { font-size: 8px; margin: 0em; padding: 0em; }"))
    XCTAssertTrue(generator.docStyle.contains(
                    "p.h2gap          { font-size: 4px; margin: 0em; padding: 0em; }"))
  }

  #if os(macOS) || os(iOS)

  private final class LargeGapGenerator: AttributedStringGenerator, @unchecked Sendable {
    override var h1GapStyle: String {
      return "font-size: 14px; margin: 0em; padding: 0em;"
    }
    override var h2GapStyle: String {
      return "font-size: 14px; margin: 0em; padding: 0em;"
    }
  }

  /// The distance in points between the text above the heading `heading` and the heading, as
  /// laid out in a text column of 369 points (the width of an iPhone's text).
  @MainActor
  private func distance(to heading: String, in markdown: String,
                        using generator: AttributedStringGenerator) throws -> CGFloat {
    let string = try XCTUnwrap(generator.generate(doc: MarkdownParser.standard.parse(markdown)))
    let storage = NSTextStorage(attributedString: string)
    let layoutManager = NSLayoutManager()
    let container = NSTextContainer(size: CGSize(width: 369, height: CGFloat.greatestFiniteMagnitude))
    container.lineFragmentPadding = 0
    layoutManager.addTextContainer(container)
    storage.addLayoutManager(layoutManager)
    layoutManager.ensureLayout(for: container)
    var previousBottom: CGFloat = 0
    var result: CGFloat?
    layoutManager.enumerateLineFragments(
        forGlyphRange: NSRange(location: 0, length: layoutManager.numberOfGlyphs)) { _, used, _, range, _ in
      let text = (string.string as NSString).substring(
                   with: layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: nil))
      if text.hasPrefix(heading) {
        result = used.minY - previousBottom
      }
      if !text.hasPrefix("\n") && !text.isEmpty && result == nil {
        previousBottom = used.maxY
      }
    }
    return try XCTUnwrap(result)
  }

  @MainActor
  func testSpacersAddSpaceAboveHeadings() throws {
    let generator = AttributedStringGenerator()
    // Above a level 3 heading there is only the space below the paragraph (0.7em)
    let h3 = try self.distance(to: "Heading", in: "Some text.\n\n### Heading\n", using: generator)
    XCTAssertEqual(h3, 9.8, accuracy: 0.3)
    // Above a level 1 heading, there is the spacer paragraph in addition: about 10 points more
    let h1 = try self.distance(to: "Heading", in: "Some text.\n\n# Heading\n", using: generator)
    XCTAssertEqual(h1 - h3, 10, accuracy: 1.5)
    // The spacer of a level 2 heading is half as high: about 5 points
    let h2 = try self.distance(to: "Heading", in: "Some text.\n\n## Heading\n", using: generator)
    XCTAssertEqual(h2 - h3, 5, accuracy: 1.5)
    // Larger spacers make more space
    let large1 = try self.distance(to: "Heading", in: "Some text.\n\n# Heading\n",
                                   using: LargeGapGenerator())
    XCTAssertEqual(large1 - h3, 17, accuracy: 2)
    let large2 = try self.distance(to: "Heading", in: "Some text.\n\n## Heading\n",
                                   using: LargeGapGenerator())
    XCTAssertEqual(large2 - h3, 17, accuracy: 2)
    // The document starts with the heading itself
    for markdown in ["# Heading\n\ntext\n", "## Heading\n\ntext\n"] {
      let first = try XCTUnwrap(generator.generate(doc: MarkdownParser.standard.parse(markdown)))
      XCTAssertTrue(first.string.hasPrefix("Heading"), markdown)
    }
  }

  #endif

  func testRelativeImageUrls() {
    XCTAssertEqual(generateHtml("![Test image](imagefile.png)"),
                   "<p><img src=\"imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](imagefile.png)"),
                   "<p><img src=\"file:///global/root/path/imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](/imagefile.png)"),
                   "<p><img src=\"file:///imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml("![Test image](one/imagefile.png)"),
                   "<p><img src=\"one/imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](one/imagefile.png)"),
                   "<p><img src=\"file:///global/root/path/one/imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](/one/imagefile.png)"),
                   "<p><img src=\"file:///one/imagefile.png\" alt=\"Test image\"/></p>")
  }
}

#endif
