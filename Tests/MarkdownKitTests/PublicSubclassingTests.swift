//
//  PublicSubclassingTests.swift
//  MarkdownKitTests
//
//  Created on 09/10/2026.
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
// Deliberately not `@testable`: this file only sees the public interface of MarkdownKit, like
// a client of the framework. It does not compile if a class or method that is meant to be
// subclassed or overridden is not `open`.
import MarkdownKit
import CommandLineKit

/// The methods called on the subclasses below
private var calls: [String] = []

private final class MyAtxParser: AtxHeadingParser {
  override func parse() -> ParseResult {
    calls.append("AtxHeadingParser.parse")
    return super.parse()
  }
}

private final class MySetextParser: SetextHeadingParser {
  override func parse() -> ParseResult {
    calls.append("SetextHeadingParser.parse")
    return super.parse()
  }
}

private final class MyThematicBreakParser: ThematicBreakParser {
  override func parse() -> ParseResult {
    calls.append("ThematicBreakParser.parse")
    return super.parse()
  }
}

private final class MyBlockquoteParser: BlockquoteParser {
  override func parse() -> ParseResult {
    calls.append("BlockquoteParser.parse")
    return super.parse()
  }
}

private final class MyListItemParser: ListItemParser {
  override func parse() -> ParseResult {
    calls.append("ListItemParser.parse")
    return super.parse()
  }
}

private final class MyLinkRefDefinitionParser: LinkRefDefinitionParser {
  override var mayInterruptParagraph: Bool {
    calls.append("LinkRefDefinitionParser.mayInterruptParagraph")
    return super.mayInterruptParagraph
  }
  override func parse() -> ParseResult {
    calls.append("LinkRefDefinitionParser.parse")
    return super.parse()
  }
  override func tryParse() -> ParseResult {
    calls.append("LinkRefDefinitionParser.tryParse")
    return super.tryParse()
  }
}

/// A code block parser which only recognizes one line of indented code
private final class MyIndentedCodeParser: CodeBlockParser {
  override func formatIndentedLine(_ n: Int = 4) -> Substring {
    calls.append("CodeBlockParser.formatIndentedLine")
    return super.formatIndentedLine(n)
  }
  override func parse() -> ParseResult {
    guard !self.shortLineIndent else {
      return .none
    }
    let code: Lines = [self.formatIndentedLine()]
    self.readNextLine()
    return .block(.indentedCode(code))
  }
}

/// A block parser which starts a container: lines starting with `!` form a block quote
private final class NoteParser: BlockParser {

  final class NoteContainer: NestedContainer {
    override var indentRequired: Bool {
      return true
    }
    override func skipIndent(input: String,
                             startIndex: String.Index,
                             endIndex: String.Index) -> String.Index? {
      guard startIndex < endIndex, input[startIndex] == "!" else {
        return nil
      }
      let index = input.index(after: startIndex)
      if index < endIndex && input[index] == " " {
        return input.index(after: index)
      }
      return index
    }
    override func makeBlock(_ docParser: DocumentParser) -> Block {
      return .blockquote(docParser.bundle(blocks: self.content))
    }
  }

  override func parse() -> ParseResult {
    guard self.shortLineIndent, self.firstContentCharacter == "!" else {
      return .none
    }
    let index = self.line.index(after: self.contentStartIndex)
    if index < self.contentEndIndex && self.line[index] == " " {
      self.resetLineStart(self.line.index(after: index))
    } else {
      self.resetLineStart(index)
    }
    return .container { outer in NoteContainer(outer: outer) }
  }
}

private final class MyDelimiterTransformer: DelimiterTransformer {
  override func transform(_ text: Text) -> Text {
    calls.append("DelimiterTransformer.transform(text)")
    return super.transform(text)
  }
  override func transform(_ fragment: TextFragment,
                          from iterator: inout Text.Iterator,
                          into res: inout Text) -> TextFragment? {
    calls.append("DelimiterTransformer.transform(fragment)")
    return super.transform(fragment, from: &iterator, into: &res)
  }
}

private final class MyCodeLinkHtmlTransformer: CodeLinkHtmlTransformer {
  override func transform(_ text: Text) -> Text {
    calls.append("CodeLinkHtmlTransformer.transform(text)")
    return super.transform(text)
  }
}

private final class MyLinkTransformer: LinkTransformer {
  override func transform(_ text: Text) -> Text {
    calls.append("LinkTransformer.transform(text)")
    return super.transform(text)
  }
}

