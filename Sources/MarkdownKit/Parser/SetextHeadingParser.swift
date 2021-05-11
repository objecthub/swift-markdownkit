//
//  SetextHeadingParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 12/05/2019.
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
/// A block parser which parses setext headings (headers with text underlining) returning
/// `heading` blocks.
///
open class SetextHeadingParser: BlockParser {

  public override func parse() -> ParseResult {
    guard self.shortLineIndent,
          !self.lazyContinuation,
          let plines = self.prevParagraphLines,
          !plines.isEmpty else {
      return .none
    }
    let ch = self.line[self.contentStartIndex]
    let level: Int
    switch ch {
      case "=":
        level = 1
      case "-":
        level = 2
      default:
        return .none
    }
    var i = self.contentStartIndex
    while i < self.contentEndIndex && self.line[i] == ch {
      i = self.line.index(after: i)
    }
    skipWhitespace(in: self.line, from: &i, to: self.contentEndIndex)
    guard i >= self.contentEndIndex else {
      return .none
    }
    self.consumeParagraphLines()
    self.readNextLine()
    return .block(.heading(level, plines.finalized()))
  }
}
