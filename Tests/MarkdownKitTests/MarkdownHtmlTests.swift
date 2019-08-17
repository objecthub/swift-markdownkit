//
//  MarkdownHtmlTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 20/07/2019.
//  Copyright © 2019 Google LLC.
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

class MarkdownHtmlTests: XCTestCase, MarkdownKitFactory {

  private func generateHtml(_ str: String) -> String {
    return HtmlGenerator().generate(doc: MarkdownParser.standard.parse(str))
                          .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
  }

  func testBasics() {
    XCTAssertEqual(generateHtml("one *two*\n**three** four"),
                   "<p>one <em>two</em>\n<strong>three</strong> four</p>")
    XCTAssertEqual(generateHtml("one _two_ __three__\n***\nfour"),
                   "<p>one <em>two</em> <strong>three</strong></p>\n<hr />\n<p>four</p>")
    XCTAssertEqual(generateHtml("# Top\n## Below\nAnd this is the text."),
                   "<h1>Top</h1>\n<h2>Below</h2>\n<p>And this is the text.</p>")
    XCTAssertEqual(generateHtml("### Sub *and* heading ###\nAnd this is the text."),
                   "<h3>Sub <em>and</em> heading</h3>\n<p>And this is the text.</p>")
  }

  func testLists() {
    XCTAssertEqual(generateHtml("""
                       - One
                       - Two
                       - Three
                     """),
                   "<ul>\n<li>One</li>\n<li>Two</li>\n<li>Three</li>\n</ul>")
    XCTAssertEqual(generateHtml("""
                       - One

                         Two
                       - Three
                       - Four
                     """),
                   "<ul>\n<li><p>One</p>\n<p>Two</p>\n</li>\n<li><p>Three</p>\n</li>\n<li>" +
                   "<p>Four</p>\n</li>\n</ul>")
  }
}
