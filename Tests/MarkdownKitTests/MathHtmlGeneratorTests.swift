//
//  MathHtmlGeneratorTests.swift
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
import MarkdownKit

/// An HTML generator of a client that typesets formulas in its own way.
private final class BracketGenerator: HtmlGenerator, MathHtmlRendering, @unchecked Sendable {
  func mathHtml(tex: String, display: Bool, block: Bool) -> String? {
    return block ? "<pre>[\(tex)]</pre>\n" : "<b>[\(display ? "D" : "I"):\(tex)]</b>"
  }
}

/// Tests for the HTML of formulas.
final class MathHtmlGeneratorTests: XCTestCase {

  private func parse(_ str: String) -> Block {
    return MathMarkdownParser.standard.parse(str)
  }

  private func html(_ str: String, _ generator: HtmlGenerator) -> String {
    return generator.generate(doc: self.parse(str))
  }

  private let markdown = "The area is $\\pi r^2$ and $$\\sum_{i=0}^n i$$ here.\n\n$$\n\\frac{a}{b}\n$$\n"

  func testGeneratorsWithoutMathOutputWriteDelimiters() {
    let expected = "<p>The area is <span class=\"math inline\">\\(\\pi r^2\\)</span> and " +
                   "<span class=\"math display\">\\[\\sum_{i=0}^n i\\]</span> here.</p>\n" +
                   "<div class=\"math display\">\\[\\frac{a}{b}\\]</div>\n"
    XCTAssertEqual(self.html(markdown, HtmlGenerator.standard), expected)
    XCTAssertEqual(self.html(markdown, MathHtmlGenerator()), expected)
    XCTAssertEqual(self.html(markdown, MathHtmlGenerator(math: .delimiters)), expected)
    XCTAssertEqual(MathHtmlGenerator.Output.delimiters,
                   MathHtmlGenerator.Output.delimiters)
    XCTAssertNotEqual(MathHtmlGenerator.Output.html,
                      MathHtmlGenerator.Output.mathml)
  }

  #if !os(watchOS)

  func testKaTeXHtml() {
    let result = self.html(markdown, MathHtmlGenerator(math: .html))
    XCTAssertTrue(result.hasPrefix("<p>The area is <span class=\"math inline\"><span class=\"katex\">" +
                                   "<span class=\"katex-html\" aria-hidden=\"true\">"), result)
    XCTAssertTrue(result.contains("</span> and <span class=\"math display\"><span class=\"katex-display\">"),
                  result)
    XCTAssertTrue(result.contains("</span></span> here.</p>\n<div class=\"math display\">" +
                                  "<span class=\"katex-display\"><span class=\"katex\">"), result)
    XCTAssertTrue(result.hasSuffix("</span></span></span></div>\n"), result)
    XCTAssertFalse(result.contains("\\("), result)
    XCTAssertFalse(result.contains("<math"), result)
  }

  func testKaTeXMathML() {
    let result = self.html(markdown, MathHtmlGenerator(math: .mathml))
    XCTAssertTrue(result.hasPrefix("<p>The area is <span class=\"math inline\"><span class=\"katex\">" +
                                   "<math xmlns="), result)
    XCTAssertTrue(result.contains("<mfrac>"), result)
    XCTAssertTrue(result.contains("<annotation encoding=\"application/x-tex\">\\pi r^2</annotation>"), result)
    XCTAssertTrue(result.contains("display=\"block\""), result)
    XCTAssertFalse(result.contains("katex-html"), result)
  }

  func testKaTeXHtmlAndMathML() {
    let result = self.html(markdown, MathHtmlGenerator(math: .htmlAndMathml))
    XCTAssertTrue(result.contains("katex-html") && result.contains("<math"), result)
    XCTAssertEqual(MathHtmlGenerator(math: .htmlAndMathml).math,
                   .katex(KaTeXOptions(output: .htmlAndMathml)))
  }

