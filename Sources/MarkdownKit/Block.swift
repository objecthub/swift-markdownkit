//
//  Block.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 25/04/2019.
//  Copyright © 2019-2021 Google LLC.
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
/// Enumeration of Markdown blocks. This enumeration defines the block structure,
/// i.e. the abstract syntax, of Markdown supported by MarkdownKit. The structure of
/// inline text is defined by the ``Text`` struct.
///
/// A parsed document is a ``Block/document(_:)`` which contains other blocks. Blocks which
/// contain blocks (block quotes, lists and list items) nest up to the depth that
/// ``DocumentParser/maxContainerDepth`` allows. The cases
/// ``Block/table(_:_:_:)`` and ``Block/definitionList(_:)`` are only created by
/// ``ExtendedMarkdownParser`` and ``FullMarkdownParser``. See <doc:UnderstandingTheSyntaxTree>
/// for a description of how Markdown syntax maps to the cases.
///
public enum Block: Equatable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
  
  /// The root of a document: the sequence of its top-level blocks.
  case document(Blocks)
  
  /// A block quote containing a sequence of blocks.
  case blockquote(Blocks)
  
  /// A list. The first parameter is the number of the first item for an ordered list, and `nil`
  /// for a bullet list. The second parameter is `true` for a tight list (a list whose items
  /// are not separated by blank lines, and are shown without paragraph spacing) and `false` for
  /// a loose list. The third parameter contains the items of the list, which are
  /// ``Block/listItem(_:_:_:)`` blocks.
  case list(Int?, Bool, Blocks)
  
  /// An item of a list. The parameters are the type of the item (its bullet or number, and
  /// whether it is a task), the density of its content, and the content of the item, which is a
  /// sequence of blocks.
  case listItem(ListType, ListDensity, Blocks)
  
  /// A paragraph containing inline text.
  case paragraph(Text)
  
  /// A heading. The first parameter is the heading level, from 1 (the most important heading)
  /// to 6. The second parameter is the text of the heading.
  case heading(Int, Text)
  
  /// A code block that is indented by four spaces. The parameter is the sequence of its lines,
  /// without the indentation.
  case indentedCode(Lines)
  
  /// A fenced code block. The first parameter is the info string, which follows the opening
  /// fence, with backslash escapes and entities resolved; its first word is the language of
  /// the code. It is `nil` if the opening fence has no info string. The second parameter is
  /// the sequence of lines of the code.
  case fencedCode(String?, Lines)
  
  /// A block of raw HTML, given by its lines.
  case htmlBlock(Lines)
  
  /// A link reference definition (`[label]: destination "title"`). The parameters are the
  /// label, the destination and the lines of the title, which is empty if the definition has
  /// no title. The inline parser uses the definitions to resolve reference links, and the
  /// generators do not show them.
  case referenceDef(String, Substring, Lines)
  
  /// A thematic break (`---`, `***` or `___`).
  case thematicBreak
  
  /// A table. The first parameter is the header row, the second parameter has the alignment of
  /// each column, and the third parameter contains the body rows. Each row has a cell for
  /// each column.
  case table(Row, Alignments, Rows)
  
  /// A list of definitions, each with a term and one or more descriptions.
  case definitionList(Definitions)
  
  /// A block whose syntax is not defined by MarkdownKit, see ``CustomBlock``.
  case custom(CustomBlock)

  /// Returns a description of the block as a string.
  public var description: String {
    switch self {
      case .document(let blocks):
        return "document(\(Block.string(from: blocks)))"
      case .blockquote(let blocks):
        return "blockquote(\(Block.string(from: blocks)))"
      case .list(let start, let tight, let blocks):
        if let start = start {
          return "list(\(start), \(tight ? "tight" : "loose"), \(Block.string(from: blocks)))"
        } else {
          return "list(\(tight ? "tight" : "loose"), \(Block.string(from: blocks)))"
        }
      case .listItem(let type, let density, let blocks):
        return "listItem(\(type), \(density), \(Block.string(from: blocks)))"
      case .paragraph(let text):
        return "paragraph(\(text.debugDescription))"
      case .heading(let level, let text):
        return "heading(\(level), \(text.debugDescription))"
      case .indentedCode(let lines):
        if let firstLine = lines.first {
          var code = firstLine.debugDescription
          for i in 1..<lines.count {
            code = code + ", \(lines[i].debugDescription)"
          }
          return "indentedCode(\(code))"
        } else {
          return "indentedCode()"
        }
      case .fencedCode(let info, let lines):
        if let firstLine = lines.first {
          var code = firstLine.debugDescription
          for i in 1..<lines.count {
            code = code + ", \(lines[i].debugDescription)"
          }
          if let info = info {
            return "fencedCode(\(info), \(code))"
          } else {
            return "fencedCode(\(code))"
          }
        } else {
          if let info = info {
            return "fencedCode(\(info),)"
          } else {
            return "fencedCode()"
          }
        }
      case .htmlBlock(let lines):
        if let firstLine = lines.first {
          var code = firstLine.debugDescription
          for i in 1..<lines.count {
            code = code + ", \(lines[i].debugDescription)"
          }
          return "htmlBlock(\(code))"
        } else {
          return "htmlBlock()"
        }
      case .referenceDef(let label, let dest, let title):
        if let firstLine = title.first {
          var titleStr = firstLine.debugDescription
          for i in 1..<title.count {
            titleStr = titleStr + ", \(title[i].debugDescription)"
          }
          return "referenceDef(\(label), \(dest), \(titleStr))"
        } else {
          return "referenceDef(\(label), \(dest))"
        }
      case .thematicBreak:
        return "thematicBreak"
      case .table(let header, let align, let rows):
        var res = Block.string(from: header) + ", "
        for a in align {
          res += a.description
        }
        for row in rows {
          res += ", " + Block.string(from: row)
        }
        return "table(\(res))"
      case .definitionList(let defs):
        var res = "definitionList"
        var sep = "("
        for def in defs {
          res += sep + def.description
          sep = "; "
        }
        return res + ")"
      case .custom(let customBlock):
        return customBlock.description
    }
  }
  
  /// Returns a debug description.
  public var debugDescription: String {
    switch self {
      case .custom(let customBlock):
        return customBlock.debugDescription
      default:
        return self.description
    }
  }
  
  /// Returns raw text for this block, i.e. ignoring all markup.
  public var string: String {
    switch self {
      case .document(let blocks):
        return blocks.string
      case .blockquote(let blocks):
        return blocks.string
      case .list(_, _, let blocks):
        return blocks.string
      case .listItem(_, _, let blocks):
        return blocks.string
      case .paragraph(let text):
        return text.string
      case .heading(_, let text):
        return text.string
      case .indentedCode(let lines):
        return lines.map { String($0) }.joined()
      case .fencedCode(_, let lines):
        return lines.map { String($0) }.joined()
      case .htmlBlock(_):
        return ""
      case .referenceDef(_, _, let lines):
        return lines.map { String($0) }.joined(separator: " ")
      case .thematicBreak:
        return "\n\n"
      case .table(let headers, _, let rows):
        return headers.map { $0.string }.joined(separator: " | ") + "\n" +
               rows.map { $0.map { $0.string }.joined(separator: " | ") }
                   .joined(separator: "\n")
      case .definitionList(let defs):
        return defs.map { $0.string }.joined(separator: "\n\n")
      case .custom(let obj):
        return obj.string
    }
  }

  fileprivate static func string(from blocks: Blocks) -> String {
    var res = ""
    for block in blocks {
      if res.isEmpty {
        res = block.description
      } else {
        res = res + ", " + block.description
      }
    }
    return res
  }
  
  fileprivate static func string(from row: Row) -> String {
    return "row(" + row.map { $0.description }.joined(separator: " | ") + ")"
  }
  
  /// The block in its normal form, for comparing syntax trees. Two trees that a parser produces
  /// from texts that mean the same, such as `a (b) c` and `a \(b\) c`, have the same normal form.
  ///
  /// - The text of paragraphs, headings, table cells and definitions is normalized, see
  ///   ``Text/normalized``.
  /// - The line terminators of code blocks, HTML blocks and formulas (``MathBlock``) are `\n`:
  ///   the parser keeps `\r\n` and `\r` in the lines of a block, but a ``SourceGenerator`` writes
  ///   `\n`.
  ///
  /// Custom blocks are not changed, so a custom block with text should compare normalized text in
  /// `equals(to:)`.
  public var normalized: Block {
    switch self {
      case .document(let blocks):
        return .document(Block.normalized(blocks))
      case .blockquote(let blocks):
        return .blockquote(Block.normalized(blocks))
      case .list(let start, let tight, let blocks):
        return .list(start, tight, Block.normalized(blocks))
      case .listItem(let type, let density, let blocks):
        return .listItem(type, density, Block.normalized(blocks))
      case .paragraph(let text):
        return .paragraph(text.normalized)
      case .heading(let level, let text):
        return .heading(level, text.normalized)
      case .indentedCode(let lines):
        return .indentedCode(Block.normalized(lines))
      case .fencedCode(let info, let lines):
        return .fencedCode(info, Block.normalized(lines))
      case .htmlBlock(let lines):
        return .htmlBlock(Block.normalized(lines))
      case .referenceDef(_, _, _), .thematicBreak:
        return self
      case .table(let header, let alignments, let rows):
        return .table(Row(header.map { $0.normalized }),
                      alignments,
                      Rows(rows.map { Row($0.map { $0.normalized }) }))
      case .definitionList(let definitions):
        return .definitionList(Definitions(definitions.map { definition in
          Definition(item: definition.item.normalized,
                     descriptions: Block.normalized(definition.descriptions))
        }))
      case .custom(let customBlock):
        if let math = customBlock as? MathBlock {
          return .custom(MathBlock(tex: math.tex.replacingOccurrences(of: "\r\n", with: "\n")
                                                 .replacingOccurrences(of: "\r", with: "\n")))
        }
        return self
    }
  }

  private static func normalized(_ blocks: Blocks) -> Blocks {
    return Blocks(blocks.map { $0.normalized })
  }

  private static func normalized(_ lines: Lines) -> Lines {
    return Lines(lines.map { line in
      if let last = line.last, last == "\r\n" || last == "\r" {
        return Substring(String(line.dropLast()) + "\n")
      }
      return line
    })
  }
  
  /// Defines an equality relation for two blocks.
  public static func == (lhs: Block, rhs: Block) -> Bool {
    switch (lhs, rhs) {
      case (.document(let lblocks), .document(let rblocks)):
        return lblocks == rblocks
      case (.blockquote(let lblocks), .blockquote(let rblocks)):
        return lblocks == rblocks
      case (.list(let ltype, let lt, let lblocks), .list(let rtype, let rt, let rblocks)):
        return ltype == rtype && lt == rt && lblocks == rblocks
      case (.listItem(let ltype, let lt, let lblocks), .listItem(let rtype, let rt, let rblocks)):
        return ltype == rtype && lt == rt && lblocks == rblocks
      case (.paragraph(let lstrs), .paragraph(let rstrs)):
        return lstrs == rstrs
      case (.heading(let ln, let lheadings), .heading(let rn, let rheadings)):
        return ln == rn && lheadings == rheadings
      case (.indentedCode(let lcode), .indentedCode(let rcode)):
        return lcode == rcode
      case (.fencedCode(let linfo, let lcode), .fencedCode(let rinfo, let rcode)):
        return linfo == rinfo && lcode == rcode
      case (.htmlBlock(let llines), .htmlBlock(let rlines)):
        return llines == rlines
      case (.referenceDef(let llab, let ldest, let lt), .referenceDef(let rlab, let rdest, let rt)):
        return llab == rlab && ldest == rdest && lt == rt
      case (.thematicBreak, .thematicBreak):
        return true
      case (.table(let lheader, let lalign, let lrows), .table(let rheader, let ralign, let rrows)):
        return lheader == rheader && lalign == ralign && lrows == rrows
      case (.definitionList(let ldefs), .definitionList(let rdefs)):
        return ldefs == rdefs
      case (.custom(let lblock), .custom(let rblock)):
        return lblock.equals(to: rblock)
      default:
        return false
    }
  }
}

