//
//  CodeLinkHtmlTransformer.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 09/06/2019.
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
/// An inline transformer which extracts code spans, auto-links and html tags and transforms
/// them into `code`, `autolinks`, and `html` text fragments.
///
open class CodeLinkHtmlTransformer: InlineTransformer {

  /// Positions of some kinds of fragments in a `Text` object. This allows finding matching
  /// delimiters without rescanning the text for every opening delimiter (which is quadratic
  /// for texts with many unmatched delimiters).
  private struct FragmentIndex {
    /// Positions of backtick delimiters (in ascending order) by length of the backtick string
    var backticks: [Int : [Int]] = [:]
    /// For every position, the position of the next fragment which cannot be part of a code
    /// span or an inline html tag (or the number of fragments if there is none)
    var nextBarrier: [Int]
    /// For every position, the position of the next `>` delimiter (or the number of
    /// fragments if there is none)
    var nextGreater: [Int]

    init(_ text: Text) {
      let n = text.count
      self.nextBarrier = [Int](repeating: n, count: n + 1)
      self.nextGreater = [Int](repeating: n, count: n + 1)
      var i = n - 1
      while i >= 0 {
        let fragment = text[i]
        switch fragment {
          case .delimiter(let ch, let length, _):
            if ch == "`" {
              self.backticks[length, default: []].append(i)
            }
            self.nextBarrier[i] = self.nextBarrier[i + 1]
            self.nextGreater[i] = ch == ">" ? i : self.nextGreater[i + 1]
          case .text(_), .softLineBreak, .hardLineBreak:
            self.nextBarrier[i] = self.nextBarrier[i + 1]
            self.nextGreater[i] = self.nextGreater[i + 1]
          default:
            self.nextBarrier[i] = i
            self.nextGreater[i] = self.nextGreater[i + 1]
        }
        i -= 1
      }
      // positions were collected backwards
      for key in self.backticks.keys {
        self.backticks[key]!.reverse()
      }
    }

    /// Returns the position of the first backtick delimiter of the given length after `pos`.
    func closingBacktick(after pos: Int, length: Int) -> Int? {
      guard let positions = self.backticks[length] else {
        return nil
      }
      var low = 0
      var high = positions.count
      while low < high {
        let mid = (low + high) / 2
        if positions[mid] > pos {
          high = mid
        } else {
          low = mid + 1
        }
      }
      return low < positions.count ? positions[low] : nil
    }
  }

  public override func transform(_ text: Text) -> Text {
    // The index is only needed if there are delimiters which might start a code span or tag
    let relevant = text.contains { fragment in
      if case .delimiter(let ch, _, []) = fragment {
        return ch == "`" || ch == "<"
      }
      return false
    }
    let index = relevant ? FragmentIndex(text) : nil
    var res: Text = Text()
    var iterator = text.makeIterator()
    var element = iterator.next()
    // Position of `element` in `text`
    var pos = 0
    loop: while let fragment = element {
      switch fragment {
        case .delimiter("`", let n, []):
          if let index = index,
             let closer = index.closingBacktick(after: pos, length: n),
             index.nextBarrier[pos + 1] > closer {
            var code = ""
            for i in (pos + 1)..<closer {
              code += text[i].rawDescription
            }
            // If the content both starts and ends with a space, but does not consist
            // only of spaces, one space is removed on each side.
            if code.count >= 2 && code.first == " " && code.last == " " &&
               code.contains(where: { $0 != " " }) {
              code = String(code.dropFirst().dropLast())
            }
            res.append(fragment: .code(Substring(code)))
            self.skip(closer - pos, in: &iterator)
            pos = closer + 1
          } else {
            res.append(fragment: fragment)
            pos += 1
          }
          element = iterator.next()
        case .delimiter("<", let n, []):
          if let index = index,
             let (closer, construct) = self.inlineConstruct(in: text, at: pos, length: n,
                                                            index: index) {
            res.append(fragment: construct)
            self.skip(closer - pos, in: &iterator)
            pos = closer + 1
          } else {
            res.append(fragment: fragment)
            pos += 1
          }
          element = iterator.next()
        default:
          // Note: this assumes that `transform` does not consume further fragments
          element = self.transform(fragment, from: &iterator, into: &res)
          pos += 1
      }
    }
    return res
  }

  private func skip(_ count: Int, in iterator: inout Text.Iterator) {
    for _ in 0..<count {
      _ = iterator.next()
    }
  }

  /// Tries to find an autolink or an inline html tag starting with the `<` delimiter at
  /// position `pos`. Returns the position of the closing `>` delimiter and the resulting
  /// fragment.
  private func inlineConstruct(in text: Text,
                               at pos: Int,
                               length n: Int,
                               index: FragmentIndex) -> (Int, TextFragment)? {
    let limit = index.nextBarrier[pos + 1]
    guard index.nextGreater[pos + 1] < limit else {
      // there is no closing `>` delimiter
      return nil
    }
    var content = ""
    // Autolinks and tags start with a non-whitespace character. `!` and `?` start comments,
    // declarations, CDATA sections and processing instructions, which may contain anything.
    // For all other constructs, `<` and `>` are only allowed inside of quoted attribute values.
    // Therefore, if no quotes were seen, no valid candidate can be found after a `>` which
    // did not complete a valid construct, nor after another `<`.
    var onlyEndsAtFirstGreater = true
    var j = pos + 1
    while j < limit {
      let fragment = text[j]
      if case .delimiter(">", n, _) = fragment {
        if isURI(content) {
          return (j, .autolink(.uri, Substring(content)))
        } else if isEmailAddress(content) {
          return (j, .autolink(.email, Substring(content)))
        } else if isHtmlTag(content) {
          return (j, .html(Substring(content)))
        }
        if onlyEndsAtFirstGreater {
          return nil
        }
      } else if case .delimiter("<", _, _) = fragment, onlyEndsAtFirstGreater {
        return nil
      }
      // Line endings are part of HTML tags as they are
      let raw: String
      switch fragment {
        case .softLineBreak, .hardLineBreak:
          raw = "\n"
        default:
          raw = fragment.rawDescription
      }
      if content.isEmpty {
        guard let first = raw.first, !first.isWhitespace else {
          return nil
        }
        if first == "!" || first == "?" {
          onlyEndsAtFirstGreater = false
        }
      }
      if onlyEndsAtFirstGreater && raw.utf8.contains(where: { $0 == 0x22 || $0 == 0x27 }) {
        onlyEndsAtFirstGreater = false
      }
      content += raw
      j += 1
    }
    return nil
  }
}
