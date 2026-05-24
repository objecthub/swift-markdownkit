//
//  SyntaxHighlighter.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 22/05/2026.
//  Copyright © 2026 Matthias Zenger. All rights reserved.
//
//  Portions of this code licensed under the MIT license:
//    Copyright 2026, Tony Smith
//    Copyright 2016, Juan-Pablo Illanes
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

import Foundation
import JavaScriptCore
#if canImport(AppKit)
import AppKit
public typealias HRColor = NSColor
public typealias HRFont  = NSFont
public typealias TextStorageEditActions = NSTextStorageEditActions
#elseif canImport(UIKit)
import UIKit
public typealias HRColor = UIColor
public typealias HRFont  = UIFont
public typealias TextStorageEditActions = NSTextStorage.EditActions
#endif

/// 
/// A syntax highlighter that uses Highlight.js to provide code syntax highlighting
/// with theme support and customizable rendering options.
///
/// `SyntaxHighlighter` wraps the Highlight.js JavaScript library to provide syntax
/// highlighting for code blocks. It supports multiple programming languages, customizable
/// themes, and can render highlighted code as attributed strings suitable for display
/// in AppKit or UIKit text views.
///
/// Example usage:
/// ```swift
/// guard let highlighter = SyntaxHighlighter.proxy else { return }
/// let config = highlighter.getConfig(forTheme: "github", withFont: "Monaco", ofSize: 14.0)
/// if let highlighted = highlighter.highlight(code: "let x = 42", as: "swift"),
///    let config {
///   let attributed = highlighter.asAttributedString(highlighted, using: config)
/// }
/// ```
/// 
public final class SyntaxHighlighter {
  