///
/// Describes whether the blocks of a list item are separated by blank lines. The parser uses it
/// to find out whether the list which contains the item is tight or loose, and records it in
/// the `listItem` block.
///
public enum ListDensity: Equatable,
                         CustomStringConvertible,
                         CustomDebugStringConvertible,
                         Sendable {
  
  /// The blocks of the item are not separated by blank lines, but the item did not follow
  /// directly after the previous line: there was a blank line in front of it, or it is the
  /// first block of its container. This only makes the list loose if the item is not the first
  /// item of the list.
  case initial
  
  /// There is at least one blank line between two blocks of the item.
  case loose
  
  /// There are no blank lines between the blocks of the item.
  case tight
  
  /// Creates the density of an item, in which `tight` tells whether its first block follows
  /// directly after the previous line, without a blank line in between.
  public init(tight: Bool) {
    self = tight ? .tight : .initial
  }
  
  /// True if the blocks of the item are not separated by blank lines, and the item does not
  /// follow a blank line.
  public var isTight: Bool {
    switch self {
      case .initial, .loose:
        return false
      case .tight:
        return true
    }
  }
  
  /// True if the blocks of the item are not separated by blank lines. Unlike `isTight`, this
  /// does not take into account whether the item follows a blank line, so it is the right
  /// property for the first item of a list.
  public var isTightInitially: Bool {
    switch self {
      case .loose:
        return false
      case .initial, .tight:
        return true
    }
  }
  
  /// Returns the density of an item after another block, which follows directly after the
  /// previous line if `tight` is true, has been added to the item.
  public func merge(tight: Bool) -> ListDensity {
    switch self {
      case .initial:
        return tight ? .initial : .loose
      case .loose:
        return .loose
      case .tight:
        return tight ? .tight : .loose
    }
  }
  
  public var description: String {
    switch self {
      case .initial:
        return "initial"
      case .loose:
        return "loose"
      case .tight:
        return "tight"
    }
  }
  
  public var debugDescription: String {
    return self.description
  }
}

