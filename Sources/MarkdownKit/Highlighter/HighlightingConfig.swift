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

import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

///
/// Theme objects used for generating attributed strings.
/// 
public class HighlightingConfig {
  public var codeFont: HRFont
  public var boldCodeFont: HRFont
  public var italicCodeFont: HRFont
  public var themeBackgroundColor: HRColor
  public var lineSpacing: CGFloat = 0.0
  public var paraSpacing: CGFloat = 0.0
  public var fontSize: CGFloat = 18.0
  public let theme: String
  public let lightTheme: String
  private var strippedTheme: [String : [String: String]]
  private var themeDict: [String : [AnyHashable: AnyObject]]
  
  public init(withTheme: String, usingFont: HRFont) {
    // Store the theme content
    self.theme = withTheme
    // Apply the font choice
    let font = usingFont
    // Store the primary font choice
    self.codeFont = font
    self.fontSize = font.pointSize
    // Generate the bold and italic variants
    #if os(iOS) || os(tvOS) || os(visionOS)
    let boldDescriptor = UIFontDescriptor(fontAttributes: [ 
      UIFontDescriptor.AttributeName.family : font.familyName,
      UIFontDescriptor.AttributeName.face : "Bold"
    ])
    let italicDescriptor  = UIFontDescriptor(fontAttributes: [ 
      UIFontDescriptor.AttributeName.family : font.familyName,
      UIFontDescriptor.AttributeName.face : "Italic"
    ])
    let obliqueDescriptor = UIFontDescriptor(fontAttributes: [ 
      UIFontDescriptor.AttributeName.family : font.familyName,
      UIFontDescriptor.AttributeName.face : "Oblique"
    ])
    self.boldCodeFont = HRFont(descriptor: boldDescriptor, size: font.pointSize)
    self.italicCodeFont = HRFont(descriptor: italicDescriptor, size: font.pointSize)
    #else
    let boldDescriptor = NSFontDescriptor(fontAttributes: [.family : font.familyName!,
                                                           .face : "Bold"])
    let italicDescriptor = NSFontDescriptor(fontAttributes: [.family : font.familyName!,
                                                             .face : "Italic"])
    let obliqueDescriptor = NSFontDescriptor(fontAttributes: [.family : font.familyName!,
                                                              .face : "Oblique"])
    self.boldCodeFont = HRFont(descriptor: boldDescriptor, size: font.pointSize) ?? font
    self.italicCodeFont = HRFont(descriptor: italicDescriptor, size: font.pointSize) ??
                          HRFont(descriptor: obliqueDescriptor, size: font.pointSize) ?? font
    #endif
    // Generate and store the theme variants
    self.strippedTheme = Self.stripTheme(self.theme)
    self.lightTheme = Self.strippedThemeToString(self.strippedTheme)
    self.themeDict = [String : [AnyHashable: AnyObject]]()
    for (className, props) in self.strippedTheme {
      var keyProps = [NSAttributedString.Key : AnyObject]()
      for (key, prop) in props {
        switch key {
          case "color":
            keyProps[Self.attributeForCSSKey(key)] = HRColor.from(cssColor: prop)
          case "font-style", "font-weight":
            switch prop {
              case "bold", "bolder", "600", "700", "800", "900":
                keyProps[Self.attributeForCSSKey(key)] = self.boldCodeFont
              case "italic", "oblique":
                keyProps[Self.attributeForCSSKey(key)] = self.italicCodeFont
              default:
                keyProps[Self.attributeForCSSKey(key)] = self.codeFont
            }
          case "background-color":
            keyProps[Self.attributeForCSSKey(key)] = HRColor.from(cssColor: prop)
          default:
            break
        }
      }
      if keyProps.count > 0 {
        let key = className.replacingOccurrences(of: ".", with: "")
        self.themeDict[key] = keyProps
      }
    }
    // Set a background color
    let backgroundColor: String? = self.strippedTheme[".hljs"]?["background"] ??
                                   self.strippedTheme[".hljs"]?["background-color"]
    if let backgroundColor {
      self.themeBackgroundColor = HRColor.from(cssColor: backgroundColor) ?? HRColor.clear
    } else {
      self.themeBackgroundColor = HRColor.white
    }
  }
  
  public func apply(to string: String, styleList: [String]) -> NSAttributedString {
    let spacedParaStyle = NSMutableParagraphStyle()
    spacedParaStyle.lineSpacing = self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0
    spacedParaStyle.paragraphSpacing = self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0
    if styleList.count > 0 {
      var attrs = [NSAttributedString.Key : Any]()
      attrs[.font] = self.codeFont
      attrs[.paragraphStyle] = spacedParaStyle
      for style in styleList {
        if let themeStyle = self.themeDict[style] as? [NSAttributedString.Key : Any] {
          for (attrName, attrValue) in themeStyle {
            attrs.updateValue(attrValue, forKey: attrName)
          }
        }
      }
      return NSAttributedString(string: string, attributes: attrs)
    } else {
      return NSAttributedString(string: string,
                                attributes:[.font: codeFont, .paragraphStyle: spacedParaStyle])
    }
  }
  
  internal static func stripTheme(_ themeString : String) -> [String : [String: String]] {
    let objcString: NSString = (themeString as NSString)
    let cssRegex = try! NSRegularExpression(
      pattern: "(?:(\\.[a-zA-Z0-9\\-_]*(?:[, ]\\.[a-zA-Z0-9\\-_]*)*)\\{([^\\}]*?)\\})",
      options:[.caseInsensitive]
    )
    let results = cssRegex.matches(in: themeString,
                                   options: [.reportCompletion],
                                   range: NSMakeRange(0, objcString.length))
    var resultDict = [String: [String: String]]()
    for result in results {
      if result.numberOfRanges == 3 {
        var attributes = [String:String]()
        let cssPairs = objcString.substring(with: result.range(at: 2)).components(separatedBy: ";")
        for pair in cssPairs {
          let cssPropComp = pair.components(separatedBy: ":")
          if (cssPropComp.count == 2) {
            attributes[cssPropComp[0]] = cssPropComp[1]
          }
        }
        if attributes.count > 0 {
          let key = objcString.substring(with: result.range(at: 1))
          if let existingAttributes = resultDict[key] {
            resultDict[key] = existingAttributes.merging(attributes,
                                                         uniquingKeysWith: { (first, _) in first })
          } else {
            resultDict[key] = attributes
          }
        }
      }
    }
    var returnDict: [String: [String: String]] = [:]
    for (keys, result) in resultDict {
      let keyArray = keys.replacingOccurrences(of: " ", with: ",").components(separatedBy: ",")
      for key in keyArray {
        var props = returnDict[key] ?? [String : String]()
        for (pName, pValue) in result {
          props.updateValue(pValue, forKey: pName)
        }
        returnDict[key] = props
      }
    }
    return returnDict
  }
  
  private static func strippedThemeToString(_ themeStringDict: [String : [String: String]]) -> String {
    var resultString: String = ""
    for (key, props) in themeStringDict {
      resultString += key + "{"
      for (cssProp, val) in props {
        if key != ".hljs" ||
           (cssProp.lowercased() != "background-color" && cssProp.lowercased() != "background") {
          resultString += "\(cssProp):\(val);"
        }
      }
      resultString += "}"
    }
    return resultString
  }
  
  private static func attributeForCSSKey(_ key: String) -> NSAttributedString.Key {
    switch key {
      case "color":
        return .foregroundColor
      case "font-weight":
        return .font
      case "font-style":
        return .font
      case "background-color":
        return .backgroundColor
      default:
        return .font
    }
  }
}
