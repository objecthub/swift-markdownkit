//
//  HighlightingConfig.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 23/05/2026.
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

#if !os(watchOS)

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

///
/// Theme objects used for generating attributed strings.
///
/// A theme is a CSS style sheet with rules for the classes that highlight.js assigns to the
/// parts of highlighted code, such as `.hljs-keyword{color:#f00;font-weight:bold}`. The
/// selectors of the rules consist of classes: `.a`, `.a.b`, descendant selectors (`.a .b`)
/// and child selectors (`.a > .b`). The cascade follows CSS: a rule with a higher specificity
/// (more classes) wins over one with a lower specificity, otherwise the last rule wins.
/// The properties `color`, `background-color`, `font-weight` and `font-style` are used.
///
/// `HighlightingConfig` is a value type: copies are independent of each other, so changing a
/// property of a copy never affects a generator which uses the original. It conforms to
/// `Sendable`; the conformance is `@unchecked` only because `NSFont` is not marked as
/// `Sendable` on macOS (fonts and colors are immutable).
///
/// The properties can be changed after creating a config. These properties influence how
/// `apply` styles text, and changes take effect immediately: the fonts `codeFont`,
/// `boldCodeFont`, `italicCodeFont` and `boldItalicCodeFont` (they are looked up when text
/// gets styled), `lineSpacing` and `paraSpacing`. The properties `themeBackgroundColor` and
/// `fontSize` are information for clients; `apply` does not use them.
/// 
public struct HighlightingConfig: @unchecked Sendable {
  public var codeFont: HRFont
  public var boldCodeFont: HRFont
  public var italicCodeFont: HRFont
  public var boldItalicCodeFont: HRFont
  
  /// The background color of the theme: the `background` (or `background-color`) of its `.hljs`
  /// rule, `clear` if that is not a color (such as a gradient), and white if there is none.
  /// It is meant for clients which draw the background of a code block. `apply` does not use
  /// it, so changing it does not change the attributed strings.
  public var themeBackgroundColor: HRColor
  
  public var lineSpacing: CGFloat = 0.0
  public var paraSpacing: CGFloat = 0.0
  
  /// The point size of the font which the config was created with. It is information for
  /// clients. `apply` does not use it, so changing it does not resize any font.
  public var fontSize: CGFloat = 18.0
  
  public let theme: String
  public let lightTheme: String
  private let styleSheet: ThemeStyleSheet<HighlightStyle>
  
