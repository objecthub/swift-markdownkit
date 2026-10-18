//
//  MathTransformer.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 17/10/2026.
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
/// An inline transformer which recognizes LaTeX math in text and turns it into ``MathFragment``
/// fragments:
/// - `$a^2$` is a formula within the line.
/// - `$$a^2$$` is a display formula within the line. (A formula which is a block of its own is
///   recognized by ``MathBlockParser``.)
/// - A code span between dollar signs, as in `$` followed by a backtick, the LaTeX, a backtick and
///   `$`, is a formula as well, which GitHub supports to avoid the ambiguities of the other
///   forms.
///
/// The rules for single dollar signs are those of Pandoc: the opening `$` is followed by a
/// character which is not white space, the closing `$` is not preceded by white space and not
/// followed by a digit, and a backslash in front of `$` makes it an ordinary character. This
/// leaves text such as `costs $5 and $6` alone. The first unescaped `$` after the opening one
/// decides: if it cannot close a formula, the opening `$` is an ordinary character.
///
/// The transformer has to come after `CodeLinkHtmlTransformer` and before `LinkTransformer`
/// (see ``MathMarkdownParser``). At this point, code spans, HTML tags and autolinks are
/// already complete, so a dollar sign within code stays code. Emphasis, links and backslash
/// escapes have not been processed yet, and the formula is built from the original characters
/// of the text, so `$a_b + c_d$`, `$f^*(x)$` or `$\{x\}$` are not changed. The delimiters around
/// the formula keep their meaning: `**$x$**` is strong emphasis.
///
open class MathTransformer: InlineTransformer {

  /// True if the transformer also recognizes the delimiters of LaTeX: `\(a^2\)` is a formula
  /// within the line and `\[a^2\]` a display formula within the line. This is `false`, and
  /// ``LaTeXMathTransformer`` overrides it. Backslashes in front of parentheses and brackets
  /// escape them in Markdown, so these forms change the meaning of existing text.
  open class var recognizesLaTeXDelimiters: Bool {
    return false
  }

  /// Stands for a fragment which cannot be part of a formula (such as a code span) in the
  /// characters that are searched for formulas.
  private static let barrier: Character = "\u{FFFC}"

  /// A formula which was found in the characters of a text.
  private struct Match {
    /// The index of the opening delimiter
    let start: Int
    /// The index after the closing delimiter
    let end: Int
    let tex: String
    let source: String
    let display: Bool
  }

  open override func transform(_ text: Text) -> Text {
    let latex = type(of: self).recognizesLaTeXDelimiters
    let hasTrigger = text.contains { fragment in
      if case .text(let str) = fragment {
        return str.contains("$") || (latex && str.contains("\\"))
      }
      return false
    }
    guard hasTrigger else {
      return text
    }
    // Flatten the text into characters; `starts[i]` is the index of the first character of the
    // fragment `i`.
    let fragments = Array(text)
    var chars: [Character] = []
    // Only the characters of text fragments can be dollar signs which start or end a formula
    var isText: [Bool] = []
    var starts: [Int] = []
    var codes: [Int: Substring] = [:]
    for fragment in fragments {
      starts.append(chars.count)
      switch fragment {
        case .text(let str):
          chars.append(contentsOf: str)
          isText.append(contentsOf: repeatElement(true, count: str.count))
        case .code(let str):
          codes[chars.count] = str
          chars.append(Self.barrier)
          isText.append(false)
        case .softLineBreak, .hardLineBreak:
          chars.append("\n")
          isText.append(false)
        case .delimiter(_, _, _), .html(_), .autolink(_, _):
          // These fragments are rebuilt from their characters
          let description = fragment.description
          chars.append(contentsOf: description)
          isText.append(contentsOf: repeatElement(false, count: description.count))
        default:
          chars.append(Self.barrier)
          isText.append(false)
      }
    }
    starts.append(chars.count)
    let matches = Self.findFormulas(in: chars, isText: isText, codes: codes, latex: latex)
    guard !matches.isEmpty else {
      return text
    }
    // Replace the formulas. They begin and end in text fragments, and cover all fragments
    // in between.
    var res = Text()
    var next = 0
    var skipUntil = 0
    for (i, fragment) in fragments.enumerated() {
      let fragmentStart = starts[i]
      let fragmentEnd = starts[i + 1]
      if fragmentEnd <= skipUntil {
        continue
      }
      guard case .text(let str) = fragment else {
        res.append(fragment: fragment)
        continue
      }
      var plainStart = max(fragmentStart, skipUntil)
      while true {
        if next < matches.count && matches[next].start < fragmentEnd {
          let match = matches[next]
          if plainStart < match.start {
            res.append(fragment: .text(Self.slice(str, plainStart - fragmentStart,
                                                  match.start - fragmentStart)))
          }
          res.append(fragment: .custom(MathFragment(tex: match.tex,
                                                    display: match.display,
                                                    source: match.source)))
          skipUntil = match.end
          plainStart = match.end
          next += 1
          if match.end >= fragmentEnd {
            break
          }
        } else {
          if plainStart < fragmentEnd {
            res.append(fragment: .text(Self.slice(str, plainStart - fragmentStart,
                                                  fragmentEnd - fragmentStart)))
          }
          break
        }
      }
    }
    return res
  }

