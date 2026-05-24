//
//  Color.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 18/08/2019.
//  Copyright © 2019-2021 Google LLC.
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

extension HRColor {
  public static func from(cssName name: String) -> HRColor? {
    switch name.lowercased() {
      // Reds
      case "red":             return HRColor(red: 1.00, green: 0.00, blue: 0.00, alpha: 1)
      case "crimson":         return HRColor(red: 0.86, green: 0.08, blue: 0.24, alpha: 1)
      case "darkred":         return HRColor(red: 0.55, green: 0.00, blue: 0.00, alpha: 1)
      case "firebrick":       return HRColor(red: 0.70, green: 0.13, blue: 0.13, alpha: 1)
      case "indianred":       return HRColor(red: 0.80, green: 0.36, blue: 0.36, alpha: 1)
      case "lightcoral":      return HRColor(red: 0.94, green: 0.50, blue: 0.50, alpha: 1)
      case "salmon":          return HRColor(red: 0.98, green: 0.50, blue: 0.45, alpha: 1)
      case "tomato":          return HRColor(red: 1.00, green: 0.39, blue: 0.28, alpha: 1)
      case "orangered":       return HRColor(red: 1.00, green: 0.27, blue: 0.00, alpha: 1)
      // Oranges & Yellows
      case "orange":          return HRColor(red: 1.00, green: 0.65, blue: 0.00, alpha: 1)
      case "darkorange":      return HRColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1)
      case "yellow":          return HRColor(red: 1.00, green: 1.00, blue: 0.00, alpha: 1)
      case "gold":            return HRColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1)
      case "lightyellow":     return HRColor(red: 1.00, green: 1.00, blue: 0.88, alpha: 1)
      case "lemonchiffon":    return HRColor(red: 1.00, green: 0.98, blue: 0.80, alpha: 1)
      case "peachpuff":       return HRColor(red: 1.00, green: 0.85, blue: 0.73, alpha: 1)
      // Greens
      case "green":           return HRColor(red: 0.00, green: 0.50, blue: 0.00, alpha: 1)
      case "lime":            return HRColor(red: 0.00, green: 1.00, blue: 0.00, alpha: 1)
      case "limegreen":       return HRColor(red: 0.20, green: 0.80, blue: 0.20, alpha: 1)
      case "darkgreen":       return HRColor(red: 0.00, green: 0.39, blue: 0.00, alpha: 1)
      case "forestgreen":     return HRColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1)
      case "seagreen":        return HRColor(red: 0.18, green: 0.55, blue: 0.34, alpha: 1)
      case "mediumseagreen":  return HRColor(red: 0.24, green: 0.70, blue: 0.44, alpha: 1)
      case "springgreen":     return HRColor(red: 0.00, green: 1.00, blue: 0.50, alpha: 1)
      case "lightgreen":      return HRColor(red: 0.56, green: 0.93, blue: 0.56, alpha: 1)
      case "palegreen":       return HRColor(red: 0.60, green: 0.98, blue: 0.60, alpha: 1)
      case "olive":           return HRColor(red: 0.50, green: 0.50, blue: 0.00, alpha: 1)
      case "yellowgreen":     return HRColor(red: 0.60, green: 0.80, blue: 0.20, alpha: 1)
      // Blues
      case "blue":            return HRColor(red: 0.00, green: 0.00, blue: 1.00, alpha: 1)
      case "darkblue":        return HRColor(red: 0.00, green: 0.00, blue: 0.55, alpha: 1)
      case "mediumblue":      return HRColor(red: 0.00, green: 0.00, blue: 0.80, alpha: 1)
      case "navy":            return HRColor(red: 0.00, green: 0.00, blue: 0.50, alpha: 1)
      case "royalblue":       return HRColor(red: 0.25, green: 0.41, blue: 0.88, alpha: 1)
      case "steelblue":       return HRColor(red: 0.27, green: 0.51, blue: 0.71, alpha: 1)
      case "dodgerblue":      return HRColor(red: 0.12, green: 0.56, blue: 1.00, alpha: 1)
      case "cornflowerblue":  return HRColor(red: 0.39, green: 0.58, blue: 0.93, alpha: 1)
      case "deepskyblue":     return HRColor(red: 0.00, green: 0.75, blue: 1.00, alpha: 1)
      case "lightskyblue":    return HRColor(red: 0.53, green: 0.81, blue: 0.98, alpha: 1)
      case "lightblue":       return HRColor(red: 0.68, green: 0.85, blue: 0.90, alpha: 1)
      case "skyblue":         return HRColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1)
      case "powderblue":      return HRColor(red: 0.69, green: 0.88, blue: 0.90, alpha: 1)
      // Purples & Pinks
      case "purple":          return HRColor(red: 0.50, green: 0.00, blue: 0.50, alpha: 1)
      case "darkviolet":      return HRColor(red: 0.58, green: 0.00, blue: 0.83, alpha: 1)
      case "blueviolet":      return HRColor(red: 0.54, green: 0.17, blue: 0.89, alpha: 1)
      case "indigo":          return HRColor(red: 0.29, green: 0.00, blue: 0.51, alpha: 1)
      case "darkmagenta":     return HRColor(red: 0.55, green: 0.00, blue: 0.55, alpha: 1)
      case "magenta":         return HRColor(red: 1.00, green: 0.00, blue: 1.00, alpha: 1)
      case "fuchsia":         return HRColor(red: 1.00, green: 0.00, blue: 1.00, alpha: 1)
      case "violet":          return HRColor(red: 0.93, green: 0.51, blue: 0.93, alpha: 1)
      case "orchid":          return HRColor(red: 0.85, green: 0.44, blue: 0.84, alpha: 1)
      case "plum":            return HRColor(red: 0.87, green: 0.63, blue: 0.87, alpha: 1)
      case "pink":            return HRColor(red: 1.00, green: 0.75, blue: 0.80, alpha: 1)
      case "hotpink":         return HRColor(red: 1.00, green: 0.41, blue: 0.71, alpha: 1)
      case "deeppink":        return HRColor(red: 1.00, green: 0.08, blue: 0.58, alpha: 1)
      case "lightpink":       return HRColor(red: 1.00, green: 0.71, blue: 0.76, alpha: 1)
      // Cyans & Teals
      case "cyan":            return HRColor(red: 0.00, green: 1.00, blue: 1.00, alpha: 1)
      case "aqua":            return HRColor(red: 0.00, green: 1.00, blue: 1.00, alpha: 1)
      case "teal":            return HRColor(red: 0.00, green: 0.50, blue: 0.50, alpha: 1)
      case "darkcyan":        return HRColor(red: 0.00, green: 0.55, blue: 0.55, alpha: 1)
      case "lightcyan":       return HRColor(red: 0.88, green: 1.00, blue: 1.00, alpha: 1)
      case "turquoise":       return HRColor(red: 0.25, green: 0.88, blue: 0.82, alpha: 1)
      case "mediumturquoise": return HRColor(red: 0.28, green: 0.82, blue: 0.80, alpha: 1)
      case "aquamarine":      return HRColor(red: 0.50, green: 1.00, blue: 0.83, alpha: 1)
      // Browns
      case "brown":           return HRColor(red: 0.65, green: 0.16, blue: 0.16, alpha: 1)
      case "saddlebrown":     return HRColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1)
      case "sienna":          return HRColor(red: 0.63, green: 0.32, blue: 0.18, alpha: 1)
      case "chocolate":       return HRColor(red: 0.82, green: 0.41, blue: 0.12, alpha: 1)
      case "peru":            return HRColor(red: 0.80, green: 0.52, blue: 0.25, alpha: 1)
      case "sandybrown":      return HRColor(red: 0.96, green: 0.64, blue: 0.38, alpha: 1)
      case "burlywood":       return HRColor(red: 0.87, green: 0.72, blue: 0.53, alpha: 1)
      case "tan":             return HRColor(red: 0.82, green: 0.71, blue: 0.55, alpha: 1)
      case "wheat":           return HRColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 1)
      case "moccasin":        return HRColor(red: 1.00, green: 0.89, blue: 0.71, alpha: 1)
      // Whites & Light Grays
      case "white":           return HRColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1)
      case "snow":            return HRColor(red: 1.00, green: 0.98, blue: 0.98, alpha: 1)
      case "ivory":           return HRColor(red: 1.00, green: 1.00, blue: 0.94, alpha: 1)
      case "floralwhite":     return HRColor(red: 1.00, green: 0.98, blue: 0.94, alpha: 1)
      case "ghostwhite":      return HRColor(red: 0.97, green: 0.97, blue: 1.00, alpha: 1)
      case "whitesmoke":      return HRColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1)
      case "seashell":        return HRColor(red: 1.00, green: 0.96, blue: 0.93, alpha: 1)
      case "honeydew":        return HRColor(red: 0.94, green: 1.00, blue: 0.94, alpha: 1)
      case "mintcream":       return HRColor(red: 0.96, green: 1.00, blue: 0.98, alpha: 1)
      case "azure":           return HRColor(red: 0.94, green: 1.00, blue: 1.00, alpha: 1)
      case "aliceblue":       return HRColor(red: 0.94, green: 0.97, blue: 1.00, alpha: 1)
      case "lavender":        return HRColor(red: 0.90, green: 0.90, blue: 0.98, alpha: 1)
      case "lavenderblush":   return HRColor(red: 1.00, green: 0.94, blue: 0.96, alpha: 1)
      case "mistyrose":       return HRColor(red: 1.00, green: 0.89, blue: 0.88, alpha: 1)
      case "linen":           return HRColor(red: 0.98, green: 0.94, blue: 0.90, alpha: 1)
      case "oldlace":         return HRColor(red: 0.99, green: 0.96, blue: 0.90, alpha: 1)
      case "antiquewhite":    return HRColor(red: 0.98, green: 0.92, blue: 0.84, alpha: 1)
      case "bisque":          return HRColor(red: 1.00, green: 0.89, blue: 0.77, alpha: 1)
      case "blanchedalmond":  return HRColor(red: 1.00, green: 0.92, blue: 0.80, alpha: 1)
      case "cornsilk":        return HRColor(red: 1.00, green: 0.97, blue: 0.86, alpha: 1)
      case "papayawhip":      return HRColor(red: 1.00, green: 0.94, blue: 0.84, alpha: 1)
      // Grays & Black
      case "black":           return HRColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1)
      case "darkgray",
           "darkgrey":        return HRColor(red: 0.66, green: 0.66, blue: 0.66, alpha: 1)
      case "gray", "grey":    return HRColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1)
      case "lightgray",
           "lightgrey":       return HRColor(red: 0.83, green: 0.83, blue: 0.83, alpha: 1)
      case "silver":          return HRColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1)
      case "gainsboro":       return HRColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1)
      case "dimgray",
           "dimgrey":         return HRColor(red: 0.41, green: 0.41, blue: 0.41, alpha: 1)
      case "slategray",
           "slategrey":       return HRColor(red: 0.44, green: 0.50, blue: 0.56, alpha: 1)
      case "lightslategray",
           "lightslategrey":  return HRColor(red: 0.47, green: 0.53, blue: 0.60, alpha: 1)
      // Special
      case "transparent":     return HRColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 0)
      default:                return nil
    }
  }
  
  public static func from(cssColor: String) -> HRColor? {
    var colorString = cssColor.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    func substring(_ lowerBound: Int, _ upperBound: Int) -> String {
      let start = colorString.index(colorString.startIndex, offsetBy: lowerBound)
      let end = colorString.index(colorString.startIndex, offsetBy: upperBound)
      return String(colorString[start..<end])
    }
    guard colorString.hasPrefix("#") else {
      return Self.from(cssName: colorString)
    }
    colorString = substring(1, colorString.count)
    guard colorString.count == 8 || colorString.count == 6 || colorString.count == 3 else {
      return nil
    }
    var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0, a: UInt64 = 0
    var alpha: CGFloat = 1.0
    let divisor: CGFloat
    if colorString.count == 6 || colorString.count == 8 {
      Scanner(string: substring(0, 2)).scanHexInt64(&r)
      Scanner(string: substring(2, 4)).scanHexInt64(&g)
      Scanner(string: substring(4, 6)).scanHexInt64(&b)
      divisor = 255.0
      if colorString.count == 8 {
        Scanner(string: substring(6, 8)).scanHexInt64(&a)
        alpha = CGFloat(a) / divisor
      }
    } else {
      Scanner(string: substring(0, 1)).scanHexInt64(&r)
      Scanner(string: substring(1, 2)).scanHexInt64(&g)
      Scanner(string: substring(2, 3)).scanHexInt64(&b)
      divisor = 15.0
    }
    return HRColor(red: CGFloat(r) / divisor,
                   green: CGFloat(g) / divisor,
                   blue: CGFloat(b) / divisor,
                   alpha: alpha)
  }
}

