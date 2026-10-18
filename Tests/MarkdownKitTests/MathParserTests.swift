//
//  MathParserTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 17/10/2026.
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

/// Tests for the syntax of LaTeX math (`MathMarkdownParser`) and for how the generators show it.
class MathParserTests: XCTestCase, MarkdownKitFactory {

  private func parse(_ str: String) -> Block {
    return MathMarkdownParser.standard.parse(str)
  }

  private func math(_ tex: String, display: Bool = false, source: String? = nil) -> TextFragment {
    return .custom(MathFragment(tex: tex, display: display, source: source))
  }

  private func mathBlock(_ tex: String) -> Block {
    return .custom(MathBlock(tex: tex))
  }

  private func html(_ str: String) -> String {
    return HtmlGenerator.standard.generate(doc: self.parse(str))
  }

  // MARK: Formulas within text

  func testFormulaWithinText() {
    XCTAssertEqual(parse("The area is $\\pi r^2$."),
                   document(paragraph(.text("The area is "), math("\\pi r^2"), .text("."))))
    XCTAssertEqual(parse("$x$"), document(paragraph(math("x"))))
    XCTAssertEqual(parse("$a$ and $b$"),
                   document(paragraph(math("a"), .text(" and "), math("b"))))
    XCTAssertEqual(parse("$a$$b$"), document(paragraph(math("a"), math("b"))))
  }

  func testLaTeXIsNotChangedByMarkdown() {
    // Characters which have a meaning in Markdown stay as they are in a formula
    for tex in ["a_b + c_d", "f^*(x) + g^*(y)", "x_1 * y_2", "\\{x\\}", "a \\\\ b", "\\, \\; \\|",
                "[a](b)", "a\\_b", "_a_", "*a*", "a~b", "\\frac{a}{b}", "a < b", "a <b> c",
                "![i](u)", "&amp; \\&", "a\\$b", "a`b", "a\\`b`"] {
      XCTAssertEqual(parse("$\(tex)$"), document(paragraph(math(tex))), tex)
      XCTAssertEqual(parse("see $\(tex)$ now"),
                     document(paragraph(.text("see "), math(tex), .text(" now"))), tex)
    }
  }

  func testDollarsInTextStayText() {
    // The opening $ must not be followed by white space, the closing $ must not be preceded by
    // white space or followed by a digit
    for str in ["costs $5 and $6", "$5,$6", "US$ 5 and $ 6", "$ a$", "$a $", "a $ b", "$", "$$",
                "$a", "a$", "$a$5", "pay $20,000 or $30,000.", "$ $", "$\n$"] {
      let doc = parse(str)
      XCTAssertFalse(html(str).contains("math"), "\(str): \(doc.debugDescription)")
    }
    XCTAssertEqual(parse("costs $5 and $6"), document(paragraph(.text("costs $5 and $6"))))
    XCTAssertEqual(parse("$a$5"), document(paragraph(.text("$a$5"))))
    // A letter after the closing dollar sign is fine
    XCTAssertEqual(parse("$a$b"), document(paragraph(math("a"), .text("b"))))
  }

  func testEscapedDollars() {
    XCTAssertEqual(parse("\\$5 and \\$6"), document(paragraph(.text("$5 and $6"))))
    XCTAssertEqual(parse("\\$a$ and $b$"),
                   document(paragraph(.text("$a$ and "), math("b"))))
    // A dollar sign in a formula is escaped, so the formula goes on; an escaped backslash is
    // not an escape
    XCTAssertEqual(parse("$a\\$b$"), document(paragraph(math("a\\$b"))))
    XCTAssertEqual(parse("$a\\\\$"), document(paragraph(math("a\\\\"))))
    XCTAssertEqual(parse("$a\\\\$ b"), document(paragraph(math("a\\\\"), .text(" b"))))
  }