  /// Returns the part of `str` between the character offsets `from` and `to`.
  private static func slice(_ str: Substring, _ from: Int, _ to: Int) -> Substring {
    let start = str.index(str.startIndex, offsetBy: from)
    let end = str.index(start, offsetBy: to - from)
    return str[start..<end]
  }

  /// Finds the formulas in `chars`, from left to right. `isText` tells which characters are
  /// those of text fragments; only these can be dollar signs which start or end a formula.
  /// `codes` contains the code of the code spans, which are represented by a barrier character.
  private static func findFormulas(in chars: [Character], isText: [Bool],
                                   codes: [Int: Substring], latex: Bool) -> [Match] {
    let n = chars.count
    var matches: [Match] = []
    // Is the character at index `i` a dollar sign that can start or end a formula?
    func isDollar(_ i: Int) -> Bool {
      return chars[i] == "$" && isText[i]
    }
    // Is the character at index `i` preceded by an odd number of backslashes?
    func isEscaped(_ i: Int) -> Bool {
      var count = 0
      var j = i - 1
      while j >= 0 && chars[j] == "\\" {
        count += 1
        j -= 1
      }
      return count % 2 == 1
    }
    // Is there a backslash followed by `char`, both in text, at index `i`? The backslash must not
    // be escaped itself: in `\\(`, the parenthesis is a delimiter and not part of the text.
    func isBackslash(_ i: Int, _ char: Character) -> Bool {
      return i + 1 < n && chars[i] == "\\" && chars[i + 1] == char && isText[i] && isText[i + 1] &&
             !isEscaped(i)
    }
    var i = 0
    while i < n {
      // A formula within a line between `\(` and `\)` or, as display math, between `\[` and `\]`
      if latex, i + 1 < n, chars[i] == "\\" {
        let opening: Character? = isBackslash(i, "(") ? ")" : isBackslash(i, "[") ? "]" : nil
        if let closing = opening {
          var k = i + 2
          var close: Int? = nil
          while k + 1 < n && chars[k] != barrier {
            if isBackslash(k, closing) {
              close = k
              break
            }
            k += 1
          }
          if let close {
            let tex = String(chars[(i + 2)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tex.isEmpty {
              matches.append(Match(start: i, end: close + 2, tex: tex,
                                   source: String(chars[i..<(close + 2)]), display: closing == "]"))
              i = close + 2
              continue
            }
          }
          i += 2
          continue
        }
      }
      guard isDollar(i) && !isEscaped(i) else {
        i += 1
        continue
      }
      // A code span between dollar signs
      if i + 2 < n && chars[i + 1] == barrier && isDollar(i + 2), let code = codes[i + 1] {
        matches.append(Match(start: i, end: i + 3, tex: String(code), source: "$`\(code)`$",
                             display: false))
        i += 3
        continue
      }
      // Display math within a line
      if i + 1 < n && isDollar(i + 1) {
        var k = i + 2
        var close: Int? = nil
        while k + 1 < n && chars[k] != barrier {
          if isDollar(k) && isDollar(k + 1) && !isEscaped(k) {
            close = k
            break
          }
          k += 1
        }
        if let close {
          let tex = String(chars[(i + 2)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
          if !tex.isEmpty {
            matches.append(Match(start: i, end: close + 2, tex: tex,
                                 source: String(chars[i..<(close + 2)]), display: true))
            i = close + 2
            continue
          }
        }
        i += 2
        continue
      }
      // A formula within a line
      guard i + 1 < n && !chars[i + 1].isWhitespace else {
        i += 1
        continue
      }
      var k = i + 1
      var close: Int? = nil
      while k < n && chars[k] != barrier {
        if isDollar(k) && !isEscaped(k) {
          close = k
          break
        }
        k += 1
      }
      if let close,
         !chars[close - 1].isWhitespace,
         close + 1 == n || !(chars[close + 1].isASCII && chars[close + 1].isNumber) {
        let tex = String(chars[(i + 1)..<close])
        matches.append(Match(start: i, end: close + 1, tex: tex, source: "$\(tex)$",
                             display: false))
        i = close + 1
      } else {
        i += 1
      }
    }
    return matches
  }
}

///
/// A ``MathTransformer`` which also recognizes the delimiters of LaTeX for formulas within a line
/// of text: `\(a^2\)` is a formula, and `\[a^2\]` is a display formula. (A formula which is a
/// block of its own is recognized by ``LaTeXMathBlockParser``.) The formula ends at the first
/// closing delimiter that is not escaped, so `\(\{x\}\)` is one formula. It can have white space
/// and a line break at its ends, but it has to contain LaTeX.
///
/// The backslash in front of the opening delimiter must not be escaped itself: in `\\(a\\)`, the
/// backslashes escape each other, and the parentheses are ordinary text. A formula which is not
/// closed before the end of the paragraph, or before a code span, is text, too. The rules for
/// the dollar signs are those of ``MathTransformer``; whichever formula starts first wins.
/// ``LaTeXMarkdownParser`` uses this transformer instead of ``MathTransformer``.
///
open class LaTeXMathTransformer: MathTransformer {

  open override class var recognizesLaTeXDelimiters: Bool {
    return true
  }
}
