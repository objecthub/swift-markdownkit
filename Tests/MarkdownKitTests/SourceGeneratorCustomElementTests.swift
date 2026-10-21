//
//  SourceGeneratorCustomElementTests.swift
//  MarkdownKitTests
//
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
import Foundation
import CommandLineKit
@testable import MarkdownKit

/// Tests how `SourceGenerator` writes custom blocks and text fragments, and the formulas of
/// `MathMarkdownParser`, which are custom elements.
class SourceGeneratorCustomElementTests: XCTestCase {

  // MARK: Custom text fragment from the documentation: underline and strike-through with tildes

  /// The `LineEmphasis` example of "Extending the Parser". It writes its source with
  /// `generateSource(via:in:)`.
  private enum TildeEmphasis: CustomTextFragment {
    case underline(Text)
    case strikethrough(Text)

    func equals(to other: CustomTextFragment) -> Bool {
      guard let that = other as? TildeEmphasis else {
        return false
      }
      switch (self, that) {
        case (.underline(let lhs), .underline(let rhs)):
          return lhs.normalized == rhs.normalized
        case (.strikethrough(let lhs), .strikethrough(let rhs)):
          return lhs.normalized == rhs.normalized
        default:
          return false
      }
    }
    func transform(via transformer: InlineTransformer) -> TextFragment {
      switch self {
        case .underline(let text):
          return .custom(TildeEmphasis.underline(transformer.transform(text)))
        case .strikethrough(let text):
          return .custom(TildeEmphasis.strikethrough(transformer.transform(text)))
      }
    }
    func generateHtml(via htmlGen: HtmlGenerator) -> String {
      return ""
    }
    func generateHtml(via htmlGen: HtmlGenerator, and attrGen: AttributedStringGenerator?) -> String {
      return ""
    }
    var rawDescription: String {
      switch self {
        case .underline(let text), .strikethrough(let text):
          return text.rawDescription
      }
    }
    var description: String {
      return self.rawDescription
    }
    var debugDescription: String {
      switch self {
        case .underline(let text):
          return "underline(\(text.debugDescription))"
        case .strikethrough(let text):
          return "strikethrough(\(text.debugDescription))"
      }
    }
    func generateSource(via generator: SourceGenerator,
                        in context: SourceGenerator.InlineContext) -> String? {
      switch self {
        case .underline(let text):
          return "~" + generator.generate(text: text, in: context) + "~"
        case .strikethrough(let text):
          return "~~" + generator.generate(text: text, in: context) + "~~"
      }
    }
  }

  private final class TildeEmphasisTransformer: EmphasisTransformer {
    override public class var supportedEmphasis: [Emphasis] {
      return super.supportedEmphasis + [
        Emphasis(ch: "~", special: false, factory: { double, text in
          return .custom(double ? TildeEmphasis.strikethrough(text) : TildeEmphasis.underline(text))
        })]
    }
  }

  private final class TildeDelimiterTransformer: DelimiterTransformer {
    override public class var emphasisChars: [Character] {
      return super.emphasisChars + ["~"]
    }
  }

  private final class TildeEmphasisParser: MarkdownParser, @unchecked Sendable {
    override public class var defaultInlineTransformers: [InlineTransformer.Type] {
      return [TildeDelimiterTransformer.self, CodeLinkHtmlTransformer.self, LinkTransformer.self,
              TildeEmphasisTransformer.self, EscapeTransformer.self]
    }
    override public class var standard: TildeEmphasisParser {
      return self.singleton
    }
    private static let singleton: TildeEmphasisParser = TildeEmphasisParser()
  }

  func testCustomFragmentWritesItsSource() {
    let parser = TildeEmphasisParser.standard
    let generator = SourceGenerator(syntax: [], parser: parser, specialCharacters: ["~"])
    for source in ["some ~underlined~ text", "~~strike~~ and ~u~", "a ~ b", "x~y~z", "\\~ not",
                   "~a *b* [c](d) `e` f~", "*~x~*", "~~ ~x~ ~~y~~ ~~", "\\~a~ \\~\\~b~~",
                   "> ~a~\n> ~~b~~\n\n- ~c~ d"] {
      let doc = parser.parse(source)
      XCTAssertNil(generator.firstMismatch(of: doc), source.debugDescription)
    }
    let doc = parser.parse("a ~b~ c")
    XCTAssertEqual(generator.generate(doc: doc), "a ~b~ c\n")
    guard case .document(let blocks) = doc, case .paragraph(let text) = blocks[0],
          case .custom(let fragment) = text[1] else {
      return XCTFail("no custom fragment")
    }
    XCTAssertTrue(fragment is TildeEmphasis)
  }

