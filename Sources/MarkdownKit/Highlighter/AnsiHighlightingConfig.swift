//
//  AnsiHighlightingConfig.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 26/05/2026.
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

#if !os(watchOS)

import Foundation
import CommandLineKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

///
/// Configuration for converting syntax-highlighted HTML to ANSI terminal strings.
///
/// `AnsiHighlightingConfig` parses CSS theme files and maps color and style information
/// to ANSI terminal escape sequences using the CommandLineKit framework. This allows
/// syntax highlighting to be displayed in terminal applications.
///
/// Example usage:
/// ```swift
/// if let config = AnsiHighlightingConfig(withTheme: "monokai", fullColorSupport: true) {
///   let ansiText = highlighter.asAnsiTerminalString(html, using: config)
///   print(ansiText)
/// }
/// ```
///
/// `AnsiHighlightingConfig` is an immutable value type and conforms to `Sendable`, so it can be
/// shared between threads.
///
public struct AnsiHighlightingConfig: Sendable {
  private let styleSheet: ThemeStyleSheet<AnsiStyle>
  
  /// Creates a new ANSI highlighter configuration from a theme name or CSS content.
  ///
  /// The theme is a CSS style sheet with rules for the classes that highlight.js assigns to
  /// the parts of highlighted code, for example `.hljs-keyword{color:#f00;font-weight:bold}`.
  /// The selectors consist of classes: `.a`, `.a.b`, descendant selectors (`.a .b`) and child
  /// selectors (`.a > .b`). The cascade follows CSS: a rule with a higher specificity (more
  /// classes) wins over one with a lower specificity, otherwise the last rule wins. The
  /// properties `color`, `background-color`, `font-weight`, `font-style` and `text-decoration`
  /// are used.
  ///
  /// - Parameters:
  ///   - withTheme: Either the name of a bundled theme (without `.css` extension),
  ///                or raw CSS content to parse.
  ///   - fullColorSupport: If true, theme colors are mapped to the 256 color palette.
  ///
  /// - Returns: A configured `AnsiHighlightingConfig` instance, or `nil` if the theme
  ///            cannot be loaded or parsed.
  ///
  /// Example:
  /// ```swift
  /// // Load a bundled theme
  /// let config1 = AnsiHighlightingConfig(withTheme: "monokai", fullColorSupport: true)
  ///
  /// // Use custom CSS
  /// let css = ".hljs { color: #ffffff; } .hljs-keyword { color: #ff0000; font-weight: bold; }"
  /// let config2 = AnsiHighlightingConfig(withTheme: css, fullColorSupport: true)
  /// ```
  public init?(withTheme nameOrContent: String, fullColorSupport: Bool) {
    let content: String
    if nameOrContent.count < 80,
       let bundle = SyntaxHighlighter.resourceBundle,
       let path = bundle.path(forResource: nameOrContent, ofType: "css"),
       let loadedContent = try? String(contentsOfFile: path) {
      content = loadedContent
    } else if SyntaxHighlighter.isValidCSS(nameOrContent) {
      content = nameOrContent
    } else {
      return nil
    }
    // Parse the CSS theme and convert the CSS properties to ANSI text properties
    self.styleSheet = ThemeStyleSheet<AnsiStyle>(css: content) {
      AnsiStyle(declarations: $0, fullColorSupport: fullColorSupport)
    }
  }
  
  /// Applies styling to a string based on the CSS classes of the elements that contain it.
  ///
  /// - Parameters:
  ///   - string: The text to style.
  ///   - styleList: The values of the class attributes of the elements around the text,
  ///                starting with the outermost element (like `["hljs", "hljs-function",
  ///                "hljs-title function_"]`; a value can consist of several class names
  ///                separated by whitespace). The style of an element replaces the style of
  ///                the elements around it.
  ///
  /// - Returns: An `AnsiText.Normalized` value with the appropriate styling applied.
  public func apply(to string: String, styleList: [String]) -> AnsiText.Normalized {
    return AnsiText.Normalized(string,
                               properties: self.styleSheet.style(forClasses: styleList).properties)
  }
  
  /// Converts a CSS color string to an ANSI `TextColor`.
  fileprivate static func cssColorToAnsiColor(_ cssColor: String,
                                          fullColorSupport: Bool) -> TextColor? {
    if let color = HRColor.from(cssColor: cssColor) {
      return Self.approximateAnsiColor(color, fullColorSupport: fullColorSupport)
    }
    return nil
  }
  
