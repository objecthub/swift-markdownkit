//
//  PerformanceTests.swift
//  MarkdownKitTests
//
//  Created on 06/10/2026.
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

///
/// Baseline benchmarks. The `scaling` tests print the time for an input of size n and 2n and
/// the ratio between both: a ratio near 2 indicates linear behavior, a ratio near 4 indicates
/// quadratic behavior. They never fail because of timing; run them with
/// `swift test --filter PerformanceTests` and compare the printed numbers before and after
/// optimizations.
///
class PerformanceTests: XCTestCase {

  // MARK: Fixtures

  private static let prose = "The quick brown fox jumps over the lazy dog, again and again. "

  private static func repeated(_ str: String, count: Int) -> String {
    return String(repeating: str, count: count)
  }

  private static func document(paragraphs: Int) -> String {
    var res = ""
    for i in 0..<paragraphs {
      res += "## Heading \(i)\n\n"
      res += repeated(prose, count: 4) + "With *emphasis*, **strong text**, `code` and " +
             "[a link](http://example.com/\(i) \"title\") plus an &amp; entity.\n\n"
      res += "- item one\n- item two\n- item three\n\n"
      res += "```swift\nlet x = \(i) < 10 && y > 3\n```\n\n"
    }
    return res
  }

  // MARK: Helpers

  private func time(_ body: () -> Void) -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    body()
    return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
  }

  private func parse(_ input: String) {
    _ = MarkdownParser.standard.parse(input)
  }

  /// Prints timings for `make(n)` and `make(2n)` and the resulting ratio.
  private func scaling(_ name: String, n: Int, _ make: (Int) -> String,
                       run: (String) -> Void) {
    let small = make(n)
    let large = make(2 * n)
    run(small) // warm up
    let t1 = time { run(small) }
    let t2 = time { run(large) }
    let ratio = t2 / max(t1, 0.001)
    print(String(format: "SCALING %@: n=%d %.1fms, n=%d %.1fms, ratio %.2f",
                 name, n, t1, 2 * n, t2, ratio))
  }

  // MARK: measure blocks

  func testParseProse() {
    let input = Self.repeated(Self.prose, count: 2000)
    measure { parse(input) }
  }

  func testParseUnicodeProse() {
    let input = Self.repeated("日本語のテキスト 🎉 émoji ünïcode 𝔘𝔫𝔦𝔠𝔬𝔡𝔢. ", count: 1000)
    measure { parse(input) }
  }

  func testParseMixedDocument() {
    let input = Self.document(paragraphs: 100)
    measure { parse(input) }
  }

  func testGenerateHtml() {
    let doc = MarkdownParser.standard.parse(Self.document(paragraphs: 100))
    measure { _ = HtmlGenerator.standard.generate(doc: doc) }
  }

  func testGenerateHtmlEntityHeavyCode() {
    let code = Self.repeated("if a < b && c > d { print(\"x & y\") }\n", count: 1000)
    let doc = MarkdownParser.standard.parse("```\n" + code + "```")
    measure { _ = HtmlGenerator.standard.generate(doc: doc) }
  }

  func testGenerateString() {
    let doc = MarkdownParser.standard.parse(Self.document(paragraphs: 100))
    measure { _ = StringGenerator.standard.generate(doc: doc) }
  }

  func testGenerateTerminal() {
    let doc = MarkdownParser.standard.parse(Self.document(paragraphs: 100))
    measure { _ = TerminalGenerator.standard.generate(doc: doc) }
  }

  // MARK: scaling checks (pathological inputs)

  func testScalingProse() {
    scaling("prose", n: 1000, { Self.repeated(Self.prose, count: $0) }, run: parse)
  }

  func testScalingEmphasisDense() {
    scaling("emphasis-dense", n: 1000, { Self.repeated("*a* **b** _c_ ", count: $0) }, run: parse)
  }

  func testScalingEmphasisUnmatched() {
    scaling("emphasis-unmatched", n: 500, { Self.repeated("*a_ ", count: $0) }, run: parse)
  }

  func testScalingUnmatchedBrackets() {
    scaling("brackets-unmatched", n: 1000, { Self.repeated("[", count: $0) }, run: parse)
  }

  func testScalingUnmatchedAngleBrackets() {
    scaling("lt-unmatched", n: 1000, { Self.repeated("a < b ", count: $0) }, run: parse)
  }

  func testScalingNestedLinks() {
    // keep n small: nested links are expected to be very slow until fixed
    scaling("links-nested", n: 8, { n in
      String(repeating: "[", count: n) + "a" + String(repeating: "](b)", count: n)
    }, run: parse)
  }

  func testScalingHtmlBlocks() {
    scaling("html-blocks", n: 2000, { Self.repeated("<div>x</div>\n", count: $0) }, run: parse)
  }

  func testScalingEntities() {
    scaling("entities", n: 2000, { Self.repeated("&x ", count: $0) + ";" }, run: { str in
      _ = str.decodingNamedCharacters()
    })
  }

  func testScalingEscapes() {
    scaling("escapes", n: 5000, { Self.repeated("a<b>&\"c'", count: $0) }, run: { str in
      _ = str.encodingPredefinedXmlEntities()
    })
  }

  func testScalingNestedBlockquotes() {
    // limited depth until nesting limits exist (deeper input can overflow the stack)
    scaling("blockquotes-nested", n: 50, { String(repeating: "> ", count: $0) + "x" },
            run: parse)
  }

  func testScalingBalancedNestedBrackets() {
    scaling("brackets-balanced-nested", n: 300, { n in
      String(repeating: "[", count: n) + "a" + String(repeating: "]", count: n)
    }, run: parse)
  }

  func testScalingMatchedBackticks() {
    scaling("backticks-matched", n: 1000, { Self.repeated("`a` ", count: $0) }, run: parse)
  }

  func testScalingManyGreaterThanAfterLessThan() {
    scaling("lt-then-gt", n: 100, { n in
      Self.repeated("<a ", count: n) + Self.repeated("> ", count: n)
    }, run: parse)
  }

  func testScalingManyEntities() {
    scaling("entities-many", n: 2000, { Self.repeated("&amp; &lt; &#35; ", count: $0) }, run: { str in
      _ = str.decodingNamedCharacters()
    })
  }

  func testScalingEmphasisNested() {
    scaling("emphasis-nested", n: 300, { n in
      String(repeating: "*a ", count: n) + "b" + String(repeating: "* ", count: n)
    }, run: parse)
  }

  func testScalingDeeplyNestedContainers() {
    scaling("containers-deep", n: 5000, { String(repeating: "> - ", count: $0) + "x" }, run: parse)
  }

  func testScalingDeeplyNestedImages() {
    scaling("images-deep", n: 1000, { n in
      String(repeating: "![a ", count: n) + "x" + String(repeating: "](u)", count: n)
    }, run: parse)
  }

  func testScalingDeeplyNestedEmphasis() {
    scaling("emphasis-deep", n: 2000, { n in
      (0..<n).map { $0 % 2 == 0 ? "*a " : "_a " }.joined() + "x " +
      (0..<n).reversed().map { $0 % 2 == 0 ? "a* " : "a_ " }.joined()
    }, run: parse)
  }
}
