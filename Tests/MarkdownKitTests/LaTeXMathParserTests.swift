//
//  LaTeXMathParserTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 18/10/2026.
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
@testable import MarkdownKit

/// Tests for the delimiters of LaTeX, `\(…\)` and `\[…\]` (`LaTeXMarkdownParser`).
class LaTeXMathParserTests: XCTestCase, MarkdownKitFactory {

  private func parse(_ str: String) -> Block {
    return LaTeXMarkdownParser.standard.parse(str)
  }

  /// The parser for the formulas with dollar signs, which does not know the forms of LaTeX
  private func parseWithDollars(_ str: String) -> Block {
    return MathMarkdownParser.standard.parse(str)
  }

  private func math(_ tex: String, display: Bool = false, source: String? = nil) -> TextFragment {
    return .custom(MathFragment(tex: tex, display: display, source: source))
  }

  private func text(_ fragments: TextFragment...) -> Text {
    var text = Text()
    for fragment in fragments {
      text.append(fragment: fragment)
    }
    return text
  }

  private func mathBlock(_ tex: String) -> Block {
    return .custom(MathBlock(tex: tex))
  }

  private func html(_ str: String) -> String {
    return HtmlGenerator.standard.generate(doc: self.parse(str))
  }

  // MARK: Formulas within text

  func testFormulaWithinText() {
    XCTAssertEqual(parse("The area is \\(\\pi r^2\\)."),
                   document(paragraph(.text("The area is "),
                                      math("\\pi r^2", source: "\\(\\pi r^2\\)"),
                                      .text("."))))
    XCTAssertEqual(parse("\\(x\\)"), document(paragraph(math("x", source: "\\(x\\)"))))
    XCTAssertEqual(parse("\\(a\\) and \\(b\\)"),
                   document(paragraph(math("a", source: "\\(a\\)"), .text(" and "),
                                      math("b", source: "\\(b\\)"))))
    XCTAssertEqual(parse("\\(a\\)\\(b\\)"),
                   document(paragraph(math("a", source: "\\(a\\)"), math("b", source: "\\(b\\)"))))
  }

  func testDisplayFormulaWithinText() {
    XCTAssertEqual(parse("see \\[a^2\\] here"),
                   document(paragraph(.text("see "),
                                      math("a^2", display: true, source: "\\[a^2\\]"),
                                      .text(" here"))))
    XCTAssertEqual(parse("\\[a\\] and \\[b\\]"),
                   document(paragraph(math("a", display: true, source: "\\[a\\]"), .text(" and "),
                                      math("b", display: true, source: "\\[b\\]"))))
  }

  func testWhiteSpaceAtTheEndsIsNotPartOfTheLaTeX() {
    XCTAssertEqual(parse("a \\( x \\) b"),
                   document(paragraph(.text("a "), math("x", source: "\\( x \\)"), .text(" b"))))
    XCTAssertEqual(parse("a \\[ x \\] b"),
                   document(paragraph(.text("a "), math("x", display: true, source: "\\[ x \\]"),
                                      .text(" b"))))
  }

  func testLaTeXIsNotChangedByMarkdown() {
    // Characters which have a meaning in Markdown stay as they are in a formula
    for tex in ["a_b + c_d", "f^*(x) + g^*(y)", "x_1 * y_2", "\\{x\\}", "a \\\\ b", "\\, \\; \\|",
                "[a](b)", "a\\_b", "_a_", "*a*", "a~b", "\\frac{a}{b}", "a < b", "a <b> c",
                "![i](u)", "&amp; \\&", "a\\$b", "a`b", "f(x)", "(a(b)c)", "a[i]", "[x]",
                "\\left( \\frac{a}{b} \\right)", "\\left[ x \\right]"] {
      XCTAssertEqual(parse("\\(\(tex)\\)"),
                     document(paragraph(math(tex, source: "\\(\(tex)\\)"))), tex)
      XCTAssertEqual(parse("see \\(\(tex)\\) now"),
                     document(paragraph(.text("see "), math(tex, source: "\\(\(tex)\\)"),
                                        .text(" now"))), tex)
      XCTAssertEqual(parse("see \\[\(tex)\\] now"),
                     document(paragraph(.text("see "),
                                        math(tex, display: true, source: "\\[\(tex)\\]"),
                                        .text(" now"))), tex)
      // A line which only consists of the formula is a block
      XCTAssertEqual(parse("\\[\(tex)\\]"), document(mathBlock(tex.trimmingCharacters(in: .whitespaces))),
                     tex)
    }
  }

