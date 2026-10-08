//
//  CrashRegressionTests.swift
//  MarkdownKitTests
//
//  Created on 08/10/2026.
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

/// Regression tests for inputs which crashed the parsers or generators. A crash aborts the
/// whole test run, so these tests mostly check that the inputs are processed at all.
class CrashRegressionTests: XCTestCase {

  private func parse(_ input: String, extended: Bool = true) -> Block {
    return (extended ? ExtendedMarkdownParser.standard : MarkdownParser.standard).parse(input)
  }

  private func terminal(_ input: String, numColumns: Int = 80) -> String {
    return TerminalGenerator(numColumns: numColumns).generate(doc: self.parse(input)).plainText
  }

  // MARK: Parsers

  /// A blank last line without a line terminator is not a line a block parser can start with.
  func testTableFollowedByWhitespaceOnlyLastLine() {
    for input in ["| a |\n|---|\n| b |\n ",
                  "| a | b |\n|---|---|\n| c | d |\n  ",
                  "| a | b |\n|---|---|\n| c | d |\n\t",
                  "a|b\n-|-\nx|y\n "] {
      guard case .document(let blocks) = self.parse(input),
            blocks.count == 1,
            case .table(_, _, let rows) = blocks[0] else {
        XCTFail("not a table: \(input.debugDescription)")
        continue
      }
      XCTAssertEqual(rows.count, 1, input.debugDescription)
    }
  }

  func testBlankLastLineAfterEveryKindOfBlock() {
    let prefixes = ["> a", "- a", "1. a", "# h", "a\n===", "a\n---", "[a]: /u", "<div>",
                    "```\ncode", "~~~", "    code", "---", "* * *", "> ```", "- ```", "> - a",
                    "| a |\n|---|\n| b |", "> | a |\n> |---|\n> | b |", "Term\n: def",
                    "<!-- c", "a\\", "a  ", "\\", ""]
    for prefix in prefixes {
      for suffix in ["\n ", "\n  ", "\n\t", "\n   \n ", "\n>", "\n> ", "\n-", "\n- ", "\n1."] {
        let input = prefix + suffix
        for extended in [false, true] {
          let doc = self.parse(input, extended: extended)
          guard case .document(_) = doc else {
            XCTFail("not a document: \(input.debugDescription)")
            continue
          }
          _ = HtmlGenerator.standard.generate(doc: doc)
        }
      }
    }
  }

  // MARK: Text fragments and generators

  func testDelimiterFragmentsWithoutCharacters() {
    for count in [-1, 0] {
      let fragment = TextFragment.delimiter("*", count, [])
      XCTAssertEqual(fragment.description, "")
      XCTAssertEqual(fragment.rawDescription, "")
      XCTAssertEqual(fragment.string, "")
      let text = Text(fragment)
      XCTAssertEqual(HtmlGenerator.standard.generate(text: text), "")
    }
    let one = TextFragment.delimiter("*", 1, [])
    XCTAssertEqual(one.description, "*")
    XCTAssertEqual(TextFragment.delimiter("_", 3, []).string, "___")
  }

  /// Rows with more cells than there are column alignments (only possible for syntax trees
  /// which were not created by the parser).
  func testTableWithMoreCellsThanAlignments() {
    let table = Block.table([Text("a")], [.left], [[Text("b"), Text("c")]])
    let doc = Block.document([table])
    let html = HtmlGenerator.standard.generate(doc: doc)
    XCTAssertTrue(html.contains("<td align=\"left\">b</td>"), html)
    XCTAssertTrue(html.contains("<td>c</td>"), html)
    XCTAssertTrue(StringGenerator.standard.generate(doc: doc).contains("c"))
    XCTAssertTrue(TerminalGenerator.standard.generate(doc: doc).plainText.contains("c"))
  }

  func testGeneratorsAcceptBlocksWhichAreNotDocuments() {
    let paragraph = Block.paragraph(Text("hi"))
    XCTAssertEqual(HtmlGenerator.standard.generate(doc: paragraph), "<p>hi</p>\n")
    XCTAssertEqual(StringGenerator.standard.generate(doc: paragraph), "hi")
    XCTAssertEqual(TerminalGenerator.standard.generate(doc: paragraph).plainText, "hi")
    // A document nested in a document
    let nested = Block.document([.document([paragraph])])
    XCTAssertEqual(HtmlGenerator.standard.generate(doc: nested), "<p>hi</p>\n")
  }

  #if os(macOS) || os(iOS)
  @MainActor
  func testAttributedStringGeneratorTableWithMoreCellsThanAlignments() {
    let table = Block.table([Text("a")], [.left], [[Text("b"), Text("c")]])
    let result = AttributedStringGenerator().generate(doc: .document([table]))
    XCTAssertNotNil(result)
    XCTAssertTrue(result?.string.contains("c") ?? false)
  }
  #endif

