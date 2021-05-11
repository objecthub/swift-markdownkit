//
//  ThematicBreakParser.swift
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
/// A block parser which parses thematic breaks returning `thematicBreak` blocks.
///
open class ThematicBreakParser: BlockParser {
  
  public override func parse() -> ParseResult {
    guard self.shortLineIndent else {
      return .none
    }
    var i = self.contentStartIndex
    let ch = self.line[i]
    switch ch {
      case "-", "_", "*":
        break
      default:
        return .none
    }
    var count = 0
    while i < self.contentEndIndex {
      switch self.line[i] {
        case " ", "\t":
          break
        case ch:
          count += 1
        default:
          return .none
      }
      i = self.line.index(after: i)
    }
    guard count >= 3 else {
      return .none
    }
    self.readNextLine()
    return .block(.thematicBreak)
  }
}
