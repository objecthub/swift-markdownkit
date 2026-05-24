//
//  SyntaxHighlighterTests.swift
//  MarkdownKitTests
//
//  Created on 24/05/2026.
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
@testable import MarkdownKit

class SyntaxHighlighterTests: XCTestCase {
  
  var highlighter: SyntaxHighlighter!
  
  override func setUp() {
    super.setUp()
    highlighter = SyntaxHighlighter.proxy
    XCTAssertNotNil(highlighter, "SyntaxHighlighter proxy should be initialized")
  }
  
  func testParseCSSFontFamilies_SingleUnquotedFamily() {
    let result = highlighter.parseCSSFontFamilies("Arial")
    XCTAssertEqual(result, ["Arial"])
  }
  
  func testParseCSSFontFamilies_MultipleUnquotedFamilies() {
    let result = highlighter.parseCSSFontFamilies("Arial, Helvetica, sans-serif")
    XCTAssertEqual(result, ["Arial", "Helvetica", "sans-serif"])
  }
  
  func testParseCSSFontFamilies_SingleQuotedFamily() {
    let result = highlighter.parseCSSFontFamilies("'Times New Roman'")
    XCTAssertEqual(result, ["Times New Roman"])
  }
  
  func testParseCSSFontFamilies_DoubleQuotedFamily() {
    let result = highlighter.parseCSSFontFamilies("\"Helvetica Neue\"")
    XCTAssertEqual(result, ["Helvetica Neue"])
  }
  
  func testParseCSSFontFamilies_MixedQuotedAndUnquoted() {
    let result = highlighter.parseCSSFontFamilies("Georgia, 'Times New Roman', serif")
    XCTAssertEqual(result, ["Georgia", "Times New Roman", "serif"])
  }
  
  func testParseCSSFontFamilies_MixedDoubleQuotedAndUnquoted() {
    let result = highlighter.parseCSSFontFamilies("Arial, \"Helvetica Neue\", sans-serif")
    XCTAssertEqual(result, ["Arial", "Helvetica Neue", "sans-serif"])
  }
  
  func testParseCSSFontFamilies_WithExtraWhitespace() {
    let result = highlighter.parseCSSFontFamilies("  Arial  ,  Helvetica  ,  sans-serif  ")
    XCTAssertEqual(result, ["Arial", "Helvetica", "sans-serif"])
  }
  
  func testParseCSSFontFamilies_QuotedWithExtraWhitespace() {
    let result = highlighter.parseCSSFontFamilies("  'Times New Roman'  ,  Georgia  ")
    XCTAssertEqual(result, ["Times New Roman", "Georgia"])
  }
  
  func testParseCSSFontFamilies_EscapedQuotesInSingleQuoted() {
    let result = highlighter.parseCSSFontFamilies("'O\\'Brien\\'s Font', Arial")
    XCTAssertEqual(result, ["O'Brien's Font", "Arial"])
  }
  
  func testParseCSSFontFamilies_EscapedQuotesInDoubleQuoted() {
    let result = highlighter.parseCSSFontFamilies("\"Font \\\"Special\\\"\", Georgia")
    XCTAssertEqual(result, ["Font \"Special\"", "Georgia"])
  }
  
  func testParseCSSFontFamilies_EmptyString() {
    let result = highlighter.parseCSSFontFamilies("")
    XCTAssertEqual(result, [])
  }
  
  func testParseCSSFontFamilies_OnlyWhitespace() {
    let result = highlighter.parseCSSFontFamilies("   ")
    XCTAssertEqual(result, [])
  }
  
  func testParseCSSFontFamilies_OnlyCommas() {
    let result = highlighter.parseCSSFontFamilies(",,,,")
    XCTAssertEqual(result, [])
  }
  
  func testParseCSSFontFamilies_TrailingComma() {
    let result = highlighter.parseCSSFontFamilies("Arial, Helvetica,")
    XCTAssertEqual(result, ["Arial", "Helvetica"])
  }
  
  func testParseCSSFontFamilies_LeadingComma() {
    let result = highlighter.parseCSSFontFamilies(",Arial, Helvetica")
    XCTAssertEqual(result, ["Arial", "Helvetica"])
  }
  
  func testParseCSSFontFamilies_MultipleConsecutiveCommas() {
    let result = highlighter.parseCSSFontFamilies("Arial,,,Helvetica")
    XCTAssertEqual(result, ["Arial", "Helvetica"])
  }
  