  public init(withTheme: String, usingFont: HRFont) {
    // Store the theme content
    self.theme = withTheme
    // Apply the font choice
    let font = usingFont
    // Store the primary font choice
    self.codeFont = font
    self.fontSize = font.pointSize
    // Generate the bold and italic variants
    let boldFont: HRFont
    let italicFont: HRFont
    let boldItalicFont: HRFont
    #if os(iOS) || os(tvOS) || os(visionOS)
    let boldDescriptor = UIFontDescriptor(fontAttributes: [ 
      UIFontDescriptor.AttributeName.family : font.familyName,
      UIFontDescriptor.AttributeName.face : "Bold"
    ])
    let italicDescriptor  = UIFontDescriptor(fontAttributes: [ 
      UIFontDescriptor.AttributeName.family : font.familyName,
      UIFontDescriptor.AttributeName.face : "Italic"
    ])
    boldFont = HRFont(descriptor: boldDescriptor, size: font.pointSize)
    italicFont = HRFont(descriptor: italicDescriptor, size: font.pointSize)
    if let descriptor = font.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
      boldItalicFont = HRFont(descriptor: descriptor, size: font.pointSize)
    } else {
      boldItalicFont = boldFont
    }
    #else
    let familyName = font.familyName ?? font.fontName
    let boldDescriptor = NSFontDescriptor(fontAttributes: [.family : familyName,
                                                           .face : "Bold"])
    let italicDescriptor = NSFontDescriptor(fontAttributes: [.family : familyName,
                                                             .face : "Italic"])
    let obliqueDescriptor = NSFontDescriptor(fontAttributes: [.family : familyName,
                                                              .face : "Oblique"])
    boldFont = HRFont(descriptor: boldDescriptor, size: font.pointSize) ?? font
    italicFont = HRFont(descriptor: italicDescriptor, size: font.pointSize) ??
                 HRFont(descriptor: obliqueDescriptor, size: font.pointSize) ?? font
    boldItalicFont = HRFont(descriptor: font.fontDescriptor.withSymbolicTraits([.bold, .italic]),
                            size: font.pointSize) ?? boldFont
    #endif
    self.boldCodeFont = boldFont
    self.italicCodeFont = italicFont
    self.boldItalicCodeFont = boldItalicFont
    // Parse the theme
    let styleSheet = ThemeStyleSheet<HighlightStyle>(css: withTheme) { HighlightStyle(declarations: $0) }
    self.styleSheet = styleSheet
    // The background of the code block is determined separately, so it is not part of the CSS
    // for rendering the code as HTML.
    self.lightTheme = styleSheet.css { rule, declaration in
      rule.selector.text != ".hljs" || (declaration.name != "background-color" &&
                                        declaration.name != "background")
    }
    // Set a background color
    self.themeBackgroundColor = styleSheet.style(forClasses: ["hljs"]).blockBackground ??
                                HRColor.white
  }
  
  public func apply(to string: String, styleList: [String]) -> NSAttributedString {
    let spacedParaStyle = NSMutableParagraphStyle()
    spacedParaStyle.lineSpacing = self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0
    spacedParaStyle.paragraphSpacing = self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0
    if styleList.count > 0 {
      let style = self.styleSheet.style(forClasses: styleList)
      var attrs = [NSAttributedString.Key : Any]()
      switch (style.bold ?? false, style.italic ?? false) {
        case (true, true):
          attrs[.font] = self.boldItalicCodeFont
        case (true, false):
          attrs[.font] = self.boldCodeFont
        case (false, true):
          attrs[.font] = self.italicCodeFont
        case (false, false):
          attrs[.font] = self.codeFont
      }
      attrs[.paragraphStyle] = spacedParaStyle
      if let foreground = style.foreground {
        attrs[.foregroundColor] = foreground
      }
      if let background = style.background {
        attrs[.backgroundColor] = background
      }
      return NSAttributedString(string: string, attributes: attrs)
    } else {
      return NSAttributedString(string: string,
                                attributes:[.font: codeFont, .paragraphStyle: spacedParaStyle])
    }
  }
}

/// The style of text in code which is rendered as an attributed string.
fileprivate struct HighlightStyle: ThemeStyle {
  /// `color`
  var foreground: HRColor? = nil
  /// `background-color`
  var background: HRColor? = nil
  /// `background` or `background-color`. This is used for the background of the whole code
  /// block (the color is `clear` if the value is not a color, e.g. a gradient).
  var blockBackground: HRColor? = nil
  /// `font-weight`: bold or not
  var bold: Bool? = nil
  /// `font-style`: italic or not
  var italic: Bool? = nil
  
  init() {}
  
  /// Creates the style for a rule; properties with values that are not understood are ignored.
  init(declarations: [ThemeDeclaration]) {
    for declaration in declarations {
      let value = declaration.value
      switch declaration.name {
        case "color":
          self.foreground = HRColor.from(cssColor: value) ?? self.foreground
        case "background-color":
          self.background = HRColor.from(cssColor: value) ?? self.background
          self.blockBackground = HRColor.from(cssColor: value) ?? HRColor.clear
        case "background":
          self.blockBackground = HRColor.from(cssColor: value) ?? HRColor.clear
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
        default:
          break
      }
    }
  }
  
  func overridden(by inner: HighlightStyle) -> HighlightStyle {
    var result = self
    result.foreground = inner.foreground ?? self.foreground
    result.background = inner.background ?? self.background
    result.blockBackground = inner.blockBackground ?? self.blockBackground
    result.bold = inner.bold ?? self.bold
    result.italic = inner.italic ?? self.italic
    return result
  }
}

#endif
