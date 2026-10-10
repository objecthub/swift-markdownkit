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

  // MARK: Task lists

  func testTaskListItems() {
    // The examples of the GFM specification
    XCTAssertEqual(html("- [ ] foo\n- [x] bar"),
                   "<ul>\n<li><input disabled=\"\" type=\"checkbox\"> foo</li>\n" +
                   "<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> bar</li>\n</ul>")
    XCTAssertEqual(html("- [x] foo\n  - [ ] bar\n  - [x] baz\n- [ ] bim"),
                   "<ul>\n<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> foo\n<ul>\n" +
                   "<li><input disabled=\"\" type=\"checkbox\"> bar</li>\n" +
                   "<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> baz</li>\n</ul>\n</li>\n" +
                   "<li><input disabled=\"\" type=\"checkbox\"> bim</li>\n</ul>")
  }

  func testTaskListItemsWithAllKindsOfMarkers() {
    for (markdown, expected) in [("* [X] caps", "<ul>\n<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> caps</li>\n</ul>"),
                                 ("+ [ ] plus", "<ul>\n<li><input disabled=\"\" type=\"checkbox\"> plus</li>\n</ul>"),
                                 ("1. [x] a\n2. [ ] b", "<ol start=\"1\">\n<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> a</li>\n" +
                                                         "<li><input disabled=\"\" type=\"checkbox\"> b</li>\n</ol>"),
                                 ("10) [ ] x", "<ol start=\"10\">\n<li><input disabled=\"\" type=\"checkbox\"> x</li>\n</ol>"),
                                 ("- [ ]\tTab", "<ul>\n<li><input disabled=\"\" type=\"checkbox\"> Tab</li>\n</ul>"),
                                 ("- [ ]    spaced", "<ul>\n<li><input disabled=\"\" type=\"checkbox\"> spaced</li>\n</ul>")] {
      XCTAssertEqual(html(markdown), expected, markdown.debugDescription)
    }
  }

  func testTaskListItemsAreLikeOtherItems() {
    // Loose lists: the checkbox is in the paragraph
    XCTAssertEqual(html("- [ ] a\n\n- [x] b"),
                   "<ul>\n<li><p><input disabled=\"\" type=\"checkbox\"> a</p>\n</li>\n" +
                   "<li><p><input checked=\"\" disabled=\"\" type=\"checkbox\"> b</p>\n</li>\n</ul>")
    // Task list items and other items can be mixed
    XCTAssertEqual(html("- [ ] a\n- b\n- [x] c"),
                   "<ul>\n<li><input disabled=\"\" type=\"checkbox\"> a</li>\n<li>b</li>\n" +
                   "<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> c</li>\n</ul>")
    // The kind of list marker still determines the lists
    XCTAssertEqual(html("+ [ ] a\n- [x] b"),
                   "<ul>\n<li><input disabled=\"\" type=\"checkbox\"> a</li>\n</ul>\n" +
                   "<ul>\n<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> b</li>\n</ul>")
    // Items with more than one line or block, and with markup
    XCTAssertEqual(html("- [ ] a\n  b"), "<ul>\n<li><input disabled=\"\" type=\"checkbox\"> a\nb</li>\n</ul>")
    XCTAssertEqual(html("- [ ] *em* ~~s~~ [l](u)"),
                   "<ul>\n<li><input disabled=\"\" type=\"checkbox\"> <em>em</em> <del>s</del> " +
                   "<a href=\"u\">l</a></li>\n</ul>")
    XCTAssertEqual(html("> - [ ] x"),
                   "<blockquote>\n<ul>\n<li><input disabled=\"\" type=\"checkbox\"> x</li>\n</ul>\n</blockquote>")
    XCTAssertEqual(html("- [ ] a\n\n  more\n  - [x] b"),
                   "<ul>\n<li><p><input disabled=\"\" type=\"checkbox\"> a</p>\n<p>more</p>\n<ul>\n" +
                   "<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> b</li>\n</ul>\n</li>\n</ul>")
  }

  func testTextWhichIsNoTaskMarker() {
    for markdown in ["- [x]foo", "- [y] foo", "- [] foo", "- [  ] foo", "- [ ]", "- [ ] ",
                     "- foo [ ] bar", "- *[ ]* foo", "- a\n\n  [ ] b", "[ ] foo", "[x] foo"] {
      let output = html(markdown)
      XCTAssertFalse(output.contains("<input"), "\(markdown.debugDescription): \(output)")
      // Without a task list marker, the result is the one of the extended parser
      XCTAssertEqual(output, html(markdown, ExtendedMarkdownParser.standard),
                     markdown.debugDescription)
    }
    // Definition lists are no lists of tasks
    XCTAssertEqual(html("Term\n: [ ] def"), "<dl>\n<dt>Term</dt>\n<dd>[ ] def</dd>\n</dl>")
    // The marker needs to be at the start of the text of the first paragraph
    XCTAssertEqual(html("- [ ]\n  foo"), "<ul>\n<li>[ ]\nfoo</li>\n</ul>")
  }

  func testTaskListSyntaxTree() {
    let doc = FullMarkdownParser.standard.parse("- [ ] a\n1. [x] b")
    XCTAssertTrue(doc.debugDescription.contains("listItem(task(bullet(-), checked: false), "),
                  doc.debugDescription)
    XCTAssertTrue(doc.debugDescription.contains("listItem(task(ordered(1, .), checked: true), "),
                  doc.debugDescription)
    // The text of a task list item does not contain the marker
    XCTAssertEqual(doc.string, "a\nb")
    // With block parsing only, the marker is text
    let blocks = FullMarkdownParser.standard.parse("- [x] a", blockOnly: true)
    XCTAssertFalse(blocks.debugDescription.contains("task"))
    XCTAssertTrue(blocks.debugDescription.contains("[x] a"))
  }

  func testSplitTaskMarker() {
    func split(_ str: String, _ rest: TextFragment...) -> (checked: Bool, rest: String)? {
      var text = Text(.text(Substring(str)))
      for fragment in rest {
        text.append(fragment: fragment)
      }
      return TaskListInlineParser.splitTaskMarker(of: text).map { ($0.checked, $0.rest.rawDescription) }
    }
    XCTAssertTrue(split("[ ] a")?.checked == false && split("[ ] a")?.rest == "a")
    XCTAssertTrue(split("[x] a")?.checked == true && split("[X] a")?.checked == true)
    XCTAssertEqual(split(" [ ] a")?.rest, nil)
    XCTAssertEqual(split("[ ]\t \ta")?.rest, "a")
    XCTAssertEqual(split("[ ] a", .softLineBreak, .text("b"))?.rest, "a b")
    XCTAssertEqual(split("[ ] ", .emph(Text(.text("b"))))?.rest, "b")
    XCTAssertNil(split("[ ]"))
    XCTAssertNil(split("[ ]a"))
    XCTAssertNil(split("[a] a"))
    XCTAssertNil(TaskListInlineParser.splitTaskMarker(of: Text()))
    XCTAssertNil(TaskListInlineParser.splitTaskMarker(of: Text(.emph(Text(.text("[ ] a"))))))
  }

  func testListTypeOfTaskListItems() {
    let task = ListType.task(.ordered(3, "."), checked: true)
    XCTAssertEqual(task.description, "task(ordered(3, .), checked: true)")
    XCTAssertEqual(task.debugDescription, task.description)
    XCTAssertEqual(task.startNumber, 3)
    XCTAssertEqual(ListType.task(.bullet("*"), checked: false).startNumber, nil)
    XCTAssertTrue(task.isTask)
    XCTAssertFalse(ListType.bullet("-").isTask)
    XCTAssertEqual(task.checked, true)
    XCTAssertEqual(ListType.task(.bullet("-"), checked: false).checked, false)
    XCTAssertNil(ListType.ordered(1, ".").checked)
    XCTAssertEqual(task.marker, .ordered(3, "."))
    XCTAssertEqual(ListType.bullet("+").marker, .bullet("+"))
    XCTAssertEqual(ListType.task(.task(.bullet("-"), checked: true), checked: false).marker, .bullet("-"))
    // Items are compatible if their markers are
    XCTAssertTrue(task.compatible(with: .ordered(1, ".")))
    XCTAssertTrue(ListType.bullet("-").compatible(with: .task(.bullet("-"), checked: false)))
    XCTAssertTrue(ListType.task(.bullet("-"), checked: true)
                    .compatible(with: .task(.bullet("-"), checked: false)))
    XCTAssertFalse(task.compatible(with: .ordered(1, ")")))
    XCTAssertFalse(task.compatible(with: .bullet("-")))
    XCTAssertFalse(ListType.task(.bullet("-"), checked: true).compatible(with: .bullet("+")))
    XCTAssertNotEqual(task, ListType.task(.ordered(3, "."), checked: false))
    XCTAssertNotEqual(task, ListType.ordered(3, "."))
  }

  func testSafeModeKeepsTheCheckboxes() {
    let doc = FullMarkdownParser.standard.parse("- [ ] a\n- [x] <i>b</i>")
    XCTAssertEqual(HtmlGenerator(safeMode: true).generate(doc: doc),
                   "<ul>\n<li><input disabled=\"\" type=\"checkbox\"> a</li>\n" +
                   "<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> " +
                   "<!-- raw HTML omitted -->b<!-- raw HTML omitted --></li>\n</ul>\n")
  }

  private func lines(_ text: String) -> [String] {
    return text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
               .filter { !$0.isEmpty }
  }

  func testTaskListsInStringAndTerminalOutput() {
    let doc = FullMarkdownParser.standard.parse(
                "- [ ] foo\n- [x] bar\n  more\n- plain\n\n1. [x] one\n2. [ ] two\n10. [x] ten")
    let expected = ["[ ] foo", "[x] bar more", "– plain", "1. [x] one", "2. [ ] two", "10. [x] ten"]
    XCTAssertEqual(self.lines(StringGenerator.standard.generate(doc: doc)), expected)
    XCTAssertEqual(self.lines(TerminalGenerator.standard.generate(doc: doc).segments
                                .map { $0.1 }.joined()), expected)
    // The text of an item is aligned with the first line
    let multiline = FullMarkdownParser.standard.parse(
                      "- [x] first line of an item which is rather long and needs to be wrapped")
    let wrapped = StringGenerator(numColumns: 30).generate(doc: multiline)
    let wrappedLines = wrapped.split(separator: "\n")
    XCTAssertGreaterThan(wrappedLines.count, 1)
    XCTAssertTrue(wrappedLines[0].contains("[x] first"))
    let indent = wrappedLines[0].distance(from: wrappedLines[0].startIndex,
                                          to: wrappedLines[0].firstIndex(of: "f")!)
    XCTAssertEqual(wrappedLines[1].prefix(while: { $0 == " " }).count, indent)
  }

  @MainActor
  func testTaskListsInAttributedStrings() throws {
    let doc = FullMarkdownParser.standard.parse("- [ ] foo\n- [x] bar\n\n1. [x] one\n2. [ ] two")
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      let html = AttributedStringGenerator(version: version).htmlGenerator.generate(doc: doc)
      XCTAssertFalse(html.contains("<input"), "\(version)")
      let text = try XCTUnwrap(AttributedStringGenerator(version: version).generate(doc: doc)).string
      for glyph in ["☐", "☑"] {
        XCTAssertTrue(text.contains(glyph), "\(version): \(text.debugDescription)")
      }
      XCTAssertTrue(text.contains("☑ one") && text.contains("☐ two"), "\(version)")
    }
    // The bullets of the OS 26 lists are replaced by the checkboxes
    let os26 = try XCTUnwrap(AttributedStringGenerator(version: .OS26).generate(doc: doc)).string
    XCTAssertFalse(os26.contains("•"), os26.debugDescription)
    XCTAssertTrue(os26.contains("☐") && os26.contains("foo"))
    // A checkbox is wider than a bullet, so it gets a cell of its own with room for a gap
    let generator = AttributedStringGenerator(version: .OS26)
    let html = generator.htmlGenerator.generate(doc: doc)
    XCTAssertTrue(html.contains("<td class=\"lcheck\"><b>☐</b></td>"), html)
    XCTAssertTrue(html.contains("<td class=\"lcheck\"><b>☑</b></td>"), html)
    XCTAssertFalse(html.contains("<td class=\"lbullet\">"), html)
    XCTAssertTrue(generator.docStyle.contains("td.lcheck"))
    let plain = FullMarkdownParser.standard.parse("- foo")
    XCTAssertTrue(generator.htmlGenerator.generate(doc: plain).contains("<td class=\"lbullet\"><b>•</b></td>"))
  }
}