  func testParseCSSFontFamilies_ComplexRealWorldExample() {
    let result = highlighter.parseCSSFontFamilies("'SF Mono', Monaco, 'Courier New', monospace")
    XCTAssertEqual(result, ["SF Mono", "Monaco", "Courier New", "monospace"])
  }
  
  func testParseCSSFontFamilies_MonospacedSystemFont() {
    let result = highlighter.parseCSSFontFamilies("ui-monospace, 'Cascadia Code', 'Source Code Pro', Menlo, Consolas, monospace")
    XCTAssertEqual(result, ["ui-monospace", "Cascadia Code", "Source Code Pro", "Menlo", "Consolas", "monospace"])
  }
  
  func testParseCSSFontFamilies_UnclosedQuote() {
    // Should handle gracefully - consumes until end of string
    let result = highlighter.parseCSSFontFamilies("'Unclosed Font, Arial")
    // Since quote never closes, everything after opening quote becomes one family name
    XCTAssertEqual(result, ["Unclosed Font, Arial"])
  }
  
  func testParseCSSFontFamilies_EmptyQuotes() {
    let result = highlighter.parseCSSFontFamilies("'', Arial")
    XCTAssertEqual(result, ["Arial"])
  }
  
  func testParseCSSFontFamilies_MixedEmptyAndValidFamilies() {
    let result = highlighter.parseCSSFontFamilies(", , Arial, , Helvetica, ,")
    XCTAssertEqual(result, ["Arial", "Helvetica"])
  }
  
  func testResolveFont_SystemFontFallback() {
    // Test with a generic fallback that should exist on all systems
    let result = highlighter.resolveFont("monospace", size: 14.0)
    XCTAssertNotNil(result, "Should resolve a font for generic monospace")
    if let (_, font) = result {
      XCTAssertEqual(font.pointSize, 14.0, accuracy: 0.01)
    }
  }
  
  func testResolveFont_SpecificSize() {
    let result = highlighter.resolveFont("monospace", size: 20.0)
    XCTAssertNotNil(result, "Should resolve a font")
    if let (_, font) = result {
      XCTAssertEqual(font.pointSize, 20.0, accuracy: 0.01)
    }
  }
  
  func testResolveFont_FallbackChain() {
    // Test with fonts that might not exist, ending with a generic fallback
    let result = highlighter.resolveFont("NonExistentFont, AnotherNonExistentFont, monospace", size: 14.0)
    XCTAssertNotNil(result, "Should fall back to monospace")
  }
  
  func testResolveFont_QuotedFontNames() {
    // Test with quoted font names in the chain
    let result = highlighter.resolveFont("'NonExistent Font', \"Another Fake Font\", monospace", size: 14.0)
    XCTAssertNotNil(result, "Should parse quoted names and fall back to monospace")
  }
  
  #if canImport(AppKit)
  func testResolveFont_CommonMacFonts() {
    // Test with fonts commonly available on macOS
    let fontNames = ["Monaco", "Menlo", "Courier"]
    for fontName in fontNames {
      let result = highlighter.resolveFont(fontName, size: 12.0)
      // At least one of these should be available on macOS
      if result != nil {
        let (family, font) = result!
        XCTAssertFalse(family.isEmpty)
        XCTAssertEqual(font.pointSize, 12.0, accuracy: 0.01)
        return // Success
      }
    }
  }
  
  func testResolveFont_SFMono() {
    // SF Mono is available on modern macOS
    let result = highlighter.resolveFont("'SF Mono', Monaco, monospace", size: 14.0)
    XCTAssertNotNil(result)
    if let (family, font) = result {
      XCTAssertFalse(family.isEmpty)
      XCTAssertEqual(font.pointSize, 14.0, accuracy: 0.01)
    }
  }
  #endif
  
  #if canImport(UIKit)
  func testResolveFont_CommonIOSFonts() {
    // Test with fonts commonly available on iOS
    let fontNames = ["Courier", "Courier New", "Menlo"]
    
    for fontName in fontNames {
      let result = highlighter.resolveFont(fontName, size: 12.0)
      // At least one of these should be available on iOS
      if result != nil {
        let (family, font) = result!
        XCTAssertFalse(family.isEmpty)
        XCTAssertEqual(font.pointSize, 12.0, accuracy: 0.01)
        return // Success
      }
    }
  }
  #endif
  
