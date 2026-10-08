//
//  CommonMarkSpecTests.swift
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
@testable import MarkdownKit

/// Runs the examples of the CommonMark specification, version 0.31.2, through `MarkdownParser`
/// and `HtmlGenerator`. The examples are stored in the file `commonmark-spec-0.31.2.json`,
/// which was downloaded from https://spec.commonmark.org/0.31.2/spec.json. The CommonMark
/// specification is Copyright (c) John MacFarlane and licensed under the Creative Commons
/// CC-BY-SA 4.0 license (https://creativecommons.org/licenses/by-sa/4.0/).
///
/// MarkdownKit does not reproduce the HTML of the reference implementation byte by byte. The
/// comparison ignores whitespace, quote entities, percent-encoding of URLs, and the `start`
/// attribute of ordered lists starting with 1. The examples in `knownDeviations` are the ones
/// for which MarkdownKit produces different results even then. The test fails if an example
/// outside of this list fails (a regression) and also if an example in the list passes
/// (the list needs to be updated; a bug was fixed).
class CommonMarkSpecTests: XCTestCase {

  private struct Example: Decodable {
    let markdown: String
    let html: String
    let example: Int
    let section: String
  }

  /// Examples for which the output of MarkdownKit differs from the specification.
  static let knownDeviations: [Int : String] = [
    9: "tab stops are not taken into account for list item indentation",
    146: "an info string of a tilde fence cannot contain backticks",
    307: "a list is considered loose if a nested list contains blank lines",
    319: "a list is considered loose if a nested list contains blank lines",
    320: "a list is considered loose if a nested block quote ends with a blank line",
    354: "currency symbols are not punctuation for emphasis delimiter runs",
    491: "a link destination in angle brackets may span lines",
    590: "the exclamation mark of an unresolved image is dropped",
    603: "a backslash in an autolink",
    641: "a backslash at the end of a line in a code span is dropped",
    643: "a backslash at the end of a line in inline HTML is dropped"
  ]

  private func loadExamples() throws -> [Example] {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: CommonMarkSpecTests.self)
    #endif
    let url = try XCTUnwrap(bundle.url(forResource: "commonmark-spec-0.31.2",
                                       withExtension: "json"))
    return try JSONDecoder().decode([Example].self, from: Data(contentsOf: url))
  }

  /// Removes differences between the output of MarkdownKit and the reference implementation
  /// which do not change how a browser renders the HTML.
  private func normalize(_ html: String) -> String {
    var result = html.replacingOccurrences(of: " start=\"1\"", with: "")
                     .replacingOccurrences(of: "&quot;", with: "\"")
                     .replacingOccurrences(of: "&#39;", with: "'")
    let attribute = try! NSRegularExpression(pattern: "(href=\"|src=\")([^\"]*)\"")
    let matches = attribute.matches(in: result, range: NSRange(result.startIndex..., in: result))
    for match in matches.reversed() {
      guard let range = Range(match.range(at: 2), in: result) else {
        continue
      }
      let value = String(result[range])
      result.replaceSubrange(range, with: value.removingPercentEncoding ?? value)
    }
    return String(result.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
  }

  func testSpecExamples() throws {
    let examples = try loadExamples()
    XCTAssertEqual(examples.count, 652)
    for example in examples {
      let doc = MarkdownParser.standard.parse(example.markdown)
      let actual = HtmlGenerator.standard.generate(doc: doc)
      let matches = self.normalize(actual) == self.normalize(example.html)
      if let reason = Self.knownDeviations[example.example] {
        XCTAssertFalse(matches, "example \(example.example) (\(example.section)) conforms " +
                                "now; remove it from knownDeviations (\(reason))")
      } else {
        XCTAssertTrue(matches, "example \(example.example) (\(example.section)) fails\n" +
                               "markdown: \(example.markdown.debugDescription)\n" +
                               "expected: \(example.html.debugDescription)\n" +
                               "actual:   \(actual.debugDescription)")
      }
    }
  }
}
