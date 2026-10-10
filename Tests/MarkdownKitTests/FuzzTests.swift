//
//  FuzzTests.swift
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

/// Feeds random sequences of Markdown fragments through the parsers and generators. The tests
/// pass if nothing crashes (a crash aborts the whole test run) and a few invariants hold.
/// The sequences are deterministic. The number of iterations can be changed with the
/// environment variable `MARKDOWNKIT_FUZZ_ITERATIONS` (e.g. for a long run before a release).
/// If a test crashes, the input of the iteration is printed first when
/// `MARKDOWNKIT_FUZZ_VERBOSE` is set.
class FuzzTests: XCTestCase {

  /// A small, fast, deterministic random number generator (xorshift64)
  private struct Xorshift: RandomNumberGenerator {
    private var state: UInt64
    init(seed: Int) {
      self.state = UInt64(truncatingIfNeeded: seed) &* 0x9E3779B97F4A7C15 | 1
      for _ in 0..<5 {
        _ = self.next()
      }
    }
    mutating func next() -> UInt64 {
      self.state ^= self.state << 13
      self.state ^= self.state >> 7
      self.state ^= self.state << 17
      return self.state
    }
  }

  /// Fragments of Markdown syntax, text and troublesome characters
  private static let tokens: [String] = [
    "#", "##", "######", "#######", "-", "*", "+", "1.", "2)", "10.", "999999999.", "0.",
    ">", ">>", "`", "``", "```", "````", "~~~", "|", ":", "---", "***", "___", "===",
    "[", "]", "(", ")", "<", ">", "!", "\\", "&", "&amp;", "&#x41;", "&#0;", "&ouml;",
    " ", "  ", "   ", "    ", "\t", "\n", "\n", "\n\n", "a", "foo", "bar", "http://x.y",
    "<a href=\"x\">", "<!--", "-->", "=", "_", "**", "~", "é", "😀", "\u{0301}", "世界",
    "\u{200D}", "\r\n", "\u{0}", "\u{1B}", "\u{202E}", "[x]: /u \"t\"", "[x]", "![i](u)",
    "<div>", "</div>", "<script>", "<x@y.z>", "Term\n: def",
    "| a | b |\n|---|:-:|\n| c |", "|---|", ":---:", "<br/>", "  \n", "\\\n", "<?", "?>",
    "<![CDATA[", "]]>", "<!X", "'", "\"", "- [ ] t", "- [x] t", "1. [ ] t", "1. a\n2. b", "~~", "~a~", "~~a~~", "x~~",
    ">\t", "-\t", "\t-\t", "1.\t", "\t\t", " \t", "*\t", "  \n", "\\ \n", "`a\\\n"
  ]

  /// Fragments for generating code blocks (indented or fenced) which get syntax highlighted
  private static let codeTokens: [String] = [
    "```swift\n", "```c\n", "```html\n", "```js\n", "```\n", "\n```\n", "    ", "\t",
    "<", ">", "&lt;", "&amp;", "&", "<span class=\"x\">", "</span>", "int x = 1 < 2;",
    "let a: Array<Int> = []", "\"str\"", "// c", "/* c */", "#include <a.h>",
    "<div class=\"a\">", "😀", "é", "\u{0301}", "\n", "\n", "x", "{", "}", "\\", "'"
  ]

  private static let widths = [-1, 0, 1, 2, 3, 5, 8, 20, 80]

  private var iterations: Int {
    if let value = ProcessInfo.processInfo.environment["MARKDOWNKIT_FUZZ_ITERATIONS"],
       let n = Int(value), n > 0 {
      return n
    }
    return 3000
  }

  private var verbose: Bool {
    return ProcessInfo.processInfo.environment["MARKDOWNKIT_FUZZ_VERBOSE"] != nil
  }

  /// Prints to the standard error stream, which is not buffered. (Buffered output would be
  /// lost if the process crashes, which is exactly when the output is needed.)
  private func log(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
  }

  private func randomInput(_ tokens: [String], _ rng: inout Xorshift) -> String {
    var input = ""
    for _ in 0..<Int.random(in: 1...40, using: &rng) {
      input += tokens.randomElement(using: &rng)!
    }
    return input
  }

  /// True if `str` contains control characters other than newline and tab
  private func hasControlCharacters(_ str: String) -> Bool {
    return str.unicodeScalars.contains { scalar in
      switch scalar.value {
        case 0x09, 0x0A:
          return false
        case 0x00...0x1F, 0x7F...0x9F:
          return true
        default:
          return false
      }
    }
  }

  func testRandomMarkdownDoesNotCrashParsersAndGenerators() {
    var rng = Xorshift(seed: 1)
    for i in 0..<self.iterations {
      let input = self.randomInput(Self.tokens, &rng)
      if self.verbose {
        self.log("FUZZ #\(i): \(input.debugDescription)")
      }
      for parser in [MarkdownParser.standard, ExtendedMarkdownParser.standard,
                     FullMarkdownParser.standard] {
        let doc = parser.parse(input)
        _ = doc.description
        _ = doc.debugDescription
        _ = doc.string
        _ = HtmlGenerator.standard.generate(doc: doc)
        // Safe mode: raw HTML is never copied to the output
        let safe = HtmlGenerator(safeMode: true).generate(doc: doc)
        XCTAssertFalse(safe.lowercased().contains("<script"),
                       "script tag in safe mode output for \(input.debugDescription)")
        let width = Self.widths.randomElement(using: &rng)!
        let text = StringGenerator(numColumns: width).generate(doc: doc)
        XCTAssertFalse(self.hasControlCharacters(text),
                       "control character in text output for \(input.debugDescription)")
        _ = StringGenerator(numColumns: width, alignDisplayWidth: false).generate(doc: doc)
        _ = TerminalGenerator(numColumns: width, syntaxHighlighting: nil).generate(doc: doc)
      }
    }
  }

  /// Markup which only `FullMarkdownParser` knows is the only difference to the extended parser
  func testFullMarkdownParserAgreesWithTheExtendedParserWithoutTheNewMarkup() {
    var rng = Xorshift(seed: 7)
    var compared = 0
    for _ in 0..<self.iterations {
      let input = self.randomInput(Self.tokens, &rng)
      // Markup which only `FullMarkdownParser` knows: tildes and task list markers
      if input.contains("~") || input.contains("[ ]") || input.contains("[x]") {
        continue
      }
      compared += 1
      XCTAssertEqual(HtmlGenerator.standard.generate(doc: FullMarkdownParser.standard.parse(input)),
                     HtmlGenerator.standard.generate(doc: ExtendedMarkdownParser.standard.parse(input)),
                     input.debugDescription)
    }
    XCTAssertGreaterThan(compared, self.iterations / 5)
  }

  func testRandomCodeBlocksDoNotCrashSyntaxHighlighting() throws {
    // Without the highlighter, this test does not test anything
    try XCTSkipIf(SyntaxHighlighter.proxy == nil, "syntax highlighter is not available")
    var rng = Xorshift(seed: 2)
    for i in 0..<max(self.iterations / 10, 10) {
      let input = self.randomInput(Self.codeTokens, &rng)
      if self.verbose {
        self.log("FUZZ code #\(i): \(input.debugDescription)")
      }
      let doc = MarkdownParser.standard.parse(input)
      let width = Self.widths.randomElement(using: &rng)!
      let result = TerminalGenerator(numColumns: width).generate(doc: doc)
      _ = result.plainText
    }
  }
}