private final class MyEmphasisTransformer: EmphasisTransformer {
  override func transform(_ text: Text) -> Text {
    calls.append("EmphasisTransformer.transform(text)")
    return super.transform(text)
  }
  override func transform(_ fragment: TextFragment,
                          from iterator: inout Text.Iterator,
                          into res: inout Text) -> TextFragment? {
    calls.append("EmphasisTransformer.transform(fragment)")
    return super.transform(fragment, from: &iterator, into: &res)
  }
}

private final class MyEscapeTransformer: EscapeTransformer {
  override func transform(_ fragment: TextFragment,
                          from iterator: inout Text.Iterator,
                          into res: inout Text) -> TextFragment? {
    calls.append("EscapeTransformer.transform(fragment)")
    return super.transform(fragment, from: &iterator, into: &res)
  }
}

private final class MyDocumentParser: DocumentParser {
  override func parse() -> Block {
    calls.append("DocumentParser.parse")
    return super.parse()
  }
}

private final class MyInlineParser: InlineParser {
  override func transform(_ text: Text) -> Text {
    calls.append("InlineParser.transform(text)")
    return super.transform(text)
  }
  override func parse(_ blocks: Blocks) -> Blocks {
    calls.append("InlineParser.parse(blocks)")
    return super.parse(blocks)
  }
}

private final class MyMarkdownParser: MarkdownParser {
  override func documentParser(blockParsers: [BlockParser.Type], input: String) -> DocumentParser {
    return MyDocumentParser(blockParsers: blockParsers, input: input)
  }
  override func inlineParser(inlineTransformers: [InlineTransformer.Type],
                             input: Block) -> InlineParser {
    return MyInlineParser(inlineTransformers: inlineTransformers, input: input)
  }
  override func parse(_ str: String, blockOnly: Bool = false) -> Block {
    calls.append("MarkdownParser.parse")
    return super.parse(str, blockOnly: blockOnly)
  }
}

private final class MyGeneratorContext: GeneratorContext {
  override func new(parent: Block?,
                    tight: Bool?,
                    itemIndent: Int?,
                    indent: Int) -> GeneratorContext {
    calls.append("GeneratorContext.new")
    return MyGeneratorContext(parent: parent ?? self.parent,
                              context: self,
                              tight: tight ?? self.tight,
                              itemIndent: itemIndent,
                              maxColumns: self.maxColumns - indent)
  }
}

private final class MyStringGenerator: StringGenerator {
  override func newContext(doc: Block, maxColumns: Int) -> GeneratorContext {
    return MyGeneratorContext(doc: doc, maxColumns: maxColumns)
  }
}

private final class MyMinimalisticTableRenderer: StringGenerator.MinimalisticTableRenderer {
  override func renderTable(_ descriptor: TableDescriptor,
                            using generate: (Text, Int) -> [String],
                            in context: GeneratorContext) -> [String]? {
    calls.append("MinimalisticTableRenderer.renderTable")
    return super.renderTable(descriptor, using: generate, in: context)
  }
}

private final class MyFullTableRenderer: StringGenerator.FullTableRenderer {
  override func renderTable(_ descriptor: TableDescriptor,
                            using generate: (Text, Int) -> [String],
                            in context: GeneratorContext) -> [String]? {
    calls.append("FullTableRenderer.renderTable")
    return super.renderTable(descriptor, using: generate, in: context)
  }
}

private final class MyTerminalMinimalisticTableRenderer:
                       TerminalGenerator.MinimalisticTableRenderer {
  override func renderTable(_ descriptor: TerminalGenerator.TableDescriptor,
                            using generate: (Text, Int) -> [AnsiText.Normalized],
                            in context: GeneratorContext) -> [AnsiText.Normalized]? {
    calls.append("TerminalGenerator.MinimalisticTableRenderer.renderTable")
    return super.renderTable(descriptor, using: generate, in: context)
  }
}

private final class MyHtmlGenerator: HtmlGenerator {
  override func generate(block: Block, parent: Parent, tight: Bool = false) -> String {
    calls.append("HtmlGenerator.generate(block)")
    return super.generate(block: block, parent: parent, tight: tight)
  }
}

private final class MyTextGenerator: StringGenerator {
  override func generate(block: Block, context: GeneratorContext) -> [String] {
    calls.append("StringGenerator.generate(block)")
    return super.generate(block: block, context: context)
  }
}

private final class MyTerminalGenerator: TerminalGenerator {
  override func generate(textFragment fragment: TextFragment) -> AnsiText.Normalized? {
    calls.append("TerminalGenerator.generate(textFragment)")
    return super.generate(textFragment: fragment)
  }
}

private final class MyTableParser: TableParser {
  override func parseRow() -> Row? {
    calls.append("TableParser.parseRow")
    return super.parseRow()
  }
}

private final class MyDefinitionListItemParser: ExtendedListItemParser {
  override func parse() -> ParseResult {
    calls.append("ExtendedListItemParser.parse")
    return super.parse()
  }
}

