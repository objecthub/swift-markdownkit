//
//  TableDescriptor.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 12/05/2026.
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

/// 
/// A `TableDescriptor` value encapsulates all information needed to render
/// a table, including metadata about each column (to determine how columns
/// are organized).
/// 
public struct TableDescriptor: Sendable {
  
  /// The header row.
  public let header: Row
  
  /// The alignment of each column.
  public let alignments: Alignments
  
  /// The body rows.
  public let rows: Rows
  
  /// Statistics for each column, which a table renderer uses to distribute the available width
  /// over the columns: `minWidth` is the width of the widest word of the column, which is the
  /// narrowest the column can be without breaking a word. `maxWidth` is the width of the
  /// widest cell, when its text is written on one line. `wordCount` is the number of words in
  /// the cells of the column, including its header.
  public let columnStats: [(minWidth: Int, maxWidth: Int, wordCount: Int)]
  
  /// Creates the description of a table.
  public init(header: Row,
              alignments: Alignments,
              rows: Rows,
              columnStats: [(minWidth: Int, maxWidth: Int, wordCount: Int)]) {
    self.header = header
    self.alignments = alignments
    self.rows = rows
    self.columnStats = columnStats
  }
  
  /// Pads `string` with the character `ch` to the width `len`, according to the alignment of
  /// `column`: left-aligned and unaligned text gets its padding on the right, right-aligned text
  /// on the left, and the padding of centered text is split between both sides. The header of a
  /// right-aligned column is centered. If `alignDisplayWidth` is true, the width is the width on
  /// the screen, which can differ from the number of characters.
  public func pad(string: String,
                  to len: Int,
                  with ch: Character = " ",
                  at column: Int,
                  inHeader header: Bool = false,
                  alignDisplayWidth: Bool = true) -> String {
    let paddingNeeded = len - (alignDisplayWidth ? string.terminalDisplayWidth : string.count)
    guard paddingNeeded > 0 else {
      return string
    }
    let alignment = self.alignments.indices.contains(column)
                      ? self.alignments[column] : .undefined
    switch header && (alignment == .right) ? .center : alignment {
      case .undefined, .left:
        // Left-aligned: padding goes on the right
        return string + String(repeating: ch, count: paddingNeeded)
      case .right:
        // Right-aligned: padding goes on the left
        return String(repeating: ch, count: paddingNeeded) + string
      case .center:
        // Center-aligned: split padding between left and right
        // Extra padding goes to the right when paddingNeeded is odd
        let leftPadding  = paddingNeeded / 2
        let rightPadding = paddingNeeded - leftPadding
        return String(repeating: ch, count: leftPadding)
               + string
               + String(repeating: ch, count: rightPadding)
    }
  }
}
