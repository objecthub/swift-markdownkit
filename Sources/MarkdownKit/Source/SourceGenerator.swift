//
//  SourceGenerator.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 21/10/2026.
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
/// `SourceGenerator` converts Markdown blocks back into Markdown source, in the
/// same way ``HtmlGenerator`` converts them into HTML. The source parses into the
/// same syntax tree it was generated from:
///
/// ```swift
/// let generator = SourceGenerator(dialect: .full)
/// let doc = MarkdownDialect.full.parser.parse(text)
/// let source = generator.generate(doc: doc)
/// MarkdownDialect.full.parser.parse(source).normalized == doc.normalized // true
/// ```
///
/// The generator does not reproduce the original text: it chooses one form for
/// every construct (ATX headings, `*` for emphasis, inline links). `normalized` is
/// needed for comparing the trees because the parser splits text at characters that
/// may start markup even if they are escaped. The tree must have been produced by
/// the parser the generator is configured for; for other trees the generator writes
/// the best source it can. ``roundTrips(_:)`` tells whether the source parses
/// back into the tree.
///
/// Instances are immutable once they have been created and conform to `Sendable`,
/// so a single instance (such as ``standard``) can be used from several threads or
/// tasks at the same time. The conformance is `@unchecked` because the class is
/// `open`: a subclass which adds mutable state has to synchronize it itself, and
/// has to restate the conformance as `@unchecked Sendable`.
///
/// Custom blocks and text fragments write their own source via
/// ``CustomBlock/generateSource(via:parent:)`` and
/// ``CustomTextFragment/generateSource(via:in:)``.
///
open class SourceGenerator: @unchecked Sendable {

  /// The chain of blocks that enclose the block which is being generated, as for
  /// ``HtmlGenerator/Parent``. The outermost block of the chain is the document.
  public enum Parent: Sendable {
    
    /// There is no enclosing block.
    case none
    
    /// The enclosing block, followed by the blocks that enclose it.
    indirect case block(Block, Parent)
  }
  
  /// A generator for the syntax of ``LaTeXMarkdownParser``, which supports
  /// everything that MarkdownKit supports. Escapes written for a larger syntax
  /// are harmless for the smaller parsers, so the source it writes parses back
  /// correctly for the syntax trees of all standard parsers. Use a generator
  /// for the actual dialect to get source with fewer escapes.
  public static let standard = SourceGenerator()

  /// The features of the syntax that this generator writes.
  public let syntax: MarkdownDialect.Syntax

  /// Characters in addition to the ones of Markdown that have to be escaped in
  /// plain text, because a custom parser gives them a meaning (such as the `~`
  /// of a custom inline transformer).
  public let specialCharacters: Set<Character>

  /// The parser that reads the generated source. ``roundTrips(_:)`` uses it.
  public let parser: MarkdownParser

  /// Creates a generator for the standard parser of `dialect`.
  public convenience init(dialect: MarkdownDialect = .fullLaTeX) {
    self.init(syntax: dialect.syntax, parser: dialect.parser)
  }

  /// Creates a generator for a parser with the given syntax. `specialCharacters`
  /// are the characters that have a meaning only for this parser, e.g. because
  /// of custom inline transformers; they are escaped in plain text.
  public init(syntax: MarkdownDialect.Syntax,
              parser: MarkdownParser,
              specialCharacters: Set<Character> = []) {
    self.syntax = syntax
    self.parser = parser
    self.specialCharacters = specialCharacters
  }

  // MARK: Documents and blocks

  /// Generates the Markdown source of a document. The result ends with a newline,
  /// unless the document ends with a code block or an HTML block whose last line
  /// has no line terminator (the parser keeps such a line for the last line of an
  /// input). A block that is not a document is handled like a document which contains
  /// this block.
  open func generate(doc: Block) -> String {
    let blocks: Blocks
    if case .document(let content) = doc {
      blocks = content
    } else {
      blocks = [doc]
    }
    var lines = self.generate(blocks: blocks, parent: .block(.document(blocks), .none))
    guard !lines.isEmpty else {
      return ""
    }
    let end = SourceGenerator.end(of: blocks)
    if end == .fence {
      // The source ends with the last line of the code, not with the closing fence
      lines.removeLast()
    }
    return lines.joined(separator: "\n") + (end == .terminated ? "\n" : "")
  }