///
/// Enumeration of Markdown list types.
///
/// The type of a list item is the marker of the item: a bullet (`-`, `+` or `*`) or a number
/// followed by `.` or `)`. A _task list item_ (supported by `FullMarkdownParser`) is a list item
/// with a checkbox, such as `- [x] done`. Its type wraps the marker of the item, so a task
/// list item still has a bullet or a number: `task(bullet("-"), checked: true)`. Use `marker`
/// to find out the marker of an item, independently of whether it is a task.
/// 
public enum ListType: Equatable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
  
  /// An item of a bullet list. The parameter is the bullet: `-`, `+` or `*`.
  case bullet(Character)
  
  /// An item of an ordered list. The parameters are the number of the item and the delimiter
  /// which follows the number: `.` or `)`.
  case ordered(Int, Character)
  
  /// A task list item with a checkbox, which is checked if `checked` is true. The first
  /// parameter is the marker of the item (a `bullet` or an `ordered` list type).
  indirect case task(ListType, checked: Bool)
  
  /// The list type without the checkbox of a task list item: the `bullet` or `ordered` list
  /// type for a task list item, and the list type itself for all other list types.
  public var marker: ListType {
    if case .task(let marker, _) = self {
      return marker.marker
    }
    return self
  }

  /// True if this is the type of a task list item.
  public var isTask: Bool {
    if case .task(_, _) = self {
      return true
    }
    return false
  }

  /// Is `true` if this is the type of a checked task list item, `false` if it is the type of
  /// a task list item which is not checked, and `nil` if this is not the type of a task list item.
  public var checked: Bool? {
    if case .task(_, let checked) = self {
      return checked
    }
    return nil
  }

  /// The number of the first item of an ordered list which an item of this type starts; `nil` for
  /// bullet list items. A task list item has the number of its marker.
  public var startNumber: Int? {
    switch self {
      case .bullet(_):
        return nil
      case .ordered(let start, _):
        return start
      case .task(let marker, _):
        return marker.startNumber
    }
  }

  /// Items with compatible list types can be part of the same list. Whether an item is a task
  /// list item does not matter.
  public func compatible(with other: ListType) -> Bool {
    switch (self.marker, other.marker) {
      case (.bullet(let lc), .bullet(let rc)):
        return lc == rc
      case (.ordered(_, let lc), .ordered(_, let rc)):
        return lc == rc
      default:
        return false
    }
  }

  public var description: String {
    switch self {
      case .bullet(let char):
        return "bullet(\(char.description))"
      case .ordered(let num, let delimiter):
        return "ordered(\(num), \(delimiter))"
      case .task(let marker, let checked):
        return "task(\(marker.description), checked: \(checked))"
    }
  }

  public var debugDescription: String {
    return self.description
  }
}