  /// Converts a CSS color string to an ANSI `BackgroundColor`.
  fileprivate static func cssColorToAnsiBackgroundColor(_ cssColor: String,
                                                    fullColorSupport: Bool) -> BackgroundColor? {
    if let color = HRColor.from(cssColor: cssColor) {
      return Self.approximateAnsiBackgroundColor(color, fullColorSupport: fullColorSupport)
    }
    return nil
  }
  
  /// Approximates an NSColor/UIColor to the nearest ANSI TextColor.
  private static func approximateAnsiColor(_ color: HRColor, fullColorSupport: Bool) -> TextColor? {
    #if os(macOS)
    guard let rgb = color.usingColorSpace(NSColorSpace.deviceRGB) else {
      return nil
    }
    return TextColor(rgb: (rgb.redComponent, rgb.greenComponent, rgb.blueComponent),
                     fullColorSupport: fullColorSupport)
    #else
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    return TextColor(rgb: (r, g, b), fullColorSupport: fullColorSupport)
    #endif
  }
  
  /// Approximates an NSColor/UIColor to the nearest ANSI BackgroundColor.
  private static func approximateAnsiBackgroundColor(_ color: HRColor,
                                                     fullColorSupport: Bool) -> BackgroundColor? {
    #if os(macOS)
    guard let rgb = color.usingColorSpace(NSColorSpace.deviceRGB) else {
      return nil
    }
    return BackgroundColor(rgb: (rgb.redComponent, rgb.greenComponent, rgb.blueComponent),
                           fullColorSupport: fullColorSupport)
    #else
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    return BackgroundColor(rgb: (r, g, b), fullColorSupport: fullColorSupport)
    #endif
  }
}

/// The style of text in code which is rendered as ANSI text.
fileprivate struct AnsiStyle: ThemeStyle {
  var textColor: TextColor? = nil
  var backgroundColor: BackgroundColor? = nil
  var bold: Bool? = nil
  var italic: Bool? = nil
  var underline: Bool? = nil
  var strikethrough: Bool? = nil
  
  init() {}
  
  /// Creates the style for a rule; properties with values that are not understood are ignored.
  init(declarations: [ThemeDeclaration], fullColorSupport: Bool) {
    for declaration in declarations {
      let value = declaration.value
      switch declaration.name {
        case "color":
          self.textColor = AnsiHighlightingConfig.cssColorToAnsiColor(
                             value, fullColorSupport: fullColorSupport) ?? self.textColor
        case "background-color":
          self.backgroundColor = AnsiHighlightingConfig.cssColorToAnsiBackgroundColor(
                                   value, fullColorSupport: fullColorSupport) ?? self.backgroundColor
        case "font-weight":
          if let weight = Int(value) {
            self.bold = weight >= 600
          } else if value == "bold" || value == "bolder" {
            self.bold = true
          } else if value == "normal" || value == "lighter" {
            self.bold = false
          }
        case "font-style":
          if value == "italic" || value.hasPrefix("oblique") {
            self.italic = true
          } else if value == "normal" {
            self.italic = false
          }
        case "text-decoration":
          if value == "none" {
            self.underline = false
            self.strikethrough = false
          } else {
            if value.contains("underline") {
              self.underline = true
            }
            if value.contains("line-through") {
              self.strikethrough = true
            }
          }
        default:
          break
      }
    }
  }
  
  func overridden(by inner: AnsiStyle) -> AnsiStyle {
    var result = self
    result.textColor = inner.textColor ?? self.textColor
    result.backgroundColor = inner.backgroundColor ?? self.backgroundColor
    result.bold = inner.bold ?? self.bold
    result.italic = inner.italic ?? self.italic
    result.underline = inner.underline ?? self.underline
    result.strikethrough = inner.strikethrough ?? self.strikethrough
    return result
  }
  
  /// The text properties for this style
  var properties: TextProperties {
    var styles: Set<TextStyle> = []
    if self.bold == true {
      styles.insert(.bold)
    }
    if self.italic == true {
      styles.insert(.italic)
    }
    if self.underline == true {
      styles.insert(.underline)
    }
    if self.strikethrough == true {
      styles.insert(.strikethrough)
    }
    return TextProperties(textColor: self.textColor,
                          backgroundColor: self.backgroundColor,
                          textStyles: styles)
  }
}

#endif