  /// Generates the lines of a sequence of blocks which have the enclosing blocks
  /// `parent`. The lines do not have line terminators and do not include the markers
  /// and the indentation of the enclosing blocks, which they add. The blank lines
  /// between the blocks are part of the result: whether two blocks are separated by
  /// a blank line is part of the syntax tree (see ``ListDensity``).
  open func generate(blocks: Blocks, parent: Parent) -> [String] {
    var density: ListDensity? = nil
    var bullet: Character? = nil
    if case .block(.listItem(let type, let itemDensity, _), _) = parent {
      density = itemDensity
      if case .bullet(let ch) = type.marker {
        bullet = ch
      }
    }
    var res: [String] = []
    for (i, block) in blocks.enumerated() {
      var lines = self.generate(block: block, parent: parent)
      // A thematic break on the line of the bullet `*` would be a thematic break by itself
      if i == 0 && bullet == "*", case .thematicBreak = block, lines == ["***"] {
        lines = ["---"]
      }
      // The next block must not be taken as content of the last item of a list
      if i + 1 < blocks.count, let columns = SourceGenerator.indentation(of: blocks[i + 1]) {
        switch block {
          case .list(_, _, _), .definitionList(_):
            lines = SourceGenerator.widenedLastItem(lines, to: columns + 1)
          default:
            break
        }
      }
      if i > 0 && !self.leaksBlank(blocks[i - 1]) &&
         !self.isAdjacent(blocks[i - 1], block, density: density, parent: parent) {
        res.append("")
      }
      res += lines
    }
    return res
  }

  /// Generates the lines of a block which has the enclosing blocks `parent`. This is
  /// the method to override for changing how a kind of block is written; call `super`
  /// for all other blocks.
  open func generate(block: Block, parent: Parent) -> [String] {
    switch block {
      case .document(let blocks):
        return self.generate(blocks: blocks, parent: parent)
      case .blockquote(let blocks):
        let lines = self.generate(blocks: blocks, parent: .block(block, parent))
        return lines.isEmpty ? [">"] : lines.map { $0.isEmpty ? ">" : "> " + $0 }
      case .list(_, _, let items):
        var lines: [String] = []
        for (i, item) in items.enumerated() {
          if i > 0 && self.lead(item) != .tight && !self.leaksBlank(items[i - 1]) {
            lines.append("")
          }
          lines += self.generate(block: item, parent: .block(block, parent))
        }
        return lines
      case .listItem(let type, let density, let blocks):
        return self.generate(item: block, type: type, density: density, blocks: blocks,
                             parent: parent)
      case .paragraph(let text):
        return self.generate(lines: text, in: InlineContext(parent: parent))
      case .heading(let level, let text):
        let context = InlineContext(parent: parent)
        if level <= 2 && self.generate(text: text, in: context).contains("\n") {
          // Only a setext heading can have several lines
          return self.generate(lines: text, in: context) + [level == 1 ? "===" : "---"]
        }
        var content = self.generate(text: text, in: context.inserting(.singleLine))
        if content.hasSuffix("#") {
          // A closing sequence of `#` is not part of the text
          content.removeLast()
          content += "\\#"
        }
        let hashes = String(repeating: "#", count: min(max(level, 1), 6))
        return [content.isEmpty ? hashes : hashes + " " + content]
      case .indentedCode(let lines):
        return lines.map { line in
          let content = SourceGenerator.withoutTerminator(line)
          return content.isEmpty ? "" : "    " + content
        }
      case .fencedCode(let info, let lines):
        return self.fence(info: info, lines: lines)
      case .htmlBlock(let lines):
        return lines.map { SourceGenerator.withoutTerminator($0) }
      case .referenceDef(let label, let destination, let title):
        return self.definition(label: label, destination: String(destination), title: title)
      case .thematicBreak:
        return ["***"]
      case .table(let header, let alignments, let rows):
        return self.generate(table: header, alignments, rows, parent: parent)
      case .definitionList(let definitions):
        return self.generate(definitions: definitions, block: block, parent: parent)
      case .custom(let customBlock):
        return self.generate(customBlock: customBlock, parent: parent)
    }
  }

