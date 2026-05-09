//
//  StringGenerator.swift
//  MarkdownKit
//
//  Created on 03/05/2026.
//  Copyright © 2026 Google LLC.
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
/// `StringGenerator` provides functionality for converting Markdown blocks into formatted
/// plain text strings with word wrapping and indentation support. The implementation is
/// extensible allowing subclasses of `StringGenerator` to override how individual Markdown
/// structures are converted into strings.
///
open class StringGenerator {
  
  /// Class `Context` provides information about the environment in which a Markdown
  /// construct is being mapped to a string.
  open class Context {
    let parent: Block
    let context: Context?
    let tight: Bool
    let itemIndent: Int?
    let maxColumns: Int
    
    public init(doc: Block, maxColumns: Int) {
      self.parent = doc
      self.context = nil
      self.tight = false
      self.itemIndent = nil
      self.maxColumns = maxColumns
    }
    
    private init(parent: Block,
                 context: Context?,
                 tight: Bool,
                 itemIndent: Int?,
                 maxColumns: Int) {
      self.parent = parent
      self.context = context
      self.tight = tight
      self.itemIndent = itemIndent
      self.maxColumns = maxColumns
    }
    
    func new(parent: Block? = nil,
             tight: Bool? = nil,
             itemIndent: Int? = nil,
             indent: Int) -> Context {
      return Context(parent: parent ?? self.parent,
                     context: self,
                     tight: tight ?? self.tight,
                     itemIndent: itemIndent,
                     maxColumns: self.maxColumns - indent)
    }
    
    var numEnclosingLists: Int {
      let num = self.context?.numEnclosingLists ?? 0
      if case .list(_, _, _) = self.parent {
        return num + 1
      } else {
        return num
      }
    }
    
    var inDefinitionList: Bool {
      if case .definitionList(_) = self.parent {
        return true
      } else {
        return false
      }
    }
  }
  
  /// A `TableDescriptor` value encapsulates all information needed to render
  /// a table, including metadata about each column (to determine how columns
  /// are organized).
  public struct TableDescriptor {
    let header: Row
    let alignments: Alignments
    let rows: Rows
    let columnStats: [(minWidth: Int, maxWidth: Int, wordCount: Int)]
    
