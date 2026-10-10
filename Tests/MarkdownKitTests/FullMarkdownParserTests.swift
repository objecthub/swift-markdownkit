//
//  FullMarkdownParserTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 10/10/2026.
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

import XCTest
import CommandLineKit
@testable import MarkdownKit

/// Tests for `FullMarkdownParser` and the features it enables: underlined and struck-through
/// text, plus the generator changes that go with them.
final class FullMarkdownParserTests: XCTestCase {

  private func html(_ markdown: String,
                    _ parser: MarkdownParser = FullMarkdownParser.standard) -> String {
    return HtmlGenerator.standard.generate(doc: parser.parse(markdown))
                                 .trimmingCharacters(in: .newlines)
  }

  // MARK: Underline and strikethrough

  func testStrikethroughAndUnderline() {
    XCTAssertEqual(html("~~Hi~~ Hello, ~there~ world!"),
                   "<p><del>Hi</del> Hello, <u>there</u> world!</p>")
    XCTAssertEqual(html("~a~ ~b~"), "<p><u>a</u> <u>b</u></p>")
    XCTAssertEqual(html("~~a ~b~ c~~"), "<p><del>a <u>b</u> c</del></p>")
    // Line breaks within the markup
    XCTAssertEqual(html("~~a\nb~~"), "<p><del>a\nb</del></p>")
    XCTAssertEqual(html("~~a  \nb~~"), "<p><del>a<br/>b</del></p>")
  }

  func testTildesCanBeUsedWithinWords() {
    XCTAssertEqual(html("foo~~bar~~baz"), "<p>foo<del>bar</del>baz</p>")
    XCTAssertEqual(html("a~b~c"), "<p>a<u>b</u>c</p>")
  }

  func testTildesWhichAreNotEmphasis() {
    // Markup cannot span paragraphs
    XCTAssertEqual(html("This ~~has a\n\nnew paragraph~~."),
                   "<p>This ~~has a</p>\n<p>new paragraph~~.</p>")
    // Three or more tildes are no markup
    XCTAssertEqual(html("This will ~~~not~~~ strike."), "<p>This will ~~~not~~~ strike.</p>")
    XCTAssertEqual(html("x ~~~a~~ y"), "<p>x ~~~a~~ y</p>")
    XCTAssertEqual(html("~~a~~~"), "<p>~~a~~~</p>")
    // Delimiters need to be next to text
    XCTAssertEqual(html("a ~ b ~ c"), "<p>a ~ b ~ c</p>")
    XCTAssertEqual(html("~~ a ~~"), "<p>~~ a ~~</p>")
    // Unmatched delimiters are text
    XCTAssertEqual(html("~a"), "<p>~a</p>")
    XCTAssertEqual(html("a~"), "<p>a~</p>")
    XCTAssertEqual(html("~~a"), "<p>~~a</p>")
    // Tildes in code are not markup
    XCTAssertEqual(html("`~~a~~`"), "<p><code>~~a~~</code></p>")
    XCTAssertEqual(html("    ~~a~~"), "<pre><code>~~a~~\n</code></pre>")
  }

  func testTildesWithDifferentLengthsMatchLikeOtherEmphasis() {
    // As with `*` and `**`, the shorter run determines the markup; the rest is text
    XCTAssertEqual(html("~~a~"), "<p>~<u>a</u></p>")
    XCTAssertEqual(html("~a~~"), "<p><u>a</u>~</p>")
  }

  func testEscapedTildes() {
    XCTAssertEqual(html("\\~\\~a\\~\\~"), "<p>~~a~~</p>")
    XCTAssertEqual(html("\\~~a~"), "<p>~<u>a</u></p>")
  }

  func testTildesCombinedWithOtherMarkup() {
    XCTAssertEqual(html("*~~a~~*"), "<p><em><del>a</del></em></p>")
    XCTAssertEqual(html("~~*a*~~"), "<p><del><em>a</em></del></p>")
    XCTAssertEqual(html("**a ~b~ c**"), "<p><strong>a <u>b</u> c</strong></p>")
    XCTAssertEqual(html("~~**a**~~ and ~_b_~"),
                   "<p><del><strong>a</strong></del> and <u><em>b</em></u></p>")
    XCTAssertEqual(html("[~~a~~](http://x)"), "<p><a href=\"http://x\"><del>a</del></a></p>")
    XCTAssertEqual(html("~~[a](http://x)~~"), "<p><del><a href=\"http://x\">a</a></del></p>")
    XCTAssertEqual(html("<b>~a~</b>"), "<p><b><u>a</u></b></p>")
    XCTAssertEqual(html("&amp;~a~"), "<p>&amp;<u>a</u></p>")
    // The alternative text of an image is plain text
    XCTAssertEqual(html("![~a~](u)"), "<p><img src=\"u\" alt=\"a\"/></p>")
  }