  /// Generates the lines of a custom block: the lines which the block returns
  /// from `generateSource(via:parent:)`. A block without source form is written
  /// as a fenced code block with its description; the source then parses into a
  /// different tree.
  open func generate(customBlock: CustomBlock, parent: Parent) -> [String] {
    if let lines = customBlock.generateSource(via: self, parent: parent) {
      return lines
    }
    let lines = customBlock.description
                           .components(separatedBy: "\n")
                           .map { Substring($0 + "\n") }
    return self.generate(block: .fencedCode(nil, Lines(lines)), parent: parent)
  }

  // MARK: Inline text

  /// Generates the source of inline text. The result contains `\n` for line breaks
  /// unless the context has the flag `singleLine`. The first character of the text
  /// is not at the start of a line; use ``generate(lines:in:)`` for the text of a
  /// paragraph.
  open func generate(text: Text, in context: InlineContext) -> String {
    return self.sourceOfText(text, in: context)
  }

  /// Generates the lines of the source of the text of a paragraph or a similar
  /// block. The text starts a line of its container, and so does the text after
  /// every line break: the characters at the start of a line that would start a
  /// block are escaped. The lines have no terminators.
  open func generate(lines text: Text, in context: InlineContext) -> [String] {
    return self.sourceOfLines(text, in: context)
  }

  /// Generates the source of one inline fragment. The text generator calls this
  /// method for every fragment; override it to change how a kind of fragment is
  /// written. The context tells whether the fragment is at the start of a line
  /// (`lineStart`) and with which character emphasis is written (`emphasisCharacter`).
  open func generate(textFragment fragment: TextFragment, in context: InlineContext) -> String {
    return self.sourceOfFragment(fragment, in: context)
  }

  /// Generates the source of a custom text fragment: the string which the fragment
  /// returns from `generateSource(via:in:)`. A fragment without source form is written
  /// as its raw text, so that the source parses into different text.
  open func generate(customFragment: CustomTextFragment, in context: InlineContext) -> String {
    return self.sourceOfCustomFragment(customFragment, in: context)
  }

  /// Escapes plain text so that it is read as the same text, using backslashes in
  /// front of the characters that have a meaning in the syntax: the characters of
  /// inline markup such as the asterisk and the backtick, the characters at the
  /// start of a line that start a block (if the context is at the start of a line),
  /// and the special characters of the generator. Entities are not escaped: text
  /// that looks like an entity is an entity.
  open func escape(_ text: String, in context: InlineContext) -> String {
    return self.escapedText(text, in: context)
  }

  // MARK: Checking

  /// Returns true if the source that is generated for `doc` parses back into `doc`:
  /// the normalized syntax trees are equal. This is the contract of the generator
  /// for the trees that its parser produces. It does not hold for the few trees that
  /// no source can express (see the design document), for trees which use features
  /// that ``syntax`` lacks, and for custom elements without source.
  public func roundTrips(_ doc: Block) -> Bool {
    return self.firstMismatch(of: doc) == nil
  }

  /// Returns a description of the first block of `doc` that differs from the block which the
  /// generated source parses into, or `nil` if the source parses back into `doc`.
  public func firstMismatch(of doc: Block) -> String? {
    let expected = SourceGenerator.blocks(of: doc.normalized)
    let actual = SourceGenerator.blocks(of: self.parser.parse(self.generate(doc: doc)).normalized)
    for i in 0..<min(expected.count, actual.count) where expected[i] != actual[i] {
      return "block \(i) is \(actual[i].debugDescription), but should be " +
             "\(expected[i].debugDescription)"
    }
    if expected.count != actual.count {
      return "the source has \(actual.count) blocks, but the document \(expected.count)"
    }
    return nil
  }

