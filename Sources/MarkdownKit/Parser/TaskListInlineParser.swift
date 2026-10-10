//
//  TaskListInlineParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 10/10/2026.
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
/// An `InlineParser` which recognizes task list items, as defined by GitHub Flavored Markdown:
/// a list item whose first block is a paragraph starting with `[ ]`, `[x]` or `[X]`, followed
/// by a space or tab. The marker is removed from the text, and the type of the list item
/// becomes `ListType.task(…, checked:)` (the marker of the item is kept inside of it). Items
/// of definition lists are not task list items.
///
/// The block parsers have already collected the items into lists when the inline parser runs,
/// so it does not matter whether all items of a list are task list items. If a document is only
/// parsed by the block parsers (`parse(_:blockOnly: true)`), the marker is part of the text.
///
/// `FullMarkdownParser` uses this class. `MarkdownParser` and `ExtendedMarkdownParser` create
/// plain `InlineParser` objects.
///
open class TaskListInlineParser: InlineParser {

  open override func parse(_ block: Block) -> Block {
    guard case .listItem(let type, let density, let blocks) = block,
          !type.isTask,
          type != .bullet(":"),
          case .paragraph(let text)? = blocks.first,
          let (checked, rest) = Self.splitTaskMarker(of: text) else {
      return super.parse(block)
    }
    var parsed = Blocks()
    parsed.append(.paragraph(self.transform(rest)))
    parsed.append(contentsOf: self.parse(Blocks(blocks.dropFirst())))
    return .listItem(.task(type, checked: checked), density, parsed)
  }

  /// If `text` starts with a task list marker (`[ ]`, `[x]` or `[X]`) followed by whitespace,
  /// returns whether the marker is checked and the text without the marker and the whitespace
  /// after it. Otherwise, `nil` is returned.
  public static func splitTaskMarker(of text: Text) -> (checked: Bool, rest: Text)? {
    guard case .text(let line)? = text.first else {
      return nil
    }
    let marker = line.prefix(3)
    guard marker == "[ ]" || marker == "[x]" || marker == "[X]" else {
      return nil
    }
    var rest = line.dropFirst(3)
    guard let space = rest.first, space == " " || space == "\t" else {
      return nil
    }
    rest = rest.drop(while: { $0 == " " || $0 == "\t" })
    var result = Text()
    if !rest.isEmpty {
      result.append(fragment: .text(rest))
    }
    for fragment in text.dropFirst() {
      result.append(fragment: fragment)
    }
    return (marker != "[ ]", result)
  }
}