  func testTildesInOtherBlocks() {
    XCTAssertEqual(html("# ~a~ b"), "<h1><u>a</u> b</h1>")
    XCTAssertEqual(html("> ~~a~~"), "<blockquote>\n<p><del>a</del></p>\n</blockquote>")
    XCTAssertEqual(html("- ~a~"), "<ul>\n<li><u>a</u></li>\n</ul>")
    XCTAssertEqual(html("| ~~a~~ | ~b~ |\n|---|---|\n| x | y |"),
                   "<table><thead><tr>\n<th><del>a</del></th><th><u>b</u></th>\n" +
                   "</tr></thead><tbody>\n<tr><td>x</td><td>y</td></tr>\n</tbody></table>")
    XCTAssertEqual(html("Term\n: ~~def~~"), "<dl>\n<dt>Term</dt>\n<dd><del>def</del></dd>\n</dl>")
    // Fenced code blocks with tildes are not affected
    XCTAssertEqual(html("~~~\ncode\n~~~"), "<pre><code>code\n</code></pre>")
  }

  func testSyntaxTree() {
    let doc = FullMarkdownParser.standard.parse("~~a~~ ~b~")
    var paragraph = Text(.strikethrough(Text(.text("a"))))
    paragraph.append(fragment: .text(" "))
    paragraph.append(fragment: .underline(Text(.text("b"))))
    XCTAssertEqual(doc, .document([.paragraph(paragraph)]))
    XCTAssertEqual(doc.debugDescription,
                   "document(paragraph(strikethrough(text(\"a\")), text(\" \"), underline(text(\"b\"))))")
  }

  func testTextFragmentDescriptions() {
    let text = Text(.text("a"))
    XCTAssertEqual(TextFragment.underline(text).description, "~a~")
    XCTAssertEqual(TextFragment.strikethrough(text).description, "~~a~~")
    XCTAssertEqual(TextFragment.underline(text).rawDescription, "a")
    XCTAssertEqual(TextFragment.strikethrough(text).string, "a")
    XCTAssertEqual(TextFragment.underline(text).debugDescription, "underline(text(\"a\"))")
    XCTAssertEqual(TextFragment.strikethrough(text).debugDescription, "strikethrough(text(\"a\"))")
    XCTAssertEqual(TextFragment.underline(text), .underline(Text(.text("a"))))
    XCTAssertNotEqual(TextFragment.underline(text), .strikethrough(text))
    XCTAssertNotEqual(TextFragment.underline(text), .emph(text))
    XCTAssertEqual(FullMarkdownParser.standard.parse("a ~~b~~ ~c~").string, "a b c")
  }

  // MARK: Other parsers

  func testOtherParsersDoNotKnowTheNewMarkup() {
    for parser in [MarkdownParser.standard, ExtendedMarkdownParser.standard] {
      XCTAssertEqual(html("~~a~~ ~b~", parser), "<p>~~a~~ ~b~</p>")
      XCTAssertEqual(html("a~b~c", parser), "<p>a~b~c</p>")
    }
  }

  func testFullParserIsAnExtendedParser() {
    let parser: MarkdownParser = FullMarkdownParser.standard
    XCTAssertTrue(parser is ExtendedMarkdownParser)
    XCTAssertTrue(parser is FullMarkdownParser)
    XCTAssertFalse(ExtendedMarkdownParser.standard is FullMarkdownParser)
    XCTAssertTrue(FullMarkdownParser.standard === FullMarkdownParser.standard)
    // Tables and definition lists come from the extended parser
    XCTAssertTrue(html("a | b\n- | -\nc | d").hasPrefix("<table>"))
    XCTAssertTrue(html("Term\n: Definition").hasPrefix("<dl>"))
    // The configuration can still be replaced
    let custom = FullMarkdownParser(inlineTransformers: [EscapeTransformer.self])
    XCTAssertEqual(html("~a~", custom), "<p>~a~</p>")
  }