#if os(iOS) || os(watchOS) || os(tvOS)

  import UIKit

  extension UIColor {
    
    public var hexString: String {
      guard let components = self.cgColor.components else {
        return "#FFFFFF"
      }
      var red = 0
      var green = 0
      var blue = 0
      if components.count >= 3 {
        red = Int(round(components[0] * 0xff))
        green = Int(round(components[1] * 0xff))
        blue = Int(round(components[2] * 0xff))
      } else if components.count >= 1 {
        red = Int(round(components[0] * 0xff))
        green = Int(round(components[0] * 0xff))
        blue = Int(round(components[0] * 0xff))
      }
      return String(format: "#%02X%02X%02X", red, green, blue)
    }
    
    public var hexStringWithAlpha: String {
      guard let components = self.cgColor.components else {
        return "#FFFFFFFF"
      }
      var red = 0
      var green = 0
      var blue = 0
      var alpha = 0xff
      if components.count >= 3 {
        red = Int(round(components[0] * 0xff))
        green = Int(round(components[1] * 0xff))
        blue = Int(round(components[2] * 0xff))
        if components.count >= 4 {
          alpha = Int(round(components[3] * 0xff))
        }
      } else if components.count >= 1 {
        red = Int(round(components[0] * 0xff))
        green = Int(round(components[0] * 0xff))
        blue = Int(round(components[0] * 0xff))
      }
      return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }
  }