  func testDisplayFormulaWithinText() {
    XCTAssertEqual(parse("see $$a^2$$ here"),
                   document(paragraph(.text("see "), math("a^2", display: true), .text(" here"))))
    XCTAssertEqual(parse("$$a^2$$ and $$b$$"),
                   document(paragraph(math("a^2", display: true), .text(" and "),
                                      math("b", display: true))))
    XCTAssertEqual(parse("a $$ x $$ b"),
                   document(paragraph(.text("a "),
                                      math("x", display: true, source: "$$ x $$"),
                                      .text(" b"))))
    // Without a closing $$ the dollar signs are text
    XCTAssertEqual(parse("a $$ b"), document(paragraph(.text("a $$ b"))))
  }

  func testCodeSpansAndCodeBetweenDollars() {
    XCTAssertEqual(parse("`$x$`"), document(paragraph(.code("$x$"))))
    XCTAssertEqual(parse("$`x_1`$"), document(paragraph(math("x_1", source: "$`x_1`$"))))
    XCTAssertEqual(parse("a $`b`$ c"),
                   document(paragraph(.text("a "), math("b", source: "$`b`$"), .text(" c"))))
    // A code span cannot be part of a formula
    XCTAssertEqual(parse("$a `b` c$"),
                   document(paragraph(.text("$a "), .code("b"), .text(" c$"))))
    XCTAssertEqual(parse("`a` $x$ `b`"),
                   document(paragraph(.code("a"), .text(" "), math("x"), .text(" "), .code("b"))))
  }

  func testFormulaOverSeveralLines() {
    XCTAssertEqual(parse("$a +\nb$"), document(paragraph(math("a +\nb"))))
    XCTAssertEqual(parse("text $a\nand b$ text"),
                   document(paragraph(.text("text "), math("a\nand b"), .text(" text"))))
    XCTAssertEqual(parse("$$x\ny $$ z"),
                   document(paragraph(math("x\ny", display: true, source: "$$x\ny $$"),
                                      .text(" z"))))
  }

  func testFormulaOverSeveralLinesEndsWhereMarkdownBlocksStart() {
    // The block structure is parsed before the formulas: a line which starts a list or another
    // block ends the paragraph. Formulas with such lines belong into a block.
    XCTAssertEqual(parse("text $a\n+ b$ text"),
                   document(paragraph(.text("text $a")),
                            list(tight: true, listItem("+", tight: true, paragraph(.text("b$ text"))))))
    XCTAssertEqual(parse("$$\na\n+ b\n$$"), document(mathBlock("a\n+ b")))
  }

  func testDelimitersAroundFormulas() {
    XCTAssertEqual(parse("**$x$**"), document(paragraph(strong(math("x")))))
    XCTAssertEqual(parse("*$a$*"), document(paragraph(emph(math("a")))))
    XCTAssertEqual(parse("foo *$x$* bar"),
                   document(paragraph(.text("foo "), emph(math("x")), .text(" bar"))))
    XCTAssertEqual(parse("~~$x$~~"),
                   document(paragraph(.strikethrough(Text(math("x"))))))
    XCTAssertEqual(parse("**bold $a_b$ text**"),
                   document(paragraph(strong(.text("bold "), math("a_b"), .text(" text")))))
  }

  func testFormulasInLinks() {
    XCTAssertEqual(parse("[$x$](http://a.b/c)"),
                   document(paragraph(link("http://a.b/c", nil, math("x")))))
    // Dollar signs in a destination are part of the destination
    XCTAssertEqual(parse("[text](http://a.b/$x$y)"),
                   document(paragraph(link("http://a.b/$x$y", nil, .text("text")))))
    XCTAssertEqual(parse("<http://a.b/$x$y>"),
                   document(paragraph(.autolink(.uri, "http://a.b/$x$y"))))
  }

  func testFormulasInBlocks() {
    XCTAssertEqual(parse("# Title $x^2$"),
                   document(.heading(1, Text(.text("Title "))
                                         .appending(math("x^2")))))
    XCTAssertEqual(parse("> quote $x$"),
                   document(blockquote(paragraph(.text("quote "), math("x")))))
    XCTAssertEqual(parse("- item $x_1$"),
                   document(list(tight: true,
                                 listItem("-", initial: true,
                                          paragraph(.text("item "), math("x_1"))))))
    XCTAssertTrue(HtmlGenerator.standard.generate(doc: MathMarkdownParser.standard.parse(
                    "a | b\n--- | ---\n$x$ | $y$")).contains(
                    "<td><span class=\"math inline\">\\(x\\)</span></td>"))
  }

