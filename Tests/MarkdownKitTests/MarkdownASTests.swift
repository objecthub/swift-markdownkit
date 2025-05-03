//
//  MarkdownASTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 26/02/2022.
//  Copyright © 2022 Google LLC.
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
import MarkdownKit

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

class MarkdownASTests: XCTestCase {
  
  private func generateHtml(imageBaseUrl: URL? = nil, _ str: String) -> String {
    return AttributedStringGenerator(imageBaseUrl: imageBaseUrl)
             .htmlGenerator
             .generate(doc: MarkdownParser.standard.parse(str))
             .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
  }
  
  func testSimpleNestedLists() {
    XCTAssertEqual(
      generateHtml("- Apple\n\t- Banana"),
      "<ul>\n<li>Apple\n<ul>\n<li>Banana</li>\n</ul>\n</li>\n</ul>\n<p style=\"margin: 0;\" />")
    XCTAssertEqual(
      AttributedStringGenerator(options: [.tightLists])
               .htmlGenerator
               .generate(doc: MarkdownParser.standard.parse("- Apple\n\t- Banana"))
               .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
      "<ul>\n<li>Apple\n<ul>\n<li>Banana</li>\n</ul>\n</li>\n</ul>\n<p style=\"margin: 0;\" />")
  }
  
  func testRelativeImageUrls() {
    XCTAssertEqual(generateHtml("![Test image](imagefile.png)"),
                   "<p><img src=\"imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](imagefile.png)"),
                   "<p><img src=\"file:///global/root/path/imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](/imagefile.png)"),
                   "<p><img src=\"file:///imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml("![Test image](one/imagefile.png)"),
                   "<p><img src=\"one/imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](one/imagefile.png)"),
                   "<p><img src=\"file:///global/root/path/one/imagefile.png\" alt=\"Test image\"/></p>")
    XCTAssertEqual(generateHtml(imageBaseUrl: URL(fileURLWithPath: "/global/root/path/"),
                                "![Test image](/one/imagefile.png)"),
                   "<p><img src=\"file:///one/imagefile.png\" alt=\"Test image\"/></p>")
  }
}

#endif
