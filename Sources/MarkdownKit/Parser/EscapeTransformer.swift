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
/// An inline transformer which removes backslash escapes. It also determines which line endings
/// are hard line breaks (a backslash or at least two spaces at the end of a line) and removes
/// trailing white space in front of other line endings.
///
/// - Important: `EscapeTransformer` has to be the **last** transformer of the list of inline
///   transformers of a `MarkdownParser`, and it should not be left out. All the other
///   transformers work on text which still contains backslashes and the white space at the end
///   of lines, as it is written:
///   - `DelimiterTransformer` classifies delimiter runs by looking at the characters next to
///     them (e.g. a `*` followed by a backslash is not at the end of a line).
///   - `CodeLinkHtmlTransformer` turns code spans, autolinks and HTML tags into fragments. A
///     backslash or spaces at the end of a line are literal text in these, and the line ending
///     is no line break.
///   - `LinkTransformer` compares link reference labels as they are written, including
///     backslashes, and parses link destinations and titles. Their backslash escapes are
///     removed by this transformer once the links exist.
///
///   A parser without `EscapeTransformer` does not recognize hard line breaks, and trailing
///   spaces and backslashes remain in the text. Transformers for additional inline markup
///   belong in front of `EscapeTransformer`.
///
open class EscapeTransformer: InlineTransformer {

  public override func transform(_ fragment: TextFragment,
                                 from iterator: inout Text.Iterator,
                                 into res: inout Text) -> TextFragment? {
    switch fragment {
      case .text(let str):
        return self.transform(text: str, after: "", from: &iterator, into: &res)
      case .delimiter(">", 1, let type) where type.contains(.escaped):
        // An escaped `>`, which did not end an autolink or HTML tag, is just a character
        return self.transformEscapedGreater(after: "", from: &iterator, into: &res)
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

  /// Transforms the text `str` which follows the (already resolved) text `prefix`. Both get
  /// appended to `res` as a single text fragment.
  private func transform(text str: Substring,
                         after prefix: String,
                         from iterator: inout Text.Iterator,
                         into res: inout Text) -> TextFragment? {
    var lookahead = iterator
    var escapesNext = false
    switch lookahead.next() {
      case .some(.softLineBreak):
        // The text is the end of a line, which is a hard line break or a soft line break
        let (text, hardLineBreak) = self.resolveLineEnding(str)
        self.append(text, after: prefix, to: &res, omitEmpty: true)
        res.append(fragment: hardLineBreak ? .hardLineBreak : .softLineBreak)
        _ = iterator.next()
        return iterator.next()
      case .some(.delimiter(">", 1, let type)) where type.contains(.escaped):
        let resolved = self.resolveEscapes(str, escapesNext: true)
        _ = iterator.next()
        return self.transformEscapedGreater(after: prefix + resolved, from: &iterator, into: &res)
      case .some(.delimiter(_, _, let type)):
        // An escaped delimiter (e.g. a backtick) is not part of the preceding text. In this
        // case, the backslash at the end of the text is the escape character.
        escapesNext = type.contains(.escaped)
      default:
        break
    }
    self.append(self.resolveEscapes(str, escapesNext: escapesNext), after: prefix, to: &res)
    return iterator.next()
  }

  /// Transforms an escaped `>` which was just consumed, following the (already resolved) text
  /// `prefix`. It gets merged with the text before and after it.
  private func transformEscapedGreater(after prefix: String,
                                       from iterator: inout Text.Iterator,
                                       into res: inout Text) -> TextFragment? {
    var lookahead = iterator
    if case .some(.text(let next)) = lookahead.next() {
      _ = iterator.next()
      return self.transform(text: next, after: prefix + ">", from: &iterator, into: &res)
    }
    res.append(fragment: .text(Substring(prefix + ">")))
    return iterator.next()
  }

  private func append(_ text: Substring,
                      after prefix: String,
                      to res: inout Text,
                      omitEmpty: Bool = false) {
    if prefix.isEmpty {
      if !omitEmpty || !text.isEmpty {
        res.append(fragment: .text(text))
      }
    } else {
      res.append(fragment: .text(Substring(prefix + text)))
    }
  }

  /// Resolves the escapes in `str`, which is a text at the end of a line. Returns the text
  /// without trailing white space and without the backslash which is a hard line break, and
  /// whether the line ending is a hard line break.
  private func resolveLineEnding(_ str: Substring) -> (Substring, Bool) {
    // A backslash directly in front of the line ending is a hard line break unless it is itself
    // escaped by another backslash
    var backslashes = 0
    var i = str.endIndex
    while i > str.startIndex {
      i = str.index(before: i)
      guard str[i] == "\\" else {
        break
      }
      backslashes += 1
    }
    if backslashes % 2 == 1 {
      let end = str.index(before: str.endIndex)
      return (self.resolveEscapes(str[str.startIndex..<end], escapesNext: false), true)
    }
    // At least two spaces in front of the line ending are a hard line break. Trailing spaces
    // and tabs are removed in any case.
    let lastTwo = str.suffix(2)
    let hardLineBreak = lastTwo.count == 2 && lastTwo.allSatisfy { $0 == " " }
    var end = str.endIndex
    while end > str.startIndex {
      let previous = str.index(before: end)
      guard str[previous] == " " || str[previous] == "\t" else {
        break
      }
      end = previous
    }
    return (self.resolveEscapes(str[str.startIndex..<end], escapesNext: false), hardLineBreak)
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