  // MARK: Terminal output

  /// A paragraph or heading consisting of nothing but line breaks has lines without any text,
  /// which CommandLineKit cannot join.
  func testTerminalOutputForLinesWithoutText() {
    for input in ["\\\na", "\\\n\\\n=", "\\\n\\\n===", "\\\n\\\na\n\n\\\n", "*\\\na*",
                  "> \\\na", "- \\\n  a", "# \\\n", "[\\\n](/u)", "![\\\na](u)"] {
      for width in [80, 20, 3, 1, 0] {
        _ = self.terminal(input, numColumns: width)
      }
    }
    XCTAssertTrue(self.terminal("\\\na").contains("a"))
  }

  // MARK: Syntax highlighting in the terminal

  private func requireHighlighter() throws {
    try XCTSkipIf(SyntaxHighlighter.proxy == nil, "syntax highlighter is not available")
  }

  func testTerminalHighlightingKeepsAngleBracketsAndEntities() throws {
    try self.requireHighlighter()
    let samples: [(String, String)] = [
      ("c", "#include <stdio.h>\nint main() { return 1 < 2; }\n"),
      ("swift", "let a: Array<Int> = []\nif a < b && c > d { print(\"x & y\") }\n"),
      ("html", "<div class=\"a\">x &amp; y</div>\n"),
      ("js", "if (a<b && c>d) { s = '<b>' + \"&lt;\" }\n")
    ]
    for (language, code) in samples {
      let output = self.terminal("```\(language)\n\(code)```\n")
      for line in code.split(separator: "\n") {
        XCTAssertTrue(output.contains(line), "\(language): \(line) in\n\(output)")
      }
    }
  }

  func testTerminalHighlightingOfCodeEndingInAngleBracket() throws {
    try self.requireHighlighter()
    // The first one is an indented code block, the others unterminated fenced code blocks
    for input in ["\t<", "    <", "```c\n<", "```c\nx <", "```c\nx <<", "```c\n<a"] {
      let output = self.terminal(input)
      XCTAssertTrue(output.contains("<"), "\(input.debugDescription): \(output)")
    }
    // An entity in code is code, it is not decoded
    XCTAssertTrue(self.terminal("```c\n&lt;").contains("&lt;"))
  }

  func testTerminalHighlightingKeepsBlankLines() throws {
    try self.requireHighlighter()
    let lines = self.terminal("```swift\nlet a = 1\n\n\nlet b = 2\n```\n")
                    .components(separatedBy: "\n")
    let first = try XCTUnwrap(lines.firstIndex { $0.contains("let a = 1") })
    XCTAssertGreaterThan(lines.count, first + 3, lines.joined(separator: "\n"))
    guard lines.count > first + 3 else {
      return
    }
    XCTAssertTrue(lines[first + 1].trimmingCharacters(in: .whitespaces).isEmpty)
    XCTAssertTrue(lines[first + 2].trimmingCharacters(in: .whitespaces).isEmpty)
    XCTAssertTrue(lines[first + 3].contains("let b = 2"), lines.joined(separator: "\n"))
  }

  /// Only the first word of an info string is the language
  func testTerminalHighlightingUsesFirstWordOfInfoString() throws {
    try self.requireHighlighter()
    func codeLine(_ info: String) -> String? {
      let output = TerminalGenerator(numColumns: 80)
                     .generate(doc: self.parse("```\(info)\nlet a = 1\n```\n")).encodedString
      return output.components(separatedBy: "\n").first { $0.contains("a") && $0.contains("1") &&
                                                          !$0.contains("╌") }
    }
    let plain = try XCTUnwrap(codeLine("swift"))
    XCTAssertNotEqual(plain, "let a = 1", "the code should be highlighted")
    XCTAssertEqual(codeLine("swift title=\"x\""), plain)
  }

  func testMultipleClassesOfHighlightedSpansAreStyled() throws {
    let config = try XCTUnwrap(AnsiHighlightingConfig(
                                 withTheme: ".hljs{color:#ffffff}.hljs-keyword{color:#ff0000}",
                                 fullColorSupport: true))
    let keyword = config.apply(to: "x", styleList: ["hljs", "hljs-keyword"])
    let plain = config.apply(to: "x", styleList: ["hljs"])
    XCTAssertNotEqual(keyword, plain)
    XCTAssertEqual(config.apply(to: "x", styleList: ["hljs", "hljs-keyword function_"]), keyword)
    XCTAssertEqual(config.apply(to: "x", styleList: ["hljs", "other  hljs-keyword"]), keyword)
  }
}
