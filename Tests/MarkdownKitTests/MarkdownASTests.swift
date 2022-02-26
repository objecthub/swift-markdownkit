//
//  MarkdownASTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 26/02/2022.
//  Copyright © 2022 Matthias Zenger. All rights reserved.
//

import XCTest
import MarkdownKit

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

class MarkdownASTests: XCTestCase {
  
  private func generateHtml(imageBaseUrl: URL? = nil, _ str: String) -> String {
    return AttributedStringGenerator(imageBaseUrl: imageBaseUrl)
             .htmlGenerator
             .generate(doc: MarkdownParser.standard.parse(str))
             .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
  }
  
  func testRelativeImageUrls() {
    XCTAssertEqual(generateHtml("![Test image](imagefile.png)"),
                   "<p><img src=\"imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](imagefile.png)"),
                   "<p><img src=\"/global/root/path/imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](/imagefile.png)"),
                   "<p><img src=\"/imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml("![Test image](one/imagefile.png)"),
                   "<p><img src=\"one/imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](one/imagefile.png)"),
                   "<p><img src=\"/global/root/path/one/imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](/one/imagefile.png)"),
                   "<p><img src=\"/one/imagefile.png\" alt=\"Test image\"/></p>")
    
  }
}

#endif
