//
//  BlockquoteParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 03/05/2019.
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
/// A block parser which parses block quotes returning `blockquote` blocks.
///
open class BlockquoteParser: BlockParser {

  private final class BlockquoteContainer: NestedContainer {

    public override var indentRequired: Bool {
      return true
    }

    internal override var blankLinesSeparateBlocks: Bool {
      return false
    }

    internal override func skipIndent(input: String,
                                      position: LinePosition,
                                      endIndex: String.Index) -> LinePosition? {
      // The marker can be indented by up to three columns
      var (pos, indent) = position.consumingWhitespace(in: input, endIndex: endIndex, columns: 4)
      guard indent < 4 && pos.index < endIndex && input[pos.index] == ">" else {
        return nil
      }
      pos.index = input.index(after: pos.index)
      pos.column += 1
      // The marker is followed by an optional space, which can be one column of a tab
      if pos.index < endIndex {
        if input[pos.index] == " " {
          pos.index = input.index(after: pos.index)
          pos.column += 1
        } else if input[pos.index] == "\t" {
          if LinePosition.tabWidth(at: pos.column) == 1 {
            pos.index = input.index(after: pos.index)
            pos.column += 1
          } else {
            pos.partialTab = 1
          }
        }
      }
      return pos
    }

    public override func makeBlock(_ docParser: DocumentParser) -> Block {
      return .blockquote(docParser.bundle(blocks: self.content))
    }

    public override var debugDescription: String {
      return self.outer.debugDescription + " <- blockquote"
    }
  }
  
  open override func parse() -> ParseResult {
    guard self.shortLineIndent && self.firstContentCharacter == ">" else {
      return .none
    }
    let i = self.line.index(after: self.contentStartIndex)
    if i < self.contentEndIndex && self.line[i] == " " {
      self.docParser.resetLineStart(self.line.index(after: i))
    } else if i < self.contentEndIndex && self.line[i] == "\t" {
      // The marker is followed by a tab, one column of which is part of the marker
      let markerColumn = self.docParser.lineColumn + self.docParser.linePartialTab +
                         self.lineIndent
      if LinePosition.tabWidth(at: markerColumn + 1) == 1 {
        self.docParser.resetLineStart(self.line.index(after: i))
      } else {
        self.docParser.resetLineStart(i, partialTab: 1)
      }
    } else {
      self.docParser.resetLineStart(i)
    }
    return .container(BlockquoteContainer.init)
  }
}