  func testResolveFont_CaseInsensitiveMatching() {
    // Font family matching should be case-insensitive
    let result1 = highlighter.resolveFont("MONOSPACE", size: 14.0)
    let result2 = highlighter.resolveFont("monospace", size: 14.0)
    let result3 = highlighter.resolveFont("MoNoSpAcE", size: 14.0)
    XCTAssertNotNil(result1)
    XCTAssertNotNil(result2)
    XCTAssertNotNil(result3)
  }
  
  func testResolveFont_EmptyString() {
    let result = highlighter.resolveFont("", size: 14.0)
    XCTAssertNil(result, "Should return nil for empty font string")
  }
  
  func testResolveFont_OnlyNonExistentFonts() {
    let result = highlighter.resolveFont("FakeFont1, FakeFont2, FakeFont3", size: 14.0)
    XCTAssertNil(result, "Should return nil when no fonts in the list exist")
  }
  
  func testResolveFont_WithWhitespace() {
    let result = highlighter.resolveFont("  monospace  ", size: 14.0)
    XCTAssertNotNil(result, "Should handle whitespace around font names")
  }
  
  func testResolveFont_ComplexCSSFontStack() {
    // Test a realistic CSS font stack
    let result = highlighter.resolveFont(
      "ui-monospace, 'SF Mono', 'Cascadia Code', 'Source Code Pro', Menlo, Consolas, 'Courier New', monospace",
      size: 13.0
    )
    XCTAssertNotNil(result, "Should resolve at least one font from realistic font stack")
    if let (family, font) = result {
      XCTAssertFalse(family.isEmpty)
      XCTAssertEqual(font.pointSize, 13.0, accuracy: 0.01)
    }
  }
  
  func testParseCSSFontFamilies_IntegrationWithResolveFont() {
    let cssString = "'SF Mono', Monaco, 'Courier New', monospace"
    let families = highlighter.parseCSSFontFamilies(cssString)
    XCTAssertEqual(families.count, 4)
    XCTAssertEqual(families, ["SF Mono", "Monaco", "Courier New", "monospace"])
    // Now verify that resolveFont can use this parsed result
    let result = highlighter.resolveFont(cssString, size: 14.0)
    XCTAssertNotNil(result, "Should resolve at least one font from the parsed families")
  }
  
  func testResolveFont_ReturnsFirstAvailableFont() {
    // When multiple fonts are available, it should return the first one
    let result = highlighter.resolveFont("monospace, serif, sans-serif", size: 14.0)
    XCTAssertNotNil(result)
    if let (family, _) = result {
      // Should match "monospace" (or its system equivalent)
      XCTAssertFalse(family.isEmpty)
    }
  }
  
  // MARK: - isValidCSS Tests
  
  func testIsValidCSS_EmptyString() {
    let result = highlighter.isValidCSS("")
    XCTAssertTrue(result, "Empty string should be considered valid CSS")
  }
  
  func testIsValidCSS_WhitespaceOnly() {
    let result = highlighter.isValidCSS("   \n  \t  ")
    XCTAssertTrue(result, "Whitespace-only string should be considered valid CSS")
  }
  
  func testIsValidCSS_SimpleRule() {
    let css = ".hljs { color: #333; }"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Simple CSS rule should be valid")
  }
  
  func testIsValidCSS_MultipleRules() {
    let css = """
    .hljs { color: #333; background: #fff; }
    .hljs-keyword { font-weight: bold; }
    .hljs-string { color: green; }
    """
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Multiple CSS rules should be valid")
  }
  
  func testIsValidCSS_RuleWithMultipleProperties() {
    let css = """
    .hljs-comment {
      color: #999;
      font-style: italic;
      opacity: 0.8;
    }
    """
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Rule with multiple properties should be valid")
  }
  
  func testIsValidCSS_EmptyRule() {
    let css = ".hljs {}"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Empty rule should be valid")
  }
  
  func testIsValidCSS_RuleWithoutSemicolon() {
    let css = ".hljs { color: #333 }"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Rule without trailing semicolon should be valid")
  }
  
