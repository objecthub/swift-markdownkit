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
    var res = ""
    var pos = self.startIndex
    // find the first character that requires encoding
    while pos < self.endIndex,
          let index = self.rangeOfCharacter(from: Self.predefinedEntities,
                                            range: pos..<self.endIndex) {
      // append the range of unproblematic characters
      res.append(contentsOf: self[pos..<index.lowerBound])
      // encode the character
      switch self[index.lowerBound] {
        case "\"":
          res.append(contentsOf: "&quot;")
        case "&":
          res.append(contentsOf: "&amp;")
        case "'":
          res.append(contentsOf: "&#39;")
        case "<":
          res.append(contentsOf: "&lt;")
        case ">":
          res.append(contentsOf: "&gt;")
        default:
          res.append(self[index.lowerBound])
      }
      pos = self.index(after: index.lowerBound)
    }
    if res.isEmpty {
      return self
    } else {
      res.append(contentsOf: self[pos..<self.endIndex])
      return res
    }
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
  
  public func decodingNamedCharacters() -> String {
    var res = ""
    var pos = self.startIndex
    // find the next `&`
    while let ampPos = self.range(of: "&", range: pos..<self.endIndex) {
      res.append(contentsOf: self[pos..<ampPos.lowerBound])
      pos = ampPos.lowerBound
      // find the next ';'
      if let semiPos = self.range(of: ";", range: pos..<self.endIndex) {
        if let nextAmpPos = self.range(of: "&", range: self.index(after: pos)..<self.endIndex),
           nextAmpPos.upperBound < semiPos.upperBound {
          res.append("&")
          pos = self.index(after: ampPos.lowerBound)
        } else {
          let charRef = String(self[pos..<semiPos.upperBound])
          if let decoded = NamedCharacters.decode(entity: charRef) {
            res.append(decoded)
          } else {
            res.append(charRef)
          }
          pos = semiPos.upperBound
        }
      // no more ';'
      } else {
        break
      }
    }
    if res.isEmpty {
      return self
    } else {
      res.append(contentsOf: self[pos..<self.endIndex])
      return res
    }
  }
  
  private static let predefinedEntities: CharacterSet = {
    var set = CharacterSet()
    set.insert(charactersIn: "\"&'<>")
    return set
  }()
}
