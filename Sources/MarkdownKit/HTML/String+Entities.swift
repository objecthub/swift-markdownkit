//
//  String+Entities.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 13/02/2021.
//  Copyright © 2021 Google LLC.
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

extension String {
  
  public func encodingPredefinedXmlEntities() -> String {
    // Work on UTF-8 bytes: the special characters are ASCII, which never occurs inside of
    // multi-byte sequences. In particular, this also escapes special characters which are
    // followed by combining marks (they form a single `Character` together).
    let utf8 = self.utf8
    guard utf8.contains(where: String.isPredefinedEntityByte) else {
      return self
    }
    var res = [UInt8]()
    res.reserveCapacity(utf8.count + utf8.count / 8 + 16)
    for byte in utf8 {
      switch byte {
        case UInt8(ascii: "\""):
          res.append(contentsOf: String.quotEntity)
        case UInt8(ascii: "&"):
          res.append(contentsOf: String.ampEntity)
        case UInt8(ascii: "'"):
          res.append(contentsOf: String.aposEntity)
        case UInt8(ascii: "<"):
          res.append(contentsOf: String.ltEntity)
        case UInt8(ascii: ">"):
          res.append(contentsOf: String.gtEntity)
        default:
          res.append(byte)
      }
    }
    return String(decoding: res, as: UTF8.self)
  }
  
  public func encodingNamedCharacters() -> String {
    var res = ""
    for ch in self {
      if let charRef = NamedCharacters.characterNameMap[ch] {
        res.append(contentsOf: charRef)
      } else {
        res.append(ch)
      }
    }
    return res
  }
  
  /// Longest sequence of bytes between `&` and `;` that can be an entity (the longest named
  /// entity is `&CounterClockwiseContourIntegral;`, which has 33 bytes in total).
  private static let maxEntityLength = 40

  public func decodingNamedCharacters() -> String {
    let utf8 = self.utf8
    guard utf8.contains(UInt8(ascii: "&")) else {
      return self
    }
    var res = [UInt8]()
    res.reserveCapacity(utf8.count)
    var i = utf8.startIndex
    var literalStart = i
    while i < utf8.endIndex {
      guard utf8[i] == UInt8(ascii: "&") else {
        i = utf8.index(after: i)
        continue
      }
      // Look for the `;` terminating an entity; a `&` before it makes this `&` a literal
      var j = utf8.index(after: i)
      var length = 1
      var end: String.Index? = nil
      while j < utf8.endIndex && length <= String.maxEntityLength {
        let byte = utf8[j]
        if byte == UInt8(ascii: ";") {
          end = utf8.index(after: j)
          break
        } else if byte == UInt8(ascii: "&") {
          break
        }
        j = utf8.index(after: j)
        length += 1
      }
      if let end = end,
         let decoded = NamedCharacters.decode(entity: String(self[i..<end])) {
        res.append(contentsOf: utf8[literalStart..<i])
        res.append(contentsOf: String(decoded).utf8)
        i = end
        literalStart = end
      } else {
        // Not an entity: this `&` is literal; continue scanning right after it
        i = utf8.index(after: i)
      }
    }
    if literalStart == utf8.startIndex {
      return self
    }
    res.append(contentsOf: utf8[literalStart..<utf8.endIndex])
    return String(decoding: res, as: UTF8.self)
  }
  
  private static let quotEntity: [UInt8] = Array("&quot;".utf8)
  private static let ampEntity: [UInt8] = Array("&amp;".utf8)
  private static let aposEntity: [UInt8] = Array("&#39;".utf8)
  private static let ltEntity: [UInt8] = Array("&lt;".utf8)
  private static let gtEntity: [UInt8] = Array("&gt;".utf8)

  private static func isPredefinedEntityByte(_ byte: UInt8) -> Bool {
    switch byte {
      case UInt8(ascii: "\""), UInt8(ascii: "&"), UInt8(ascii: "'"), UInt8(ascii: "<"),
           UInt8(ascii: ">"):
        return true
      default:
        return false
    }
  }
}