  func testManyDollarsAreParsedInLinearTime() {
    // Opening dollar signs which cannot be closed must not make parsing quadratic
    let input = String(repeating: "$1 ", count: 20_000)
    let start = Date()
    let doc = parse(input)
    XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    XCTAssertEqual(HtmlGenerator.standard.generate(doc: doc), "<p>\(input.dropLast())</p>\n")
    let displays = String(repeating: "$$ ", count: 20_001)
    XCTAssertFalse(html(displays).contains("math"))
  }

  // MARK: Blocks

  func testDisplayBlocks() {
    XCTAssertEqual(parse("$$\nx = y\n$$"), document(mathBlock("x = y")))
    XCTAssertEqual(parse("$$\nx = y\n$$\n"), document(mathBlock("x = y")))
    XCTAssertEqual(parse("$$ x = y $$"), document(mathBlock("x = y")))
    XCTAssertEqual(parse("$$x$$"), document(mathBlock("x")))
    XCTAssertEqual(parse("$$ a\nb $$"), document(mathBlock("a\nb")))
    XCTAssertEqual(parse("$$ a\nb\n$$"), document(mathBlock("a\nb")))
    XCTAssertEqual(parse("$$\na\nb $$"), document(mathBlock("a\nb")))
    XCTAssertEqual(parse("before\n\n$$\nx\n$$\n\nafter"),
                   document(paragraph(.text("before")), mathBlock("x"),
                            paragraph(.text("after"))))
  }

  func testLinesOfABlockAreNotParsedAsMarkdown() {
    XCTAssertEqual(parse("$$\n- a\n> b\n| c |\n# d\n1. e\n* f\n    g\n---\n$$"),
                   document(mathBlock("- a\n> b\n| c |\n# d\n1. e\n* f\ng\n---")))
    XCTAssertEqual(parse("$$\n\\begin{aligned}\na &= b \\\\\n  c &= d\n\\end{aligned}\n$$"),
                   document(mathBlock("\\begin{aligned}\na &= b \\\\\nc &= d\n\\end{aligned}")))
  }

  func testBlockInterruptsParagraph() {
    XCTAssertEqual(parse("text\n$$\nx\n$$\nmore"),
                   document(paragraph(.text("text")), mathBlock("x"), paragraph(.text("more"))))
  }

  func testBlocksWhichAreNotClosedAreText() {
    for str in ["$$\nx", "$$\nx\n\ny\n$$", "$$", "$$\n", "$$ x"] {
      let doc = parse(str)
      XCTAssertFalse(html(str).contains("math"), "\(str.debugDescription): \(doc.debugDescription)")
    }
    // The text goes on in a paragraph; there is no formula in the rest of the document
    XCTAssertEqual(parse("$$\nx\n\ny"),
                   document(paragraph(.text("$$"), .softLineBreak, .text("x")),
                            paragraph(.text("y"))))
    XCTAssertEqual(parse("$$\nx\n\n# h\n\n$$\ny\n$$"),
                   document(paragraph(.text("$$"), .softLineBreak, .text("x")),
                            .heading(1, Text(.text("h"))),
                            mathBlock("y")))
  }

  func testTextWithSeveralDisplayFormulasIsNotABlock() {
    XCTAssertEqual(parse("$$a$$ and $$b$$"),
                   document(paragraph(math("a", display: true), .text(" and "),
                                      math("b", display: true))))
    XCTAssertEqual(parse("$$a$$ text"),
                   document(paragraph(math("a", display: true), .text(" text"))))
    XCTAssertEqual(parse("$$a$$ and\nthen $$b$$"),
                   document(paragraph(math("a", display: true), .text(" and"), .softLineBreak,
                                      .text("then "), math("b", display: true))))
  }

