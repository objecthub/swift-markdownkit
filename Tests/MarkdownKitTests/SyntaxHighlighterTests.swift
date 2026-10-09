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
import CommandLineKit
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
  
  #if os(macOS)
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
  #else
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
    let result = SyntaxHighlighter.isValidCSS("")
    XCTAssertTrue(result, "Empty string should be considered valid CSS")
  }
  
  func testIsValidCSS_WhitespaceOnly() {
    let result = SyntaxHighlighter.isValidCSS("   \n  \t  ")
    XCTAssertTrue(result, "Whitespace-only string should be considered valid CSS")
  }
  
  func testIsValidCSS_SimpleRule() {
    let css = ".hljs { color: #333; }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "Simple CSS rule should be valid")
  }
  
  func testIsValidCSS_MultipleRules() {
    let css = """
    .hljs { color: #333; background: #fff; }
    .hljs-keyword { font-weight: bold; }
    .hljs-string { color: green; }
    """
    let result = SyntaxHighlighter.isValidCSS(css)
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
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "Rule with multiple properties should be valid")
  }
  
  func testIsValidCSS_EmptyRule() {
    let css = ".hljs {}"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "Empty rule should be valid")
  }
  
  func testIsValidCSS_RuleWithoutSemicolon() {
    let css = ".hljs { color: #333 }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "Rule without trailing semicolon should be valid")
  }
  
  func testIsValidCSS_AtRule() {
    let css = "@media screen { .hljs { color: black; } }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "@media rule should be valid")
  }
  
  func testIsValidCSS_KeyframesRule() {
    let css = """
    @keyframes fade {
      0% { opacity: 0; }
      100% { opacity: 1; }
    }
    """
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "@keyframes rule should be valid")
  }
  
  func testIsValidCSS_ComplexSelector() {
    let css = ".hljs .hljs-keyword.bold, .hljs-strong { font-weight: bold; }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "Complex selector should be valid")
  }
  
  func testIsValidCSS_PseudoClass() {
    let css = ".hljs-link:hover { text-decoration: underline; }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "Pseudo-class selector should be valid")
  }
  
  func testIsValidCSS_NestedRules() {
    let css = """
    @media (prefers-color-scheme: dark) {
      .hljs { background: #1e1e1e; }
      .hljs-keyword { color: #569cd6; }
    }
    """
    let result = SyntaxHighlighter.isValidCSS(css)
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
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "Real-world CSS example should be valid")
  }
  
  // MARK: - isValidCSS Invalid Cases
  
  func testIsValidCSS_UnbalancedBracesExtra() {
    let css = ".hljs { color: red; } }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertFalse(result, "CSS with extra closing brace should be invalid")
  }
  
  func testIsValidCSS_UnbalancedBracesMissing() {
    let css = ".hljs { color: red;"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertFalse(result, "CSS with missing closing brace should be invalid")
  }
  
  func testIsValidCSS_HTMLTag() {
    let css = "<div>Not CSS</div>"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertFalse(result, "HTML tags should make CSS invalid")
  }
  
  func testIsValidCSS_AngleBracketsInContent() {
    let css = ".hljs { content: '<div>'; }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertFalse(result, "Angle brackets in content should make CSS invalid")
  }
  
  func testIsValidCSS_NoRules() {
    let css = "This is just text without any CSS rules"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertFalse(result, "Text without CSS rules should be invalid")
  }
  
  func testIsValidCSS_OnlySelector() {
    let css = ".hljs"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertFalse(result, "Selector without rule block should be invalid")
  }
  
  func testIsValidCSS_MalformedPropertyNoColon() {
    let css = ".hljs { color red; }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertFalse(result, "Property without colon should be invalid")
  }
  
  func testIsValidCSS_OnlyBraces() {
    let css = "{ }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertFalse(result, "Only braces without selector should be invalid")
  }
  
  func testIsValidCSS_JavaScriptCode() {
    let css = "function test() { return true; }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertFalse(result, "JavaScript code should be invalid CSS")
  }
  
  // MARK: - isValidCSS Edge Cases
  
  func testIsValidCSS_CommentOnly() {
    let css = "/* This is a comment */"
    let result = SyntaxHighlighter.isValidCSS(css)
    // Comments without rules - implementation dependent
    // The function checks for at least one rule pattern
    XCTAssertFalse(result, "Comment-only CSS should be invalid (no actual rules)")
  }
  
  func testIsValidCSS_RuleWithComment() {
    let css = """
    /* Header styles */
    .hljs { color: #333; }
    """
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "CSS with comments should be valid")
  }
  
  func testIsValidCSS_ImportStatement() {
    let css = "@import url('other.css');"
    let result = SyntaxHighlighter.isValidCSS(css)
    // @import without a rule block
    XCTAssertFalse(result, "@import alone should be invalid (no rule pattern)")
  }
  
  func testIsValidCSS_ImportWithRule() {
    let css = """
    @import url('other.css');
    .hljs { color: red; }
    """
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "@import with rules should be valid")
  }
  
  func testIsValidCSS_VeryLongRule() {
    var properties = ""
    for i in 1...100 {
      properties += "property\(i): value\(i); "
    }
    let css = ".hljs { \(properties) }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "Very long rule should be valid")
  }
  
  func testIsValidCSS_UnicodeCharacters() {
    let css = ".hljs-中文 { color: red; }"
    let result = SyntaxHighlighter.isValidCSS(css)
    // CSS allows unicode in selectors
    XCTAssertTrue(result, "Unicode characters in selector should be valid")
  }
  
  func testIsValidCSS_EscapedCharacters() {
    let css = ".hljs\\:hover { color: blue; }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "Escaped characters should be valid")
  }
  
  func testIsValidCSS_MultilineValue() {
    let css = """
    .hljs {
      content: "Line 1
      Line 2";
    }
    """
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "Multiline value should be valid")
  }
  
  func testIsValidCSS_URLValue() {
    let css = ".hljs { background: url(data:image/png;base64,ABC123); }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "URL values should be valid")
  }
  
  func testIsValidCSS_CalcFunction() {
    let css = ".hljs { width: calc(100% - 20px); }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "calc() function should be valid")
  }
  
  func testIsValidCSS_VarFunction() {
    let css = ".hljs { color: var(--main-color); }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "var() function should be valid")
  }
  
  func testIsValidCSS_ImportantFlag() {
    let css = ".hljs { color: red !important; }"
    let result = SyntaxHighlighter.isValidCSS(css)
    XCTAssertTrue(result, "!important flag should be valid")
  }

  // MARK: Highlighting configs are value types

  /// A theme in the same (minified) format as the bundled themes
  private static let testTheme = ".hljs{color:#ffffff;background:#101010}" +
                                 ".hljs-keyword{color:#ff0000;font-weight:bold}"

  /// The line and paragraph spacing of the paragraph style of an attributed string
  private func spacing(of string: NSAttributedString) -> [CGFloat] {
    guard let style = string.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                        as? NSParagraphStyle else {
      return []
    }
    return [style.lineSpacing, style.paragraphSpacing]
  }

  func testHighlightingConfigIsAValueType() {
    let font = HRFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    let config = HighlightingConfig(withTheme: SyntaxHighlighterTests.testTheme, usingFont: font)
    var copy = config
    copy.lineSpacing = 7
    copy.paraSpacing = 3
    // Changing the copy does not affect the original
    XCTAssertEqual(config.lineSpacing, 0)
    XCTAssertEqual(config.paraSpacing, 0)
    XCTAssertEqual(copy.lineSpacing, 7)
    XCTAssertEqual(self.spacing(of: config.apply(to: "let", styleList: ["hljs-keyword"])), [0, 0])
    XCTAssertEqual(self.spacing(of: copy.apply(to: "let", styleList: ["hljs-keyword"])), [7, 3])
    XCTAssertEqual(self.spacing(of: copy.apply(to: "x", styleList: [])), [7, 3])
    // Styled text uses the fonts which were determined when the config was created
    let styled = copy.apply(to: "let", styleList: ["hljs-keyword"])
    XCTAssertEqual(styled.attribute(.font, at: 0, effectiveRange: nil) as? HRFont, config.boldCodeFont)
    XCTAssertNotNil(styled.attribute(.foregroundColor, at: 0, effectiveRange: nil))
    XCTAssertEqual(config.theme, SyntaxHighlighterTests.testTheme)
  }

  func testGeneratorKeepsItsOwnHighlightingConfig() throws {
    var config = try XCTUnwrap(AttributedStringGenerator.standard.codeBlockHighlightingConfig)
    let original = config.lineSpacing
    config.lineSpacing = original + 5
    XCTAssertEqual(AttributedStringGenerator.standard.codeBlockHighlightingConfig?.lineSpacing, original)
  }

  func testAnsiHighlightingConfigIsAValueType() throws {
    let config = try XCTUnwrap(AnsiHighlightingConfig(withTheme: SyntaxHighlighterTests.testTheme,
                                                      fullColorSupport: true))
    let copy = config
    let styled = config.apply(to: "let", styleList: ["hljs-keyword"])
    XCTAssertEqual(copy.apply(to: "let", styleList: ["hljs-keyword"]), styled)
    XCTAssertNotEqual(styled, config.apply(to: "let", styleList: []))
    XCTAssertNil(AnsiHighlightingConfig(withTheme: "not a theme", fullColorSupport: true))
  }

  // MARK: Parsing themes

  /// A style which just collects the declarations
  private struct Declarations: ThemeStyle {
    var values: [String: String] = [:]
    init() {}
    init(_ declarations: [ThemeDeclaration]) {
      for declaration in declarations {
        self.values[declaration.name] = declaration.value
      }
    }
    func overridden(by inner: Declarations) -> Declarations {
      var result = self
      result.values.merge(inner.values) { _, new in new }
      return result
    }
  }

  private func sheet(_ css: String) -> ThemeStyleSheet<Declarations> {
    return ThemeStyleSheet<Declarations>(css: css) { Declarations($0) }
  }

  private static let minifiedTheme = ".hljs{color:#ffffff;background:#101010}" +
                                     ".hljs-keyword,.hljs-literal{color:#FF0000;font-weight:bold}"

  private static let formattedTheme = """
    /* A theme written by hand */
    .hljs {
      color: #ffffff;
      background: #101010;
    }

    /* keywords are bold and red */
    .hljs-keyword,
    .hljs-literal {
      COLOR: #FF0000 !important;
      font-weight: bold ;
    }
    """

  private static let normalizedTheme =
    ".hljs{color:#ffffff;background:#101010;}" +
    ".hljs-keyword{color:#FF0000;font-weight:bold;}" +
    ".hljs-literal{color:#FF0000;font-weight:bold;}"

  func testStyleSheetParsesMinifiedAndFormattedCSS() {
    XCTAssertEqual(self.sheet(SyntaxHighlighterTests.minifiedTheme).css(),
                   SyntaxHighlighterTests.normalizedTheme)
    XCTAssertEqual(self.sheet(SyntaxHighlighterTests.formattedTheme).css(),
                   SyntaxHighlighterTests.normalizedTheme)
    // Whitespace in all places, including tabs, windows line endings and a comment inside a rule
    let spaced = ".hljs\t{ color :#ffffff ;\r\n background:\t#101010 }\r\n" +
                 ".hljs-keyword ,\r\n .hljs-literal{ color: #FF0000; /* red; bold */ font-weight: bold }"
    XCTAssertEqual(self.sheet(spaced).css(), SyntaxHighlighterTests.normalizedTheme)
    XCTAssertEqual(self.sheet("").css(), "")
    XCTAssertEqual(self.sheet("/* unterminated .a{color:red}").css(), "")
  }

  func testStyleSheetIgnoresAtRulesAndUnsupportedSelectors() {
    let css = """
      @import url("other.css");
      @media screen and (-ms-high-contrast: active) {
        .hljs-keyword { color: highlight; }
        .hljs-extra { color: highlight; }
      }
      .hljs-keyword { color: red; }
      .hljs-keyword:hover { color: green; }
      .hljs ::selection { color: blue; }
      .hljs-a + .hljs-b { color: blue; }
      #id.hljs-a { color: blue; }
      .hljs-a[x] { color: blue; }
      h1 { color: pink; }
      * { color: pink; }
      pre code.hljs { display: block; }
      pre > code.hljs-b { display: block; }
      @font-face { font-family: x; src: url(x); }
      .hljs-tag { }
      .hljs-c > { color: blue; }
      """
    XCTAssertEqual(self.sheet(css).css(),
                   ".hljs-keyword{color:red;}.hljs{display:block;}.hljs-b{display:block;}")
  }

  func testStyleSheetParsesSelectors() {
    func selectors(_ css: String) -> [String] {
      return self.sheet(css).rules.map { $0.selector.text }
    }
    XCTAssertEqual(selectors(".a .b, .c{x:y}"), [".a .b", ".c"])
    XCTAssertEqual(selectors(".a>.b,.c > .d.e{x:y}"), [".a > .b", ".c > .d.e"])
    XCTAssertEqual(selectors(".a.a.b{x:y}"), [".a.b"])
    XCTAssertEqual(selectors("code.a  div  .b span.c{x:y}"), [".a .b .c"])
    // A selector which is not supported does not affect the others of the list
    XCTAssertEqual(selectors(".a, b, .c:hover, .d{x:y}"), [".a", ".d"])
    XCTAssertEqual(self.sheet(".a .b > .c.d, .e{x:y}").rules.map { $0.selector.specificity }, [4, 1])
  }

  func testStyleSheetAppliesRulesInSourceOrder() {
    // The last rule wins, per property (this used to depend on the order of a dictionary)
    for _ in 0..<20 {
      XCTAssertEqual(self.sheet(".a{color:red}.a{color:blue}").style(forClasses: ["a"]).values,
                     ["color": "blue"])
      XCTAssertEqual(self.sheet(".a,.b{color:red;font-weight:bold}.b{color:blue}")
                       .style(forClasses: ["b"]).values,
                     ["color": "blue", "font-weight": "bold"])
      XCTAssertEqual(self.sheet(".b{color:blue}.a,.b{color:red}").style(forClasses: ["b"]).values,
                     ["color": "red"])
      XCTAssertEqual(self.sheet(".a{color:red;color:blue}").style(forClasses: ["a"]).values,
                     ["color": "blue"])
    }
  }

  func testStyleSheetMatchesCompoundSelectorsAndMoreSpecificRulesWin() {
    let sheet = self.sheet(".a.b{color:red}.b{color:blue}.c.d{color:green}.c{x:y}")
    // The more specific rule wins, although it is written first/last
    XCTAssertEqual(sheet.style(forClasses: ["a b"]).values["color"], "red")
    XCTAssertEqual(sheet.style(forClasses: ["b a"]).values["color"], "red")
    XCTAssertEqual(sheet.style(forClasses: ["b"]).values["color"], "blue")
    XCTAssertEqual(sheet.style(forClasses: ["a"]).values["color"], nil)
    XCTAssertEqual(sheet.style(forClasses: ["c   d"]).values["color"], "green")
    XCTAssertEqual(sheet.style(forClasses: ["c"]).values["color"], nil)
    XCTAssertEqual(self.sheet(".b{color:blue}.a.b{color:red}.b{x:y}").style(forClasses: ["a b"]).values,
                   ["color": "red", "x": "y"])
  }

  func testStyleSheetMatchesDescendantSelectors() {
    let sheet = self.sheet(".hljs-keyword{color:cyan}.hljs-function .hljs-keyword{color:pink}")
    // The keyword is pink within a function, and cyan elsewhere
    XCTAssertEqual(sheet.style(forClasses: ["hljs", "hljs-function", "hljs-keyword"]).values["color"],
                   "pink")
    XCTAssertEqual(sheet.style(forClasses: ["hljs", "hljs-function", "hljs-params",
                                            "hljs-keyword"]).values["color"], "pink")
    XCTAssertEqual(sheet.style(forClasses: ["hljs", "hljs-keyword"]).values["color"], "cyan")
    // A keyword which contains a function is not within a function
    XCTAssertEqual(sheet.style(forClasses: ["hljs-keyword", "hljs-function"]).values["color"], "cyan")
    // The ancestor itself is not styled by the rule
    XCTAssertEqual(sheet.style(forClasses: ["hljs", "hljs-function"]).values["color"], nil)
    // Classes of an element can be given in any order
    XCTAssertEqual(sheet.style(forClasses: ["hljs", "hljs-function",
                                            "x hljs-keyword"]).values["color"], "pink")
  }

  func testStyleSheetMatchesChildSelectors() {
    let sheet = self.sheet(".a > .b{color:red}")
    XCTAssertEqual(sheet.style(forClasses: ["a", "b"]).values["color"], "red")
    XCTAssertEqual(sheet.style(forClasses: ["x", "a", "b"]).values["color"], "red")
    XCTAssertEqual(sheet.style(forClasses: ["a", "x", "b"]).values["color"], nil)
    XCTAssertEqual(sheet.style(forClasses: ["b", "a"]).values["color"], nil)
    XCTAssertEqual(sheet.style(forClasses: ["b"]).values["color"], nil)
  }

  func testStyleSheetBacktracksForMixedSelectors() {
    // `.c` needs an ancestor `.b` which is a child of `.a`
    let sheet = self.sheet(".a > .b .c{color:red}")
    XCTAssertEqual(sheet.style(forClasses: ["a", "b", "c"]).values["color"], "red")
    XCTAssertEqual(sheet.style(forClasses: ["b", "a", "b", "c"]).values["color"], "red")
    // The nearest `.b` is not a child of `.a`, but another `.b` further out is
    XCTAssertEqual(sheet.style(forClasses: ["a", "b", "b", "c"]).values["color"], "red")
    XCTAssertEqual(sheet.style(forClasses: ["a", "x", "b", "c"]).values["color"], nil)
    XCTAssertEqual(sheet.style(forClasses: ["b", "c"]).values["color"], nil)
  }

  func testStyleSheetLayersTheStylesOfNestedElements() {
    let sheet = self.sheet(".a{color:red;font-weight:bold}.b{color:blue}.c{font-weight:normal}")
    // Inner elements replace the properties of outer ones, and inherit the others
    XCTAssertEqual(sheet.style(forClasses: ["a", "b"]).values,
                   ["color": "blue", "font-weight": "bold"])
    XCTAssertEqual(sheet.style(forClasses: ["a", "b", "c"]).values,
                   ["color": "blue", "font-weight": "normal"])
    XCTAssertEqual(sheet.style(forClasses: []).values, [:])
    XCTAssertEqual(sheet.style(forClasses: ["x"]).values, [:])
  }

  func testStyleSheetCacheDoesNotChangeResults() {
    let sheet = self.sheet(".a{color:red}.a .b{color:blue}.c{x:y}")
    let expected = [["a"]: ["color": "red"], ["a", "b"]: ["color": "blue"],
                    ["b"]: [:], ["a", "c"]: ["color": "red", "x": "y"]]
    // The same lists of classes are looked up repeatedly, and more lists than the cache holds
    for round in 0..<3 {
      for (classes, values) in expected {
        XCTAssertEqual(sheet.style(forClasses: classes).values, values, "\(classes)")
      }
      for i in 0..<(round == 0 ? 1500 : 10) {
        XCTAssertEqual(sheet.style(forClasses: ["a", "z\(i)"]).values, ["color": "red"])
      }
    }
    // Copies of a style sheet behave in the same way
    let copy = sheet
    XCTAssertEqual(copy.style(forClasses: ["a", "b"]).values, ["color": "blue"])
  }

  private func bundledTheme(_ name: String) throws -> String {
    let bundle = try XCTUnwrap(SyntaxHighlighter.resourceBundle)
    let path = try XCTUnwrap(bundle.path(forResource: name, ofType: "css"))
    return try String(contentsOfFile: path, encoding: .utf8)
  }

  /// Themes of the bundle: compound selectors at the end of a list, at-rules and descendant
  /// selectors used to confuse the parser
  func testBundledThemesAreParsedCorrectly() throws {
    // `.hljs-doctag,.hljs-keyword,...,.hljs-variable.language_{color:#ff7b72}`
    let github = self.sheet(try self.bundledTheme("github-dark"))
    XCTAssertEqual(github.style(forClasses: ["hljs", "hljs-keyword"]).values["color"], "#ff7b72")
    // `@media screen and (-ms-high-contrast:active){...{color:highlight}}` does not apply
    let a11y = self.sheet(try self.bundledTheme("a11y-dark"))
    XCTAssertEqual(a11y.style(forClasses: ["hljs", "hljs-string"]).values["color"], "#abe338")
    // A comment before the first rule
    let stack = self.sheet(try self.bundledTheme("stackoverflow-dark"))
    XCTAssertEqual(stack.style(forClasses: ["hljs"]).values["background"], "#1c1b1b")
    // `.hljs-built_in,.hljs-class .hljs-title{color:#e6c07b}` and `...,.hljs-title{color:#61aeee}`
    let atom = self.sheet(try self.bundledTheme("atom-one-dark"))
    XCTAssertEqual(atom.style(forClasses: ["hljs", "hljs-class", "hljs-title"]).values["color"],
                   "#e6c07b")
    XCTAssertEqual(atom.style(forClasses: ["hljs", "hljs-title"]).values["color"], "#61aeee")
    XCTAssertNotEqual(atom.style(forClasses: ["hljs", "hljs-class"]).values["color"], "#e6c07b")
    // `.hljs-function .hljs-keyword{color:#ff79c6}` and `.hljs-keyword,...{color:#8be9fd}`
    let dracula = self.sheet(try self.bundledTheme("dracula"))
    XCTAssertEqual(dracula.style(forClasses: ["hljs", "hljs-function", "hljs-keyword"]).values["color"],
                   "#ff79c6")
    XCTAssertEqual(dracula.style(forClasses: ["hljs", "hljs-keyword"]).values["color"], "#8be9fd")
    // Every theme has rules, and parsing it twice gives the same result
    for name in highlighter.availableThemes {
      let css = try self.bundledTheme(name)
      XCTAssertGreaterThan(self.sheet(css).rules.count, 5, name)
      XCTAssertEqual(self.sheet(css).css(), self.sheet(css).css(), name)
    }
  }

  func testHighlightingConfigsFromFormattedCSS() throws {
    let font = HRFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    let minified = HighlightingConfig(withTheme: SyntaxHighlighterTests.minifiedTheme, usingFont: font)
    let formatted = HighlightingConfig(withTheme: SyntaxHighlighterTests.formattedTheme, usingFont: font)
    let red = HRColor.from(cssColor: "#FF0000")
    for config in [minified, formatted] {
      let styled = config.apply(to: "let", styleList: ["hljs", "hljs-keyword"])
      XCTAssertEqual(styled.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? HRColor, red)
      XCTAssertEqual(styled.attribute(.font, at: 0, effectiveRange: nil) as? HRFont,
                     config.boldCodeFont)
    }
    XCTAssertEqual(formatted.themeBackgroundColor, minified.themeBackgroundColor)
    XCTAssertEqual(formatted.themeBackgroundColor, HRColor.from(cssColor: "#101010"))
    XCTAssertEqual(formatted.lightTheme, minified.lightTheme)
    // The same through the highlighter, which also accepts the CSS of a theme
    let viaHighlighter = try XCTUnwrap(highlighter.getConfig(
                           forTheme: SyntaxHighlighterTests.formattedTheme, withFont: font))
    let styled = viaHighlighter.apply(to: "let", styleList: ["hljs", "hljs-literal"])
    XCTAssertEqual(styled.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? HRColor, red)
    // The ANSI configs
    let ansiMinified = try XCTUnwrap(AnsiHighlightingConfig(
                         withTheme: SyntaxHighlighterTests.minifiedTheme, fullColorSupport: true))
    let ansiFormatted = try XCTUnwrap(AnsiHighlightingConfig(
                          withTheme: SyntaxHighlighterTests.formattedTheme, fullColorSupport: true))
    let ansiViaHighlighter = try XCTUnwrap(highlighter.getAnsiConfig(
                               forTheme: SyntaxHighlighterTests.formattedTheme, fullColorSupport: true))
    let expected = ansiMinified.apply(to: "let", styleList: ["hljs", "hljs-keyword"])
    XCTAssertNotEqual(expected, ansiMinified.apply(to: "let", styleList: []))
    XCTAssertEqual(ansiFormatted.apply(to: "let", styleList: ["hljs", "hljs-keyword"]), expected)
    XCTAssertEqual(ansiViaHighlighter.apply(to: "let", styleList: ["hljs", "hljs-keyword"]), expected)
  }

  func testLightThemeKeepsTheSelectorsAndLeavesOutTheBlockBackground() {
    let font = HRFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    let css = "pre code.hljs{display:block;background:#101010}.hljs{color:#fff}" +
              ".hljs-function .hljs-keyword{color:#f0f}.hljs-meta > .hljs-string{color:#0ff}" +
              ".hljs-keyword:hover{color:#00f}"
    XCTAssertEqual(HighlightingConfig(withTheme: css, usingFont: font).lightTheme,
                   ".hljs{display:block;}.hljs{color:#fff;}" +
                   ".hljs-function .hljs-keyword{color:#f0f;}.hljs-meta > .hljs-string{color:#0ff;}")
  }

  func testHighlightingConfigStylesNestedElements() throws {
    let font = HRFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    let css = ".hljs-keyword{color:#00f;font-weight:bold}" +
              ".hljs-function .hljs-keyword{color:#f0f;font-style:italic}" +
              ".hljs-title.function_{font-weight:bold;font-style:italic}" +
              ".hljs-comment{font-style:italic}.hljs-strong{font-weight:bold}.hljs-em{font-style:normal}"
    let config = HighlightingConfig(withTheme: css, usingFont: font)
    func attributes(_ stack: [String]) -> (color: HRColor?, font: HRFont?) {
      let styled = config.apply(to: "x", styleList: stack)
      return (styled.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? HRColor,
              styled.attribute(.font, at: 0, effectiveRange: nil) as? HRFont)
    }
    // Descendant selectors apply in their context only
    XCTAssertEqual(attributes(["hljs", "hljs-keyword"]).color, HRColor.from(cssColor: "#00f"))
    XCTAssertEqual(attributes(["hljs", "hljs-function", "hljs-keyword"]).color,
                   HRColor.from(cssColor: "#f0f"))
    XCTAssertNil(attributes(["hljs", "hljs-function"]).color)
    // Bold, italic and bold-italic text use the corresponding fonts
    XCTAssertEqual(attributes(["hljs", "hljs-keyword"]).font, config.boldCodeFont)
    XCTAssertEqual(attributes(["hljs", "hljs-comment"]).font, config.italicCodeFont)
    XCTAssertEqual(attributes(["hljs", "hljs-function", "hljs-keyword"]).font, config.boldItalicCodeFont)
    XCTAssertEqual(attributes(["hljs", "hljs-title function_"]).font, config.boldItalicCodeFont)
    XCTAssertEqual(attributes(["hljs", "hljs-title"]).font, config.codeFont)
    // An inner element can switch off what an outer element sets
    XCTAssertEqual(attributes(["hljs", "hljs-strong", "hljs-em"]).font, config.boldCodeFont)
    XCTAssertEqual(attributes(["hljs", "hljs-comment", "hljs-em"]).font, config.codeFont)
    // Changing the fonts of a config takes effect for styled text
    var changed = config
    let other = HRFont.monospacedSystemFont(ofSize: 20, weight: .black)
    changed.boldCodeFont = other
    let styled = changed.apply(to: "x", styleList: ["hljs", "hljs-keyword"])
    XCTAssertEqual(styled.attribute(.font, at: 0, effectiveRange: nil) as? HRFont, other)
  }

  func testAnsiHighlightingConfigStylesNestedElements() throws {
    let css = ".hljs{color:#fff}.hljs-keyword{color:#f00;font-weight:bold}" +
              ".hljs-function .hljs-keyword{color:#0f0;text-decoration:underline}" +
              ".hljs-em{font-style:italic}.hljs-strong{font-weight:bold}.hljs-plain{font-weight:normal;text-decoration:none}" +
              ".hljs-strike{text-decoration:line-through}"
    let config = try XCTUnwrap(AnsiHighlightingConfig(withTheme: css, fullColorSupport: true))
    func properties(_ stack: [String]) -> TextProperties {
      return config.apply(to: "x", styleList: stack).segments.first?.0 ?? .empty
    }
    let plain = properties(["hljs"])
    XCTAssertNotNil(plain.textColor)
    XCTAssertEqual(plain.textStyles, [])
    let keyword = properties(["hljs", "hljs-keyword"])
    XCTAssertNotEqual(keyword.textColor, plain.textColor)
    XCTAssertEqual(keyword.textStyles, [.bold])
    // The descendant rule applies within a function only
    let inFunction = properties(["hljs", "hljs-function", "hljs-keyword"])
    XCTAssertNotEqual(inFunction.textColor, keyword.textColor)
    XCTAssertEqual(inFunction.textStyles, [.bold, .underline])
    XCTAssertEqual(properties(["hljs", "hljs-function"]).textColor, plain.textColor)
    // Styles of outer elements are inherited, and can be switched off
    XCTAssertEqual(properties(["hljs", "hljs-strong", "hljs-em"]).textStyles, [.bold, .italic])
    XCTAssertEqual(properties(["hljs", "hljs-strong", "hljs-plain"]).textStyles, [])
    XCTAssertEqual(properties(["hljs", "hljs-strike"]).textStyles, [.strikethrough])
  }
}
