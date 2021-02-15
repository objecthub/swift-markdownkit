//
//  MarkdownStringTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 14/02/2021.
//  Copyright © 2021 Google LLC.
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

class MarkdownStringTests: XCTestCase {

  func testAmpersandEncoding() throws {
    XCTAssertEqual("head tail".encodingPredefinedXmlEntities(),
                   "head tail")
    XCTAssertEqual("head & tail".encodingPredefinedXmlEntities(),
                   "head &amp; tail")
    XCTAssertEqual("head && tail".encodingPredefinedXmlEntities(),
                   "head &amp;&amp; tail")
  }
  
  func testPredefinedEncodings() throws {
    XCTAssertEqual("head \"tail\"".encodingPredefinedXmlEntities(),
                   "head &quot;tail&quot;")
    XCTAssertEqual("head'n tail".encodingPredefinedXmlEntities(),
                   "head&#39;n tail")
    XCTAssertEqual("\"'x\" corresponds to (quote x)".encodingPredefinedXmlEntities(),
                   "&quot;&#39;x&quot; corresponds to (quote x)")
  }
  
  func testDecodingEntities() throws {
    XCTAssertEqual("&quot;&#39;x&quot; corresponds to (quote x)".decodingNamedCharacters(),
                   "\"'x\" corresponds to (quote x)")
    XCTAssertEqual("head&tail&nbsp;is not &quot;&fork;&quot;".decodingNamedCharacters(),
                   "head&tail\u{000A0}is not \"⋔\"")
    XCTAssertEqual("x&napprox;3.141".decodingNamedCharacters(),
                   "x≉3.141")
    XCTAssertEqual("&ntriangleleft;&ntrianglelefteq;&ntriangleright;".decodingNamedCharacters(),
                   "⋪⋬⋫")
  }
  
  static let allTests = [
    ("testAmpersandEncoding", testAmpersandEncoding),
    ("testPredefinedEncodings", testPredefinedEncodings),
    ("testDecodingEntities", testDecodingEntities),
  ]
}