  private static func blocks(of doc: Block) -> Blocks {
    if case .document(let blocks) = doc {
      return blocks
    }
    return [doc]
  }

  // MARK: Items, tables, definitions

  private func generate(item: Block,
                        type: ListType,
                        density: ListDensity,
                        blocks: Blocks,
                        parent: Parent) -> [String] {
    let marker: String
    switch type.marker {
      case .ordered(let number, let delimiter):
        marker = "\(number)\(delimiter)"
      case .bullet(let bullet):
        marker = String(bullet)
      default:
        marker = "-"
    }
    var lines = self.generate(blocks: blocks, parent: .block(item, parent))
    if let checked = type.checked {
      let box = self.syntax.contains(.taskLists) ? (checked ? "[x]" : "[ ]")
                                                  : (checked ? "\\[x]" : "\\[ ]")
      if lines.isEmpty {
        lines = [box]
      } else {
        lines[0] = box + " " + lines[0]
      }
    }
    guard !lines.isEmpty else {
      return [marker]
    }
    let indent = String(repeating: " ", count: marker.count + 1)
    // The first block is on the line after the marker if it cannot follow the marker
    // directly: a list that started on a new line (its first item is tight although
    // this item follows a blank line), and an HTML block with leading white space
    // (it would be taken as spacing)
    var markerAlone = false
    if type.checked == nil, let first = blocks.first {
      if density == .initial && self.lead(first) == .tight {
        markerAlone = true
      } else if case .htmlBlock(let htmlLines) = first, let line = htmlLines.first,
                line.first == " " || line.first == "\t" {
        markerAlone = true
      }
    }
    if markerAlone {
      return [marker] + lines.map { $0.isEmpty ? "" : indent + $0 }
    }
    var res: [String] = []
    for (i, line) in lines.enumerated() {
      if i == 0 {
        res.append(line.isEmpty ? marker : marker + " " + line)
      } else {
        res.append(line.isEmpty ? "" : indent + line)
      }
    }
    return res
  }

  private func generate(table header: Row,
                        _ alignments: Alignments,
                        _ rows: Rows,
                        parent: Parent) -> [String] {
    guard self.syntax.contains(.tables) else {
      // Without tables, every row is a paragraph
      var lines: [String] = []
      for row in [header] + rows {
        var text = Text()
        for (i, cell) in row.enumerated() {
          if i > 0 {
            text.append(fragment: .text(" | "))
          }
          for fragment in cell {
            text.append(fragment: fragment)
          }
        }
        if !lines.isEmpty {
          lines.append("")
        }
        lines += self.generate(lines: text, in: InlineContext(parent: parent))
      }
      return lines
    }
    // The table parser splits and unescapes a row before it parses the inline markup of the
    // cells, so all pipes of a cell are escaped after the cell has been generated
    let context = InlineContext(flags: .tableCell, parent: parent)
    func row(_ cells: Row) -> String {
      return "| " + cells.map {
        self.generate(text: $0, in: context).replacingOccurrences(of: "|", with: "\\|")
      }.joined(separator: " | ") + " |"
    }
    var lines = [row(header)]
    lines.append("| " + alignments.map { alignment -> String in
      switch alignment {
        case .undefined:
          return "---"
        case .left:
          return ":---"
        case .right:
          return "---:"
        case .center:
          return ":---:"
      }
    }.joined(separator: " | ") + " |")
    for cells in rows {
      lines.append(row(cells))
    }
    return lines
  }

  private func generate(definitions: Definitions, block: Block, parent: Parent) -> [String] {
    let context = InlineContext(parent: parent)
    var lines: [String] = []
    for (i, definition) in definitions.enumerated() {
      // A term that follows a description without blank line would continue the description
      if i > 0 && !(definitions[i - 1].descriptions.last.map { self.leaksBlank($0) } ?? false) {
        lines.append("")
      }
      lines += self.generate(lines: definition.item, in: context)
      for description in definition.descriptions {
        if self.syntax.contains(.definitionLists) {
          if self.lead(description) != .tight {
            lines.append("")
          }
          lines += self.generate(block: description, parent: .block(block, parent))
        } else if case .listItem(_, _, let blocks) = description {
          // Without definition lists, a description is a sequence of blocks
          lines.append("")
          lines += self.generate(blocks: blocks, parent: .block(block, parent))
        }
      }
    }
    return lines
  }

