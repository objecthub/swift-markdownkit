//
//  ExtendedMarkdownHtmlTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 18/07/2020.
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

class ExtendedMarkdownHtmlTests: XCTestCase, MarkdownKitFactory {

  private func generateHtml(_ str: String) -> String {
    return HtmlGenerator().generate(doc: ExtendedMarkdownParser.standard.parse(str))
                          .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
  }

  func testTables() {
    XCTAssertEqual(generateHtml(" Column A | Column B\n" +
                                " -------- | --------\n"),
                   "<table><thead><tr>\n" +
                   "<th>Column A</th><th>Column B</th>\n" +
                   "</tr></thead><tbody>\n" +
                   "</tbody></table>")
    XCTAssertEqual(generateHtml(" Column A | Column B\n" +
                                " -------- | --------\n" +
                                "     1    |     2   \n"),
                   "<table><thead><tr>\n" +
                   "<th>Column A</th><th>Column B</th>\n" +
                   "</tr></thead><tbody>\n" +
                   "<tr><td>1</td><td>2</td></tr>\n" +
                   "</tbody></table>")
    XCTAssertEqual(generateHtml(" Column A |**Column B**\n" +
                                " :------- | :------:\n" +
                                "     1    |     2   \n" +
                                " reg *it* | __bold__\n"),
                   "<table><thead><tr>\n" +
                   "<th align=\"left\">Column A</th>" +
                   "<th align=\"center\"><strong>Column B</strong></th>\n" +
                   "</tr></thead><tbody>\n" +
                   "<tr><td align=\"left\">1</td><td align=\"center\">2</td></tr>\n" +
                   "<tr><td align=\"left\">reg <em>it</em></td>" +
                   "<td align=\"center\"><strong>bold</strong></td></tr>\n" +
                   "</tbody></table>")
  }
  
  func testDescriptionLists() {
    XCTAssertEqual(generateHtml("Item **name**\n" +
                                ": Description of\n" +
                                "  _item_"),
                   "<dl>\n" +
                   "<dt>Item <strong>name</strong></dt>\n" +
                   "<dd>Description of\n<em>item</em></dd>\n" +
                   "</dl>")
    XCTAssertEqual(generateHtml("Item name\n" +
                                ": Description of\n" +
                                "item\n" +
                                ": Another description\n\n" +
                                "Item two\n" +
                                ": Description two\n" +
                                ": Description three\n"),
                   "<dl>\n" +
                   "<dt>Item name</dt>\n" +
                   "<dd>Description of\nitem</dd>\n" +
                   "<dd>Another description</dd>\n" +
                   "<dt>Item two</dt>\n" +
                   "<dd>Description two</dd>\n" +
                   "<dd>Description three</dd>\n" +
                   "</dl>")
  }
  
  static let allTests = [
    ("testTables", testTables),
    ("testDescriptionLists", testDescriptionLists),
  ]
}
