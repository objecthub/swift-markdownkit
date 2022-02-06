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
    XCTAssertEqual(generateHtml("expressive & simple &amp; elegant"),
                   "<p>expressive &amp; simple &amp; elegant</p>")
    XCTAssertEqual(generateHtml("This is `a &amp; b`"),
                   "<p>This is <code>a &amp;amp; b</code></p>")
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
  
  func testNestedLists() {
    XCTAssertEqual(generateHtml("""
        - foo
        - bar
            * one
            * two
            * three
        - goo
      """),
      "<ul>\n<li><p>foo</p>\n</li>\n<li><p>bar</p>\n<ul>\n<li>one</li>\n<li>two</li>\n" +
      "<li>three</li>\n</ul>\n</li>\n<li><p>goo</p>\n</li>\n</ul>")
  }
  
  func testImageLinks() {
    XCTAssertEqual(generateHtml("""
        This is an inline image: ![example *image*](folder/image.jpg "image title").
      """),
      "<p>This is an inline image: <img src=\"folder/image.jpg\" alt=\"example image\"" +
      " title=\"image title\"/>.</p>")
    XCTAssertEqual(generateHtml("""
        This is an image block:

        ![example *image*](folder/image.jpg)
      """),
      "<p>This is an image block:</p>\n" +
      "<p><img src=\"folder/image.jpg\" alt=\"example image\"/></p>")
  }
  
  func testAutolinks() {
    XCTAssertEqual(generateHtml("Test <www.example.com> test"),
                   "<p>Test &lt;www.example.com&gt; test</p>")
    XCTAssertEqual(generateHtml("Test <http://www.example.com> test"),
                   "<p>Test <a href=\"http://www.example.com\">http://www.example.com</a> test</p>")
  }
  
  func testCodeBlocks() {
    XCTAssertEqual(generateHtml("Test\n\n```\nThis should <b>not be bold</b>.\n```\n"),
                   "<p>Test</p>\n<pre><code>This should &lt;b&gt;not be bold&lt;/b&gt;.\n" +
                   "</code></pre>")
  }
  
  static let allTests = [
    ("testBasics", testBasics),
    ("testLists", testLists),
    ("testNestedLists", testNestedLists),
    ("testImageLinks", testImageLinks),
    ("testAutolinks", testAutolinks),
  ]
}