private final class MyDocumentParser2: ExtendedDocumentParser {
  override func bundle(blocks: [Block]) -> Blocks {
    calls.append("ExtendedDocumentParser.bundle")
    return super.bundle(blocks: blocks)
  }
}

private final class MyHtmlBlockPlugin: HtmlBlockParserPlugin {
  override func startCondition(_ line: String) -> Bool {
    calls.append("HtmlBlockParserPlugin.startCondition")
    return line.hasPrefix("<note")
  }
  override func endCondition(_ line: String) -> Bool {
    return line.contains("</note>")
  }
}

private final class MyHtmlBlockParser: HtmlBlockParser {
  override class var supportedParsers: [HtmlBlockParserPlugin.Type] {
    return [MyHtmlBlockPlugin.self]
  }
}

private final class MyAttributedStringGenerator: AttributedStringGenerator {
  override var htmlGenerator: HtmlGenerator {
    calls.append("AttributedStringGenerator.htmlGenerator")
    return MyHtmlGenerator()
  }
}

/// Tests that the classes and methods which are meant to be subclassed and overridden can be
/// subclassed and overridden from outside of the framework.
class PublicSubclassingTests: XCTestCase {

  override func setUp() {
    calls = []
  }

  func testBlockParsersCanBeOverridden() {
    let parser = MarkdownParser(blockParsers: [
                                  MyAtxParser.self,
                                  MySetextParser.self,
                                  MyThematicBreakParser.self,
                                  MyIndentedCodeParser.self,
                                  FencedCodeBlockParser.self,
                                  HtmlBlockParser.self,
                                  MyLinkRefDefinitionParser.self,
                                  MyBlockquoteParser.self,
                                  MyListItemParser.self])
    // The line of text which continues in the next line makes the parsers decide whether they
    // interrupt a paragraph
    let doc = parser.parse("# Title\n\nHeading\n=\n\n---\n\n    code\n\n[a]: /u\n\ntext\nmore\n\n> quote\n\n- item\n")
    XCTAssertEqual(Set(calls.filter { !$0.hasPrefix("LinkRefDefinitionParser.") }),
                   Set(["AtxHeadingParser.parse", "SetextHeadingParser.parse",
                        "ThematicBreakParser.parse", "CodeBlockParser.formatIndentedLine",
                        "BlockquoteParser.parse", "ListItemParser.parse"]))
    XCTAssertTrue(calls.contains("LinkRefDefinitionParser.parse"))
    XCTAssertTrue(calls.contains("LinkRefDefinitionParser.tryParse"))
    XCTAssertTrue(calls.contains("LinkRefDefinitionParser.mayInterruptParagraph"))
    XCTAssertEqual(HtmlGenerator.standard.generate(doc: doc),
                   "<h1>Title</h1>\n<h1>Heading</h1>\n<hr />\n<pre><code>code\n</code></pre>\n" +
                   "<p>text\nmore</p>\n<blockquote>\n<p>quote</p>\n</blockquote>\n<ul>\n<li>item</li>\n</ul>\n")
  }

  func testInlineTransformersCanBeOverridden() {
    let parser = MarkdownParser(inlineTransformers: [MyDelimiterTransformer.self,
                                                     MyCodeLinkHtmlTransformer.self,
                                                     MyLinkTransformer.self,
                                                     MyEmphasisTransformer.self,
                                                     MyEscapeTransformer.self])
    let doc = parser.parse("*a* [b](/u) `c` \\*")
    XCTAssertEqual(Set(calls),
                   Set(["DelimiterTransformer.transform(text)",
                        "DelimiterTransformer.transform(fragment)",
                        "CodeLinkHtmlTransformer.transform(text)",
                        "LinkTransformer.transform(text)",
                        "EmphasisTransformer.transform(text)",
                        "EmphasisTransformer.transform(fragment)",
                        "EscapeTransformer.transform(fragment)"]))
    XCTAssertEqual(HtmlGenerator.standard.generate(doc: doc),
                   "<p><em>a</em> <a href=\"/u\">b</a> <code>c</code> *</p>\n")
  }

  func testDocumentParserInlineParserAndMarkdownParserCanBeOverridden() {
    let doc = MyMarkdownParser().parse("a *b*")
    XCTAssertTrue(calls.contains("MarkdownParser.parse"))
    XCTAssertTrue(calls.contains("DocumentParser.parse"))
    XCTAssertTrue(calls.contains("InlineParser.parse(blocks)") ||
                  calls.contains("InlineParser.transform(text)"))
    XCTAssertEqual(HtmlGenerator.standard.generate(doc: doc), "<p>a <em>b</em></p>\n")
  }