#elseif os(macOS)

  import Cocoa

  extension NSColor {

    public var hexString: String {
      guard let rgb = self.usingColorSpace(NSColorSpace.deviceRGB) else {
        return "#FFFFFF"
      }
      let red   = Int(round(rgb.redComponent * 0xff))
      let green = Int(round(rgb.greenComponent * 0xff))
      let blue  = Int(round(rgb.blueComponent * 0xff))
      return String(format: "#%02X%02X%02X", red, green, blue)
    }
    
    public var hexStringWithAlpha: String {
      guard let rgb = self.usingColorSpace(NSColorSpace.deviceRGB) else {
        return "#FFFFFFFF"
      }
      let red   = Int(round(rgb.redComponent * 0xff))
      let green = Int(round(rgb.greenComponent * 0xff))
      let blue  = Int(round(rgb.blueComponent * 0xff))
      let alpha = Int(round(rgb.alphaComponent * 0xff))
      return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }
  }

  public let mdDefaultColor = NSColor.textColor.hexString
  public let mdDefaultBackgroundColor = NSColor.textBackgroundColor.hexString

#endif

#if os(iOS)

  public let mdDefaultColor = UIColor.label.hexString
  public let mdDefaultBackgroundColor = UIColor.systemBackground.hexString

#elseif os(tvOS)

  public let mdDefaultColor = UIColor.label.hexString
  public let mdDefaultBackgroundColor = UIColor.white.hexString

#elseif os(watchOS)

  public let mdDefaultColor = UIColor.black.hexString
  public let mdDefaultBackgroundColor = UIColor.white.hexString

#endif
