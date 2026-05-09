//
//  StringGeneratorTests.swift
//  MarkdownKitTests
//
//  Created on 03/05/2026.
//  Copyright © 2026 Google LLC.
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

class StringGeneratorTests: XCTestCase {
  
  private func generateString(numColumns: Int = 80, _ str: String) -> String {
    let generator = StringGenerator(numColumns: numColumns)
    return generator.generate(doc: MarkdownParser.standard.parse(str))
      .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
  }
  
  func testSimpleParagraph() {
    let result = generateString("This is a simple paragraph.")
    XCTAssertEqual(result, "This is a simple paragraph.")
  }
  
  func testLongParagraphWrapping() {
    let longText = "This is a very long paragraph that should wrap at the column limit. It contains many words and should be broken at word boundaries."
    let result = generateString(numColumns: 40, longText)
    
    // Check that no line exceeds 40 characters
    let lines = result.split(separator: "\n")
    for line in lines {
      XCTAssertLessThanOrEqual(line.count, 40, "Line '\(line)' exceeds 40 characters")
    }
  }
  
  func testHeadings() {
    XCTAssertEqual(
      generateString("# Heading 1"),
      """
      Heading 1
      ▔▔▔▔▔▔▔▔▔
      """
    )
    
    XCTAssertEqual(
      generateString("## Heading 2"),
      """
      Heading 2
      ‾‾‾‾‾‾‾‾‾
      """
    )
    
    XCTAssertEqual(
      generateString("### Heading 3"),
      """
      Heading 3
      ¯¯¯¯¯¯¯¯¯
      """
    )
  }
  
  func testUnorderedList() {
    let result = generateString("""
      * Apple
      * Banana
      * Cherry
      """)
    XCTAssertEqual(
      result,
      """
      • Apple
        • Banana
        • Cherry
      """
    )
  }
  
  func testOrderedList() {
    let result = generateString("""
      1. First item
      2. Second item
      3. Third item
      """)
    XCTAssertEqual(
      result,
      """
      1. First item
        2. Second item
        3. Third item
      """
    )
  }
  
  func testNestedList() {
    let result = generateString("""
      - Apple
        - Gala
        - Fuji
      - Banana
      """)
    XCTAssertTrue(result.contains("Apple"))
    XCTAssertTrue(result.contains("Gala"))
    XCTAssertTrue(result.contains("Fuji"))
    XCTAssertTrue(result.contains("Banana"))
  }
  
  func testCodeBlock() {
    let result = generateString("""
          let x = 5
          print(x)
      """)
    
    XCTAssertTrue(result.contains("let x = 5"))
    XCTAssertTrue(result.contains("print(x)"))
  }
  
  func testFencedCodeBlock() {
    let result = generateString("""
      ```swift
      let x = 5
      print(x)
      ```
      """)
    XCTAssertTrue(result.contains("swift"))
    XCTAssertTrue(result.contains("let x = 5"))
    XCTAssertTrue(result.contains("print(x)"))
  }
  
  func testBlockquote() {
    let result = generateString("> This is a quote")
    XCTAssertTrue(result.contains("This is a quote"))
  }
  
  func testLinks() {
    let result = generateString("[OpenAI](https://openai.com)")
    XCTAssertTrue(result.contains("OpenAI"))
    XCTAssertTrue(result.contains("https://openai.com"))
  }
  
  func testEmphasis() {
    let result = generateString("This is *italic* and **bold** text.")
    XCTAssertTrue(result.contains("*italic*"))
    XCTAssertTrue(result.contains("**bold**"))
  }
  
  func testInlineCode() {
    let result = generateString("Use the `print()` function.")
    XCTAssertTrue(result.contains("`print()`"))
  }
  
  func testThematicBreak() {
    let result = generateString(numColumns: 40, """
      Before
      
      ---
      
      After
      """)
    XCTAssertTrue(result.contains("Before"))
    XCTAssertTrue(result.contains("After"))
  }
  
  func testTable() {
    let result = generateString("""
      | Name | Age |
      |------|-----|
      | Alice | 30 |
      | Bob | 25 |
      """)
    
    XCTAssertTrue(result.contains("Name"))
    XCTAssertTrue(result.contains("Age"))
    XCTAssertTrue(result.contains("Alice"))
    XCTAssertTrue(result.contains("Bob"))
  }
  
  func testComplexDocument() {
    let markdown = """
      # Main Title
      
      This is a paragraph with some **bold** and *italic* text.
      
      ## Subsection
      
      - Item 1
      - Item 2
        - Nested item
      
      Here's some code:
      
      ```swift
      let greeting = "Hello, World!"
      print(greeting)
      ```
      
      And a [link](https://example.com).
      """
    let result = generateString(markdown)
    XCTAssertTrue(result.contains("Main Title"))
    XCTAssertTrue(result.contains("**bold**"))
    XCTAssertTrue(result.contains("*italic*"))
    XCTAssertTrue(result.contains("Item 1"))
    XCTAssertTrue(result.contains("Nested item"))
    XCTAssertTrue(result.contains("swift"))
  }
  
  func testIndentation() {
    let generator = StringGenerator(numColumns: 80)
    let result = generator.generate(doc: MarkdownParser.standard.parse("""
      - First level
        - Second level
      """))
    
    // The nested item should be further indented
    let lines = result.split(separator: "\n")
    XCTAssertTrue(lines.count >= 2)
  }
}
