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
/// `AnsiHighlighterConfig` parses CSS theme files and maps color and style information
/// to ANSI terminal escape sequences using the CommandLineKit framework. This allows
/// syntax highlighting to be displayed in terminal applications.
///
/// Example usage:
/// ```swift
/// if let config = AnsiHighlighterConfig(withTheme: "monokai") {
///   let ansiString = highlighter.asAnsiTerminalString(html, using: config)
///   print(ansiString ?? "")
/// }
/// ```
///
public class AnsiHighlightingConfig {
  private var strippedTheme: [String : [String: String]]
  private var styleDict: [String : TextProperties]
  
  /// Creates a new ANSI highlighter configuration from a theme name or CSS content.
  ///
  /// - Parameter withTheme: Either the name of a bundled theme (without `.css` extension),
  ///                        or raw CSS content to parse.
  ///
  /// - Returns: A configured `AnsiHighlighterConfig` instance, or `nil` if the theme
  ///            cannot be loaded or parsed.
  ///
  /// Example:
  /// ```swift
  /// // Load a bundled theme
  /// let config1 = AnsiHighlighterConfig(withTheme: "monokai")
  ///
  /// // Use custom CSS
  /// let css = ".hljs { color: #ffffff; } .hljs-keyword { color: #ff0000; font-weight: bold; }"
  /// let config2 = AnsiHighlighterConfig(withTheme: css)
  /// ```
  public init?(withTheme nameOrContent: String, fullColorSupport: Bool) {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: SyntaxHighlighter.self)
    #endif
    let content: String
    if nameOrContent.count < 80,
       let path = bundle.path(forResource: nameOrContent, ofType: "css"),
       let loadedContent = try? String(contentsOfFile: path) {
      content = loadedContent
    } else if SyntaxHighlighter.proxy?.isValidCSS(nameOrContent) == true {
      content = nameOrContent
    } else {
      return nil
    }
    // Parse the CSS theme
    self.strippedTheme = HighlightingConfig.stripTheme(content)
    self.styleDict = [String : TextProperties]()
    // Convert CSS properties to ANSI text properties
    for (className, props) in self.strippedTheme {
      var textColor: TextColor? = nil
      var backgroundColor: BackgroundColor? = nil
      var styles: Set<TextStyle> = []
      for (key, prop) in props {
        switch key {
          case "color":
            textColor =
                Self.cssColorToAnsiColor(prop, fullColorSupport: fullColorSupport) ?? textColor
          case "background-color":
            backgroundColor =
                Self.cssColorToAnsiBackgroundColor(prop, fullColorSupport: fullColorSupport) ??
                backgroundColor
          case "font-style":
            switch prop {
              case "italic", "oblique":
                styles.insert(.italic)
              default:
                break
            }
          case "font-weight":
            switch prop {
              case "bold", "bolder", "600", "700", "800", "900":
                styles.insert(.bold)
              default:
                break
            }
          case "text-decoration":
            if prop.contains("underline") {
              styles.insert(.underline)
            }
            if prop.contains("line-through") {
              styles.insert(.strikethrough)
            }
          default:
            break
        }
      }
      let key = className.replacingOccurrences(of: ".", with: "")
      self.styleDict[key] = TextProperties(textColor: textColor,
                                          backgroundColor: backgroundColor,
                                          textStyles: styles)
    }
  }
  
  /// Applies styling to a string based on a list of CSS class names.
  ///
  /// - Parameters:
  ///   - string: The text to style.
  ///   - styleList: An array of CSS class names (without the leading dot).
  ///
  /// - Returns: An `AnsiText.Normalized` value with the appropriate styling applied.
  public func apply(to string: String, styleList: [String]) -> AnsiText.Normalized {
    var properties = TextProperties.empty
    for style in styleList {
      if let themeStyle = self.styleDict[style] {
        properties = properties.with(themeStyle)
      }
    }
    return AnsiText.Normalized(string, properties: properties)
  }
  
  /// Converts a CSS color string to an ANSI `TextColor`.
  private static func cssColorToAnsiColor(_ cssColor: String,
                                          fullColorSupport: Bool) -> TextColor? {
    if let color = HRColor.from(cssColor: cssColor) {
      return Self.approximateAnsiColor(color, fullColorSupport: fullColorSupport)
    }
    return nil
  }
  
  /// Converts a CSS color string to an ANSI `BackgroundColor`.
  private static func cssColorToAnsiBackgroundColor(_ cssColor: String,
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

#endif

