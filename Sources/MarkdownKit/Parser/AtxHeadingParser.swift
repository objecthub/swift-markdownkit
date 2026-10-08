//
//  ATXHeadingParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 01/05/2019.
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
/// A block parser which parses ATX headings (of the form `## Header`) returning `heading` blocks.
///
open class AtxHeadingParser: BlockParser {
  
  open override func parse() -> ParseResult {
    guard self.shortLineIndent else {
      return .none
    }
    var i = self.contentStartIndex
    var level = 0
    while i < self.contentEndIndex && self.line[i] == "#" && level < 7 {
      i = self.line.index(after: i)
      level += 1
    }
    func isSpaceOrTab(_ ch: Character) -> Bool {
      return ch == " " || ch == "\t"
    }
    guard level > 0 && level < 7 &&
          (i >= self.contentEndIndex || isSpaceOrTab(self.line[i])) else {
      return .none
    }
    while i < self.contentEndIndex && isSpaceOrTab(self.line[i]) {
      i = self.line.index(after: i)
    }
    // `end` is the (exclusive) end of the heading text; first drop trailing whitespace
    var end = self.contentEndIndex
    while end > i && isSpaceOrTab(self.line[self.line.index(before: end)]) {
      end = self.line.index(before: end)
    }
    // An optional closing sequence of `#` characters has to be preceded by whitespace
    // (or, if it makes up the whole text, it results in an empty heading).
    var closing = end
    while closing > i && self.line[self.line.index(before: closing)] == "#" {
      closing = self.line.index(before: closing)
    }
    if closing < end {
      if closing == i {
        end = i
      } else if isSpaceOrTab(self.line[self.line.index(before: closing)]) {
        end = closing
        while end > i && isSpaceOrTab(self.line[self.line.index(before: end)]) {
          end = self.line.index(before: end)
        }
      }
    }
    let res: Block = .heading(level, Text(self.line[i..<end]))
    self.readNextLine()
    return .block(res)
  }
  
}
