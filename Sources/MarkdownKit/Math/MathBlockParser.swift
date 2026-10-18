//
//  MathBlockParser.swift
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
/// A block parser for formulas which are blocks of their own, returning ``MathBlock`` blocks:
///
/// ```
/// $$
/// \int_0^1 x^2 \, dx = \frac{1}{3}
/// $$
/// ```
///
/// The block starts with a line that begins with `$$` and ends with a line that ends with `$$`;
/// the LaTeX can also be on these lines, and a block can consist of a single line (`$$x^2$$`).
/// A block cannot contain a blank line. If it is not closed before the end of its container or
/// before a blank line, or if the lines contain more `$$` than the opening and the closing one
/// (as in `$$a$$ and $$b$$`, which is text with two formulas), the lines are not a block of
/// this parser and are parsed as a paragraph. Formulas which are blocks can also be written as
/// fenced code blocks with the info string `math` (see ``MathInlineParser``).
///
/// The parser is a ``RestorableBlockParser``, as it reads ahead to find the end of the block.
/// It has to come before `TableParser` (see ``MathMarkdownParser``).
///
public final class MathBlockParser: RestorableBlockParser {

  public override func tryParse() -> ParseResult {
    return self.parseMathBlock(opening: "$$", closing: "$$")
  }
}

///
/// A block parser for formulas which are blocks of their own, which are written between the
/// delimiters of LaTeX, returning ``MathBlock`` blocks:
///
/// ```
/// \[
/// \int_0^1 x^2 \, dx = \frac{1}{3}
/// \]
/// ```
///
/// This parser works like ``MathBlockParser``, with `\[` instead of the opening `$$` and `\]`
/// instead of the closing one: the block starts with a line that begins with `\[` and ends with a
/// line that ends with `\]`, the LaTeX can also be on these lines, a block can consist of a
/// single line (`\[x^2\]`), and it cannot contain a blank line. Lines with more delimiters than
/// the opening and the closing one (as in `\[a\] and \[b\]`) are not a block, but a paragraph with
/// formulas (see ``LaTeXMathTransformer``).
///
/// The parser has to come before `TableParser` (see ``LaTeXMarkdownParser``). Since a backslash in
/// front of a bracket escapes it in Markdown, text such as `\[not a link]` is a formula here.
///
public final class LaTeXMathBlockParser: RestorableBlockParser {

  public override func tryParse() -> ParseResult {
    return self.parseMathBlock(opening: "\\[", closing: "\\]")
  }
}

extension RestorableBlockParser {

  /// The content of the current line, without its indentation and trailing white space.
  private var mathContent: String {
    return String(self.line[self.contentStartIndex..<self.contentEndIndex])
             .trimmingCharacters(in: .whitespaces)
  }

  /// Parses a formula that is a block, which starts with a line that begins with `opening` and
  /// ends with a line that ends with `closing`.
  func parseMathBlock(opening: String, closing: String) -> ParseResult {
    guard self.shortLineIndent && !self.lineEmpty else {
      return .none
    }
    let first = self.mathContent
    guard first.hasPrefix(opening) else {
      return .none
    }
    var text = String(first.dropFirst(opening.count))
    var parts: [String] = []
    // A block which consists of a single line
    if Self.mathEnds(text, with: closing) {
      text = String(text.dropLast(closing.count)).trimmingCharacters(in: .whitespaces)
      guard !text.isEmpty && !Self.mathContains(text, opening, closing) else {
        return .none
      }
      self.readNextLine()
      return .block(.custom(MathBlock(tex: text)))
    }
    // The first line has to be the start of the formula and not of a paragraph with formulas
    guard !Self.mathContains(text, opening, closing) else {
      return .none
    }
    text = text.trimmingCharacters(in: .whitespaces)
    if !text.isEmpty {
      parts.append(text)
    }
    self.readNextLine()
    var closed = false
    while !self.finished && !self.lineLeavesContainer && !self.lineEmpty {
      var line = self.mathContent
      if Self.mathEnds(line, with: closing) {
        line = String(line.dropLast(closing.count)).trimmingCharacters(in: .whitespaces)
        guard !Self.mathContains(line, opening, closing) else {
          return .none
        }
        if !line.isEmpty {
          parts.append(line)
        }
        closed = true
        self.readNextLine()
        break
      }
      guard !Self.mathContains(line, opening, closing) else {
        return .none
      }
      parts.append(line)
      self.readNextLine()
    }
    guard closed && !parts.isEmpty else {
      return .none
    }
    return .block(.custom(MathBlock(tex: parts.joined(separator: "\n"))))
  }

  /// Is the string followed by `closing` that is not escaped by a backslash?
  private static func mathEnds(_ str: String, with closing: String) -> Bool {
    guard str.hasSuffix(closing) else {
      return false
    }
    return !Self.mathIsEscaped(Array(str), str.count - closing.count)
  }

  /// Does the string contain `opening` or `closing` that is not escaped by a backslash?
  private static func mathContains(_ str: String, _ opening: String, _ closing: String) -> Bool {
    let chars = Array(str)
    let delimiters = [Array(opening), Array(closing)]
    var i = 0
    while i < chars.count {
      for delimiter in delimiters where i + delimiter.count <= chars.count &&
                                        Array(chars[i..<(i + delimiter.count)]) == delimiter {
        if !Self.mathIsEscaped(chars, i) {
          return true
        }
      }
      i += 1
    }
    return false
  }

  /// Is the character at index `i` preceded by an odd number of backslashes?
  private static func mathIsEscaped(_ chars: [Character], _ i: Int) -> Bool {
    var count = 0
    var j = i - 1
    while j >= 0 && chars[j] == "\\" {
      count += 1
      j -= 1
    }
    return count % 2 == 1
  }
}
