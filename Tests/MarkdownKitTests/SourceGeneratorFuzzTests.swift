//
//  SourceGeneratorFuzzTests.swift
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
@testable import MarkdownKit

/// Parses random sequences of Markdown fragments, writes the trees back as source, and checks
/// that the source parses into the same tree (`roundTrips`) and that writing it again does not
/// change it. A few trees cannot be written back: emphasis next to runs of delimiters whose
/// length changes when they are escaped, formulas that span lines and start a paragraph (see
/// the design document), so the tests allow a small fraction of the inputs to fail. The
/// sequences are deterministic. The number of iterations can be changed with the environment
/// variable `MARKDOWNKIT_FUZZ_ITERATIONS`.
class SourceGeneratorFuzzTests: XCTestCase {

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

  /// Fragments of Markdown syntax, text and troublesome characters. Combining marks and joiners
  /// are left out: after a space that the generator writes, they form a single character.
  private static let tokens: [String] = [
    "#", "##", "######", "#######", "-", "*", "+", "1.", "2)", "10.", "999999999.", "0.",
    ">", ">>", "`", "``", "```", "````", "~~~", "|", ":", "---", "***", "___", "===",
    "[", "]", "(", ")", "<", ">", "!", "\\", "&", "&amp;", "&#x41;", "&#0;", "&ouml;",
    " ", "  ", "   ", "    ", "\t", "\n", "\n", "\n\n", "a", "foo", "bar", "http://x.y",
    "<a href=\"x\">", "<!--", "-->", "=", "_", "**", "~", "é", "😀", "世界",
    "\r\n", "[x]: /u \"t\"", "[x]", "![i](u)",
    "<div>", "</div>", "<script>", "<x@y.z>", "Term\n: def",
    "| a | b |\n|---|:-:|\n| c |", "|---|", ":---:", "<br/>", "  \n", "\\\n", "<?", "?>",
    "<![CDATA[", "]]>", "<!X", "'", "\"", "- [ ] t", "- [x] t", "1. [ ] t", "1. a\n2. b", "~~", "~a~",
    "~~a~~", "x~~", ">\t", "-\t", "\t-\t", "1.\t", "\t\t", " \t", "*\t", "  \n", "\\ \n", "`a\\\n"
  ]

  private static let mathTokens: [String] = [
    "$", "$", "$$", "\\$", "$`", "`$", "$$\n", "\n$$", "$$ ", " $$", "```math\n", "~~~math\n",
    "x^2", "a_b", "f^*(x)", "\\\\", "{", "}", "\\frac{a}{b}", "[a](b)", "*", "_", "~", "`", "\n\n",
    " ", "5", "<b>", "<", ">", "- ", "> ", "| ", "# "
  ]

  private static let latexTokens: [String] = [
    "\\(", "\\)", "\\[", "\\]", "\\(", "\\)", "\\[", "\\]", "\\\\", "\\\\(", "\\\\]", "\\", "(", ")",
    "[", "]", "\\[\n", "\n\\]", "\\[ ", " \\]", "\\(x\\)", "\\[x\\]", "\n\n"
  ]

  private var iterations: Int {
    if let value = ProcessInfo.processInfo.environment["MARKDOWNKIT_FUZZ_ITERATIONS"],
       let n = Int(value), n > 0 {
      return n
    }
    return 3000
  }

  private func tokens(for dialect: MarkdownDialect) -> [String] {
    switch dialect {
      case .fullMath:
        return Self.tokens + Self.mathTokens
      case .fullLaTeX:
        return Self.tokens + Self.mathTokens + Self.latexTokens
      default:
        return Self.tokens
    }
  }

  private func randomInput(_ tokens: [String], _ rng: inout Xorshift) -> String {
    var input = ""
    for _ in 0..<Int.random(in: 1...40, using: &rng) {
      input += tokens.randomElement(using: &rng)!
    }
    return input
  }

  /// Checks the round trip of random documents, which the parser of `parseDialect` produces, with
  /// the generator `generator` (for the same dialect, or for a larger syntax).
  private func check(parse parseDialect: MarkdownDialect,
                     with generator: SourceGenerator,
                     seed: Int) {
    var rng = Xorshift(seed: seed)
    var failures: [String] = []
    for _ in 0..<self.iterations {
      let input = self.randomInput(self.tokens(for: parseDialect), &rng)
      let doc = parseDialect.parser.parse(input)
      if let mismatch = generator.firstMismatch(of: doc) {
        failures.append("\(input.debugDescription): \(mismatch)")
      } else {
        let output = generator.generate(doc: doc)
        if generator.generate(doc: parseDialect.parser.parse(output)) != output {
          failures.append("\(input.debugDescription): the output is not a fixed point")
        }
      }
    }
    // The parts of a document that no source can express are rare
    XCTAssertLessThanOrEqual(failures.count, max(3, self.iterations / 100),
                             "\(parseDialect): \(failures.prefix(5).joined(separator: "\n"))")
  }

  func testRandomDocumentsRoundTrip() {
    for (i, dialect) in MarkdownDialect.allCases.enumerated() {
      self.check(parse: dialect, with: dialect.sourceGenerator, seed: 101 + i)
    }
  }

  /// The source which is written for the largest syntax can be read by every parser: the
  /// escapes of syntax that a dialect lacks are harmless.
  func testSourceOfStandardGeneratorIsReadByEveryDialect() {
    for (i, dialect) in MarkdownDialect.allCases.enumerated() {
      self.check(parse: dialect, with: SourceGenerator(syntax: .fullLaTeX, parser: dialect.parser),
                 seed: 201 + i)
    }
  }
}
