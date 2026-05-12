//
//  TerminalGenerator.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 10/05/2026.
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
import CommandLineKit

///
/// `StringGenerator` provides functionality for converting Markdown blocks into formatted
/// plain text strings with word wrapping and indentation support. The implementation is
/// extensible allowing subclasses of `StringGenerator` to override how individual Markdown
/// structures are converted into strings.
///
open class TerminalGenerator {
  
  /// A `TableDescriptor` value encapsulates all information needed to render
  /// a table, including metadata about each column (to determine how columns
  /// are organized).
  public struct TableDescriptor {
    let header: Row
    let alignments: Alignments
    let rows: Rows
    let columnStats: [(minWidth: Int, maxWidth: Int, wordCount: Int)]
  }
  
  /// `TableRenderer` objects are able to render tables as an array of strings where
  /// each string is representing a line of text.
  public protocol TableRenderer {
    func renderTable(_ descriptor: TableDescriptor,
                     using generate: (Text, Int) -> [AnsiText.Normalized],
                     in context: GeneratorContext) -> [AnsiText.Normalized]?
  }
  
  /// The maximum number of columns to output (the width of the document).
  public let numColumns: Int
  
  /// The text properties of headers.
  public let headerProperties: [TextProperties]
  
  /// The text properties of links.
  public let linkProperties: TextProperties
  
  /// The text properties for inline code.
  public let codeProperties: TextProperties
  
  /// The text properties for code block borders.
  public let codeBlockBorderProperties: TextProperties
  
  /// The text properties for code block borders.
  public let codeBlockLangProperties: TextProperties
  
  /// The text properties for inline emphasis.
  public let emphasisProperties: TextProperties
  
  /// The text properties for inline strong text.
  public let strongProperties: TextProperties
  
  /// The text properties for definition terms.
  public let defTermProperties: TextProperties
  
  /// The text properties for definition descriptions.
  public let defDescrProperties: TextProperties
  
  /// The text properties for the blockquote markup.
  public let blockquoteProperties: TextProperties
  
  /// The text properties for thematic break lines.
  public let breakProperties: TextProperties
  
  /// Plugins for rendering tables. The first renderer that returns a result
  /// determines what the output will be.
  public let tableRenderers: [TableRenderer]
  
  /// Default `StringGenerator` implementation with 80 columns
  public static let standard = TerminalGenerator(numColumns: 80)
  
  /// Initialize with a specific column width
  public init(numColumns: Int = 80,
              headerProperties: [TextProperties] = [
                TextProperties(textColor: .red, textStyles: [.bold]),
                TextProperties(textColor: .default, textStyles: [.bold]),
                TextProperties(textColor: .navy, textStyles: []),
                TextProperties(textColor: .navy, textStyles: [.underline]),
                TextProperties(textColor: .default, textStyles: [.underline])
              ],
              linkProperties: TextProperties = .blue,
              codeProperties: TextProperties = .underline,
              codeBlockBorderProperties: TextProperties = .default,
              codeBlockLangProperties: TextProperties = .grey,
              emphasisProperties: TextProperties = .italic,
              strongProperties: TextProperties = .bold,
              defTermProperties: TextProperties = TextProperties(textColor: .grey,
                                                                 textStyles: [.bold]),
              defDescrProperties: TextProperties = TextProperties(textColor: .grey),
              blockquoteProperties: TextProperties = .silver,
              breakProperties: TextProperties = TextProperties(textColor: .maroon,
                                                               textStyles: [.dim]),
              tableRenderers: [TableRenderer] = [
                MinimalisticTableRenderer(borderProperties: .silver,
                                          headerProperties: .italic),
                FullTableRenderer()
              ]) {
    self.numColumns = numColumns
    self.headerProperties = headerProperties
    self.linkProperties = linkProperties
    self.codeProperties = codeProperties
    self.codeBlockBorderProperties = codeBlockBorderProperties
    self.codeBlockLangProperties = codeBlockLangProperties
    self.emphasisProperties = emphasisProperties
    self.strongProperties = strongProperties
    self.defTermProperties = defTermProperties
    self.defDescrProperties = defDescrProperties
    self.blockquoteProperties = blockquoteProperties
    self.breakProperties = breakProperties
    self.tableRenderers = tableRenderers
  }
  
