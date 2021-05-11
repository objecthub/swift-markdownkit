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
  
  public override func parse() -> ParseResult {
    guard self.shortLineIndent else {
      return .none
    }
    var i = self.contentStartIndex
    var level = 0
    while i < self.contentEndIndex && self.line[i] == "#" && level < 7 {
      i = self.line.index(after: i)
      level += 1
    }
    guard level > 0 && level < 7 && (i >= self.contentEndIndex || self.line[i] == " ") else {
      return .none
    }
    while i < self.contentEndIndex && self.line[i] == " " {
      i = self.line.index(after: i)
    }
    guard i < self.contentEndIndex else {
      let res: Block = .heading(level, Text(self.line[i..<i]))
      self.readNextLine()
      return .block(res)
    }
    var e = self.line.index(before: self.contentEndIndex)
    while e > i && self.line[e] == " " {
      e = self.line.index(before: e)
    }
    if e > i && self.line[e] == "#" {
      let e0 = e
      while e > i && self.line[e] == "#" {
        e = self.line.index(before: e)
      }
      if e >= i && self.line[e] == " " {
        while e >= i && self.line[e] == " " {
          e = self.line.index(before: e)
        }
      } else {
        e = e0
      }
    }
    let res: Block = .heading(level, Text(self.line[i...e]))
    self.readNextLine()
    return .block(res)
  }
  
}