  private struct Example: Decodable {
    let markdown: String
    let example: Int
  }

  /// The additional markup does not change how other Markdown is parsed
  func testCommonMarkExamplesAreParsedLikeByTheExtendedParser() throws {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: FullMarkdownParserTests.self)
    #endif
    let url = try XCTUnwrap(bundle.url(forResource: "commonmark-spec-0.31.2",
                                       withExtension: "json"))
    let examples = try JSONDecoder().decode([Example].self, from: Data(contentsOf: url))
    XCTAssertEqual(examples.count, 652)
    for example in examples {
      XCTAssertEqual(HtmlGenerator.standard.generate(
                       doc: FullMarkdownParser.standard.parse(example.markdown)),
                     HtmlGenerator.standard.generate(
                       doc: ExtendedMarkdownParser.standard.parse(example.markdown)),
                     "example \(example.example): \(example.markdown.debugDescription)")
    }
  }

  // MARK: Generators

  func testSafeModeKeepsTheMarkup() {
    let doc = FullMarkdownParser.standard.parse("~~a~~ ~b~ <i>c</i>")
    XCTAssertEqual(HtmlGenerator(safeMode: true).generate(doc: doc),
                   "<p><del>a</del> <u>b</u> <!-- raw HTML omitted -->c<!-- raw HTML omitted --></p>\n")
  }

  func testStringGenerator() {
    let doc = FullMarkdownParser.standard.parse("~~a~~ ~b~ *c*")
    XCTAssertEqual(StringGenerator.standard.generate(doc: doc).trimmingCharacters(in: .newlines),
                   "~~a~~ ~b~ *c*")
  }

  private func textProperties(_ text: AnsiText.Normalized, of string: String) -> TextProperties? {
    return text.segments.first(where: { $0.1 == string })?.0
  }

  func testTerminalGenerator() {
    let doc = FullMarkdownParser.standard.parse("~~a~~ ~b~ *c*")
    let text = TerminalGenerator.standard.generate(doc: doc)
    XCTAssertEqual(self.textProperties(text, of: "a")?.textStyles, [.strikethrough])
    XCTAssertEqual(self.textProperties(text, of: "b")?.textStyles, [.underline])
    XCTAssertEqual(self.textProperties(text, of: "c")?.textStyles, [.italic])
    // The text properties can be configured
    let generator = TerminalGenerator(
                      underlineProperties: TextProperties(textColor: .red, textStyles: [.underline]),
                      strikethroughProperties: TextProperties(textColor: .blue,
                                                              textStyles: [.strikethrough, .dim]))
    let custom = generator.generate(doc: doc)
    XCTAssertEqual(self.textProperties(custom, of: "a"),
                   TextProperties(textColor: .blue, textStyles: [.strikethrough, .dim]))
    XCTAssertEqual(self.textProperties(custom, of: "b"),
                   TextProperties(textColor: .red, textStyles: [.underline]))
    // Nested markup combines
    let nested = TerminalGenerator.standard.generate(doc: FullMarkdownParser.standard.parse("~~*a*~~"))
    XCTAssertEqual(self.textProperties(nested, of: "a")?.textStyles, [.strikethrough, .italic])
  }

  @MainActor
  func testAttributedStringGenerator() throws {
    let doc = FullMarkdownParser.standard.parse("plain ~~gone~~ and ~under~ the end")
    let result = try XCTUnwrap(AttributedStringGenerator().generate(doc: doc))
    func style(of word: String, _ key: NSAttributedString.Key) -> Int {
      let range = (result.string as NSString).range(of: word)
      XCTAssertNotEqual(range.location, NSNotFound, word)
      return (result.attribute(key, at: range.location, effectiveRange: nil) as? Int) ?? 0
    }
    XCTAssertNotEqual(style(of: "gone", .strikethroughStyle), 0)
    XCTAssertEqual(style(of: "gone", .underlineStyle), 0)
    XCTAssertNotEqual(style(of: "under", .underlineStyle), 0)
    XCTAssertEqual(style(of: "under", .strikethroughStyle), 0)
    XCTAssertEqual(style(of: "plain", .strikethroughStyle), 0)
    XCTAssertEqual(style(of: "plain", .underlineStyle), 0)
  }

  // MARK: Tables without rows

  func testTableWithoutRowsHasNoBody() {
    for markdown in ["a | b\n--- | ---", "| a | b |\n|:-:|--:|", "a | b\n--- | ---\n"] {
      for parser in [ExtendedMarkdownParser.standard, FullMarkdownParser.standard] {
        let output = html(markdown, parser)
        XCTAssertTrue(output.hasPrefix("<table><thead>"), output)
        XCTAssertTrue(output.hasSuffix("</tr></thead></table>"), output)
        XCTAssertFalse(output.contains("<tbody>"), output)
      }
    }
    // Tables with rows still have a body
    XCTAssertTrue(html("a | b\n--- | ---\n1 | 2").contains("<tbody>\n<tr><td>1</td>"))
  }

  func testTableWithoutRowsHasNoBodyInAttributedStringHtml() {
    let doc = FullMarkdownParser.standard.parse("a | b\n--- | ---")
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      let generator = AttributedStringGenerator(version: version)
      let output = generator.htmlGenerator.generate(doc: doc)
      XCTAssertTrue(output.contains("</tr></thead></table>"), output)
      XCTAssertFalse(output.contains("<tbody>"), output)
    }
    let withRows = FullMarkdownParser.standard.parse("a | b\n--- | ---\n1 | 2")
    XCTAssertTrue(AttributedStringGenerator().htmlGenerator.generate(doc: withRows)
                                              .contains("<tbody>"))
  }

  // MARK: Hooks of custom text fragments

  private struct Shout: CustomTextFragment {
    let word: String
    func equals(to other: CustomTextFragment) -> Bool {
      return (other as? Shout)?.word == self.word
    }
    func transform(via transformer: InlineTransformer) -> TextFragment {
      return .custom(self)
    }
    func generateHtml(via htmlGen: HtmlGenerator) -> String {
      return "<b>\(self.word)</b>"
    }
    func generateHtml(via htmlGen: HtmlGenerator, and attrGen: AttributedStringGenerator?) -> String {
      return self.generateHtml(via: htmlGen)
    }
    var rawDescription: String {
      return self.word
    }
    var description: String {
      return self.word
    }
    var debugDescription: String {
      return "shout(\(self.word))"
    }
    func generateText(via generator: StringGenerator) -> String {
      return self.word.uppercased()
    }
    func generateText(via generator: TerminalGenerator) -> AnsiText.Normalized {
      return AnsiText.Normalized(self.word.uppercased(), properties: .bold)
    }
  }

  /// A custom text fragment without its own text generation
  private struct Plain: CustomTextFragment {
    let word: String
    func equals(to other: CustomTextFragment) -> Bool {
      return (other as? Plain)?.word == self.word
    }
    func transform(via transformer: InlineTransformer) -> TextFragment {
      return .custom(self)
    }
    func generateHtml(via htmlGen: HtmlGenerator) -> String {
      return self.word
    }
    func generateHtml(via htmlGen: HtmlGenerator, and attrGen: AttributedStringGenerator?) -> String {
      return self.word
    }
    var rawDescription: String {
      return self.word
    }
    var description: String {
      return self.word
    }
    var debugDescription: String {
      return "plain(\(self.word))"
    }
  }

  func testCustomTextFragmentsCanGenerateText() {
    let doc = Block.document([.paragraph(Text(.custom(Shout(word: "hey"))))])
    XCTAssertEqual(StringGenerator.standard.generate(doc: doc).trimmingCharacters(in: .newlines),
                   "HEY")
    let text = TerminalGenerator.standard.generate(doc: doc)
    XCTAssertEqual(self.textProperties(text, of: "HEY"), .bold)
  }

  func testCustomTextFragmentsHaveDefaultsForGeneratingText() {
    // Without own implementation, the raw text is used (without control characters)
    let doc = Block.document([.paragraph(Text(.custom(Plain(word: "a\u{1B}b"))))])
    XCTAssertEqual(StringGenerator.standard.generate(doc: doc).trimmingCharacters(in: .newlines),
                   "a\u{FFFD}b")
    let text = TerminalGenerator.standard.generate(doc: doc)
    XCTAssertEqual(self.textProperties(text, of: "a\u{FFFD}b"), TextProperties.empty)
  }
}
