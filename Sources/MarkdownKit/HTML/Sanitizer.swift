//
//  Sanitizer.swift
//  MarkdownKit
//
//  Created on 06/10/2026.
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

import Foundation

///
/// Helpers for making Markdown content safe to embed into HTML attributes and terminal output.
///
enum Sanitizer {

  /// Returns `str` as it can be embedded into a double-quoted HTML attribute. Entities in `str`
  /// get decoded before the result is encoded again, which mirrors how text is treated.
  static func attribute(_ str: String) -> String {
    return str.decodingNamedCharacters().encodingPredefinedXmlEntities()
  }

  /// Returns the language name that is used for the `class` attribute of a code block, or `nil`
  /// if the info string does not contain a usable one. Only the first word of the info string
  /// is considered and only characters that cannot break out of an attribute are kept.
  static func languageClass(for info: String) -> String? {
    let word = info.split(whereSeparator: { $0.isWhitespace }).first ?? ""
    let name = String(word.unicodeScalars.filter(Sanitizer.isLanguageScalar))
    return name.isEmpty ? nil : name
  }

  private static func isLanguageScalar(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar {
      case "a"..."z", "A"..."Z", "0"..."9", "_", "+", "#", ".", "-":
        return true
      default:
        return false
    }
  }

  private static let allowedSchemes: Set<String> = ["http", "https", "mailto"]
  private static let allowedImageSchemes: Set<String> = ["http", "https"]
  private static let allowedImageDataPrefixes = ["data:image/png", "data:image/gif",
                                                 "data:image/jpeg", "data:image/webp"]

  /// Returns true if the given (entity-decoded) URL is considered safe to link to or, if
  /// `image` is true, to load as image. Relative URLs are safe; absolute URLs need to use
  /// one of a small set of schemes.
  static func isSafeURL(_ url: String, image: Bool = false) -> Bool {
    // Browsers ignore whitespace and control characters when determining the scheme.
    let cleaned = String(String.UnicodeScalarView(
                           url.unicodeScalars.filter { $0.value > 0x20 && $0.value != 0x7F }))
                    .lowercased()
    var scheme = ""
    for ch in cleaned {
      if ch == ":" {
        if image && Sanitizer.allowedImageDataPrefixes.contains(where: { cleaned.hasPrefix($0) }) {
          return true
        }
        return (image ? Sanitizer.allowedImageSchemes : Sanitizer.allowedSchemes).contains(scheme)
      } else if ch == "/" || ch == "?" || ch == "#" {
        return true
      } else {
        scheme.append(ch)
      }
    }
    return true
  }
}

extension String {

  /// Returns a copy of this string in which control characters that can be abused for
  /// manipulating terminals are replaced with U+FFFD. These are C0 controls (except tab and
  /// newline), DEL, C1 controls, and the bidirectional embedding, override and isolate
  /// characters.
  func sanitizingControlCharacters() -> String {
    guard self.unicodeScalars.contains(where: String.isUnsafeScalar) else {
      return self
    }
    var res = String.UnicodeScalarView()
    for scalar in self.unicodeScalars {
      res.append(String.isUnsafeScalar(scalar) ? "\u{FFFD}" : scalar)
    }
    return String(res)
  }

  private static func isUnsafeScalar(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
      case 0x09, 0x0A:
        return false
      case 0x00...0x1F, 0x7F...0x9F, 0x202A...0x202E, 0x2066...0x2069:
        return true
      default:
        return false
    }
  }
}
