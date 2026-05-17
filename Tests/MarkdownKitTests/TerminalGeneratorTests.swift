//
//  TerminalGeneratorTests.swift
//  MarkdownKitTests
//  
//  Created by Matthias Zenger on 17/05/2021.
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
import Foundation
import MarkdownKit
import CommandLineKit

class TerminalGeneratorTests: XCTestCase {
  
  private func generateTerminalText(numColumns: Int = 80, _ str: String) -> AnsiText.Normalized {
    let generator = TerminalGenerator(numColumns: numColumns)
    return generator.generate(doc: ExtendedMarkdownParser.standard.parse(str))
  }
  
  private func generateTerminalTextLines(numColumns: Int = 80, _ str: String) -> [String] {
    let result = generateTerminalText(numColumns: numColumns, str)
    return result.encodedString.split(separator: "\n").map { String($0) }
  }
  
  func testSimpleParagraph() {
    let result = generateTerminalText("This is a simple paragraph.")
    let plain = result.plainText
    XCTAssertTrue(plain.contains("This is a simple paragraph."))
  }
  
  func testLongParagraphWrapping() {
    let longText = "This is a very long paragraph that should wrap at the column limit. It contains many words and should be broken at word boundaries to ensure proper formatting."
    let lines = generateTerminalTextLines(numColumns: 40, longText)
    // Check that lines were created (wrapped)
    XCTAssertGreaterThan(lines.count, 1, "Long text should wrap into multiple lines")
    // Check that no line exceeds column limit
    for line in lines {
      XCTAssertLessThanOrEqual(line.terminalDisplayWidth, 40,
                               "Line '\(line)' exceeds 40 display width columns")
    }
  }
  
  func testHeading1() {
    let result = generateTerminalText("# Main Title")
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Main Title"))
    XCTAssertTrue(plain.contains("▔"), "H1 should have ▔ underline")
  }
  
  func testHeading2() {
    let result = generateTerminalText("## Subsection")
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Subsection"))
    XCTAssertTrue(plain.contains("‾"), "H2 should have ‾ underline")
  }
  
  func testHeading3() {
    let result = generateTerminalText("### Minor heading")
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Minor heading"))
    XCTAssertTrue(plain.contains("¯"), "H3 should have ¯ underline")
  }
  
  func testHeading4AndHigher() {
    let result = generateTerminalText("#### Fourth level")
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Fourth level"))
  }
  