  func testSpecialCharactersAreEscapedInPlainText() {
    let parser = TildeEmphasisParser.standard
    // The text `~a~` is not emphasis: the character has to be escaped
    let doc = parser.parse("\\~a\\~ and \\~\\~b\\~\\~")
    let plain = SourceGenerator(syntax: [], parser: parser)
    XCTAssertFalse(plain.roundTrips(doc))
    let escaping = SourceGenerator(syntax: [], parser: parser, specialCharacters: ["~"])
    XCTAssertEqual(escaping.generate(doc: doc), "\\~a\\~ and \\~\\~b\\~\\~\n")
    XCTAssertTrue(escaping.roundTrips(doc))
  }

  func testCustomFragmentWithoutSourceIsWrittenAsPlainText() {
    struct Plain: CustomTextFragment {
      func equals(to other: CustomTextFragment) -> Bool { return other is Plain }
      func transform(via transformer: InlineTransformer) -> TextFragment { return .custom(self) }
      func generateHtml(via htmlGen: HtmlGenerator) -> String { return "" }
      func generateHtml(via htmlGen: HtmlGenerator, and attrGen: AttributedStringGenerator?) -> String {
        return ""
      }
      var rawDescription: String { return "*raw* [text]" }
      var description: String { return "plain" }
      var debugDescription: String { return "plain" }
    }
    let doc = Block.document([.paragraph(Text(.custom(Plain())))])
    XCTAssertEqual(SourceGenerator.standard.generate(doc: doc), "\\*raw\\* [text]\n")
    XCTAssertFalse(SourceGenerator.standard.roundTrips(doc))
  }

  func testCustomFragmentCannotBreakASingleLine() {
    struct Wide: CustomTextFragment {
      func equals(to other: CustomTextFragment) -> Bool { return other is Wide }
      func transform(via transformer: InlineTransformer) -> TextFragment { return .custom(self) }
      func generateHtml(via htmlGen: HtmlGenerator) -> String { return "" }
      func generateHtml(via htmlGen: HtmlGenerator, and attrGen: AttributedStringGenerator?) -> String {
        return ""
      }
      var rawDescription: String { return "a\nb" }
      var description: String { return "wide" }
      var debugDescription: String { return "wide" }
      func generateSource(via generator: SourceGenerator,
                          in context: SourceGenerator.InlineContext) -> String? {
        return "{a\nb}"
      }
    }
    let text = Text(.custom(Wide()))
    XCTAssertEqual(SourceGenerator.standard.generate(doc: .paragraph(text)), "{a\nb}\n")
    // A heading of level 1 or 2 with a line break is a setext heading
    XCTAssertEqual(SourceGenerator.standard.generate(doc: .heading(1, text)), "{a\nb}\n===\n")
    // A heading of level 3 is one line: the fragment is written as plain text
    XCTAssertEqual(SourceGenerator.standard.generate(doc: .heading(3, text)), "### a b\n")
    XCTAssertEqual(SourceGenerator.standard.generate(
                     doc: .table([text], [.undefined], [])), "| a b |\n| --- |\n")
  }

  // MARK: Custom block

  private struct Callout: CustomBlock {
    let text: Text
    var description: String { return "callout(\(self.text.rawDescription))" }
    var debugDescription: String { return self.description }
    func equals(to other: CustomBlock) -> Bool { return (other as? Callout)?.text == self.text }
    func parse(via parser: InlineParser) -> Block { return .custom(self) }
    func generateHtml(via htmlGen: HtmlGenerator, tight: Bool) -> String { return "" }
    func generateHtml(via htmlGen: HtmlGenerator,
                      and attGen: AttributedStringGenerator?,
                      tight: Bool) -> String {
      return ""
    }
    func generateSource(via generator: SourceGenerator,
                        parent: SourceGenerator.Parent) -> [String]? {
      return ["{{"] + generator.generate(lines: self.text, in: .init(parent: parent)) + ["}}"]
    }
  }