  func testBlocksInContainers() {
    XCTAssertEqual(parse("> $$\n> x\n> $$"), document(blockquote(mathBlock("x"))))
    XCTAssertEqual(parse("- $$\n  x\n  $$"),
                   document(list(tight: true, listItem("-", initial: true, mathBlock("x")))))
    XCTAssertEqual(parse("1. text\n\n   $$\n   a\n   b\n   $$"),
                   document(list(1, tight: false,
                                 listItem(1, ".", tight: false, paragraph(.text("text")),
                                          mathBlock("a\nb")))))
    // Indented by four spaces, it is an indented code block
    XCTAssertEqual(parse("    $$\n    x\n    $$"),
                   document(indentedCode("$$\n", "x\n", "$$")))
  }

  func testFencedMathBlocks() {
    XCTAssertEqual(parse("```math\nx^2\n```"), document(mathBlock("x^2")))
    XCTAssertEqual(parse("```math\na\nb\n```\n"), document(mathBlock("a\nb")))
    XCTAssertEqual(parse("~~~math title\nx\n~~~"), document(mathBlock("x")))
    XCTAssertEqual(parse("> ```math\n> x\n> ```"), document(blockquote(mathBlock("x"))))
    XCTAssertEqual(parse("- ```math\n  x\n  ```"),
                   document(list(tight: true, listItem("-", initial: true, mathBlock("x")))))
    // Other code blocks are code blocks
    XCTAssertEqual(parse("```latex\nx\n```"), document(fencedCode("latex", "x\n")))
    XCTAssertEqual(parse("```mathematica\nx\n```"), document(fencedCode("mathematica", "x\n")))
    XCTAssertEqual(parse("```\n$$\nx\n$$\n```"), document(fencedCode(nil, "$$\n", "x\n", "$$\n")))
    // Without the inline parser, the block is a code block
    XCTAssertEqual(MathMarkdownParser.standard.parse("```math\nx\n```", blockOnly: true),
                   document(fencedCode("math", "x\n")))
  }

  func testCodeBlocksAndSpansAreNotChanged() {
    XCTAssertEqual(parse("    $x$ and $$y$$"), document(indentedCode("$x$ and $$y$$")))
    XCTAssertEqual(parse("```\n$x$\n```"), document(fencedCode(nil, "$x$\n")))
    // Dollar signs in HTML tags and autolinks do not start or end formulas (found by fuzzing)
    XCTAssertEqual(parse("<a title=\"$x$\"> $y$"),
                   document(paragraph(.html("a title=\"$x$\""), .text(" "), math("y"))))
    XCTAssertEqual(parse("see <http://a.b/$x$y> and $z$"),
                   document(paragraph(.text("see "), .autolink(.uri, "http://a.b/$x$y"),
                                      .text(" and "), math("z"))))
    // The characters of an autolink in a formula are part of the formula
    XCTAssertEqual(parse("$a <http://a.b/$x> c$"),
                   document(paragraph(math("a <http://a.b/$x> c"))))
    XCTAssertEqual(parse("<span>$x$</span>"),
                   document(paragraph(.html("span"), math("x"), .html("/span"))))
  }

  // MARK: Equality and descriptions

  func testFragmentsAndBlocksAreEquatable() {
    XCTAssertEqual(math("x"), math("x"))
    XCTAssertNotEqual(math("x"), math("y"))
    XCTAssertNotEqual(math("x"), math("x", display: true))
    XCTAssertNotEqual(math("x"), .text("$x$"))
    XCTAssertEqual(mathBlock("x"), mathBlock("x"))
    XCTAssertNotEqual(mathBlock("x"), mathBlock("y"))
    XCTAssertNotEqual(mathBlock("x"), fencedCode("math", "x\n"))
  }

  func testDescriptionsAreTheSource() {
    let doc = parse("A $x_1$ and $$y$$ and $`z`$.\n\n$$\nq\n$$")
    guard case .document(let blocks) = doc, case .paragraph(let text)? = blocks.first else {
      XCTFail(doc.debugDescription)
      return
    }
    XCTAssertEqual(text.description, "A $x_1$ and $$y$$ and $`z`$.")
    XCTAssertEqual(text.rawDescription, "A $x_1$ and $$y$$ and $`z`$.")
    XCTAssertEqual(blocks[1].description, "$$\nq\n$$")
    XCTAssertEqual(blocks[1].string, "q")
  }