  // MARK: Code and reference definitions

  /// The line without its terminator, if it has one.
  private static func withoutTerminator(_ line: Substring) -> String {
    if let last = line.last, last == "\n" || last == "\r\n" || last == "\r" {
      return String(line.dropLast())
    }
    return String(line)
  }

  private func fence(info: String?, lines: Lines) -> [String] {
    let content = lines.map { SourceGenerator.withoutTerminator($0) }
    // The fence consists of backticks, unless the info string has a backtick
    let fenceCharacter: Character = info?.contains("`") ?? false ? "~" : "`"
    var longestRun = 0
    for line in content {
      longestRun = max(longestRun, line.drop(while: { $0 == " " }).prefix(while: {
        $0 == fenceCharacter
      }).count)
    }
    let fence = String(repeating: fenceCharacter, count: max(3, longestRun + 1))
    // The parser resolves escapes and entities in the info string
    var infoString = ""
    if var info = info {
      info = info.replacingOccurrences(of: "\\", with: "\\\\")
                 .replacingOccurrences(of: "&", with: "\\&")
      if info.hasPrefix(" ") || info.hasPrefix("\t") {
        info = (info.hasPrefix(" ") ? "&#32;" : "&#9;") + info.dropFirst()
      }
      if info.hasSuffix(" ") || info.hasSuffix("\t") {
        info = info.dropLast() + (info.hasSuffix(" ") ? "&#32;" : "&#9;")
      }
      infoString = info
    }
    return [fence + infoString] + content + [fence]
  }

  private func definition(label: String, destination: String, title: Lines) -> [String] {
    // The tree stores the parts of the definition as they were written
    let bare = !destination.isEmpty && !destination.hasPrefix("<") &&
               !destination.contains(where: { isAsciiWhitespaceOrControl($0) }) &&
               LinkRefDefinitionParser.balanced(Substring(destination))
    var first = "[" + label + "]: "
    if bare {
      first += destination
    } else {
      var escaped = ""
      var prevBackslash = false
      for ch in destination {
        if ch == ">" && !prevBackslash {
          escaped += "\\"
        }
        escaped.append(ch)
        prevBackslash = !prevBackslash && ch == "\\"
      }
      first += "<" + escaped + ">"
    }
    guard !title.isEmpty else {
      return [first]
    }
    // Choose a delimiter of the title that does not occur in it, unless escaped
    func contains(_ delimiter: Character) -> Bool {
      var prevBackslash = false
      for line in title {
        for ch in line {
          if !prevBackslash && ch == delimiter {
            return true
          }
          prevBackslash = !prevBackslash && ch == "\\"
        }
        prevBackslash = false
      }
      return false
    }
    var opening: Character = "\"", closing: Character = "\""
    if contains("\"") {
      if contains("'") {
        opening = "("
        closing = ")"
      } else {
        opening = "'"
        closing = "'"
      }
    }
    var lines: [String] = []
    for (i, line) in title.enumerated() {
      var res = String(line)
      if i == 0 {
        res = first + " " + String(opening) + res
      }
      if i == title.count - 1 {
        res.append(closing)
      }
      lines.append(res)
    }
    return lines
  }

  // MARK: Separation of blocks

  /// Whether a block follows the previous line directly (`tight`), follows a blank
  /// line (`blank`), or whether this is not recorded in the syntax tree (`any`).
  /// The density of the first item of a list records it; it reaches through block quotes.
  private enum Lead {
    case tight, blank, any
  }