    func pad(string: String,
             to len: Int,
             with ch: Character = " ",
             at column: Int,
             inHeader header: Bool = false) -> String {
      let paddingNeeded = len - string.count
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
  
  /// `TableRenderer` objects are able to render tables as an array of strings where
  /// each string is representing a line of text.
  public protocol TableRenderer {
    func renderTable(_ descriptor: TableDescriptor,
                     using generate: (Text, Int) -> [String],
                     in context: Context) -> [String]?
  }
  
  /// The maximum number of columns to output (the width of the document).
  public let numColumns: Int
  
  /// Plugins for rendering tables. The first renderer that returns a result
  /// determines what the output will be.
  public let tableRenderers: [TableRenderer]
  
  /// Default `StringGenerator` implementation with 80 columns
  public static let standard = StringGenerator(numColumns: 80)
  
  /// Initialize with a specific column width
  public init(numColumns: Int = 80, tableRenderers: [TableRenderer]? = nil) {
    self.numColumns = numColumns
    if let tableRenderers {
      self.tableRenderers = tableRenderers
    } else {
      self.tableRenderers = [
        MinimalisticTableRenderer(),
        FullTableRenderer()
      ]
    }
  }
  
  /// `generate` takes a block representing a Markdown document and returns a corresponding
  /// formatted plain text string.
  open func generate(doc: Block) -> String {
    guard case .document(let blocks) = doc else {
      preconditionFailure("cannot generate string from \(doc)")
    }
    return self.generate(blocks: blocks,
                         context: self.newContext(doc: doc, maxColumns: self.numColumns))
               .joined(separator: "\n")
  }
  
  /// Generate a string from a sequence of blocks
  open func generate(blocks: Blocks, context: Context) -> [String] {
    var lines: [String] = []
    var skip = true
    for block in blocks {
      // Add spacing between blocks unless it's tight
      if !skip && !context.tight {
        lines.append("")
      }
      // Generate the text for `block`
      let text = self.generate(block: block, context: context)
      // Append it to the result
      lines.append(contentsOf: text)
      // Determine if the next block should be separated by newline
      skip = self.skipNewline(for: block, and: text, in: context)
    }
    return lines
  }
  
  /// Determines if the next block should be separated by newline
  open func skipNewline(for block: Block, and lines: [String], in context: Context) -> Bool {
    switch block {
      case .heading(_, _):
        if let last = lines.last, last.count > 2 {
          switch (last.first!, last.last!) {
            case ("▔", "▔"), ("‾", "‾"), ("¯", "¯"):
              return true
            default:
              return false
          }
        }
        return false
      default:
        return false
    }
  }
  
  /// Generate a string from a single block
  open func generate(block: Block, context: Context) -> [String] {
    switch block {
      case .document(let blocks):
        return self.generate(blocks: blocks, context: context)
      case .blockquote(let blocks):
        let indent = self.blockquoteIndent
        let lines = self.generate(blocks: blocks,
                                  context: context.new(parent: block,
                                                       tight: false,
                                                       indent: indent.count))
                        .map { line in indent + line }
        return lines
      case .list(let start, let tight, let blocks):
        let indent = self.listIndent
        let lines = self.generate(blocks: blocks,
                                  context: context.new(
                                    parent: block,
                                    tight: tight,
                                    itemIndent: start != nil ? (blocks.count > 9 ? 4 : 3) : 2,
                                    indent: indent.count))
                        .map { line in indent + line }
        return lines
      case .listItem(let type, let density, let blocks):
        let (prefix, indent) = self.listPrefix(type: type,
                                               context: context,
                                               columns: context.itemIndent)
        let lines = self.generate(blocks: blocks,
                                  context: context.new(parent: block,
                                                       tight: density.isTight,
                                                       indent: prefix.count))
        var result: [String] = []
        for (index, line) in lines.enumerated() {
          result.append((index == 0 ? prefix : indent) + line)
        }
        return result
      case .paragraph(let text):
        return self.generate(text: text, maxColumns: context.maxColumns)
      case .heading(let level, let text):
        if let ch = self.headingUnderlineCharacter(level: level) {
          var lines = self.generate(text: text, maxColumns: context.maxColumns)
          lines.append(String(repeating: ch, count: self.width(of: lines)))
          return lines
        } else {
          let indent = String(repeating: self.headingUnderlineCharacter(level: 0) ?? "#",
                              count: level) + " "
          let lines = self.generate(text: text, maxColumns: context.maxColumns - indent.count)
          return lines.map { line in indent + line }
        }
      case .indentedCode(let lines):
        var result: [String] = []
        result.append(String(repeating: "╌", count: context.maxColumns))
        for line in lines {
          let normalized = line.hasSuffix("\n") ? line[..<line.index(before: line.endIndex)] : line
          result.append(String(normalized))
        }
        result.append(String(repeating: "╌", count: context.maxColumns))
        return result
      case .fencedCode(let lang, let lines):
        var result: [String] = []
        if let lang {
          let suffix = " \(lang) ╌╌╌"
          result.append(String(repeating: "╌", count: context.maxColumns - suffix.count) + suffix)
        } else {
          result.append(String(repeating: "╌", count: context.maxColumns))
        }
        for line in lines {
          let normalized = line.hasSuffix("\n") ? line[..<line.index(before: line.endIndex)] : line
          result.append(String(normalized))
        }
        result.append(String(repeating: "╌", count: context.maxColumns))
        return result
      case .htmlBlock(_):
        return []
      case .referenceDef(_, _, _):
        return []
      case .thematicBreak:
        return ["   " + String(repeating: "◠", count: context.maxColumns - 6)]
      case .table(let header, let align, let rows):
        let descriptor = self.tableDescriptor(header: header, alignments: align, rows: rows)
        for renderer in self.tableRenderers {
          if let lines = renderer.renderTable(descriptor,
                                              using: self.generate(text:maxColumns:),
                                              in: context) {
            return lines
          }
        }
        return []
      case .definitionList(let defs):
        let (termPrefix, defPrefix) = self.definitionPrefix(definitions: defs, context: context)
        let indent = self.definitionIndent(definitions: defs, context: context)
        let defIndent = defPrefix + indent
        let lineIndent = defPrefix + String(repeating: " ", count: indent.count)
        var result: [String] = []
        var first = true
        for def in defs {
          if !first && !context.tight {
            result.append("")
          }
          first = false
          let term = self.generate(text: def.item, maxColumns: context.maxColumns - 1)
                         .map { line in termPrefix + line }
          result.append(contentsOf: term)
          let defContext = context.new(parent: block, tight: true, indent: defIndent.count)
          for descr in def.descriptions {
            if case .listItem(_, _, let blocks) = descr {
              let lines = self.generate(blocks: blocks, context: defContext)
              for (index, line) in lines.enumerated() {
                result.append((index == 0 ? defIndent : lineIndent) + line)
              }
            }
          }
        }
        return result
      case .custom(let customBlock):
        // For custom blocks, fall back to their description
        return [customBlock.description]
    }
  }
  
  /// Generate a string from text (inline content)
  open func generate(text: Text, maxColumns: Int? = nil) -> [String] {
    var lines: [String] = []
    var current: String = ""
    for fragment in text {
      if let str = self.generate(textFragment: fragment) {
        current += str
      } else {
        lines.append(current)
        current = ""
      }
    }
    if !current.isEmpty {
      lines.append(current)
    }
    if let maxColumns {
      var result: [String] = []
      for line in lines {
        result.append(contentsOf: self.wordWrap(line, maxColumns: maxColumns))
      }
      return result
    } else {
      return lines
    }
  }
  
  /// Generate a string from a single text fragment. `nil` signals a forced
  /// new line.
  open func generate(textFragment fragment: TextFragment) -> String? {
    switch fragment {
      case .text(let str):
        return str.replacingOccurrences(of: "\n", with: " ").decodingNamedCharacters()
      case .code(let str):
        return "`\(str.replacingOccurrences(of: "\n", with: " "))`"
      case .emph(let text):
        return "*\(self.generate(text: text).joined(separator: " "))*"
      case .strong(let text):
        return "**\(self.generate(text: text).joined(separator: " "))**"
      case .link(let text, let uri, _):
        let linkText = self.generate(text: text).joined(separator: " ")
        if let uri = uri {
          return "\(linkText) [\(uri)]"
        } else {
          return linkText
        }
      case .autolink(_, let str):
        return str.replacingOccurrences(of: "\n", with: " ")
      case .image(let text, let uri, _):
        let altText = self.generate(text: text).joined(separator: " ")
        if let uri = uri {
          return "[Image: \(altText) | \(uri)]"
        } else {
          return "[Image: \(altText)]"
        }
      case .html(_):
        return "" // Skip HTML in plain text output
      case .delimiter(let ch, let n, _):
        return String(repeating: ch, count: n)
      case .softLineBreak:
        return " "
      case .hardLineBreak:
        return nil
      case .custom(let customTextFragment):
        return customTextFragment.rawDescription
    }
  }
  
  open func tableDescriptor(header: Row, alignments: Alignments, rows: Rows) -> TableDescriptor {
    // Initial text rendering
    let headerLines = header.map { text in self.generate(text: text) }
    let rowLines = rows.map { row in row.map { cell in self.generate(text: cell) } }
    // Calculate the maximum and minimum column widths
    var numWords: [Int] = []
    var columnWidths = headerLines.map {
      lines in lines.max(by: { $0.count < $1.count })?.count ?? 0
    }
    var minWidths: [Int] = []
    for lines in headerLines {
      var width = 0
      var wordcount = 0
      for line in lines {
        let words = self.tokenize(line)
        wordcount += words.count
        width = max(width, words.max(by: { $0.count < $1.count })?.count ?? 0)
      }
      numWords.append(wordcount)
      minWidths.append(width)
    }
    for row in rowLines {
      for (index, lines) in row.enumerated() {
        // Expand `columnWidths` as needed
        while index >= columnWidths.count {
          columnWidths.append(0)
        }
        // Compute new maximum width
        columnWidths[index] = max(columnWidths[index],
                                  lines.max(by: { $0.count < $1.count })?.count ?? 0)
        // Expand `minWidths` as needed
        while index >= minWidths.count {
          minWidths.append(0)
        }
        while index >= numWords.count {
          numWords.append(0)
        }
        // Compute new minimum width
        var width = 0
        var wordcount = 0
        for line in lines {
          let words = self.tokenize(line)
          wordcount += words.count
          width = max(width, words.max(by: { $0.count < $1.count })?.count ?? 0)
        }
        numWords[index] += wordcount
        minWidths[index] = max(minWidths[index], width)
      }
    }
    return TableDescriptor(header: header,
                           alignments: alignments,
                           rows: rows,
                           columnStats: columnWidths.enumerated().map { (i, maxWidth) in
                             (minWidth: minWidths[i], maxWidth: maxWidth, wordCount: numWords[i])
                           })
  }
  
  public func tokenize(_ str: String) -> [String] {
    return str.split(whereSeparator: \.isWhitespace).map(String.init)
  }
  
  public func wordWrap(_ text: String, maxColumns: Int) -> [String] {
    let words = self.tokenize(text)
    var lines: [String] = []
    var currentLine = ""
    for word in words {
      if currentLine.isEmpty {
        currentLine = word
      } else if currentLine.count + 1 + word.count <= maxColumns {
        currentLine += " " + word
      } else {
        lines.append(currentLine)
        currentLine = word
      }
    }
    if !currentLine.isEmpty {
      lines.append(currentLine)
    }
    return lines
  }
  
  public func width(of lines: [String]) -> Int {
    var width = 0
    for line in lines {
      width = max(width, line.count)
    }
    return width
  }
    
  open func newContext(doc: Block, maxColumns: Int) -> Context {
    return Context(doc: doc, maxColumns: maxColumns)
  }
  
  open func headingUnderlineCharacter(level: Int) -> Character? {
    switch level {
      case 0:
        return "#"
      case 1:
        return "▔"
      case 2:
        return "‾"
      case 3:
        return "¯"
      default:
        return nil
    }
  }
  
  open var blockquoteIndent: String {
    return " ┃ "
  }
  
  open var listIndent: String {
    return "  "
  }
  
  open func listPrefix(type: ListType, context: Context, columns: Int?) -> (String, String) {
    let level = context.numEnclosingLists
    let prefix: String
    switch type {
      case .bullet(let ch):
        switch ch {
          case "*":
            prefix = level < 2 ? "• " : (level < 3 ? "◦ " : "⋅ ")
          case "-":
            prefix = level > 1 ? "- " : "– "
          default:
            prefix = "\(ch) "
        }
      case .ordered(let num, let ch):
        prefix = "\(num)\(ch) "
    }
    let columns = columns ?? prefix.count
    return (String(repeating: " ", count: max(columns - prefix.count, 0)) + prefix,
            String(repeating: " ", count: max(columns, 2)))
  }
  
  open func definitionPrefix(definitions: Definitions, context: Context) -> (String, String) {
    switch context.parent {
      case .definitionList(_), .listItem(_, _, _), .list(_, _, _):
        return ("", "")
      default:
        return (" ", " ")
    }
  }
  
  open func definitionIndent(definitions: Definitions, context: Context) -> String {
    return " → "
  }
  
  /// This is a table renderer which can be used for tables where each cell
  /// can be represented on one line. The generated output looks like this:
  /// 
  ///     No. │        Name        │    Date
  ///     ────┼────────────────────┼───────────
  ///       1 │  Diana Kellermann  │ 17/09/1984
  ///       2 │ Michael Zimmermann │ 10/01/1977
  ///       3 │   Leonie Schmid    │ 19/12/1986
  ///  
  public class MinimalisticTableRenderer: TableRenderer {
    open func renderTable(_ descriptor: TableDescriptor,
                          using generate: (Text, Int) -> [String],
                          in context: Context) -> [String]? {
      guard self.canRenderSlim(descriptor, in: context) else {
        return nil
      }
      let indent =
        String(repeating: " ",
               count: min((context.maxColumns -
                         descriptor.columnStats.reduce(-3, { (r, v) in r + v.maxWidth + 3 }))/2, 4))
      let headerLines = descriptor.header.map { text in
        generate(text, context.maxColumns).joined()
      }
      let rowLines = descriptor.rows.map { row in row.map { cell in
        generate(cell, context.maxColumns).joined()
      } }
      // Now render the table...
      var result: [String] = []
      // 1. Header row
      var line = indent
      for (coli, stat) in descriptor.columnStats.enumerated() {
        let lineText = coli < headerLines.count ? headerLines[coli] : ""
        line += coli > 0 ? " │ " : ""
        line += descriptor.pad(string: lineText,
                               to: stat.maxWidth,
                               with: " ",
                               at: coli,
                               inHeader: true)
      }
      result.append(line)
      // 2. Separator row
      line = indent
      for (coli, stat) in descriptor.columnStats.enumerated() {
        if coli > 0 {
          line += "─┼─"
        }
        line += String(repeating: "─", count: stat.maxWidth)
      }
      result.append(line)
      // 3. Iterate over all rows
      for row in rowLines {
        // Iterate over all lines of the current row
        var line = indent
        // Iterate over all columns and include the current line
        for (coli, stat) in descriptor.columnStats.enumerated() {
          if coli > 0 {
            line += " │ "
          }
          let lineText = coli < row.count ? row[coli] : ""
          line += descriptor.pad(string: lineText, to: stat.maxWidth, with: " ", at: coli)
        }
        result.append(line)
      }
      return result
    }
    
    open func canRenderSlim(_ descriptor: TableDescriptor, in context: Context) -> Bool {
      return descriptor.columnStats.reduce(-3, { (r, v) in r + v.maxWidth + 3 })
               <= context.maxColumns
    }
  }
  
  /// This is a table renderer which can render any table without constraints (other
  /// than that the available width is reasonable for such a table). The generated
  /// output looks like this:
  /// 
  /// ┌────────────────────────┬─────────────────────────────────────────────┬───────┐
  /// │ Column 1               │                  Column 2                   │ Col 3 │
  /// ╞════════════════════════╪═════════════════════════════════════════════╪═══════╡
  /// │ This text is very long │     Lorem ipsum dolor sit amet, consectetur │  One  │
  /// │ and I wonder how it    │                            adipiscing elit. │       │
  /// │ will be laid out.      │                                             │       │
  /// ├────────────────────────┼─────────────────────────────────────────────┼───────┤
  /// │ Last **cell**!         │  Last cell justo nec finibus. Aenean libero │  Two  │
  /// │                        │  nunc, elementum at justo congue, tristique │       │
  /// │                        │                                  tincidunt. │       │
  /// └────────────────────────┴─────────────────────────────────────────────┴───────┘
  /// 
  public class FullTableRenderer: TableRenderer {
    
    struct Delimiter {
      let left: Character
      let right: Character
      let mid: Character
      let line: Character
      
      var leftStart: String {
        return "\(self.left)\(self.line)"
      }
      
      var rightEnd: String {
        return "\(self.line)\(self.right)"
      }
      
      var midSeparator: String {
        return "\(self.line)\(self.mid)\(self.line)"
      }
      
      func separatorLine(_ columnWidths: [Int]) -> String {
        var line = self.leftStart
        for (index, width) in columnWidths.enumerated() {
          line += String(repeating: self.line, count: max(width, 1))
          line += (index < columnWidths.count - 1) ? self.midSeparator : self.rightEnd
        }
        return line
      }
    }
    
    let topDelimiter: Delimiter
    let bottomDelimiter: Delimiter
    let headerSeparator: Delimiter
    let rowSeparator: Delimiter
    let bar: Character
    
    init(topDelimiter: Delimiter = Delimiter(left: "┌", right: "┐", mid: "┬", line: "─"),
         bottomDelimiter: Delimiter = Delimiter(left: "└", right: "┘", mid: "┴", line: "─"),
         headerSeparator: Delimiter = Delimiter(left: "╞", right: "╡", mid: "╪", line: "═"),
         rowSeparator: Delimiter = Delimiter(left: "├", right: "┤", mid: "┼", line: "─"),
         bar: Character = "│") {
      self.topDelimiter = topDelimiter
      self.bottomDelimiter = bottomDelimiter
      self.headerSeparator = headerSeparator
      self.rowSeparator = rowSeparator
      self.bar = bar
    }
    
    open func renderTable(_ descriptor: TableDescriptor,
                          using generate: (Text, Int) -> [String],
                          in context: Context) -> [String]? {
      let columnWidths = self.columnWidths(descriptor, in: context)
      let headerLines = descriptor.header.enumerated().map { (i, text) in
        generate(text, columnWidths[i])
      }
      let rowLines = descriptor.rows.map { row in row.enumerated().map { (i, cell) in
        generate(cell, columnWidths[i])
      } }
      // Calculate the row heights
      let headerHeight = headerLines.max(by: { $0.count < $1.count })?.count ?? 0
      var rowHeights: [Int] = []
      for row in rowLines {
        rowHeights.append(row.max(by: { $0.count < $1.count })?.count ?? 0)
      }
      // Now render the table...
      var result: [String] = []
      // 1. Upper border of header
      result.append(self.topDelimiter.separatorLine(columnWidths))
      // 2. Header row
      self.renderRow(descriptor,
                     lines: headerLines,
                     height: headerHeight,
                     header: true,
                     columnWidths: columnWidths,
                     insertInto: &result)
      // 3. Iterate over all rows
      for (rowi, row) in rowLines.enumerated() {
        // Generate a separator row
        if rowi == 0 {
          result.append(self.headerSeparator.separatorLine(columnWidths))
        } else {
          result.append(self.rowSeparator.separatorLine(columnWidths))
        }
        // Iterate over all lines of the current row
        self.renderRow(descriptor,
                       lines: row,
                       height: rowHeights[rowi],
                       columnWidths: columnWidths,
                       insertInto: &result)
      }
      // 5. Bottom border
      result.append(self.bottomDelimiter.separatorLine(columnWidths))
      return result
    }
    
    open func renderRow(_ descriptor: TableDescriptor,
                        lines: [[String]],
                        height: Int,
                        header: Bool = false,
                        columnWidths: [Int],
                        insertInto result: inout [String]) {
      for linei in 0..<height {
        var line = String(self.bar)
        for (coli, width) in columnWidths.enumerated() {
          let lineText = coli < lines.count && linei < lines[coli].count ? lines[coli][linei] : ""
          line += " "
          line += descriptor.pad(string: lineText,
                                 to: width,
                                 with: " ",
                                 at: coli,
                                 inHeader: header)
          line += " \(self.bar)"
        }
        result.append(line)
      }
    }
    
    open func columnWidths(_ descriptor: TableDescriptor, in context: Context) -> [Int] {
      // Create an initial assignment of column widths based on the maximum width
      var columnWidths: [Int] = descriptor.columnStats.map(\.maxWidth)
      func totalWidth(_ widths: [Int]) -> Int {
        widths.reduce(1, { (r, v) in r + v + 3 })
      }
      // Scale down column sizes proportionally to the current distribution trying to
      // fit them into the maximum width provided by the context.
      var total = totalWidth(columnWidths)
      if total > context.maxColumns {
        while total > context.maxColumns {
          let factor = Double(context.maxColumns)/Double(total)
          for i in 0..<columnWidths.count {
            columnWidths[i] = max(Int(Double(columnWidths[i]) * factor),
                                  descriptor.columnStats[i].minWidth)
          }
          let newTotal = totalWidth(columnWidths)
          if newTotal >= total {
            break
          }
          total = newTotal
        }
        // If we are now below the maximum width, increase the smallest columns
        // incrementally if they could benefit from an extension.
        while total < context.maxColumns {
          var smallest = 0
          for i in 1..<columnWidths.count {
            if columnWidths[i] < columnWidths[smallest] &&
                columnWidths[i] < descriptor.columnStats[i].maxWidth {
              smallest = i
            }
          }
          columnWidths[smallest] += 1
          total += 1
        }
      }
      return columnWidths
    }
  }
}