  // MARK: Generators

  func testHtml() {
    XCTAssertEqual(html("The area is $\\pi r^2$."),
                   "<p>The area is <span class=\"math inline\">\\(\\pi r^2\\)</span>.</p>\n")
    XCTAssertEqual(html("see $$a^2$$ here"),
                   "<p>see <span class=\"math display\">\\[a^2\\]</span> here</p>\n")
    XCTAssertEqual(html("$$\nx = y\n$$"), "<div class=\"math display\">\\[x = y\\]</div>\n")
    XCTAssertEqual(html("```math\nx = y\n```"), "<div class=\"math display\">\\[x = y\\]</div>\n")
    // The LaTeX is escaped
    XCTAssertEqual(html("$a<b \\& \"c\"$"),
                   "<p><span class=\"math inline\">\\(a&lt;b \\&amp; &quot;c&quot;\\)</span></p>\n")
    XCTAssertEqual(html("$$\n</div><script>alert(1)</script>\n$$"),
                   "<div class=\"math display\">\\[&lt;/div&gt;&lt;script&gt;alert(1)&lt;/script&gt;\\]</div>\n")
    // The same parser leaves the other markup alone
    XCTAssertEqual(html("**bold** ~~gone~~ $x$"),
                   "<p><strong>bold</strong> <del>gone</del> <span class=\"math inline\">\\(x\\)</span></p>\n")
  }

  func testStringGenerator() {
    let text = StringGenerator(numColumns: 80).generate(doc: parse("A $x_1$ and $$y$$.\n\n$$\nq = r\n$$"))
    XCTAssertTrue(text.contains("A $x_1$ and $$y$$."), text)
    XCTAssertTrue(text.contains("$$\nq = r\n$$"), text)
  }

  func testTerminalGenerator() {
    let result = TerminalGenerator(numColumns: 80, syntaxHighlighting: nil)
                   .generate(doc: parse("A $x_1$ and $$y$$.\n\n$$\nq = r\n$$"))
    let text = result.plainText
    XCTAssertTrue(text.contains("A $x_1$ and $$y$$."), text)
    XCTAssertTrue(text.contains("$$\nq = r\n$$"), text)
  }

  func testControlCharactersAreNotPassedToTerminals() {
    let block = Block.document([.custom(MathBlock(tex: "a\u{1B}[31m b\u{202E}"))])
    let text = StringGenerator(numColumns: 80).generate(doc: block)
    XCTAssertFalse(text.unicodeScalars.contains { $0.value == 0x1B || $0.value == 0x202E }, text)
    let terminal = TerminalGenerator(numColumns: 80, syntaxHighlighting: nil).generate(doc: block)
    XCTAssertFalse(terminal.plainText.unicodeScalars.contains { $0.value == 0x1B || $0.value == 0x202E })
    let inline = Block.document([.paragraph(Text(math("a\u{1B}[31m b")))])
    XCTAssertFalse(StringGenerator(numColumns: 80).generate(doc: inline).unicodeScalars
                     .contains { $0.value == 0x1B })
  }

  #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
  func testAttributedStringGeneratorShowsTheSourceAsCode() {
    let generator = AttributedStringGenerator()
    XCTAssertEqual(generator.htmlGenerator().generate(doc: parse("A $x<y$ and $$z$$.")),
                   "<p>A <code>$x&lt;y$</code> and <code>$$z$$</code>.</p>\n")
    let block = generator.htmlGenerator().generate(doc: parse("$$\nq = r\n$$"))
    XCTAssertTrue(block.contains("class=\"codebox\""), block)
    XCTAssertTrue(block.contains("q = r"), block)
    XCTAssertFalse(block.contains("math"), block)
    let fenced = generator.htmlGenerator().generate(doc: parse("```math\na\nb\n```"))
    XCTAssertTrue(fenced.contains("a\nb"), fenced)
  }
  #endif
}

private extension Text {
  func appending(_ fragment: TextFragment) -> Text {
    var res = self
    res.append(fragment: fragment)
    return res
  }
}