  func testContainerStartingBlockParserCanBeWrittenOutsideOfTheFramework() {
    let parser = MarkdownParser(blockParsers: [NoteParser.self])
    XCTAssertEqual(HtmlGenerator.standard.generate(doc: parser.parse("! hello\n! world\n\nafter")),
                   "<blockquote>\n<p>hello\nworld</p>\n</blockquote>\n<p>after</p>\n")
  }

  func testGeneratorContextCanBeSubclassed() {
    let generator = MyStringGenerator()
    let text = generator.generate(doc: MarkdownParser.standard.parse("- a\n- b"))
    XCTAssertTrue(text.contains("a"))
    XCTAssertTrue(calls.contains("GeneratorContext.new"))
  }

  func testTableRenderersCanBeSubclassed() {
    let doc = ExtendedMarkdownParser.standard.parse("| a | b |\n|---|---|\n| c | d |\n")
    let generator = StringGenerator(tableRenderers: [MyMinimalisticTableRenderer(alignDisplayWidth: true),
                                                    MyFullTableRenderer(alignDisplayWidth: true)])
    XCTAssertTrue(generator.generate(doc: doc).contains("c"))
    XCTAssertTrue(calls.contains("MinimalisticTableRenderer.renderTable"))
    let terminal = TerminalGenerator(tableRenderers: [MyTerminalMinimalisticTableRenderer()])
    XCTAssertTrue(terminal.generate(doc: doc).plainText.contains("c"))
    XCTAssertTrue(calls.contains("TerminalGenerator.MinimalisticTableRenderer.renderTable"))
  }

  func testStringTableRendererCanBeCustomized() {
    let doc = ExtendedMarkdownParser.standard.parse("| a | b |\n|---|---|\n| c | d |\n")
    // A table which does not fit into the width is rendered by the full renderer
    let renderer = StringGenerator.FullTableRenderer(
                     topDelimiter: .init(left: "+", right: "+", mid: "+", line: "-"),
                     bottomDelimiter: .init(left: "+", right: "+", mid: "+", line: "-"),
                     headerSeparator: .init(left: "+", right: "+", mid: "+", line: "="),
                     rowSeparator: .init(left: "+", right: "+", mid: "+", line: "-"),
                     bar: "|",
                     alignDisplayWidth: true)
    let text = StringGenerator(tableRenderers: [renderer]).generate(doc: doc)
    XCTAssertTrue(text.contains("+-"), text)
  }

  func testGeneratorsCanBeSubclassed() {
    let doc = ExtendedMarkdownParser.standard.parse("# a\n\n- b\n\n| c |\n|---|\n| d |\n")
    _ = MyHtmlGenerator().generate(doc: doc)
    XCTAssertTrue(calls.contains("HtmlGenerator.generate(block)"))
    _ = MyTextGenerator().generate(doc: doc)
    XCTAssertTrue(calls.contains("StringGenerator.generate(block)"))
    _ = MyTerminalGenerator().generate(doc: doc)
    XCTAssertTrue(calls.contains("TerminalGenerator.generate(textFragment)"))
  }

  func testExtendedParsersCanBeSubclassed() {
    let parser = MarkdownParser(blockParsers: MarkdownParser.headingParsers + [
                                  MyDefinitionListItemParser.self, MyTableParser.self])
    _ = parser.parse("| a |\n|---|\n| b |\n\n: c\n")
    XCTAssertTrue(calls.contains("TableParser.parseRow"))
    XCTAssertTrue(calls.contains("ExtendedListItemParser.parse"))
    let extended = ExtendedDocumentParser(blockParsers: [MyDefinitionListItemParser.self],
                                          input: "Term\n: definition\n")
    _ = extended.parse()
    _ = MyDocumentParser2(blockParsers: [], input: "").parse()
    XCTAssertTrue(calls.contains("ExtendedDocumentParser.bundle"))
  }

  func testHtmlBlockParserPluginsCanBeWrittenOutsideOfTheFramework() {
    let parser = MarkdownParser(blockParsers: [MyHtmlBlockParser.self])
    let doc = parser.parse("<note>\nsome *note*\n</note>\n")
    XCTAssertTrue(calls.contains("HtmlBlockParserPlugin.startCondition"))
    guard case .document(let blocks) = doc, case .htmlBlock(_)? = blocks.first else {
      return XCTFail("not an HTML block: \(doc)")
    }
  }

  func testAttributedStringGeneratorCanBeSubclassed() {
    let generator = MyAttributedStringGenerator()
    XCTAssertTrue(generator.htmlGenerator is MyHtmlGenerator)
    XCTAssertTrue(calls.contains("AttributedStringGenerator.htmlGenerator"))
  }
}
