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
/// A block parser which parses block quotes eturning `blockquote` blocks.
///
open class BlockquoteParser: BlockParser {

  private final class BlockquoteContainer: NestedContainer {

    public override var indentRequired: Bool {
      return true
    }

    public override func skipIndent(input: String,
                                    startIndex: String.Index,
                                    endIndex: String.Index) -> String.Index? {
      var index = startIndex
      var indent = 0
      while index < endIndex && input[index] == " " {
        indent += 1
        index = input.index(after: index)
      }
      guard indent < 4 && index < endIndex && input[index] == ">" else {
        return nil
      }
      index = input.index(after: index)
      if index < endIndex && input[index] == " " {
        index = input.index(after: index)
      }
      return index
    }

    public override func makeBlock(_ docParser: DocumentParser) -> Block {
      return .blockquote(docParser.bundle(blocks: self.content))
    }

    public override var debugDescription: String {
      return self.outer.debugDescription + " <- blockquote"
    }
  }
  
  public override func parse() -> ParseResult {
    guard self.shortLineIndent && self.line[self.contentStartIndex] == ">" else {
      return .none
    }
    let i = self.line.index(after: self.contentStartIndex)
    if i < self.contentEndIndex && self.line[i] == " " {
      self.docParser.resetLineStart(self.line.index(after: i))
    } else {
      self.docParser.resetLineStart(i)
    }
    return .container(BlockquoteContainer.init)
  }
}