  private struct Opaque: CustomBlock {
    var description: String { return "opaque *block*\n# not a heading" }
    var debugDescription: String { return "opaque" }
    func equals(to other: CustomBlock) -> Bool { return other is Opaque }
    func parse(via parser: InlineParser) -> Block { return .custom(self) }
    func generateHtml(via htmlGen: HtmlGenerator, tight: Bool) -> String { return "" }
    func generateHtml(via htmlGen: HtmlGenerator,
                      and attGen: AttributedStringGenerator?,
                      tight: Bool) -> String {
      return ""
    }
  }

  func testCustomBlockWritesItsSource() {
    let text = Text(Substring("# a *b*"))
    let doc = Block.document([
      .paragraph(Text("before")),
      .custom(Callout(text: text)),
      .list(nil, true, [.listItem(.bullet("-"), .initial, [.custom(Callout(text: text))])]),
      .blockquote([.custom(Callout(text: text))])
    ])
    // The text of the block is escaped, and the lines get the prefix of the container
    XCTAssertEqual(SourceGenerator.standard.generate(doc: doc),
                   "before\n\n{{\n\\# a \\*b\\*\n}}\n\n- {{\n  \\# a \\*b\\*\n  }}\n\n" +
                   "> {{\n> \\# a \\*b\\*\n> }}\n")
  }

  func testCustomBlockWithoutSourceIsWrittenAsCode() {
    let doc = Block.document([.custom(Opaque())])
    XCTAssertEqual(SourceGenerator.standard.generate(doc: doc),
                   "```\nopaque *block*\n# not a heading\n```\n")
    XCTAssertFalse(SourceGenerator.standard.roundTrips(doc))
  }

  // MARK: Formulas

  func testFormulaFragments() {
    let source = "a $x$ and $$y$$ and $`z`$ and \\(u\\) and \\[v\\]"
    let doc = MarkdownDialect.fullLaTeX.parser.parse(source)
    XCTAssertEqual(SourceGenerator.standard.generate(doc: doc), source + "\n")
    XCTAssertTrue(SourceGenerator.standard.roundTrips(doc))
    // The delimiters of LaTeX are replaced by dollar signs if the syntax has no LaTeX delimiters
    let math = MarkdownDialect.fullMath.sourceGenerator
    XCTAssertEqual(math.generate(doc: doc), "a $x$ and $$y$$ and $`z`$ and $u$ and $$v$$\n")
    XCTAssertFalse(math.roundTrips(doc))
    // ... unless the LaTeX has dollar signs
    let dollars = MarkdownDialect.fullLaTeX.parser.parse("\\(a \\$ b\\)")
    XCTAssertEqual(math.generate(doc: dollars), "\\\\(a \\\\\\$ b\\\\)\n")
    // Without formulas, a formula is plain text
    let plain = MarkdownDialect.full.sourceGenerator.generate(doc: doc)
    XCTAssertEqual(plain, "a $x$ and $$y$$ and $\\`z\\`$ and \\\\(u\\\\) and \\\\[v\\\\]\n")
  }

  func testFormulaBlocks() {
    for source in ["$$\nx\n$$", "$$\na\nb\n$$", "$$\n  x\n$$", "```math\nx\n\ny\n```",
                   "```math\na \nb\n```", "```math\n$$\nx\n```", "\\[\nx\n\\]"] {
      let doc = MarkdownDialect.fullLaTeX.parser.parse(source)
      XCTAssertTrue(SourceGenerator.standard.roundTrips(doc), source.debugDescription)
    }
    // A formula is written between lines with dollar signs, if that is possible
    let doc = MarkdownDialect.fullLaTeX.parser.parse("\\[\nx\n\\]\n\n```math\nx\n\ny\n```")
    XCTAssertEqual(SourceGenerator.standard.generate(doc: doc), "$$\nx\n$$\n\n```math\nx\n\ny\n```\n")
    // ... and as a fenced code block in a syntax without formulas
    XCTAssertEqual(MarkdownDialect.full.sourceGenerator.generate(doc: doc),
                   "```math\nx\n```\n\n```math\nx\n\ny\n```\n")
  }
}