  private func lead(_ block: Block) -> Lead {
    switch block {
      case .list(_, _, let items):
        return items.first.map { self.lead($0) } ?? .any
      case .listItem(_, let density, let blocks):
        switch density {
          case .tight:
            return .tight
          case .initial:
            return .blank
          case .loose:
            // The density only tells that the item contains a blank line; the blocks tell more
            switch blocks.first {
              case .list(_, _, _)?, .blockquote(_)?:
                return self.lead(blocks.first!)
              default:
                return .any
            }
        }
      case .blockquote(let blocks):
        return blocks.first.map { self.lead($0) } ?? .any
      default:
        return .any
    }
  }

  /// How an HTML block ends.
  private enum HtmlEnd {
    /// at a blank line (types 6 and 7)
    case blankLine
    /// at a line with the end marker of the type (types 1 to 5)
    case marker
    /// at the end of the container: the block has no end marker
    case open
  }

  private func htmlPlugin(_ lines: Lines) -> HtmlBlockParserPlugin? {
    guard let first = lines.first else {
      return nil
    }
    let line = SourceGenerator.htmlContent(first)
    for type in HtmlBlockParser.supportedParsers {
      let plugin = type.init()
      if plugin.startCondition(line) {
        return plugin
      }
    }
    return nil
  }

  /// The content of a line of an HTML block as the plugins of the parser see it.
  private static func htmlContent(_ line: Substring) -> String {
    return SourceGenerator.withoutTerminator(line.drop(while: { $0 == " " || $0 == "\t" }))
                          .lowercased()
  }

  private func htmlEnd(_ lines: Lines) -> HtmlEnd? {
    guard let plugin = self.htmlPlugin(lines), let last = lines.last else {
      return nil
    }
    if plugin.emptyLineTerminator {
      return .blankLine
    }
    return plugin.endCondition(SourceGenerator.htmlContent(last)) ? .marker : .open
  }

  /// Returns true if a blank line after the block would become part of it: the block
  /// ends with an HTML block which has not been closed by its end marker, and the HTML
  /// block is in an item (a blank line does not end an item).
  private func leaksBlank(_ block: Block) -> Bool {
    switch block {
      case .htmlBlock(let lines):
        return self.htmlEnd(lines) == .open
      case .list(_, _, let items):
        return items.last.map { self.leaksBlank($0) } ?? false
      case .listItem(_, _, let blocks):
        return blocks.last.map { self.leaksBlank($0) } ?? false
      case .definitionList(let definitions):
        return definitions.last?.descriptions.last.map { self.leaksBlank($0) } ?? false
      default:
        return false
    }
  }

  /// Returns true if `next` can start on the line after `previous`, which is not a
  /// line break in the text of a paragraph. The syntax tree of a parser only asks
  /// for it if it is possible.
  private func canFollow(_ previous: Block, _ next: Block, parent: Parent) -> Bool {
    switch previous {
      case .paragraph(_), .table(_, _, _):
        if case .table(_, _, _) = previous, case .list(_, _, _) = next {
          return true
        }
        // The block has to interrupt a paragraph
        switch next {
          case .heading(let level, let text):
            return level > 2 ||
                   !self.generate(text: text, in: InlineContext(parent: parent)).contains("\n")
          case .thematicBreak, .fencedCode(_, _), .blockquote(_), .table(_, _, _):
            return true
          case .list(_, _, let items):
            if case .listItem(let type, _, let blocks)? = items.first {
              return !blocks.isEmpty && (type.startNumber ?? 1) == 1
            }
            return false
          case .htmlBlock(let lines):
            return self.htmlPlugin(lines)?.canInterruptParagraph ?? false
          case .custom(let customBlock):
            return customBlock is MathBlock
          default:
            return false
        }
      case .blockquote(_), .list(_, _, _), .definitionList(_):
        // A paragraph would continue the paragraph at the end of the block
        switch next {
          case .paragraph(_), .definitionList(_):
            return false
          default:
            return true
        }
      case .htmlBlock(let lines):
        return self.htmlEnd(lines) != .blankLine
      case .referenceDef(_, _, _):
        switch next {
          case .paragraph(_), .definitionList(_):
            return false
          default:
            return true
        }
      default:
        return true
    }
  }