  func testTheDollarSignsStillWork() {
    XCTAssertEqual(parse("$a$ and \\(b\\) and $$c$$ and \\[d\\]"),
                   document(paragraph(math("a"), .text(" and "),
                                      math("b", source: "\\(b\\)"), .text(" and "),
                                      math("c", display: true), .text(" and "),
                                      math("d", display: true, source: "\\[d\\]"))))
    // Whichever formula starts first wins, and a delimiter inside of it is part of its LaTeX
    XCTAssertEqual(parse("$a \\(b$ c\\)"),
                   document(paragraph(math("a \\(b"), .text(" c)"))))
    XCTAssertEqual(parse("\\(a $b\\) c$"),
                   document(paragraph(math("a $b", source: "\\(a $b\\)"), .text(" c$"))))
    XCTAssertEqual(parse("costs $5 and $6"), document(paragraph(.text("costs $5 and $6"))))
  }

  func testTheParserWithDollarsLeavesTheFormsOfLaTeXAlone() {
    // A backslash escapes a parenthesis and a bracket in Markdown
    XCTAssertEqual(parseWithDollars("\\(a\\) \\[b\\]"), document(paragraph(.text("(a) [b]"))))
    XCTAssertEqual(parse("\\(a\\) \\[b\\]"),
                   document(paragraph(math("a", source: "\\(a\\)"), .text(" "),
                                      math("b", display: true, source: "\\[b\\]"))))
  }

  // MARK: Text which is not a formula

  func testFormsWhichAreNotFormulasAreParsedLikeAnyOtherText() {
    for str in ["\\(a", "a\\)", "\\[a", "a\\]", "\\(\\)", "\\( \\)", "\\[\\]", "\\[ \\]",
                "\\)a\\(", "\\]a\\[", "(a) [b]", "\\(", "\\[", "a \\( b",
                "\\\\(a\\\\)", "\\\\[a\\\\]", "\\(a\\\\)", "\\[a\\\\]", "\\(a `b` c\\)",
                "\\(a **b** c", "\\[a\\", "\\", "x\\(", "[a\\]](b)"] {
      XCTAssertEqual(parse(str), parseWithDollars(str), str.debugDescription)
    }
    XCTAssertEqual(parse("\\(a"), document(paragraph(.text("(a"))))
    // A formula can contain brackets and parentheses of the other kind
    XCTAssertEqual(parse("\\(a\\] \\[b\\)"),
                   document(paragraph(math("a\\] \\[b", source: "\\(a\\] \\[b\\)"))))
  }

  func testTheBackslashInFrontOfTheOpeningDelimiterMustNotBeEscaped() {
    XCTAssertEqual(parse("\\\\(a\\)"), parseWithDollars("\\\\(a\\)"))
    XCTAssertEqual(parse("a \\\\\\(b\\) c"),
                   document(paragraph(.text("a \\"), math("b", source: "\\(b\\)"), .text(" c"))))
  }

  func testTheFormulaEndsAtTheFirstClosingDelimiterWhichIsNotEscaped() {
    XCTAssertEqual(parse("\\(a\\)b\\)"),
                   document(paragraph(math("a", source: "\\(a\\)"), .text("b)"))))
    // The line break `\\` is not the end of a formula, but `\\\)` is
    XCTAssertEqual(parse("\\(a \\\\) b\\)"),
                   document(paragraph(math("a \\\\) b", source: "\\(a \\\\) b\\)"))))
    XCTAssertEqual(parse("\\(a \\\\\\) b"),
                   document(paragraph(math("a \\\\", source: "\\(a \\\\\\)"), .text(" b"))))
  }

  func testCodeSpansAreNotPartOfFormulas() {
    XCTAssertEqual(parse("`\\(x\\)`"), document(paragraph(.code("\\(x\\)"))))
    XCTAssertEqual(parse("\\(a `b` c\\)"), parseWithDollars("\\(a `b` c\\)"))
    XCTAssertEqual(parse("\\(a\\) `b` \\(c\\)"),
                   document(paragraph(math("a", source: "\\(a\\)"), .text(" "), .code("b"),
                                      .text(" "), math("c", source: "\\(c\\)"))))
  }

  func testFormulasCanContinueOnTheNextLine() {
    XCTAssertEqual(parse("see \\(a +\nb\\) here"),
                   document(paragraph(.text("see "), math("a +\nb", source: "\\(a +\nb\\)"),
                                      .text(" here"))))
    // A blank line ends the paragraph, and with it the formula
    XCTAssertEqual(parse("\\(a\n\nb\\)"), parseWithDollars("\\(a\n\nb\\)"))
  }

  // MARK: Markdown around formulas