///
/// Rows are arrays of text.
///
public typealias Row = ContiguousArray<Text>

/// A sequence of table rows.
public typealias Rows = ContiguousArray<Row>

///
/// Column alignments are represented as arrays of `Alignment` enum values
/// 
public enum Alignment: UInt, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
  /// The column has no alignment (`---` in the separator row of the table).
  case undefined = 0
  /// The text of the column is aligned to the left (`:---`).
  case left = 1
  /// The text of the column is aligned to the right (`---:`).
  case right = 2
  /// The text of the column is centered (`:---:`).
  case center = 3
  
  public var description: String {
    switch self {
      case .undefined:
        return "-"
      case .left:
        return "L"
      case .right:
        return "R"
      case .center:
        return "C"
    }
  }
  
  public var debugDescription: String {
    return self.description
  }
}

/// The alignments of the columns of a table: one for each column.
public typealias Alignments = ContiguousArray<Alignment>

///
/// A definition of a definition list: a term and its descriptions. A term can have several
/// descriptions (`: description`).
///
public struct Definition: Equatable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
  /// The term that is defined.
  public let item: Text
  /// The descriptions of the term. Each description is a `listItem` block, whose content
  /// is the text of the description.
  public let descriptions: Blocks
  
  /// Creates the definition of the term `item`.
  public init(item: Text, descriptions: Blocks) {
    self.item = item
    self.descriptions = descriptions
  }
  
  public var description: String {
    return "\(self.item.debugDescription) : \(Block.string(from: self.descriptions))"
  }
  
  public var debugDescription: String {
    return self.description
  }
  
  /// The text of the definition without any markup: the term, a colon, and the descriptions.
  public var string: String {
    return "\(self.item.rawDescription): \(self.descriptions.string)"
  }
}

/// A sequence of definitions: the content of a definition list.
public typealias Definitions = ContiguousArray<Definition>