  /// The shared singleton instance of `SyntaxHighlighter`.
  ///
  /// This property provides access to a pre-configured `SyntaxHighlighter` instance
  /// that has loaded the Highlight.js library and discovered available themes.
  /// Returns `nil` if the required resources (highlight.min.js) cannot be loaded.
  ///
  /// - Note: The proxy is lazily initialized on first access.
  public static var proxy: SyntaxHighlighter? = {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: SyntaxHighlighter.self)
    #endif
    // Load highlight.min.js code from this bundle
    guard let path = bundle.path(forResource: "highlight.min", ofType: "js") else {
      return nil
    }
    // Load the JS code
    do {
      guard let context = JSContext() else {
        return nil
      }
      let js = try String(contentsOfFile: path)
      // Execute the JS
      let _ = context.evaluateScript(js)
      guard let hljs = context.globalObject.objectForKeyedSubscript("hljs") else {
        return nil
      }
      // Extract the supported languages
      let res: JSValue? = hljs.invokeMethod("listLanguages", withArguments: [])
      let supportedLanguages = (res?.toArray() as? [String]) ?? []
      // Find available themes
      let paths = bundle.paths(forResourcesOfType: "css", inDirectory: nil) as [NSString]
      var availableThemes = [String]()
      for path in paths {
        availableThemes.append(path.lastPathComponent.replacingOccurrences(of: ".css", with: ""))
      }
      return SyntaxHighlighter(hljs: hljs,
                               supportedLanguages: supportedLanguages,
                               availableThemes: availableThemes)
    } catch {
      return nil
    }
  }()
  
  /// Reference to the result of evaluating `highlight.min.js`.
  private let hljs: JSValue
  
  /// An array of language identifiers supported by Highlight.js.
  ///
  /// This array contains the names of all programming languages that can be
  /// passed to the `highlight(code:as:ignoreIllegals:)` method. Common values
  /// include "swift", "python", "javascript", "cpp", etc.
  ///
  /// - Note: The list is populated from Highlight.js's `listLanguages()` method
  ///   during initialization.
  public let supportedLanguages: [String]
  
  /// An array of available theme names.
  ///
  /// This array contains the base names (without `.css` extension) of all theme
  /// files bundled with the framework. These names can be passed to the
  /// `getConfig(forTheme:withFont:ofSize:)` method to load a specific highlighting theme.
  ///
  /// Common themes may include "github", "monokai", "xcode", "atom-one-dark", etc.
  public let availableThemes: [String]
  
  private let htmlEscape = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;",
                                                    options: .caseInsensitive)
  
  /// Internal initializer.
  private init(hljs: JSValue, supportedLanguages: [String], availableThemes: [String]) {
    self.hljs = hljs
    self.supportedLanguages = supportedLanguages
    self.availableThemes = availableThemes
  }
  
  /// Loads a highlighting theme with a custom font specified by CSS font-family string.
  /// and returns a corresponding config object.
  ///
  /// This method loads a syntax highlighting theme and configures it with a font
  /// resolved from a CSS-style font-family specification. If the specified font
  /// cannot be found, falls back to the system monospaced font.
  ///
  /// - Parameters:
  ///   - name: The name of the theme to load (without `.css` extension).
  ///           Must match a theme name from `availableThemes`.
  ///   - withFont: An optional CSS font-family string (e.g., "'SF Mono', Monaco, monospace").
  ///               If `nil`, uses the system monospaced font. The first available font
  ///               in the list will be used.
  ///   - ofSize: The point size for the font. Default is 14.0.
  ///
  /// - Returns: A configured `HighlightingConfig` instance, or `nil` if the theme
  ///            file cannot be found, loaded, or initialized.
  ///
  /// Example:
  /// ```swift
  /// let config = highlighter.getConfig(forTheme: "github",
  ///                                    withFont: "'SF Mono', Menlo, monospace",
  ///                                    ofSize: 13.0)
  /// ```
  public func getConfig(forTheme nameOrContent: String,
                        withFont: String? = nil,
                        ofSize: Float = 14.0) -> HighlightingConfig? {
    let font: HRFont
    if let withFont,
       let (_, rfont) = self.resolveFont(withFont, size: CGFloat(ofSize)) {
      font = rfont
    } else {
      font = HRFont.monospacedSystemFont(ofSize: CGFloat(ofSize), weight: .regular)
    }
    return self.getConfig(forTheme: nameOrContent, withFont: font)
  }
  
  /// Loads a highlighting theme with a specific font instance.
  ///
  /// This method loads a syntax highlighting theme and configures it with the
  /// provided font object.
  ///
  /// - Parameters:
  ///   - name: The name of the theme to load (without `.css` extension).
  ///           Must match a theme name from `availableThemes`.
  ///   - withFont: An optional font instance to use for rendering. If `nil`,
  ///               uses the system monospaced font at 14pt.
  ///
  /// - Returns: A configured `HighlightingConfig` instance, or `nil` if the theme
  ///            file cannot be found or loaded.
  ///
  /// Example:
  /// ```swift
  /// let font = NSFont.monospacedSystemFont(ofSize: 12.0, weight: .regular)
  /// let config = highlighter.getConfig(forTheme: "monokai", withFont: font)
  /// ```
  public func getConfig(forTheme nameOrContent: String, withFont: HRFont?) -> HighlightingConfig? {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: SyntaxHighlighter.self)
    #endif
    guard nameOrContent.count < 80,
          let path = bundle.path(forResource: nameOrContent, ofType: "css"),
          let content = try? String(contentsOfFile: path) else {
      if self.isValidCSS(nameOrContent) {
        return HighlightingConfig(
          withTheme: nameOrContent,
          usingFont: withFont ?? HRFont.monospacedSystemFont(ofSize: 14.0, weight: .regular))
      } else {
        return nil
      }
    }
    return HighlightingConfig(
             withTheme: content,
             usingFont: withFont ?? HRFont.monospacedSystemFont(ofSize: 14.0, weight: .regular))
  }
  
  /// Applies syntax highlighting to source code.
  ///
  /// This method uses Highlight.js to analyze and highlight the provided source code,
  /// returning an HTML string with appropriate span tags and class names for styling.
  ///
  /// - Parameters:
  ///   - code: The source code to highlight.
  ///   - language: An optional language identifier (e.g., "swift", "python"). If `nil`,
  ///               Highlight.js will attempt to auto-detect the language. Use values
  ///               from `supportedLanguages`.
  ///   - ignoreIllegals: If `true`, ignores syntax errors and continues highlighting.
  ///                     Default is `false`.
  ///
  /// - Returns: An HTML string with syntax highlighting markup, or `nil` if highlighting
  ///            fails or produces undefined output.
  ///
  /// Example:
  /// ```swift
  /// let html = highlighter.highlight(code: "func hello() { print(\"Hi\") }",
  ///                                  as: "swift")
  /// ```
  ///
  /// - Note: The returned HTML is intended to be converted to an attributed string
  ///         using `asAttributedString(_:using:fastRender:lineNumbering:)`.
  public func highlight(code: String,
                        as language: String? = nil,
                        ignoreIllegals: Bool = false) -> String? {
    let result: JSValue
    if let language {
      let options: [String: Any] = ["language" : language, "ignoreIllegals" : ignoreIllegals]
      result = self.hljs.invokeMethod("highlight", withArguments: [code, options])
    } else {
      result = self.hljs.invokeMethod("highlightAuto", withArguments: [code])
    }
    guard let html: String = result.objectForKeyedSubscript("value")?.toString() else {
      return nil
    }
    return html == "undefined" ? nil : html
  }
  
  /// Converts highlighted HTML into a styled attributed string.
  ///
  /// This method takes the HTML output from `highlight(code:as:ignoreIllegals:)` and
  /// converts it into an `NSAttributedString` suitable for display in text views,
  /// with colors and styling applied according to the specified theme.
  ///
  /// - Parameters:
  ///   - html: The HTML string returned by `highlight(code:as:ignoreIllegals:)`.
  ///   - config: The highlighting config to apply for colors and styling.
  ///   - fastRender: If `true`, uses a custom parser for faster rendering. If `false`,
  ///                 uses the system HTML parser (slower but more robust). Default is `true`.
  ///   - lineNumbering: Optional configuration for adding line numbers to the output.
  ///                    If `nil`, no line numbers are added.
  ///
  /// - Returns: A styled `NSAttributedString` with syntax highlighting applied,
  ///            or `nil` if conversion fails.
  ///
  /// Example:
  /// ```swift
  /// if let html = highlighter.highlight(code: sourceCode, as: "swift"),
  ///    let config = highlighter.getConfig(forTheme: "github") {
  ///   let lineConfig = SyntaxHighlighter.LineNumberConfig(fontSize: 12.0)
  ///   let attributed = highlighter.asAttributedString(html,
  ///                                                   using: config,
  ///                                                   lineNumbering: lineConfig)
  /// }
  /// ```
  public func asAttributedString(_ html: String,
                                 using config: HighlightingConfig,
                                 fastRender: Bool = true,
                                 lineNumbering: LineNumberConfig? = nil) -> NSAttributedString? {
    var result: NSAttributedString? = nil
    if fastRender {
      result = self.attributedString(for: html, using: config)
    } else {
      let extendedHtml = "<style>" + config.lightTheme +
      "</style><pre><code class=\"hljs\">" + html +
      "</code></pre>"
      if let data = extendedHtml.data(using: String.Encoding.utf8) {
        let options: [NSAttributedString.DocumentReadingOptionKey : Any] = [
          .documentType : NSAttributedString.DocumentType.html,
          .characterEncoding : String.Encoding.utf8.rawValue
        ]
        result = try? NSMutableAttributedString(data: data,
                                                options: options,
                                                documentAttributes: nil)
      }
    }
    if result == nil {
      return result
    } else if let lineNumbering, let result {
      return addLineNumbers(to: result, config: lineNumbering)
    } else {
      return result
    }
  }
  
  private func attributedString(for htmlString: String,
                                using config: HighlightingConfig) -> NSAttributedString? {
    let resultString = NSMutableAttributedString(string: "")
    var scanned: String? = nil
    var propStack: [String] = ["hljs"]
    let scanner: Scanner = Scanner(string: htmlString)
    scanner.charactersToBeSkipped = nil
    while !scanner.isAtEnd {
        // Read up to the first tag
      scanned = scanner.scanUpToString("<")
      if let content = scanned, !content.isEmpty {
        resultString.append(config.apply(to: content, styleList: propStack))
        if scanner.isAtEnd {
          continue
        }
      }
        // Skip over the tag delimiter
      scanner.skipNextCharacter()
        // Get the next charactor
      let nextChar: String = scanner.getNextCharacter(in: htmlString)
      if nextChar == "s" {
          // We have a SPAN tag, so skip over the tag...
        _ = scanner.scanString("span class=\"")
          // ... get the inner class info...
        scanned = scanner.scanUpToString("\">")
          // ... skip over the closing tag...
        _ = scanner.scanString("\">")
          // ... and stash the class data we extracted
        if let content = scanned, !content.isEmpty {
          propStack.append(content)
        }
      } else if nextChar == "/" {
          // We have a SPAN end tag so skip over it
        _ = scanner.scanString("/span>")
        propStack.removeLast()
      } else {
          // We have code text, so style it based on the previous SPAN classe we've stored
        let attrScannedString: NSAttributedString =
        config.apply(to: "<", styleList: propStack)
        resultString.append(attrScannedString)
        scanner.skipNextCharacter()
      }
    }
      // Process HTML escapes in the rendered attribute string
    let results = self.htmlEscape.matches(in: resultString.string,
                                          options: [.reportCompletion],
                                          range: NSMakeRange(0, resultString.length))
    var localOffset = 0
    for result: NSTextCheckingResult in results {
      let fixedRange = NSMakeRange(result.range.location - localOffset,
                                   result.range.length)
      let entity = (resultString.string as NSString).substring(with: fixedRange)
      if let decodedEntity = NamedCharacters.decode(entity: entity) {
        resultString.replaceCharacters(in: fixedRange, with: String(decodedEntity))
        localOffset += (result.range.length - 1);
      }
    }
    return resultString
  }
  
  /// Configuration for adding line numbers to highlighted code.
  ///
  /// `LineNumberConfig` controls the appearance and behavior of line numbers
  /// that can be prepended to each line of syntax-highlighted code.
  ///
  /// Example:
  /// ```swift
  /// let config = SyntaxHighlighter.LineNumberConfig(
  ///   usingDarkTheme: true,
  ///   fontSize: 12.0,
  ///   separator: " │ ",
  ///   numberStart: 10,
  ///   minWidth: 3
  /// )
  /// ```
  public struct LineNumberConfig {
    
    /// The first line number to display.
    ///
    /// When getting, returns the starting line number (minimum value is 1).
    /// When setting, values less than or equal to 1 are normalized to 1.
    ///
    /// Example:
    /// ```swift
    /// config.numberStart = 42  // First line will be numbered 42
    /// ```
    public var numberStart: Int {    // The first line number.
      get {                          // Negative values reset any existint value to zero.
        return self.baseStart
      }
      set (newValue) {
        self.baseStart = newValue > 1 ? newValue : 1
      }
    }
    
    /// The minimum number of digits to display for line numbers.
    ///
    /// This ensures consistent alignment by padding line numbers with leading zeros.
    /// For example, a value of 3 produces "001", "002", etc. The minimum value is 2.
    /// If the actual line count requires more digits, this value is automatically
    /// overridden.
    ///
    /// Example:
    /// ```swift
    /// config.minWidth = 4  // Produces "0001", "0002", etc.
    /// ```
    public var minWidth: Int {       // The minimum number of line-number digits to show,
      get {                          // eg. 3 for `001`, 4 for `0001` etc.
        return self.baseMinWidth     // This will always be overriden if highest line number
      }                              // has more digits than this value.
                                     // The default, and smallest acceptable value is 2.
      set (newValue) {
        self.baseMinWidth = newValue > 2 ? newValue : 2
      }
    }
    
    /// The string placed between the line number and the code.
    ///
    /// When getting, returns the separator string (minimum is two spaces).
    /// When setting, empty strings are converted to two spaces.
    ///
    /// Example:
    /// ```swift
    /// config.separator = " │ "  // Visual separator between number and code
    /// ```
    public var separator: String {   // A string placed between the line number and the line.
      get {                          // Empty strings are converted to two spaces
        return self.baseSeparator
      }
      set (newValue) {
        self.baseSeparator = newValue == "" ? "  " : newValue
      }
    }
    
    /// Whether to use dark theme colors for line numbers.
    ///
    /// When `true`, line numbers are rendered in white (with transparency).
    /// When `false`, line numbers are rendered in black (with transparency).
    public var usingDarkTheme: Bool
    
    /// The string used to separate lines in the output.
    ///
    /// Typically this should be `"\n"`, but can be customized if needed.
    /// Default is `"\n"`.
    public var lineBreak: String
    
    /// The font size for line numbers.
    ///
    /// This should typically match the font size of the code itself for
    /// proper alignment. Default is 14.0.
    public var fontSize: CGFloat
    
    /// Internal storage for the separator string.
    private var baseSeparator: String
    
    /// Internal storage for the starting line number.
    private var baseStart: Int
    
    /// Internal storage for the minimum width.
    private var baseMinWidth: Int
    
    /// Creates a new line numbering configuration.
    ///
    /// - Parameters:
    ///   - usingDarkTheme: Whether to use dark theme colors. Default is `false`.
    ///   - lineBreak: The line break character(s). Default is `"\n"`.
    ///   - fontSize: The font size for line numbers. Default is 14.0.
    ///   - separator: The separator between number and code. Default is `"  "`.
    ///                Empty strings are converted to two spaces.
    ///   - numberStart: The first line number. Default is 0 (normalized to 1).
    ///                  Values ≤ 1 are normalized to 1.
    ///   - minWidth: Minimum digits for line numbers. Default is 2.
    ///               Values < 2 are normalized to 2.
    ///
    /// Example:
    /// ```swift
    /// let config = SyntaxHighlighter.LineNumberConfig(
    ///   usingDarkTheme: true,
    ///   fontSize: 13.0,
    ///   separator: " | ",
    ///   numberStart: 1,
    ///   minWidth: 3
    /// )
    /// ```
    public init(usingDarkTheme: Bool = false,
                lineBreak: String = "\n",
                fontSize: CGFloat = 14.0,
                separator: String = "  ",
                numberStart: Int = 0,
                minWidth: Int = 2) {
      self.usingDarkTheme = usingDarkTheme
      self.lineBreak = lineBreak
      self.fontSize = fontSize
      self.baseSeparator = separator == "" ? "  " : separator
      self.baseStart = numberStart > 1 ? numberStart : 1
      self.baseMinWidth = minWidth > 2 ? minWidth : 2
    }
  }
  
  private func addLineNumbers(to renderedCode: NSAttributedString,
                              config: LineNumberConfig) -> NSAttributedString? {
    let subStrings = renderedCode.string.components(separatedBy: config.lineBreak)
    var range = NSRange(location: 0, length: 0)
    var lines: [NSAttributedString] = []
    for string in subStrings {
      range.length = string.utf16.count
      lines.append(renderedCode.attributedSubstring(from: range))
      range.location += range.length + config.lineBreak.utf16.count
    }
      // Determine the maximum digit width of the line number field
    var formatCount = config.minWidth
    var lineIndex = config.numberStart > 1 ? config.numberStart - 1 : 0
    var lineCount: Int = lines.count + lineIndex
    while lineCount > 99 {
      formatCount += 1
      lineCount = lineCount / 100
    }
      // Determine the color according to the usage mode
    let color: HRColor = config.usingDarkTheme ? .white : .black
      // Set the line number attributes
    let attribs: [NSAttributedString.Key : Any] = [
      .foregroundColor: color.withAlphaComponent(0.2),
      .font: HRFont.monospacedSystemFont(ofSize: config.fontSize, weight: .ultraLight)
    ]
      // Iterate over the rendered lines, prepending the line number
    let formatString = "%0\(formatCount)i"
    let result = NSMutableAttributedString()
    for line in lines {
        // Add the line number
      lineIndex += 1
      result.append(NSAttributedString(string: String(format: formatString, lineIndex),
                                       attributes: attribs))
        // Add a separator
      result.append(NSAttributedString(string: config.separator,
                                       attributes: attribs))
        // Add the line itself and restore the line break
      result.append(line)
      result.append(NSAttributedString(string: config.lineBreak,
                                       attributes: attribs))
    }
    return result
  }
  
  /// Parses a CSS-style font family string into an array of font family names.
  /// Handles single-quoted, double-quoted, and unquoted names, comma-separated.
  /// Examples:
  ///   "Georgia, 'Times New Roman', serif"  →  ["Georgia", "Times New Roman", "serif"]
  ///   `"Arial, \"Helvetica Neue\", sans-serif"` → ["Arial", "Helvetica Neue", "sans-serif"]
  func parseCSSFontFamilies(_ css: String) -> [String] {
    var result: [String] = []
    var current = ""
    var index = css.startIndex
    func skipWhitespace() {
      while index < css.endIndex, css[index].isWhitespace {
        index = css.index(after: index)
      }
    }
    while index < css.endIndex {
      skipWhitespace()
      guard index < css.endIndex else {
        break
      }
      let ch = css[index]
      if ch == "\"" || ch == "'" {
        // Quoted font name — consume until matching closing quote
        let quote = ch
        index = css.index(after: index)
        while index < css.endIndex, css[index] != quote {
          if css[index] == "\\" {
            // Skip escape character
            index = css.index(after: index)
            guard index < css.endIndex else {
              break
            }
          }
          current.append(css[index])
          index = css.index(after: index)
        }
        if index < css.endIndex { // consume closing quote
          index = css.index(after: index)
        }
      } else if ch == "," {
        // Delimiter — save current token
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
          result.append(trimmed)
        }
        current = ""
        index = css.index(after: index)
      } else {
        // Unquoted character
        current.append(ch)
        index = css.index(after: index)
      }
    }
    // Flush last token
    let trimmed = current.trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty {
      result.append(trimmed)
    }
    return result
  }
  
  #if canImport(AppKit)
  /// Returns all available font family names on macOS.
  private func availableFontFamilies() -> Set<String> {
    Set(NSFontManager.shared.availableFontFamilies)
  }
  
  /// Attempts to load a font for the given family name and size on macOS.
  private func loadFont(family: String, size: CGFloat) -> NSFont? {
    if let font = NSFont(name: family, size: size) {
      return font
    }
    return NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size)
  }
  #elseif canImport(UIKit)
  /// Returns all available font family names on iOS.
  private func availableFontFamilies() -> Set<String> {
    Set(UIFont.familyNames)
  }
  
  /// Attempts to load a font for the given family name and size on iOS.
  private func loadFont(family: String, size: CGFloat) -> UIFont? {
    guard let firstName = UIFont.fontNames(forFamilyName: family).first else {
      return nil
    }
    return UIFont(name: firstName, size: size)
  }
  #endif
  
  /// Finds the first font family name from a CSS font-family string for which
  /// a font actually exists on the system, returning the matched HRFont.
  func resolveFont(_ css: String, size: CGFloat) -> (familyName: String, font: HRFont)? {
    let families = self.parseCSSFontFamilies(css)
    let available = self.availableFontFamilies()
    for f in families {
      var family: String
      switch f.lowercased() {
        case "serif":
          family = "Georgia"
        case "sans-serif":
          family = "Arial"
        case "monospace":
          let sysFont = HRFont.monospacedSystemFont(ofSize: size, weight: .regular)
          return (sysFont.familyName ?? "monospace", sysFont)
        default:
          family = f
      }
      if let matched = available.first(where:{ $0.caseInsensitiveCompare(family) == .orderedSame }),
         let font = self.loadFont(family: matched, size: size) {
        return (matched, font)
      }
    }
    return nil
  }
  
  /// Quick and dirty check to see if `css` is likely to contain CSS data. 
  func isValidCSS(_ css: String) -> Bool {
    let trimmed = css.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return true
    }
    // 1. Balanced braces
    var depth = 0
    for char in trimmed {
      if char == "{" {
        depth += 1
      } else if char == "}" {
        depth -= 1
        if depth < 0 {
          print("(1)")
          return false
        }
      }
    }
    guard depth == 0 else {
      print("(2)")
      return false
    }
    // 2. No obviously illegal characters at the top level
    let illegalPattern = #"[<>]"#
    if trimmed.range(of: illegalPattern, options: .regularExpression) != nil {
      print("(3)")
      return false
    }
    // 3. Must contain at least one plausible rule: something { something }
    let rulePattern = #"[^{}]+\{[^{}]*\}"#
    if trimmed.range(of: rulePattern, options: .regularExpression) == nil {
      print("(4)")
      return false
    }
    // 4. Each declaration block should contain plausible property: value pairs
    //    (allows empty blocks and at-rules like @media, @keyframes)
    let blockPattern = #"\{([^{}]*)\}"#
    let regex = try! NSRegularExpression(pattern: blockPattern)
    let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
    for match in matches {
      guard let range = Range(match.range(at: 1), in: trimmed) else {
        continue
      }
      let block = trimmed[range].trimmingCharacters(in: .whitespacesAndNewlines)
      // Empty blocks are fine (e.g. in @keyframes)
      guard !block.isEmpty else {
        continue
      }
      // Each non-empty block should have at least one "property: value" pair
      let declarationPattern = #".*:.*"#
      if block.range(of: declarationPattern, options: .regularExpression) == nil {
        print("(5)")
        return false
      }
    }
    return true
  }
}

private extension Scanner {
  func getNextCharacter(in outer: String) -> String {
    let string: NSString = self.string as NSString
    let idx: Int = self.currentIndex.utf16Offset(in: outer)
    let nextChar: String = string.substring(with: NSMakeRange(idx, 1))
    return nextChar
  }
  
  func skipNextCharacter() {
    self.currentIndex = self.string.index(after: self.currentIndex)
  }
}