  /// `generate` takes a block representing a Markdown document and returns a corresponding
  /// formatted plain text string.
  open func generate(doc: Block) -> AnsiText.Normalized {
    guard case .document(let blocks) = doc else {
      preconditionFailure("cannot generate string from \(doc)")
    }
    return self.generate(blocks: blocks,
                         context: self.newContext(doc: doc, maxColumns: self.numColumns))
               .joined(separator: "\n")
  }
  
  /// Generate a string from a sequence of blocks
  open func generate(blocks: Blocks, context: GeneratorContext) -> [AnsiText.Normalized] {
    var lines: [AnsiText.Normalized] = []
    var skip = true
    for block in blocks {
      // Add spacing between blocks unless it's tight
      if !skip && !context.tight {
        lines.append(AnsiText.Normalized())
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
  open func skipNewline(for block: Block, and lines: [AnsiText.Normalized],
                        in context: GeneratorContext) -> Bool {
    switch block {
      case .heading(_, _):
        if let last = lines.last, last.count > 2 {
          switch (last.first!.character, last.last!.character) {
            case (" ", "▔"), ("▔", "▔"), (" ", "‾"), ("‾", "‾"), (" ", "¯"), ("¯", "¯"):
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
  open func generate(block: Block, context: GeneratorContext) -> [AnsiText.Normalized] {
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
        var result: [AnsiText.Normalized] = []
        for (index, line) in lines.enumerated() {
          result.append((index == 0 ? prefix : indent).appending(line))
        }
        return result
      case .paragraph(let text):
        return self.generate(text: text, maxColumns: context.maxColumns)
      case .heading(let level, let text):
        // Distinguish headers with underline vs. others
        if let ch = self.headingUnderlineCharacter(level: level) {
          var lines = self.generate(text: text, maxColumns: context.maxColumns)
          lines.append(AnsiText.Normalized(repeating: ch, count: self.width(of: lines)))
          if level > 0 && level <= self.headerProperties.count {
            lines = lines.map { text in text.applying(properties: self.headerProperties[level - 1])}
          }
          if level == 1 {
            var res: [AnsiText.Normalized?] = []
            for line in lines {
              res.append(nil)
              res.append(line)
            }
            return res.joined(separator: " ", maxWidth: context.maxColumns, align: .center)
          }
          return lines
        // No underlining
        } else {
          let lines = self.generate(text: text, maxColumns: context.maxColumns)
          if level > 0 && level <= self.headerProperties.count {
            return lines.map { line in
              line.applying(properties: self.headerProperties[level - 1])
            }
          } else {
            return lines
          }
        }
      case .indentedCode(let lines):
        var result: [AnsiText.Normalized] = []
        result.append(self.codeBlockBorder(maxColumns: context.maxColumns))
        for line in lines {
          let normalized = line.hasSuffix("\n") ? line[..<line.index(before: line.endIndex)] : line
          result.append(AnsiText.Normalized(String(normalized)))
        }
        result.append(self.codeBlockBorder(maxColumns: context.maxColumns))
        return result
      case .fencedCode(let lang, let lines):
        var result: [AnsiText.Normalized] = []
        result.append(self.codeBlockBorder(lang: lang, maxColumns: context.maxColumns))
        for line in lines {
          let normalized = line.hasSuffix("\n") ? line[..<line.index(before: line.endIndex)] : line
          result.append(AnsiText.Normalized(String(normalized)))
        }
        result.append(self.codeBlockBorder(maxColumns: context.maxColumns))
        return result
      case .htmlBlock(_):
        return []
      case .referenceDef(_, _, _):
        return []
      case .thematicBreak:
        return [AnsiText.Normalized("   ").appending(
                  AnsiText.Normalized(repeating: "◠",
                                      count: context.maxColumns - 6,
                                      properties: self.breakProperties))]
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
        let lineIndent = defPrefix + AnsiText.Normalized(repeating: " ", count: indent.count)
        var result: [AnsiText.Normalized] = []
        var first = true
        for def in defs {
          if !first && !context.tight {
            result.append(AnsiText.Normalized())
          }
          first = false
          let term = self.generate(text: def.item, maxColumns: context.maxColumns - 1)
                         .map { line in
                           termPrefix.appending(line).applying(properties: self.defTermProperties)
                         }
          result.append(contentsOf: term)
          let defContext = context.new(parent: block, tight: true, indent: defIndent.count)
          for descr in def.descriptions {
            if case .listItem(_, _, let blocks) = descr {
              let lines = self.generate(blocks: blocks, context: defContext)
              for (index, line) in lines.enumerated() {
                result.append((index == 0 ? defIndent : lineIndent) +
                              line.applying(properties: self.defDescrProperties))
              }
            }
          }
        }
        return result
      case .custom(let customBlock):
        // For custom blocks, fall back to their description
        return [AnsiText.Normalized(customBlock.description)]
    }
  }
  
  /// Generate a string from text (inline content)
  open func generate(text: Text, maxColumns: Int? = nil) -> [AnsiText.Normalized] {
    var lines: [AnsiText.Normalized] = []
    var current = AnsiText.Normalized()
    for fragment in text {
      if let str = self.generate(textFragment: fragment) {
        current.append(str)
      } else {
        lines.append(current)
        current = AnsiText.Normalized()
      }
    }
    if !current.isEmpty {
      lines.append(current)
    }
    if let maxColumns {
      var result: [AnsiText.Normalized] = []
      for line in lines {
        let wrapped = line.tokenize().joined(separator: " ", maxWidth: maxColumns, align: .left)
        result.append(contentsOf: wrapped)
      }
      return result
    } else {
      return lines
    }
  }
  
  /// Generate a string from a single text fragment. `nil` signals a forced
  /// new line.
  open func generate(textFragment fragment: TextFragment) -> AnsiText.Normalized? {
    switch fragment {
      case .text(let str):
        return AnsiText.Normalized(str.replacingOccurrences(of: "\n", with: " ")
                                      .decodingNamedCharacters())
      case .code(let str):
        return AnsiText.Normalized(str.replacingOccurrences(of: "\n", with: " "),
                                   properties: self.codeProperties)
      case .emph(let text):
        var nested = self.generate(text: text).joined(separator: " ")
        nested.apply(properties: self.emphasisProperties)
        return nested
      case .strong(let text):
        var nested = self.generate(text: text).joined(separator: " ")
        nested.apply(properties: self.strongProperties)
        return nested
      case .link(let text, let uri, _):
        let linkText = self.generate(text: text).joined(separator: " ")
        if let uri = uri {
          return AnsiText.Normalized("\(linkText) ") +
                 AnsiText.Normalized("[\(uri)]", properties: self.linkProperties)
        } else {
          return linkText
        }
      case .autolink(_, let str):
        return AnsiText.Normalized(str.replacingOccurrences(of: "\n", with: " "),
                                   properties: self.linkProperties)
      case .image(let text, let uri, _):
        let altText = self.generate(text: text).joined(separator: " ")
        if let uri = uri {
          return AnsiText.Normalized("[Image: \(altText) | \(uri)]",
                                     properties: self.linkProperties)
        } else {
          return AnsiText.Normalized("[Image: \(altText)]", properties: self.linkProperties)
        }
      case .html(_):
        return AnsiText.Normalized()
      case .delimiter(let ch, let n, _):
        return AnsiText.Normalized(repeating: ch, count: n)
      case .softLineBreak:
        return AnsiText.Normalized(" ")
      case .hardLineBreak:
        return nil
      case .custom(let customTextFragment):
        return AnsiText.Normalized(customTextFragment.rawDescription)
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
        let words = line.tokenize()
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
          let words = line.tokenize()
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
  
  open func tokenize(_ str: String) -> [String] {
    return str.split(whereSeparator: \.isWhitespace).map(String.init)
  }
  
  open func wordWrap(_ text: String, maxColumns: Int) -> [String] {
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
  
  public func width(of lines: [AnsiText.Normalized]) -> Int {
    var width = 0
    for line in lines {
      width = max(width, line.count)
    }
    return width
  }
    
  open func newContext(doc: Block, maxColumns: Int) -> GeneratorContext {
    return GeneratorContext(doc: doc, maxColumns: maxColumns)
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
  
  open func codeBlockBorder(lang: String? = nil, maxColumns: Int) -> AnsiText.Normalized {
    if let lang {
      var suffix = AnsiText.Normalized(" \(lang) ", properties: self.codeBlockLangProperties)
      suffix.append(AnsiText.Normalized("╌╌╌", properties: self.codeBlockBorderProperties))
      var result = AnsiText.Normalized(repeating: "╌",
                                       count: maxColumns - suffix.count,
                                       properties: self.codeBlockBorderProperties)
      result.append(suffix)
      return result
    } else {
      return AnsiText.Normalized(String(repeating: "╌", count: maxColumns),
                                 properties: self.codeBlockBorderProperties)
    }
  }
  
  open var blockquoteIndent: AnsiText.Normalized {
    return AnsiText.Normalized(" ┃ ", properties: self.blockquoteProperties)
  }
  
  open var listIndent: AnsiText.Normalized {
    return AnsiText.Normalized("  ")
  }
  
  open func listPrefix(type: ListType, context: GeneratorContext, columns: Int?)
                      -> (AnsiText.Normalized, AnsiText.Normalized) {
    let level = context.numEnclosingLists
    let prefix: AnsiText.Normalized
    switch type {
      case .bullet(let ch):
        switch ch {
          case "*":
            prefix = AnsiText.Normalized(level < 2 ? "• " : (level < 3 ? "◦ " : "⋅ "))
          case "-":
            prefix = AnsiText.Normalized(level > 1 ? "- " : "– ")
          default:
            prefix = AnsiText.Normalized("\(ch) ")
        }
      case .ordered(let num, let ch):
        prefix = AnsiText.Normalized("\(num)\(ch) ")
    }
    let columns = columns ?? prefix.count
    return (AnsiText.Normalized(repeating: " ", count: max(columns - prefix.count, 0)) + prefix,
            AnsiText.Normalized(repeating: " ", count: max(columns, 2)))
  }
  
  open func definitionPrefix(definitions: Definitions,
                             context: GeneratorContext) -> (AnsiText.Normalized, AnsiText.Normalized) {
    switch context.parent {
      case .definitionList(_), .listItem(_, _, _), .list(_, _, _):
        return (AnsiText.Normalized(), AnsiText.Normalized())
      default:
        return (AnsiText.Normalized(" "), AnsiText.Normalized(" "))
    }
  }
  
  open func definitionIndent(definitions: Definitions,
                             context: GeneratorContext) -> AnsiText.Normalized {
    return AnsiText.Normalized(" → ")
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
    let borderProperties: TextProperties
    let headerProperties: TextProperties
    
    public init(borderProperties: TextProperties = .grey,
                headerProperties: TextProperties = .italic) {
      self.borderProperties = borderProperties
      self.headerProperties = headerProperties
    }
    
    open func renderTable(_ descriptor: TableDescriptor,
                          using generate: (Text, Int) -> [AnsiText.Normalized],
                          in context: GeneratorContext) -> [AnsiText.Normalized]? {
      guard self.canRenderSlim(descriptor, in: context) else {
        return nil
      }
      let indent =
        AnsiText.Normalized(repeating: " ",
                            count: min((context.maxColumns -
                                        descriptor.columnStats.reduce(-3, { r, v in
                                          r + v.maxWidth + 3
                                        }))/2, 4))
      let headerLines = descriptor.header.map { text in
        generate(text, context.maxColumns).joined()
      }
      let rowLines = descriptor.rows.map { row in row.map { cell in
        generate(cell, context.maxColumns).joined()
      } }
      // Now render the table...
      var result: [AnsiText.Normalized] = []
      // 1. Header row
      var line = indent
      for (coli, stat) in descriptor.columnStats.enumerated() {
        var lineText = coli < headerLines.count ? headerLines[coli] : AnsiText.Normalized()
        lineText.apply(properties: .italic)
        line.append(AnsiText.Normalized(coli > 0 ? " │ " : "", properties: self.borderProperties))
        let alignment: AnsiText.Alignment
        switch descriptor.alignments.indices.contains(coli) ? descriptor.alignments[coli]
                                                            : .undefined {
          case .undefined, .left:
            alignment = .left
          case .right, .center:
            alignment = .center
        }
        line.append(contentsOf: lineText.tokenize()
          .joined(separator: " ", maxWidth: stat.maxWidth, align: alignment, fill: TextProperties.none))
      }
      result.append(line)
      // 2. Separator row
      line = indent
      for (coli, stat) in descriptor.columnStats.enumerated() {
        if coli > 0 {
          line.append(AnsiText.Normalized("─┼─", properties: self.borderProperties))
        }
        line.append(AnsiText.Normalized(repeating: "─",
                                        count: stat.maxWidth,
                                        properties: self.borderProperties))
      }
      result.append(line)
      // 3. Iterate over all rows
      for row in rowLines {
        // Iterate over all lines of the current row
        var line = indent
        // Iterate over all columns and include the current line
        for (coli, stat) in descriptor.columnStats.enumerated() {
          if coli > 0 {
            line.append(AnsiText.Normalized(" │ ", properties: self.borderProperties))
          }
          let lineText = coli < row.count ? row[coli] : AnsiText.Normalized("")
          let alignment: AnsiText.Alignment
          switch descriptor.alignments.indices.contains(coli) ? descriptor.alignments[coli]
                                                              : .undefined {
            case .undefined, .left:
              alignment = .left
            case .right:
              alignment = .right
            case .center:
              alignment = .center
          }
          line.append(contentsOf: lineText.tokenize()
            .joined(separator: " ", maxWidth: stat.maxWidth, align: alignment, fill: TextProperties.none))
        }
        result.append(line)
      }
      return result
    }
    
    open func canRenderSlim(_ descriptor: TableDescriptor, in context: GeneratorContext) -> Bool {
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
    
    public struct Delimiter {
      public let left: Character
      public let right: Character
      public let mid: Character
      public let line: Character
      public let properties: TextProperties
      
      public init(left: Character,
                  right: Character,
                  mid: Character,
                  line: Character,
                  properties: TextProperties) {
        self.left = left
        self.right = right
        self.mid = mid
        self.line = line
        self.properties = properties
      }
      
      public var leftStart: AnsiText.Normalized {
        return AnsiText.Normalized("\(self.left)\(self.line)", properties: properties)
      }
      
      public var rightEnd: AnsiText.Normalized {
        return AnsiText.Normalized("\(self.line)\(self.right)", properties: properties)
      }
      
      public var midSeparator: AnsiText.Normalized {
        return AnsiText.Normalized("\(self.line)\(self.mid)\(self.line)", properties: properties)
      }
      
      public func separatorLine(_ columnWidths: [Int]) -> AnsiText.Normalized {
        var line = self.leftStart
        for (index, width) in columnWidths.enumerated() {
          line.append(AnsiText.Normalized(repeating: self.line, count: max(width, 1), properties: properties))
          line.append((index < columnWidths.count - 1) ? self.midSeparator : self.rightEnd)
        }
        return line
      }
    }
    
    let topDelimiter: Delimiter
    let bottomDelimiter: Delimiter
    let headerSeparator: Delimiter
    let rowSeparator: Delimiter
    let bar: AnsiText.Normalized
    let spaceBar: AnsiText.Normalized
    let headerProperties: TextProperties
    let rowProperties: TextProperties
    
    public init(topDelimiter: Delimiter = Delimiter(left: "┌", right: "┐", mid: "┬", line: "─", properties: .grey),
                bottomDelimiter: Delimiter = Delimiter(left: "└", right: "┘", mid: "┴", line: "─", properties: .grey),
                headerSeparator: Delimiter = Delimiter(left: "╞", right: "╡", mid: "╪", line: "═", properties: .grey),
                rowSeparator: Delimiter = Delimiter(left: "├", right: "┤", mid: "┼", line: "─", properties: .grey),
                bar: Character = "│",
                barProperties: TextProperties = .grey,
                headerProperties: TextProperties = TextProperties(textColor: .grey, textStyles: [.bold, .italic]),
                rowProperties: TextProperties = .none) {
      self.topDelimiter = topDelimiter
      self.bottomDelimiter = bottomDelimiter
      self.headerSeparator = headerSeparator
      self.rowSeparator = rowSeparator
      self.bar = AnsiText.Normalized("\(bar)", properties: barProperties)
      self.spaceBar = AnsiText.Normalized(" \(bar)", properties: barProperties)
      self.headerProperties = headerProperties
      self.rowProperties = rowProperties
    }
    
    open func renderTable(_ descriptor: TableDescriptor,
                          using generate: (Text, Int) -> [AnsiText.Normalized],
                          in context: GeneratorContext) -> [AnsiText.Normalized]? {
      let columnWidths = self.columnWidths(descriptor, in: context)
      let headerLines = descriptor.header.enumerated().map { (i, text) in
        return generate(text, columnWidths[i])
      }
      let rowLines = descriptor.rows.map { row in row.enumerated().map { (i, cell) in
        return generate(cell, columnWidths[i])
      } }
      // Calculate the row heights
      let headerHeight = headerLines.max(by: { $0.count < $1.count })?.count ?? 0
      var rowHeights: [Int] = []
      for row in rowLines {
        rowHeights.append(row.max(by: { $0.count < $1.count })?.count ?? 0)
      }
      // Now render the table...
      var result: [AnsiText.Normalized] = []
      // 1. Upper border of header
      result.append(self.topDelimiter.separatorLine(columnWidths))
      // 2. Header row
      self.renderRow(descriptor,
                     lines: headerLines,
                     height: headerHeight,
                     header: true,
                     columnWidths: columnWidths,
                     fill: self.headerProperties,
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
                       fill: self.rowProperties,
                       insertInto: &result)
      }
      // 5. Bottom border
      result.append(self.bottomDelimiter.separatorLine(columnWidths))
      return result
    }
    
    open func renderRow(_ descriptor: TableDescriptor,
                        lines: [[AnsiText.Normalized]],
                        height: Int,
                        header: Bool = false,
                        columnWidths: [Int],
                        fill: TextProperties = .none,
                        insertInto result: inout [AnsiText.Normalized]) {
      for linei in 0..<height {
        var line = self.bar
        for (coli, width) in columnWidths.enumerated() {
          let lineText = coli < lines.count && linei < lines[coli].count ? lines[coli][linei]
                                                                         : AnsiText.Normalized("")
          line.append(AnsiText.Normalized(" "))
          let alignment: AnsiText.Alignment
          switch descriptor.alignments.indices.contains(coli) ? descriptor.alignments[coli]
                                                              : .undefined {
            case .undefined, .left:
              alignment = .left
            case .right:
              alignment = header ? .center : .right
            case .center:
              alignment = .center
          }
          line.append(contentsOf: lineText.tokenize()
            .joined(separator: " ", maxWidth: width, align: alignment, fill: TextProperties.none)
            .map { text in text.applying(properties: fill, override: false)})
          line.append(self.spaceBar)
        }
        result.append(line)
      }
    }
    
    open func columnWidths(_ descriptor: TableDescriptor, in context: GeneratorContext) -> [Int] {
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