  func testIsValidCSS_AtRule() {
    let css = "@media screen { .hljs { color: black; } }"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "@media rule should be valid")
  }
  
  func testIsValidCSS_KeyframesRule() {
    let css = """
    @keyframes fade {
      0% { opacity: 0; }
      100% { opacity: 1; }
    }
    """
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "@keyframes rule should be valid")
  }
  
  func testIsValidCSS_ComplexSelector() {
    let css = ".hljs .hljs-keyword.bold, .hljs-strong { font-weight: bold; }"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Complex selector should be valid")
  }
  
  func testIsValidCSS_PseudoClass() {
    let css = ".hljs-link:hover { text-decoration: underline; }"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Pseudo-class selector should be valid")
  }
  
  func testIsValidCSS_NestedRules() {
    let css = """
    @media (prefers-color-scheme: dark) {
      .hljs { background: #1e1e1e; }
      .hljs-keyword { color: #569cd6; }
    }
    """
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Nested rules should be valid")
  }
  
  func testIsValidCSS_RealWorldExample() {
    let css = """
    .hljs {
      display: block;
      overflow-x: auto;
      padding: 0.5em;
      color: #333;
      background: #f8f8f8;
    }
    
    .hljs-comment,
    .hljs-quote {
      color: #998;
      font-style: italic;
    }
    
    .hljs-keyword,
    .hljs-selector-tag,
    .hljs-subst {
      color: #333;
      font-weight: bold;
    }
    """
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Real-world CSS example should be valid")
  }
  
  // MARK: - isValidCSS Invalid Cases
  
  func testIsValidCSS_UnbalancedBracesExtra() {
    let css = ".hljs { color: red; } }"
    let result = highlighter.isValidCSS(css)
    XCTAssertFalse(result, "CSS with extra closing brace should be invalid")
  }
  
  func testIsValidCSS_UnbalancedBracesMissing() {
    let css = ".hljs { color: red;"
    let result = highlighter.isValidCSS(css)
    XCTAssertFalse(result, "CSS with missing closing brace should be invalid")
  }
  
  func testIsValidCSS_HTMLTag() {
    let css = "<div>Not CSS</div>"
    let result = highlighter.isValidCSS(css)
    XCTAssertFalse(result, "HTML tags should make CSS invalid")
  }
  
  func testIsValidCSS_AngleBracketsInContent() {
    let css = ".hljs { content: '<div>'; }"
    let result = highlighter.isValidCSS(css)
    XCTAssertFalse(result, "Angle brackets in content should make CSS invalid")
  }
  
  func testIsValidCSS_NoRules() {
    let css = "This is just text without any CSS rules"
    let result = highlighter.isValidCSS(css)
    XCTAssertFalse(result, "Text without CSS rules should be invalid")
  }
  
  func testIsValidCSS_OnlySelector() {
    let css = ".hljs"
    let result = highlighter.isValidCSS(css)
    XCTAssertFalse(result, "Selector without rule block should be invalid")
  }
  
  func testIsValidCSS_MalformedPropertyNoColon() {
    let css = ".hljs { color red; }"
    let result = highlighter.isValidCSS(css)
    XCTAssertFalse(result, "Property without colon should be invalid")
  }
  
  func testIsValidCSS_OnlyBraces() {
    let css = "{ }"
    let result = highlighter.isValidCSS(css)
    XCTAssertFalse(result, "Only braces without selector should be invalid")
  }
  
  func testIsValidCSS_JavaScriptCode() {
    let css = "function test() { return true; }"
    let result = highlighter.isValidCSS(css)
    XCTAssertFalse(result, "JavaScript code should be invalid CSS")
  }
  
  // MARK: - isValidCSS Edge Cases
  
  func testIsValidCSS_CommentOnly() {
    let css = "/* This is a comment */"
    let result = highlighter.isValidCSS(css)
    // Comments without rules - implementation dependent
    // The function checks for at least one rule pattern
    XCTAssertFalse(result, "Comment-only CSS should be invalid (no actual rules)")
  }
  
  func testIsValidCSS_RuleWithComment() {
    let css = """
    /* Header styles */
    .hljs { color: #333; }
    """
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "CSS with comments should be valid")
  }
  
  func testIsValidCSS_ImportStatement() {
    let css = "@import url('other.css');"
    let result = highlighter.isValidCSS(css)
    // @import without a rule block
    XCTAssertFalse(result, "@import alone should be invalid (no rule pattern)")
  }
  
  func testIsValidCSS_ImportWithRule() {
    let css = """
    @import url('other.css');
    .hljs { color: red; }
    """
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "@import with rules should be valid")
  }
  
  func testIsValidCSS_VeryLongRule() {
    var properties = ""
    for i in 1...100 {
      properties += "property\(i): value\(i); "
    }
    let css = ".hljs { \(properties) }"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Very long rule should be valid")
  }
  
  func testIsValidCSS_UnicodeCharacters() {
    let css = ".hljs-中文 { color: red; }"
    let result = highlighter.isValidCSS(css)
    // CSS allows unicode in selectors
    XCTAssertTrue(result, "Unicode characters in selector should be valid")
  }
  
  func testIsValidCSS_EscapedCharacters() {
    let css = ".hljs\\:hover { color: blue; }"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Escaped characters should be valid")
  }
  
  func testIsValidCSS_MultilineValue() {
    let css = """
    .hljs {
      content: "Line 1
      Line 2";
    }
    """
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "Multiline value should be valid")
  }
  
  func testIsValidCSS_URLValue() {
    let css = ".hljs { background: url(data:image/png;base64,ABC123); }"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "URL values should be valid")
  }
  
  func testIsValidCSS_CalcFunction() {
    let css = ".hljs { width: calc(100% - 20px); }"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "calc() function should be valid")
  }
  
  func testIsValidCSS_VarFunction() {
    let css = ".hljs { color: var(--main-color); }"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "var() function should be valid")
  }
  
  func testIsValidCSS_ImportantFlag() {
    let css = ".hljs { color: red !important; }"
    let result = highlighter.isValidCSS(css)
    XCTAssertTrue(result, "!important flag should be valid")
  }
  
  static let allTests = [
    // parseCSSFontFamilies tests
    ("testParseCSSFontFamilies_SingleUnquotedFamily", testParseCSSFontFamilies_SingleUnquotedFamily),
    ("testParseCSSFontFamilies_MultipleUnquotedFamilies", testParseCSSFontFamilies_MultipleUnquotedFamilies),
    ("testParseCSSFontFamilies_SingleQuotedFamily", testParseCSSFontFamilies_SingleQuotedFamily),
    ("testParseCSSFontFamilies_DoubleQuotedFamily", testParseCSSFontFamilies_DoubleQuotedFamily),
    ("testParseCSSFontFamilies_MixedQuotedAndUnquoted", testParseCSSFontFamilies_MixedQuotedAndUnquoted),
    ("testParseCSSFontFamilies_MixedDoubleQuotedAndUnquoted", testParseCSSFontFamilies_MixedDoubleQuotedAndUnquoted),
    ("testParseCSSFontFamilies_WithExtraWhitespace", testParseCSSFontFamilies_WithExtraWhitespace),
    ("testParseCSSFontFamilies_QuotedWithExtraWhitespace", testParseCSSFontFamilies_QuotedWithExtraWhitespace),
    ("testParseCSSFontFamilies_EscapedQuotesInSingleQuoted", testParseCSSFontFamilies_EscapedQuotesInSingleQuoted),
    ("testParseCSSFontFamilies_EscapedQuotesInDoubleQuoted", testParseCSSFontFamilies_EscapedQuotesInDoubleQuoted),
    ("testParseCSSFontFamilies_EmptyString", testParseCSSFontFamilies_EmptyString),
    ("testParseCSSFontFamilies_OnlyWhitespace", testParseCSSFontFamilies_OnlyWhitespace),
    ("testParseCSSFontFamilies_OnlyCommas", testParseCSSFontFamilies_OnlyCommas),
    ("testParseCSSFontFamilies_TrailingComma", testParseCSSFontFamilies_TrailingComma),
    ("testParseCSSFontFamilies_LeadingComma", testParseCSSFontFamilies_LeadingComma),
    ("testParseCSSFontFamilies_MultipleConsecutiveCommas", testParseCSSFontFamilies_MultipleConsecutiveCommas),
    ("testParseCSSFontFamilies_ComplexRealWorldExample", testParseCSSFontFamilies_ComplexRealWorldExample),
    ("testParseCSSFontFamilies_MonospacedSystemFont", testParseCSSFontFamilies_MonospacedSystemFont),
    ("testParseCSSFontFamilies_UnclosedQuote", testParseCSSFontFamilies_UnclosedQuote),
    ("testParseCSSFontFamilies_EmptyQuotes", testParseCSSFontFamilies_EmptyQuotes),
    ("testParseCSSFontFamilies_MixedEmptyAndValidFamilies", testParseCSSFontFamilies_MixedEmptyAndValidFamilies),
    // resolveFont tests
    ("testResolveFont_SystemFontFallback", testResolveFont_SystemFontFallback),
    ("testResolveFont_SpecificSize", testResolveFont_SpecificSize),
    ("testResolveFont_FallbackChain", testResolveFont_FallbackChain),
    ("testResolveFont_QuotedFontNames", testResolveFont_QuotedFontNames),
    ("testResolveFont_CaseInsensitiveMatching", testResolveFont_CaseInsensitiveMatching),
    ("testResolveFont_EmptyString", testResolveFont_EmptyString),
    ("testResolveFont_OnlyNonExistentFonts", testResolveFont_OnlyNonExistentFonts),
    ("testResolveFont_WithWhitespace", testResolveFont_WithWhitespace),
    ("testResolveFont_ComplexCSSFontStack", testResolveFont_ComplexCSSFontStack),
    // Integration tests
    ("testParseCSSFontFamilies_IntegrationWithResolveFont", testParseCSSFontFamilies_IntegrationWithResolveFont),
    ("testResolveFont_ReturnsFirstAvailableFont", testResolveFont_ReturnsFirstAvailableFont),
    // isValidCSS tests - Valid cases
    ("testIsValidCSS_EmptyString", testIsValidCSS_EmptyString),
    ("testIsValidCSS_WhitespaceOnly", testIsValidCSS_WhitespaceOnly),
    ("testIsValidCSS_SimpleRule", testIsValidCSS_SimpleRule),
    ("testIsValidCSS_MultipleRules", testIsValidCSS_MultipleRules),
    ("testIsValidCSS_RuleWithMultipleProperties", testIsValidCSS_RuleWithMultipleProperties),
    ("testIsValidCSS_EmptyRule", testIsValidCSS_EmptyRule),
    ("testIsValidCSS_RuleWithoutSemicolon", testIsValidCSS_RuleWithoutSemicolon),
    ("testIsValidCSS_AtRule", testIsValidCSS_AtRule),
    ("testIsValidCSS_KeyframesRule", testIsValidCSS_KeyframesRule),
    ("testIsValidCSS_ComplexSelector", testIsValidCSS_ComplexSelector),
    ("testIsValidCSS_PseudoClass", testIsValidCSS_PseudoClass),
    ("testIsValidCSS_NestedRules", testIsValidCSS_NestedRules),
    ("testIsValidCSS_RealWorldExample", testIsValidCSS_RealWorldExample),
    // isValidCSS tests - Invalid cases
    ("testIsValidCSS_UnbalancedBracesExtra", testIsValidCSS_UnbalancedBracesExtra),
    ("testIsValidCSS_UnbalancedBracesMissing", testIsValidCSS_UnbalancedBracesMissing),
    ("testIsValidCSS_HTMLTag", testIsValidCSS_HTMLTag),
    ("testIsValidCSS_AngleBracketsInContent", testIsValidCSS_AngleBracketsInContent),
    ("testIsValidCSS_NoRules", testIsValidCSS_NoRules),
    ("testIsValidCSS_OnlySelector", testIsValidCSS_OnlySelector),
    ("testIsValidCSS_MalformedPropertyNoColon", testIsValidCSS_MalformedPropertyNoColon),
    ("testIsValidCSS_OnlyBraces", testIsValidCSS_OnlyBraces),
    ("testIsValidCSS_JavaScriptCode", testIsValidCSS_JavaScriptCode),
    // isValidCSS tests - Edge cases
    ("testIsValidCSS_CommentOnly", testIsValidCSS_CommentOnly),
    ("testIsValidCSS_RuleWithComment", testIsValidCSS_RuleWithComment),
    ("testIsValidCSS_ImportStatement", testIsValidCSS_ImportStatement),
    ("testIsValidCSS_ImportWithRule", testIsValidCSS_ImportWithRule),
    ("testIsValidCSS_VeryLongRule", testIsValidCSS_VeryLongRule),
    ("testIsValidCSS_UnicodCharacters", testIsValidCSS_UnicodeCharacters),
    ("testIsValidCSS_EscapedCharacters", testIsValidCSS_EscapedCharacters),
    ("testIsValidCSS_MultilineValue", testIsValidCSS_MultilineValue),
    ("testIsValidCSS_URLValue", testIsValidCSS_URLValue),
    ("testIsValidCSS_CalcFunction", testIsValidCSS_CalcFunction),
    ("testIsValidCSS_VarFunction", testIsValidCSS_VarFunction),
    ("testIsValidCSS_ImportantFlag", testIsValidCSS_ImportantFlag),
  ]
}
