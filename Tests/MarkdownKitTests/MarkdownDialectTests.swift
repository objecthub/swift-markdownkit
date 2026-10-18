//
//  MarkdownDialectTests.swift
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

/// Tests for `MarkdownDialect`: each dialect gives its standard parser, and the parsers differ
/// in the syntax they recognize, each one extending the previous one.
final class MarkdownDialectTests: XCTestCase {

  func testEachDialectHasItsStandardParser() {
    XCTAssertTrue(MarkdownDialect.commonMark.parser === MarkdownParser.standard)
    XCTAssertTrue(MarkdownDialect.extendedCommonMark.parser === ExtendedMarkdownParser.standard)
    XCTAssertTrue(MarkdownDialect.full.parser === FullMarkdownParser.standard)
    XCTAssertTrue(MarkdownDialect.fullMath.parser === MathMarkdownParser.standard)
  }

  func testAllDialectsAreListedInOrderOfTheirSyntax() {
    XCTAssertEqual(MarkdownDialect.allCases, [.commonMark, .extendedCommonMark, .full, .fullMath])
  }

  /// The text fragments of the first paragraph of a document.
  private func fragments(_ markdown: String, _ dialect: MarkdownDialect) -> Text? {
    guard case .document(let blocks) = dialect.parser.parse(markdown),
          case .paragraph(let text)? = blocks.first else {
      return nil
    }
    return text
  }

  func testTablesNeedAnExtendedDialect() {
    let table = "| a | b |\n|---|---|\n| c | d |\n"
    for dialect in MarkdownDialect.allCases {
      guard case .document(let blocks) = dialect.parser.parse(table) else {
        return XCTFail("document expected")
      }
      var isTable = false
      if case .table? = blocks.first {
        isTable = true
      }
      XCTAssertEqual(isTable, dialect != .commonMark, "\(dialect)")
    }
  }

  func testUnderlineNeedsTheFullDialect() {
    for dialect in MarkdownDialect.allCases {
      let text = self.fragments("a ~b~ c", dialect)
      var hasUnderline = false
      if let text {
        for fragment in text {
          if case .underline = fragment {
            hasUnderline = true
          }
        }
      }
      XCTAssertEqual(hasUnderline, dialect == .full || dialect == .fullMath, "\(dialect)")
    }
  }

  func testFormulasNeedTheMathDialect() {
    for dialect in MarkdownDialect.allCases {
      let text = self.fragments("a $b$ c", dialect)
      var hasFormula = false
      if let text {
        for fragment in text {
          if case .custom(let custom) = fragment, custom is MathFragment {
            hasFormula = true
          }
        }
      }
      XCTAssertEqual(hasFormula, dialect == .fullMath, "\(dialect)")
    }
  }
}