  func testEmphasisAroundFormulas() {
    XCTAssertEqual(parse("**\\(x\\)**"),
                   document(paragraph(.strong(Text(.custom(MathFragment(tex: "x",
                                                                       display: false,
                                                                       source: "\\(x\\)")))))))
    XCTAssertEqual(parse("*\\(x\\)* and _\\[y\\]_"),
                   document(paragraph(.emph(Text(math("x", source: "\\(x\\)"))), .text(" and "),
                                      .emph(Text(math("y", display: true, source: "\\[y\\]"))))))
  }

  func testFormulasInLinksAndLinkDestinations() {
    XCTAssertEqual(parse("[\\(x\\)](http://example.org)"),
                   document(paragraph(.link(Text(math("x", source: "\\(x\\)")),
                                            "http://example.org", nil))))
    // Escaped parentheses in a destination are not formulas which change it
    XCTAssertEqual(html("[a](http://example.org/f\\(x\\))"),
                   HtmlGenerator.standard.generate(doc: parseWithDollars("[a](http://example.org/f\\(x\\))")))
  }

  func testFormulasInHeadingsListsQuotesAndTables() {
    XCTAssertEqual(parse("# Title \\(x\\)"),
                   document(.heading(1, self.text(.text("Title "), math("x", source: "\\(x\\)")))))
    XCTAssertTrue(html("- item \\(x\\)\n- item \\[y\\]\n").contains("class=\"math inline\""))
    XCTAssertTrue(html("> quote \\(x\\)\n").contains("class=\"math inline\""))
    let table = html("| a | b |\n|---|---|\n| \\(x\\) | \\[y\\] |\n")
    XCTAssertTrue(table.contains("<td><span class=\"math inline\">\\(x\\)</span></td>"), table)
    XCTAssertTrue(table.contains("<td><span class=\"math display\">\\[y\\]</span></td>"), table)
  }

  // MARK: Formulas which are blocks

  func testBlockBetweenLinesWithBrackets() {
    XCTAssertEqual(parse("\\[\n\\int_0^1 x^2 \\, dx\n\\]"),
                   document(mathBlock("\\int_0^1 x^2 \\, dx")))
    XCTAssertEqual(parse("\\[\na\n= b\n\\]"), document(mathBlock("a\n= b")))
    XCTAssertEqual(parse("before\n\n\\[\nx\n\\]\n\nafter"),
                   document(paragraph(.text("before")), mathBlock("x"), paragraph(.text("after"))))
  }

  func testBlockWithTheLaTeXOnTheLinesOfTheDelimiters() {
    XCTAssertEqual(parse("\\[ x^2 \\]"), document(mathBlock("x^2")))
    XCTAssertEqual(parse("\\[x\n y\\]"), document(mathBlock("x\ny")))
    XCTAssertEqual(parse("\\[ a\nb\n\\]"), document(mathBlock("a\nb")))
    XCTAssertEqual(parse("\\[\na\nb \\]"), document(mathBlock("a\nb")))
  }

  func testLinesWhichStartOtherBlocksAreNotPartOfTheParagraph() {
    // The lines of a block are not parsed as Markdown: these would be a list, a quote or a heading
    XCTAssertEqual(parse("\\[\na\n- b\n+ c\n> d\n# e\n| f\n\\]"),
                   document(mathBlock("a\n- b\n+ c\n> d\n# e\n| f")))
  }

  func testBlocksInListItemsAndQuotes() {
    XCTAssertEqual(parse("> \\[\n> x\n> \\]\n"), document(blockquote(mathBlock("x"))))
    XCTAssertEqual(parse("- item\n\n  \\[\n  x\n  \\]\n"),
                   document(list(tight: false,
                                 listItem("-", tight: false, paragraph(.text("item")),
                                          mathBlock("x")))))
  }

  func testTheDollarBlocksStillWork() {
    XCTAssertEqual(parse("$$\nx\n$$\n\n\\[\ny\n\\]"), document(mathBlock("x"), mathBlock("y")))
    XCTAssertEqual(parse("```math\nx\n```\n"), document(mathBlock("x")))
  }

  func testLinesWhichAreNotABlockAreAParagraphWithFormulas() {
    // More delimiters than the opening and the closing one
    XCTAssertEqual(parse("\\[a\\] and \\[b\\]"),
                   document(paragraph(math("a", display: true, source: "\\[a\\]"), .text(" and "),
                                      math("b", display: true, source: "\\[b\\]"))))
    // Not closed
    XCTAssertEqual(parse("\\[\nx\n"), parseWithDollars("\\[\nx\n"))
    // A blank line ends the block
    XCTAssertEqual(parse("\\[\nx\n\ny\n\\]"), parseWithDollars("\\[\nx\n\ny\n\\]"))
    // An escaped backslash does not close it
    XCTAssertEqual(parse("\\[\nx\\\\]\n"), parseWithDollars("\\[\nx\\\\]\n"))
  }