  func testKaTeXOptions() {
    let options = KaTeXOptions(output: .mathml, macros: ["\\RR": "\\mathbb{R}"])
    let result = self.html("$x \\in \\RR$", MathHtmlGenerator(math: .katex(options)))
    XCTAssertTrue(result.contains("mathvariant=\"double-struck\""), result)
    // Without the macro, the formula is invalid
    XCTAssertTrue(self.html("$x \\in \\RR$", MathHtmlGenerator(math: .mathml)).contains("katex-error"))
  }

  func testInvalidFormulasAreShownWithTheirSource() {
    let generator = MathHtmlGenerator(math: .mathml)
    XCTAssertEqual(self.html("a $\\frac{$ b", generator),
                   "<p>a <span class=\"math inline\"><span class=\"katex-error\" " +
                   "title=\"KaTeX parse error: Unexpected end of input in a macro argument, expected &#39;}&#39; " +
                   "at end of input: \\frac{\">$\\frac{$</span></span> b</p>\n")
    let block = self.html("$$\n\\badcmd\n$$", generator)
    XCTAssertTrue(block.hasPrefix("<div class=\"math display\"><span class=\"katex-error\" " +
                                  "title=\"KaTeX parse error: Undefined control sequence: \\badcmd"), block)
    XCTAssertTrue(block.hasSuffix(">$$\\badcmd$$</span></div>\n"), block)
    // Too long
    let long = String(repeating: "x", count: 20_000)
    XCTAssertTrue(self.html("$\(long)$", generator).contains("The formula is longer than 10000 bytes"))
  }

  func testWithoutAnEngineFormulasAreWrittenWithDelimiters() {
    let generator = MathHtmlGenerator(math: .html, engine: nil)
    XCTAssertEqual(self.html(markdown, generator), self.html(markdown, HtmlGenerator.standard))
  }

  func testMarkdownAroundFormulasIsUnchanged() {
    let result = self.html("**bold $x_1$** and ~~gone~~ [link $y$](http://example.com)",
                           MathHtmlGenerator(math: .mathml))
    XCTAssertTrue(result.hasPrefix("<p><strong>bold <span class=\"math inline\">"), result)
    XCTAssertTrue(result.contains("</span></strong> and <del>gone</del> <a href=\"http://example.com\">link "),
                  result)
  }

  func testHtmlOfUntrustedMarkdownIsSafe() {
    let attack = "$\\href{javascript:alert(1)}{x}$ $\\includegraphics{http://evil/x.png}$ " +
                 "$a\\htmlClass{x}{y}$\n\n$$\n</div><script>alert(1)</script>\n$$\n"
    for output in [MathHtmlGenerator.Output.html, .mathml, .htmlAndMathml, .delimiters] {
      for safeMode in [false, true] {
        let result = self.html(attack, MathHtmlGenerator(math: output, safeMode: safeMode))
        for forbidden in ["<a ", "<img", "<script", "</div><", "href=", "onclick", "src="] {
          XCTAssertFalse(result.contains(forbidden), "\(output) safeMode \(safeMode): \(forbidden): \(result)")
        }
      }
    }
  }

  func testManyFormulas() {
    let source = (0..<400).map { "$x_{\($0)}^2 + \\frac{\($0)}{2}$" }.joined(separator: "\n")
    let start = Date()
    let result = self.html(source, MathHtmlGenerator(math: .html))
    XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    XCTAssertEqual(result.components(separatedBy: "class=\"katex\"").count - 1, 400)
  }

  #endif

  func testAGeneratorOfTheClientCanTypesetFormulas() {
    let result = self.html(markdown, BracketGenerator())
    XCTAssertEqual(result, "<p>The area is <b>[I:\\pi r^2]</b> and <b>[D:\\sum_{i=0}^n i]</b> here.</p>\n" +
                           "<pre>[\\frac{a}{b}]</pre>\n")
  }

  func testOtherGeneratorsDoNotChange() {
    let doc = self.parse(markdown)
    XCTAssertTrue(StringGenerator(numColumns: 80).generate(doc: doc).contains("$\\pi r^2$"))
  }
}
