//
//  ExtendedMarkdownBlockTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 17/07/2020.
//  Copyright © 2020 Google LLC.
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

class ExtendedMarkdownBlockTests: XCTestCase, MarkdownKitFactory {
  
  private func parseBlocks(_ str: String) -> Block {
    return ExtendedMarkdownParser.standard.parse(str, blockOnly: true)
  }

  func testBlockParserCounts() {
    XCTAssertEqual(MarkdownParser.standard.documentParser(input: "").blockParsers.count, 9)
    XCTAssertEqual(ExtendedMarkdownParser.standard.documentParser(input: "").blockParsers.count, 10)
  }
  
  func testMinimalTable() {
    XCTAssertEqual(parseBlocks("|column\n|-"), document(table(["column"],[.undefined])))
    XCTAssertEqual(parseBlocks("|colA|colB\n|-|-"), document(table(["colA", "colB"],
                                                                   [.undefined, .undefined])))
    XCTAssertEqual(parseBlocks("colA|colB\n|-|-"), document(table(["colA", "colB"],
                                                                  [.undefined, .undefined])))
    XCTAssertEqual(parseBlocks("colA|colB\n-|-"), document(table(["colA", "colB"],
                                                                 [.undefined, .undefined])))
    XCTAssertEqual(parseBlocks("colA|colB|\n-|-|\n"), document(table(["colA", "colB"],
                                                                     [.undefined, .undefined])))
  }
  
  func testComplexTable() {
    XCTAssertEqual(parseBlocks(" | col A | col B | col C | \n" +
                               "-| :--- |----: |   \n" +
                               "  this is|very cool   | right?  \n" +
                               "| and *now*|__with__| markup|\n" +
                               "||||\n"),
                   document(table(["col A", "col B", "col C"],
                                  [.undefined, .left, .right],
                                  ["this is", "very cool", "right?"],
                                  ["and *now*", "__with__", "markup"],
                                  ["", "", ""])))
  }
  
  func testComplexWrappedTable() {
    XCTAssertEqual(parseBlocks(" | col A | col B | col C | \n" +
                               "-| :--- |----: |   \n" +
                               "  this is \\\n" +
                               " a very long line |very \\| cool   | right?  \n" +
                               "| and *now*|__with__| markup|\n" +
                               "||||\n"),
                   document(table(["col A", "col B", "col C"],
                                  [.undefined, .left, .right],
                                  ["this is $a very long line", "very \\| cool", "right?"],
                                  ["and *now*", "__with__", "markup"],
                                  ["", "", ""])))
    XCTAssertEqual(parseBlocks(" | col A | col B | col C | \n" +
                               "-| :--- |:---: |   \n" +
                               "  this is \\\n" +
                               " a very long line |and here \\\n" +
                               "is another \\\n" +
                               "     one| right?  \n" +
                               "       | and *now*|__with__\n" +
                               "||||foo|bar|\n"),
                   document(table(["col A", "col B", "col C"],
                                  [.undefined, .left, .center],
                                  ["this is $a very long line",
                                   "and here $is another $one",
                                   "right?"],
                                  ["and *now*", "__with__", nil],
                                  ["", "", ""])))
  }
  
  func testTableTermination() {
    XCTAssertEqual(parseBlocks("This is a paragraph\n\n" +
                               " | col A | col B |\n" +
                               " | -     | -:    |\n" +
                               " | 1     | 2     |\n" +
                               " | 3\n" +
                               "And this is another paragraph\n"),
                   document(paragraph("This is a paragraph"),
                            table(["col A", "col B"],
                                  [.undefined, .right],
                                  ["1", "2"],
                                  ["3", nil]),
                            paragraph("And this is another paragraph")))
    XCTAssertEqual(parseBlocks("This is a paragraph\n\n" +
                               " | col A | col B |\n" +
                               " | -     | -:    |\n" +
                               " | 1     | 2     |\n" +
                               " | 3     | 4     | 5 |\n" +
                               "# Header   \n Word1 word2.\n"),
                   document(paragraph("This is a paragraph"),
                            table(["col A", "col B"],
                                  [.undefined, .right],
                                  ["1", "2"],
                                  ["3", "4"]),
                            atxHeading(1, "Header"),
                            paragraph("Word1 word2.")))
    XCTAssertEqual(parseBlocks("one\n\n     \n    \n      foo\n    bar\n" +
                               " | col A | col B |\n" +
                               " | -     | -:    |\n" +
                               " | 1     | 2     |\n" +
                               " | 3     | 4     | 5 |\n" +
                               "- item"),
                   document(paragraph("one"),
                            indentedCode("  foo\n", "bar\n"),
                            table(["col A", "col B"],
                                  [.undefined, .right],
                                  ["1", "2"],
                                  ["3", "4"]),
                            list(listItem("-", tight: true, paragraph("item")))))
  }
  
  func testNestedTable() {
    XCTAssertEqual(parseBlocks("> | col A | col B |\n" +
                               "> | -     | -:    |\n" +
                               "> | 1     | 2     |\n" +
                               "Last line"),
                   document(blockquote(table(["col A", "col B"],
                                             [.undefined, .right],
                                             ["1", "2"])),
                            paragraph("Last line")))
    XCTAssertEqual(parseBlocks("- One\n" +
                               "- Two:\n" +
                               "  | col A | col B |\n" +
                               "  | -     | -:    |\n" +
                               "  | 1     | 2     |\n" +
                               "  End table\n" +
                               "- Three"),
                   document(list(tight: false,
                                 listItem("-", paragraph("One")),
                                 listItem("-", tight: true,
                                          paragraph("Two:"),
                                          table(["col A", "col B"],
                                                [.undefined, .right],
                                                ["1", "2"]),
                                          paragraph("End table")),
                                 listItem("-", tight: true, paragraph("Three")))))
  }
}