  func testUnorderedListAsterisk() {
    let markdown = """
      * Apple
      * Banana
      * Cherry
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Apple"))
    XCTAssertTrue(plain.contains("Banana"))
    XCTAssertTrue(plain.contains("Cherry"))
    XCTAssertTrue(plain.contains("•"), "Unordered lists should use bullet point")
  }
  
  func testUnorderedListDash() {
    let markdown = """
      - First
      - Second
      - Third
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("First"))
    XCTAssertTrue(plain.contains("Second"))
    XCTAssertTrue(plain.contains("Third"))
    XCTAssertTrue(plain.contains("–"), "Unordered lists should use dahes")
  }
  
  func testOrderedList() {
    let markdown = """
      1. First item
      2. Second item
      3. Third item
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("First item"))
    XCTAssertTrue(plain.contains("Second item"))
    XCTAssertTrue(plain.contains("Third item"))
    XCTAssertTrue(plain.contains("1"))
    XCTAssertTrue(plain.contains("2"))
    XCTAssertTrue(plain.contains("3"))
  }
  
  func testNestedList() {
    let markdown = """
      * Fruits
        * Apples
          * Gala
          * Fuji
        * Bananas
      * Vegetables
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Fruits"))
    XCTAssertTrue(plain.contains("Apples"))
    XCTAssertTrue(plain.contains("Gala"))
    XCTAssertTrue(plain.contains("Fuji"))
    XCTAssertTrue(plain.contains("Bananas"))
    XCTAssertTrue(plain.contains("Vegetables"))
  }
  
  func testTightVsLooseLists() {
    let tight = """
      * Item 1
      * Item 2
      * Item 3
      """
    let loose = """
      * Item 1
      
      * Item 2
      
      * Item 3
      """
    let tightResult = generateTerminalTextLines(tight)
    let looseResult = generateTerminalTextLines(loose)
    // Loose lists should have more lines due to spacing
    XCTAssertGreaterThan(looseResult.count, tightResult.count,
                         "Loose lists should have more lines than tight lists")
  }
  
  func testIndentedCodeBlock() {
    let markdown = """
          let x = 5
          print(x)
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("let x = 5"))
    XCTAssertTrue(plain.contains("print(x)"))
    XCTAssertTrue(plain.contains("╌"), "Code blocks should have border characters")
  }
  
  func testFencedCodeBlock() {
    let markdown = """
      ```swift
      let name = "World"
      print("Hello, \\(name)!")
      ```
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("swift"), "Language tag should be visible")
    XCTAssertTrue(plain.contains("let name"))
    XCTAssertTrue(plain.contains("print"))
  }
  
  func testFencedCodeBlockNoLanguage() {
    let markdown = """
      ```
      function test() {
        return true;
      }
      ```
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("function test()"))
    XCTAssertTrue(plain.contains("return true"))
  }
  
  func testBlockquote() {
    let markdown = "> This is a quote from someone wise."
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("This is a quote from someone wise."))
    XCTAssertTrue(plain.contains("┃"), "Blockquotes should have vertical bar")
  }
  
  func testNestedBlockquote() {
    let markdown = """
      > Level 1
      > > Level 2
      > > > Level 3
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Level 1"))
    XCTAssertTrue(plain.contains("Level 2"))
    XCTAssertTrue(plain.contains("Level 3"))
  }
  
  func testBlockquoteMultipleParagraphs() {
    let markdown = """
      > First paragraph in quote.
      >
      > Second paragraph in quote.
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("First paragraph"))
    XCTAssertTrue(plain.contains("Second paragraph"))
  }
  
  func testEmphasis() {
    let markdown = "This is *italic* text."
    let result = generateTerminalText(markdown)
    XCTAssertTrue(result.plainText.contains("italic"))
    
    // Check that italic styling is applied
    let hasItalic = result.contains { fragment in
      fragment.character == "i" && fragment.properties.textStyles.contains(.italic)
    }
    XCTAssertTrue(hasItalic, "Italic text should have italic style applied")
  }
  
  func testStrong() {
    let markdown = "This is **bold** text."
    let result = generateTerminalText(markdown)
    XCTAssertTrue(result.plainText.contains("bold"))
    // Check that bold styling is applied
    let hasBold = result.contains { fragment in
      fragment.character == "b" && fragment.properties.textStyles.contains(.bold)
    }
    XCTAssertTrue(hasBold, "Bold text should have bold style applied")
  }
  
  func testInlineCode() {
    let markdown = "Use the `print()` function."
    let result = generateTerminalText(markdown)
    XCTAssertTrue(result.plainText.contains("print()"))
    
    // Check that code styling is applied
    let hasCodeStyle = result.contains { fragment in
      fragment.character == "p" && fragment.properties.textStyles.contains(.underline)
    }
    XCTAssertTrue(hasCodeStyle, "Inline code should have underline style")
  }
  
  func testCombinedFormatting() {
    let markdown = "Text with ***bold and italic*** formatting."
    let result = generateTerminalText(markdown)
    XCTAssertTrue(result.plainText.contains("bold and italic"))
  }
  
  func testLink() {
    let markdown = "[Google](https://google.com)"
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Google"))
    XCTAssertTrue(plain.contains("https://google.com"))
  }
  
  func testAutolink() {
    let markdown = "<https://example.com>"
    let result = generateTerminalText(markdown)
    XCTAssertTrue(result.plainText.contains("https://example.com"))
  }
  
  func testEmailAutolink() {
    let markdown = "<user@example.com>"
    let result = generateTerminalText(markdown)
    XCTAssertTrue(result.plainText.contains("user@example.com"))
  }
  
  func testLinkWithTitle() {
    let markdown = "[Link](https://example.com \"Example Site\")"
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Link"))
    XCTAssertTrue(plain.contains("https://example.com"))
  }
  
  func testImage() {
    let markdown = "![Alt text](https://example.com/image.png)"
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Image"))
    XCTAssertTrue(plain.contains("Alt text"))
    XCTAssertTrue(plain.contains("https://example.com/image.png"))
  }
  
  func testImageNoURL() {
    let markdown = "![Just alt text]()"
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Image"))
    XCTAssertTrue(plain.contains("Just alt text"))
  }
  
  func testSoftLineBreak() {
    let markdown = """
      This is a line
      that continues.
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("This is a line that continues."))
  }
  
  func testHardLineBreak() {
    let markdown = "First line  \nSecond line"
    let lines = generateTerminalTextLines(markdown)
    XCTAssertGreaterThanOrEqual(lines.count, 2, "Hard line break should create separate lines")
  }
  
  func testThematicBreak() {
    let markdown = """
      Before
      
      ---
      
      After
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Before"))
    XCTAssertTrue(plain.contains("After"))
    XCTAssertTrue(plain.contains("◠"), "Thematic break should use the ◠ character")
  }
  
  func testSimpleTable() {
    let markdown = """
      | Name | Age |
      |------|-----|
      | Alice | 30 |
      | Bob | 25 |
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Name"))
    XCTAssertTrue(plain.contains("Age"))
    XCTAssertTrue(plain.contains("Alice"))
    XCTAssertTrue(plain.contains("Bob"))
    XCTAssertTrue(plain.contains("30"))
    XCTAssertTrue(plain.contains("25"))
    XCTAssertTrue(plain.contains("│"), "Table should use vertical bar separator")
  }
  
  func testTableAlignment() {
    let markdown = """
      | Left | Center | Right |
      |:-----|:------:|------:|
      | A | B | C |
      | 1 | 2 | 3 |
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Left"))
    XCTAssertTrue(plain.contains("Center"))
    XCTAssertTrue(plain.contains("Right"))
    XCTAssertTrue(plain.contains("A"))
    XCTAssertTrue(plain.contains("B"))
    XCTAssertTrue(plain.contains("C"))
  }
  
  func testTableVaryingLengths() {
    let markdown = """
      | Short | Very Long Column Name |
      |-------|----------------------|
      | A | Small |
      | Long text here | B |
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Short"))
    XCTAssertTrue(plain.contains("Very Long Column Name"))
    XCTAssertTrue(plain.contains("Long text here"))
  }
  
  func testTableWithFormatting() {
    let markdown = """
      | Name | Description |
      |------|-------------|
      | **Bold** | *Italic* text |
      | `code` | [Link](url) |
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Bold"))
    XCTAssertTrue(plain.contains("Italic"))
    XCTAssertTrue(plain.contains("code"))
    XCTAssertTrue(plain.contains("Link"))
  }
  
  func testWideTable() {
    let markdown = """
      | Column 1 | Column 2 | Column 3 | Column 4 | Column 5 |
      |----------|----------|----------|----------|----------|
      | Very long text here | More text | Even more text | Additional content | Last column |
      """
    let result = generateTerminalText(numColumns: 80, markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Column 1"))
    // Wide tables may wrap text within cells
    XCTAssertTrue(plain.contains("Very long text") || plain.contains("Very long"))
    XCTAssertTrue(plain.contains("here"))
  }
  
  func testDefinitionList() {
    let markdown = """
      Term 1
      :   Definition 1
      
      Term 2
      :   Definition 2a
      :   Definition 2b
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Term 1"))
    XCTAssertTrue(plain.contains("Definition 1"))
    XCTAssertTrue(plain.contains("Term 2"))
    XCTAssertTrue(plain.contains("Definition 2a"))
    XCTAssertTrue(plain.contains("Definition 2b"))
    XCTAssertTrue(plain.contains("→"), "Definition lists should use → arrow")
  }
  
  func testDefinitionListFormatted() {
    let markdown = """
      **Important Term**
      :   This is a crucial definition.
      
      `Code Term`
      :   A technical definition.
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("Important Term"))
    XCTAssertTrue(plain.contains("Code Term"))
    XCTAssertTrue(plain.contains("crucial definition"))
    XCTAssertTrue(plain.contains("technical definition"))
  }
  
  func testComplexDocument() {
    let markdown = """
      # Main Title
      
      This is an introductory paragraph with **bold** and *italic* text.
      
      ## Features
      
      - Feature 1
      - Feature 2
        - Sub-feature A
        - Sub-feature B
      - Feature 3
      
      ## Code Example
      
      Here's some Swift code:
      
      ```swift
      struct Example {
          let value: String
      }
      ```
      
      ## Table
      
      | Name | Value |
      |------|-------|
      | A | 1 |
      | B | 2 |
      
      ### Conclusion
      
      Visit [our site](https://example.com) for more info.
      """
    
    let result = generateTerminalText(numColumns: 80, markdown)
    let plain = result.plainText
    
    // Verify major sections are present
    XCTAssertTrue(plain.contains("Main Title"))
    XCTAssertTrue(plain.contains("Features"))
    XCTAssertTrue(plain.contains("Code Example"))
    XCTAssertTrue(plain.contains("Table"))
    XCTAssertTrue(plain.contains("Conclusion"))
    
    // Verify content elements
    XCTAssertTrue(plain.contains("Feature 1"))
    XCTAssertTrue(plain.contains("Sub-feature A"))
    XCTAssertTrue(plain.contains("struct Example"))
    XCTAssertTrue(plain.contains("our site"))
  }
  
  func testCustomNumColumns() {
    let text = String(repeating: "word ", count: 50)
    
    let narrow = generateTerminalTextLines(numColumns: 40, text)
    let wide = generateTerminalTextLines(numColumns: 120, text)
    
    XCTAssertGreaterThan(narrow.count, wide.count,
                         "Narrower columns should produce more wrapped lines")
  }
  
  func testCustomTextProperties() {
    let customGenerator = TerminalGenerator(
      numColumns: 80,
      linkProperties: TextProperties(textColor: .red, textStyles: [.bold])
    )
    
    let doc = ExtendedMarkdownParser.standard.parse("[Link](https://example.com)")
    let result = customGenerator.generate(doc: doc)
    
    // Check that custom properties are applied
    let hasRedLink = result.contains { fragment in
      fragment.properties.textColor == .red
    }
    XCTAssertTrue(hasRedLink, "Custom link properties should be applied")
  }
  
  func testEmptyDocument() {
    let result = generateTerminalText("")
    XCTAssertTrue(result.isEmpty || result.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }
  
  func testWhitespaceDocument() {
    let result = generateTerminalText("   \n\n   \n   ")
    let trimmed = result.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
    XCTAssertTrue(trimmed.isEmpty)
  }
  
  func testVeryLongWord() {
    let longWord = String(repeating: "a", count: 100)
    let result = generateTerminalText(numColumns: 40, longWord)
    // Should handle gracefully without crashing
    XCTAssertFalse(result.isEmpty)
  }
  
  func testUnicodeEmoji() {
    let markdown = """
      # 🎉 Title with Emoji
      
      Some text with emojis: 🚀 ✅ ❌ 💡
      
      | Emoji | Meaning |
      |-------|---------|
      | ✅ | Success |
      | ❌ | Failure |
      """
    
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("🎉"))
    XCTAssertTrue(plain.contains("🚀"))
    XCTAssertTrue(plain.contains("✅"))
    XCTAssertTrue(plain.contains("❌"))
    XCTAssertTrue(plain.contains("💡"))
  }
  
  func testHTMLCharacterDecoding() {
    let markdown = "Text with &amp; &lt; &gt; &quot; entities."
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("&"))
    XCTAssertTrue(plain.contains("<"))
    XCTAssertTrue(plain.contains(">"))
    XCTAssertTrue(plain.contains("\""))
  }
  
  func testMultipleBlankLines() {
    let markdown = """
      First paragraph.
      
      
      
      Second paragraph.
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("First paragraph"))
    XCTAssertTrue(plain.contains("Second paragraph"))
  }
  
  func testContextNesting() {
    let markdown = """
      * List 1
        * Nested 1
          * Deep nested
      """
    let result = generateTerminalText(markdown)
    let plain = result.plainText
    XCTAssertTrue(plain.contains("List 1"))
    XCTAssertTrue(plain.contains("Nested 1"))
    XCTAssertTrue(plain.contains("Deep nested"))
  }
  
  func testTightContext() {
    let tightList = """
      * Item 1
      * Item 2
      """
    let looseList = """
      * Item 1
      
      * Item 2
      """
    let tightLines = generateTerminalTextLines(tightList)
    let looseLines = generateTerminalTextLines(looseList)
    // Loose list should have more lines
    XCTAssertGreaterThanOrEqual(looseLines.count, tightLines.count)
  }
  
  func testLargeDocument() {
    var markdown = "# Large Document\n\n"
    
    for i in 1...500 {
      markdown += """
        ## Section \(i)
        
        This is paragraph \(i) with some **bold** and *italic* text.
        
        * Item 1
        * Item 2
        * Item 3
        
        ```
        And this is a code block.
        ```
        
        """
    }
    let generator = TerminalGenerator(numColumns: 80)
    let doc = ExtendedMarkdownParser.standard.parse(markdown)
    // Should complete without timeout or crash
    let result = generator.generate(doc: doc)
    XCTAssertFalse(result.isEmpty)
  }
}

extension AnsiText.Normalized {
  var plainText: String {
    return self.description
  }
}
