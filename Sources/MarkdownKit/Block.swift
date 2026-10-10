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
/// inline text is defined by the `Text` struct.
/// 
public enum Block: Equatable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
  case document(Blocks)
  case blockquote(Blocks)
  case list(Int?, Bool, Blocks)
  case listItem(ListType, ListDensity, Blocks)
  case paragraph(Text)
  case heading(Int, Text)
  case indentedCode(Lines)
  case fencedCode(String?, Lines)
  case htmlBlock(Lines)
  case referenceDef(String, Substring, Lines)
  case thematicBreak
  case table(Row, Alignments, Rows)
  case definitionList(Definitions)
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

public enum ListDensity: Equatable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
  case initial
  case loose
  case tight
  
  public init(tight: Bool) {
    self = tight ? .tight : .initial
  }
  
  public var isTight: Bool {
    switch self {
      case .initial, .loose:
        return false
      case .tight:
        return true
    }
  }
  
  public var isTightInitially: Bool {
    switch self {
      case .loose:
        return false
      case .initial, .tight:
        return true
    }
  }
  
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
  case bullet(Character)
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
public typealias Rows = ContiguousArray<Row>

///
/// Column alignments are represented as arrays of `Alignment` enum values
/// 
public enum Alignment: UInt, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
  case undefined = 0
  case left = 1
  case right = 2
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

public typealias Alignments = ContiguousArray<Alignment>

public struct Definition: Equatable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
  public let item: Text
  public let descriptions: Blocks
  
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
  
  public var string: String {
    return "\(self.item.rawDescription): \(self.descriptions.string)"
  }
}

public typealias Definitions = ContiguousArray<Definition>
