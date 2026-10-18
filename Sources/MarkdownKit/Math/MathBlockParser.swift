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

  /// The content of the current line, without its indentation and trailing white space.
  private var content: String {
    return String(self.line[self.contentStartIndex..<self.contentEndIndex])
             .trimmingCharacters(in: .whitespaces)
  }

  public override func tryParse() -> ParseResult {
    guard self.shortLineIndent && !self.lineEmpty else {
      return .none
    }
    let first = self.content
    guard first.hasPrefix("$$") else {
      return .none
    }
    var text = String(first.dropFirst(2))
    var parts: [String] = []
    // A block which consists of a single line
    if Self.endsWithDelimiter(text) {
      text = String(text.dropLast(2)).trimmingCharacters(in: .whitespaces)
      guard !text.isEmpty && !Self.containsDelimiter(text) else {
        return .none
      }
      self.readNextLine()
      return .block(.custom(MathBlock(tex: text)))
    }
    // The first line has to be the start of the formula and not of a paragraph with formulas
    guard !Self.containsDelimiter(text) else {
      return .none
    }
    text = text.trimmingCharacters(in: .whitespaces)
    if !text.isEmpty {
      parts.append(text)
    }
    self.readNextLine()
    var closed = false
    while !self.finished && !self.lineLeavesContainer && !self.lineEmpty {
      var line = self.content
      if Self.endsWithDelimiter(line) {
        line = String(line.dropLast(2)).trimmingCharacters(in: .whitespaces)
        guard !Self.containsDelimiter(line) else {
          return .none
        }
        if !line.isEmpty {
          parts.append(line)
        }
        closed = true
        self.readNextLine()
        break
      }
      guard !Self.containsDelimiter(line) else {
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

  /// Is the string followed by `$$` that is not escaped by a backslash?
  private static func endsWithDelimiter(_ str: String) -> Bool {
    guard str.hasSuffix("$$") else {
      return false
    }
    return !Self.isEscaped(Array(str), str.count - 2)
  }

  /// Does the string contain `$$` that is not escaped by a backslash?
  private static func containsDelimiter(_ str: String) -> Bool {
    let chars = Array(str)
    var i = 0
    while i + 1 < chars.count {
      if chars[i] == "$" && chars[i + 1] == "$" && !Self.isEscaped(chars, i) {
        return true
      }
      i += 1
    }
    return false
  }

  /// Is the character at index `i` preceded by an odd number of backslashes?
  private static func isEscaped(_ chars: [Character], _ i: Int) -> Bool {
    var count = 0
    var j = i - 1
    while j >= 0 && chars[j] == "\\" {
      count += 1
      j -= 1
    }
    return count % 2 == 1
  }
}
