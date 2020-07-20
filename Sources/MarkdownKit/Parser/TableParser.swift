//
//  TableParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 17/07/2020.
//  Copyright © 2020 Google LLC.
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
/// A block parser which parses tables returning `table` blocks.
///
open class TableParser: RestorableBlockParser {

  open override func parse() -> ParseResult {
    guard self.shortLineIndent else {
      return .none
    }
    var i = self.contentStartIndex
    var prev = Character(" ")
    while i < self.contentEndIndex {
      if self.line[i] == "|" && prev != "\\" {
        return super.parse()
      }
      prev = self.line[i]
      i = self.line.index(after: i)
    }
    return .none
  }
  
  open override func tryParse() -> ParseResult {
    guard let header = self.parseRow() else {
      return .none
    }
    self.readNextLine()
    guard let alignrow = self.parseRow(), alignrow.count == header.count else {
      return .none
    }
    var alignments = Alignments()
    for cell in alignrow {
      guard case .some(.text(let str)) = cell.first, str.count > 0 else {
        return .none
      }
      var check: Substring
      if str.first! == ":" {
        if str.count > 2 && str.last! == ":" {
          alignments.append(.center)
          check = str[str.index(after: str.startIndex)..<str.index(before: str.endIndex)]
        } else {
          alignments.append(.left)
          check = str[str.index(after: str.startIndex)..<str.endIndex]
        }
      } else if str.last! == ":" {
        alignments.append(.right)
        check = str[str.startIndex..<str.index(before: str.endIndex)]
      } else {
        alignments.append(.undefined)
        check = str
      }
      guard check.allSatisfy(isDash) else {
        return .none
      }
    }
    self.readNextLine()
    var rows = Rows()
    while let r = self.parseRow() {
      var row = r
      // Remove cells if parsed row has too many
      if row.count > header.count {
        row.removeLast(row.count - header.count)
      // Append cells if parsed row has too few
      } else if row.count < header.count {
        for _ in row.count..<header.count {
          row.append(Text())
        }
      }
      rows.append(row)
      self.readNextLine()
    }
    return .block(.table(header, alignments, rows))
  }
  
  open func parseRow() -> Row? {
    var i = self.contentStartIndex
    skipWhitespace(in: self.line, from: &i, to: self.contentEndIndex)
    guard i < self.contentEndIndex else {
      return nil
    }
    var validRow = false
    if self.line[i] == "|" {
      validRow = true
      i = self.line.index(after: i)
      skipWhitespace(in: self.line, from: &i, to: self.contentEndIndex)
    }
    var res = Row()
    var text: Text? = nil
    while i < self.contentEndIndex {
      var j = i
      var k = i
      var prev = Character(" ")
      while j < self.contentEndIndex && (self.line[j] != "|" || prev == "\\") {
        prev = self.line[j]
        j = self.line.index(after: j)
        if prev != " " {
          k = j
        }
      }
      if j < self.contentEndIndex {
        if text == nil {
          res.append(Text(self.line[i..<k]))
        } else {
          text!.append(fragment: .text(self.line[i..<k]))
          res.append(text!)
          text = nil
        }
        validRow = true
        i = self.line.index(after: j)
        skipWhitespace(in: self.line, from: &i, to: self.contentEndIndex)
      } else if prev == "\\" {
        if text == nil {
          text = Text(self.line[i..<self.line.index(before: k)])
        } else {
          text!.append(fragment: .text(self.line[i..<self.line.index(before: k)]))
        }
        self.readNextLine()
        i = self.contentStartIndex
        skipWhitespace(in: self.line, from: &i, to: self.contentEndIndex)
      } else {
        if text == nil {
          res.append(Text(self.line[i..<k]))
        } else {
          text!.append(fragment: .text(self.line[i..<k]))
          res.append(text!)
          text = nil
        }
        break
      }
    }
    return validRow && !res.isEmpty ? res : nil
  }
}
