//
//  ListItemParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 05/05/2019.
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
/// A block parser for parsing list items. There are two types of list items:
/// _bullet list items_ and _ordered list items_. They are represented using `listItem` blocks
/// using either the `bullet` or the `ordered list type.
///
open class ListItemParser: BlockParser {
  
  /// Set of supported bullet characters.
  private let bulletChars: Set<Character>
  
  /// Used for extending `ListItemParser`
  public init(docParser: DocumentParser, bulletChars: Set<Character>) {
    self.bulletChars = bulletChars
    super.init(docParser: docParser)
  }
  
  public required init(docParser: DocumentParser) {
    self.bulletChars = ["-", "+", "*"]
    super.init(docParser: docParser)
  }
  
  private class BulletListItemContainer: NestedContainer {
    let bullet: Character
    let indent: Int

    init(bullet: Character, tight: Bool, indent: Int, outer: Container) {
      self.bullet = bullet
      self.indent = indent
      super.init(outer: outer)
      self.density = .init(tight: tight)
    }

    internal override func skipIndent(input: String,
                                      position: LinePosition,
                                      endIndex: String.Index) -> LinePosition? {
      let (res, consumed) = position.consumingWhitespace(in: input,
                                                         endIndex: endIndex,
                                                         columns: self.indent)
      return consumed >= self.indent ? res : nil
    }

    internal override var endsAtBlankLineIfEmpty: Bool {
      return true
    }

    public override func makeBlock(_ docParser: DocumentParser) -> Block {
      return .listItem(.bullet(self.bullet), self.density ?? .tight, docParser.bundle(blocks: self.content))
    }

    public override var debugDescription: String {
      return self.outer.debugDescription + " <- bulletListItem(\(self.bullet))"
    }
  }

  private final class OrderedListItemContainer: BulletListItemContainer {
    let number: Int

    init(number: Int, delimiter: Character, tight: Bool, indent: Int, outer: Container) {
      self.number = number
      super.init(bullet: delimiter, tight: tight, indent: indent, outer: outer)
    }

    public override func makeBlock(_ docParser: DocumentParser) -> Block {
      return .listItem(.ordered(self.number, self.bullet),
                       self.density ?? .tight,
                       docParser.bundle(blocks: self.content))
    }

    public override var debugDescription: String {
      return self.outer.debugDescription + " <- orderedListItem(\(self.number), \(self.bullet))"
    }
  }

  public override func parse() -> ParseResult {
    guard self.shortLineIndent else {
      return .none
    }
    guard var marker = self.firstContentCharacter else {
      return .none
    }
    var i = self.contentStartIndex
    var listMarkerIndent = 0
    var number: Int? = nil
    switch marker {
      case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
        var n = self.line[i].wholeNumberValue!
        i = self.line.index(after: i)
        listMarkerIndent += 1
        numloop: while i < self.contentEndIndex && listMarkerIndent < 9 {
          switch self.line[i] {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
              n = n * 10 + self.line[i].wholeNumberValue!
            default:
              break numloop
          }
          i = self.line.index(after: i)
          listMarkerIndent += 1
        }
        guard i < self.contentEndIndex else {
          return .none
        }
        number = n
        marker = self.line[i]
        switch marker {
          case ".", ")":
            break
          default:
            return .none
        }
      default:
        if self.bulletChars.contains(marker) {
          break
        }
        return .none
    }
    i = self.line.index(after: i)
    listMarkerIndent += 1
    // Determine the amount of whitespace (in columns, taking tab stops into account) between
    // the list marker and the content
    let markerEnd = i
    let markerEndColumn = self.docParser.lineColumn + self.docParser.linePartialTab +
                          self.lineIndent + listMarkerIndent
    var indent = 0
    var column = markerEndColumn
    loop: while i < self.contentEndIndex {
      switch self.line[i] {
        case " ":
          indent += 1
          column += 1
        case "\t":
          indent += LinePosition.tabWidth(at: column)
          column += LinePosition.tabWidth(at: column)
        default:
          break loop
      }
      i = self.line.index(after: i)
    }
    let blankRest = i >= self.contentEndIndex
    guard blankRest || indent > 0 else {
      return .none
    }
    // A list item can only interrupt a paragraph if it is not empty and, in case of an ordered
    // list item, if its number is 1. This does not apply if the paragraph belongs to an
    // enclosing list item or block quote which does not continue on this line.
    if self.prevParagraphLines != nil && !self.lazyContinuation {
      if blankRest || (number != nil && number! != 1) {
        return .none
      }
    }
    var partialTab = 0
    if blankRest {
      // The item starts with a blank line: the content starts one space after the marker
      indent = 1
    } else if indent > 4 {
      // Five or more columns: the content is an indented code block which follows one column
      // of white space (which can be part of a tab)
      indent = 1
      if self.line[markerEnd] == "\t" && LinePosition.tabWidth(at: markerEndColumn) > 1 {
        i = markerEnd
        partialTab = 1
      } else {
        i = self.line.index(after: markerEnd)
      }
    }
    indent += self.lineIndent + listMarkerIndent
    self.docParser.resetLineStart(i, partialTab: partialTab)
    let tight = !self.prevLineEmpty
    if let number = number {
      return .container { encl in
        OrderedListItemContainer(number: number,
                                 delimiter: marker,
                                 tight: tight,
                                 indent: indent,
                                 outer: encl)
      }
    } else {
      return .container { encl in
        BulletListItemContainer(bullet: marker, tight: tight, indent: indent, outer: encl)
      }
    }
  }
}
