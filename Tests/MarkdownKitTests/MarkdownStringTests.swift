//
//  MarkdownStringTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 14/02/2021.
//  Copyright © 2021 Matthias Zenger. All rights reserved.
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
}
