//
//  EscapeTransformer.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 18/10/2019.
//  Copyright © 2019 Google LLC.
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
/// An inline transformer which removes backslash escapes.
///
open class EscapeTransformer: InlineTransformer {

  public override func transform(_ fragment: TextFragment,
                                 from iterator: inout Text.Iterator,
                                 into res: inout Text) -> TextFragment? {
    switch fragment {
      case .text(let str):
        // An escaped delimiter (e.g. a backtick) is not part of the preceding text. In this
        // case, the backslash at the end of the text is the escape character.
        var lookahead = iterator
        var escapesNext = false
        if case .some(.delimiter(_, _, let type)) = lookahead.next() {
          escapesNext = type.contains(.escaped)
        }
        res.append(fragment: .text(self.resolveEscapes(str, escapesNext: escapesNext)))
      case .link(let inner, let uri, let title):
        res.append(fragment: .link(self.transform(inner),
                                   self.resolveEscapes(uri),
                                   self.resolveEscapes(title)))
      case .image(let inner, let uri, let title):
        res.append(fragment: .image(self.transform(inner),
                                    self.resolveEscapes(uri),
                                    self.resolveEscapes(title)))
      default:
        return super.transform(fragment, from: &iterator, into: &res)
    }
    return iterator.next()
  }

  private func resolveEscapes(_ str: String?) -> String? {
    if let str = str {
      return String(self.resolveEscapes(Substring(str), escapesNext: false))
    } else {
      return nil
    }
  }

  /// Removes backslashes which escape ASCII punctuation characters. Backslashes in front of
  /// any other character, or at the end of the text, are literal backslashes. If `escapesNext`
  /// is true, a backslash at the end of the text is removed because it escapes the delimiter
  /// following this text.
  private func resolveEscapes(_ str: Substring, escapesNext: Bool) -> Substring {
    guard !str.isEmpty else {
      return str
    }
    var res: String? = nil
    var i = str.startIndex
    while i < str.endIndex {
      if str[i] == "\\" {
        let next = str.index(after: i)
        if next < str.endIndex {
          guard isAsciiPunctuation(str[next]) else {
            // literal backslash
            res?.append("\\")
            i = next
            continue
          }
          if res == nil {
            res = String(str[str.startIndex..<i])
          }
          if str[next] == "&" && self.startsEntity(str, at: next) {
            // An escaped `&` must not start an entity reference. Entities get decoded when
            // generating output; `&amp;` decodes to a single `&`.
            res!.append("&amp;")
          } else {
            res!.append(str[next])
          }
          i = str.index(after: next)
          continue
        } else if escapesNext {
          if res == nil {
            res = String(str[str.startIndex..<i])
          }
          break
        }
      }
      res?.append(str[i])
      i = str.index(after: i)
    }
    guard res == nil else {
      return Substring(res!)
    }
    return str
  }

  /// Returns true if there is something that looks like an entity reference (e.g. `&ouml;` or
  /// `&#35;`) starting at the ampersand at `start`.
  private func startsEntity(_ str: Substring, at start: Substring.Index) -> Bool {
    var i = str.index(after: start)
    var length = 0
    while i < str.endIndex && length <= 32 {
      let ch = str[i]
      if ch == ";" {
        return length > 0
      } else if ch.isASCII && (ch.isLetter || ch.isNumber || (ch == "#" && length == 0)) {
        length += 1
        i = str.index(after: i)
      } else {
        return false
      }
    }
    return false
  }
}