  private func isAdjacent(_ previous: Block,
                          _ next: Block,
                          density: ListDensity?,
                          parent: Parent) -> Bool {
    if let density = density, density != .loose {
      // The blocks of the item are not separated by blank lines
      return self.canFollow(previous, next, parent: parent)
    }
    return self.lead(next) == .tight && self.canFollow(previous, next, parent: parent)
  }

  /// How the source of a sequence of blocks ends.
  private enum End {
    /// with a line terminator
    case terminated
    /// with the last line of a code or HTML block which has no terminator
    case unterminated
    /// like `unterminated`, but the block is a fenced code block (that has no closing fence)
    case fence
  }

  private static func end(of blocks: Blocks) -> End {
    guard let last = blocks.last else {
      return .terminated
    }
    switch last {
      case .indentedCode(let lines), .htmlBlock(let lines):
        return lines.last.map { SourceGenerator.hasTerminator($0) ? .terminated : .unterminated }
                         ?? .terminated
      case .fencedCode(_, let lines):
        return lines.last.map { SourceGenerator.hasTerminator($0) ? .terminated : .fence }
                         ?? .terminated
      case .blockquote(let blocks), .document(let blocks), .listItem(_, _, let blocks):
        return SourceGenerator.end(of: blocks)
      case .list(_, _, let items):
        return SourceGenerator.end(of: items.last.map { [$0] } ?? [])
      case .definitionList(let definitions):
        return SourceGenerator.end(of: definitions.last?.descriptions ?? [])
      default:
        return .terminated
    }
  }

  private static func hasTerminator(_ line: Substring) -> Bool {
    if let last = line.last {
      return last == "\n" || last == "\r\n" || last == "\r"
    }
    return false
  }

  // MARK: Items that must not be taken for content of the previous list

  /// The number of columns by which the first line of a block is indented in the source, if
  /// this indentation could make the line part of the last item of a list in front of the block.
  private static func indentation(of block: Block) -> Int? {
    switch block {
      case .indentedCode(let lines):
        guard let first = lines.first else {
          return nil
        }
        return 4 + first.prefix(while: { $0 == " " }).count
      case .htmlBlock(let lines):
        guard let first = lines.first else {
          return nil
        }
        var columns = 0
        for ch in first {
          if ch == " " {
            columns += 1
          } else if ch == "\t" {
            columns += 4 - columns % 4
          } else {
            break
          }
        }
        return columns > 0 ? columns : nil
      default:
        return nil
    }
  }

  /// Returns the lines of a list or definition list where the content of the last item is
  /// indented by at least `indent` columns, with spaces after the marker (at most four), then
  /// spaces in front of the marker (at most three).
  private static func widenedLastItem(_ lines: [String], to indent: Int) -> [String] {
    // The last item starts with the last line that is neither empty nor indented
    guard let start = lines.lastIndex(where: { !$0.isEmpty && $0.first != " " }) else {
      return lines
    }
    let first = Array(lines[start])
    var markerWidth = 1
    if first[0].isASCII && first[0].isNumber {
      markerWidth = 0
      while markerWidth < first.count && first[markerWidth].isASCII && first[markerWidth].isNumber {
        markerWidth += 1
      }
      markerWidth += 1
    }
    guard markerWidth <= first.count, indent > markerWidth + 1 else {
      return lines
    }
    let spaces = first[markerWidth...].prefix(while: { $0 == " " }).count
    var padding = 1
    if first.count > markerWidth && spaces < 5 {
      padding = min(4, indent - markerWidth)
    }
    let leading = min(3, max(0, indent - markerWidth - padding))
    var res = lines
    res[start] = String(repeating: " ", count: leading) + String(first[..<markerWidth]) +
                 String(repeating: " ", count: padding - 1) + String(first[markerWidth...])
    let extra = String(repeating: " ", count: leading + padding - 1)
    for i in (start + 1)..<lines.count where !lines[i].isEmpty {
      res[i] = extra + lines[i]
    }
    return res
  }
}