  func testBlockParsersDoNotChangeOtherDocuments() {
    for str in ["a [b] c", "[a]: http://example.org\n\n[a]", "- [ ] task", "[x](y)", "![x](y)",
                "\\[", "\\]", "text\n\\\n"] {
      XCTAssertEqual(parse(str), parseWithDollars(str), str.debugDescription)
    }
  }

  func testTypicalOutputOfLanguageModels() {
    let markdown = """
      The roots of \\(ax^2 + bx + c = 0\\) are

      \\[
      x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
      \\]

      1. Compute \\(\\Delta = b^2 - 4ac\\).
      2. If \\(\\Delta > 0\\) there are two roots:

         \\[
         x_{1,2} = \\frac{-b \\pm \\sqrt{\\Delta}}{2a}
         \\]

      Note that \\(a \\neq 0\\) and \\([a, b]\\) is an interval.
      """
    let html = self.html(markdown)
    XCTAssertEqual(html.components(separatedBy: "<span class=\"math inline\">").count - 1, 5, html)
    XCTAssertEqual(html.components(separatedBy: "<div class=\"math display\">").count - 1, 2, html)
    XCTAssertTrue(html.contains("<span class=\"math inline\">\\(\\Delta &gt; 0\\)</span>"), html)
    XCTAssertTrue(html.contains("<li><p>If"), html)
  }

  // MARK: Generators

  func testGeneratorsShowTheFormulasAsTheyWereWritten() {
    let doc = parse("An \\(x^2\\) and \\[y\\] and\n\n\\[\nz\n\\]\n")
    let html = HtmlGenerator.standard.generate(doc: doc)
    XCTAssertEqual(html,
                   "<p>An <span class=\"math inline\">\\(x^2\\)</span> and " +
                   "<span class=\"math display\">\\[y\\]</span> and</p>\n" +
                   "<div class=\"math display\">\\[z\\]</div>\n")
    XCTAssertEqual(StringGenerator(numColumns: 80).generate(doc: doc),
                   "An \\(x^2\\) and \\[y\\] and\n\n$$\nz\n$$")
  }

  #if !os(watchOS)
  func testKaTeXTypesetsTheFormulas() throws {
    let generator = MathHtmlGenerator(math: .mathml)
    let html = generator.generate(doc: parse("An \\(x^2\\) and\n\n\\[\nz\n\\]\n"))
    XCTAssertTrue(html.contains("<span class=\"math inline\"><span class=\"katex\"><math"), html)
    XCTAssertTrue(html.contains("<div class=\"math display\"><span class=\"katex\"><math"), html)
  }
  #endif

  // MARK: Configuration

  func testTheParserIsAMathParserWithTheLaTeXBlockParserAndTransformer() {
    XCTAssertTrue(LaTeXMarkdownParser.standard === LaTeXMarkdownParser.standard)
    XCTAssertFalse(MathMarkdownParser.standard is LaTeXMarkdownParser)
    let blockParsers = LaTeXMarkdownParser.defaultBlockParsers.map { String(describing: $0) }
    let mathBlockParsers = MathMarkdownParser.defaultBlockParsers.map { String(describing: $0) }
    XCTAssertEqual(blockParsers.count, mathBlockParsers.count + 1)
    let index = blockParsers.firstIndex(of: "MathBlockParser")
    XCTAssertEqual(index.map { blockParsers[$0 + 1] }, "LaTeXMathBlockParser")
    XCTAssertEqual(blockParsers.firstIndex(of: "TableParser").map { $0 > index! + 1 }, true)
    let transformers = LaTeXMarkdownParser.defaultInlineTransformers.map { String(describing: $0) }
    let mathTransformers = MathMarkdownParser.defaultInlineTransformers.map { String(describing: $0) }
    XCTAssertEqual(transformers, mathTransformers.map { $0 == "MathTransformer" ? "LaTeXMathTransformer" : $0 })
    XCTAssertFalse(MathTransformer.recognizesLaTeXDelimiters)
    XCTAssertTrue(LaTeXMathTransformer.recognizesLaTeXDelimiters)
  }

  func testTheDialectGivesTheParser() {
    XCTAssertTrue(MarkdownDialect.fullLaTeX.parser === LaTeXMarkdownParser.standard)
  }
}
