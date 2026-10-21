//
//  SourceGenerator+Text.swift
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

extension SourceGenerator {

  ///
  /// Describes where inline text is written. A ``CustomTextFragment`` gets the context in
  /// which it is written, and passes it on (changed with ``inserting(_:)`` if it adds
  /// brackets) when it asks the generator to write the text inside of it.
  ///
  public struct InlineContext: Sendable {
  
    /// The restrictions of the place where text is written.
    public struct Flags: OptionSet, Sendable {

      public let rawValue: Int

      public init(rawValue: Int) {
        self.rawValue = rawValue
      }

      /// The text is the text of a link or an image, between `[` and `]`.
      public static let linkText = Flags(rawValue: 1 << 0)

      /// The text has to be written in one line: it must not contain line breaks. This
      /// is the case for ATX headings and table cells.
      public static let singleLine = Flags(rawValue: 1 << 1)

      /// The text is the content of a table cell. A table cell is a single line, so this
      /// flag includes ``singleLine``. The table generator escapes the pipes of the
      /// finished cell.
      public static let tableCell = Flags(rawValue: 1 << 1 | 1 << 2)
    }

    /// The restrictions of the place where text is written.
    public var flags: Flags

    /// The blocks that enclose the block with the text.
    public var parent: Parent

    /// True if the text is written at the start of a line of its container. A character
    /// at the start of a line may start a block, so it needs to be escaped.
    public internal(set) var lineStart: Bool = false

    /// The character which an emphasis fragment is written with, `*` or `_`. The generator
    /// changes it when emphasis is next to emphasis, as `**` would otherwise merge two runs.
    public internal(set) var emphasisCharacter: Character = "*"

    /// The emphasis that encloses the text: its character and whether it is strong.
    var parentEmphasis: (character: Character, strong: Bool)? = nil

    /// Stand-ins for brackets in the text of a paragraph. They are present while the text is
    /// written and resolved at the end, when it is known which brackets are part of links.
    var markers: Markers? = nil

    /// Creates a context for text in a block with the enclosing blocks `parent`.
    public init(flags: Flags = [], parent: Parent = .none) {
      self.flags = flags
      self.parent = parent
    }

    /// Returns true if the context has the given flag.
    public func contains(_ flag: Flags) -> Bool {
      return self.flags.contains(flag)
    }

    /// Returns the context for the text inside of a construct which restricts the text
    /// by `flag`, e.g. `.linkText` for the text between brackets.
    public func inserting(_ flag: Flags) -> InlineContext {
      var res = self.nested()
      res.flags.insert(flag)
      return res
    }

    /// The context of text in the middle of a line, inside of other text.
    func nested() -> InlineContext {
      var res = self
      res.lineStart = false
      res.emphasisCharacter = "*"
      res.parentEmphasis = nil
      return res
    }
  }

  /// The characters which stand for brackets while text is written. The bracket of a
  /// link, the bracket of a text that is not part of a link, and their closing
  /// counterparts. They are characters from the last plane of private use, chosen so
  /// that they do not occur in the text.
  struct Markers: Sendable {
    let litOpen: Character
    let litClose: Character
    let linkOpen: Character
    let linkClose: Character

    private static let first: UInt32 = 0x10FFF0
    private static let last: UInt32 = 0x10FFFD

    init(avoiding used: Set<UInt32>) {
      var chars: [Character] = []
      var value = Markers.first
      while chars.count < 4 {
        if !used.contains(value) || value > Markers.last {
          chars.append(Character(Unicode.Scalar(min(value, Markers.last))!))
        }
        value += 1
      }
      self.litOpen = chars[0]
      self.litClose = chars[1]
      self.linkOpen = chars[2]
      self.linkClose = chars[3]
    }

    /// Records the characters of the string that could be mistaken for markers.
    static func record(_ str: String, in used: inout Set<UInt32>) {
      for scalar in str.unicodeScalars where scalar.value >= Markers.first {
        used.insert(scalar.value)
      }
    }

    static func record(_ text: Text, in used: inout Set<UInt32>) {
      for fragment in text {
        switch fragment {
          case .text(let str), .code(let str), .html(let str):
            Markers.record(String(str), in: &used)
          case .autolink(_, let str):
            Markers.record(String(str), in: &used)
          case .emph(let inner), .strong(let inner), .underline(let inner),
               .strikethrough(let inner):
            Markers.record(inner, in: &used)
          case .link(let inner, let uri, let title), .image(let inner, let uri, let title):
            Markers.record(inner, in: &used)
            Markers.record(uri ?? "", in: &used)
            Markers.record(title ?? "", in: &used)
          case .custom(let custom):
            Markers.record(custom.rawDescription, in: &used)
            Markers.record(custom.description, in: &used)
          default:
            break
        }
      }
    }
  }

  // MARK: Text

  func sourceOfText(_ text: Text, in context: InlineContext) -> String {
    return self.complete(context, text: text) { self.write(text, $0, lineStart: false) }
  }

  func sourceOfLines(_ text: Text, in context: InlineContext) -> [String] {
    let res = self.complete(context, text: text) { self.write(text, $0, lineStart: true) }
    return res.components(separatedBy: "\n")
  }

  func sourceOfFragment(_ fragment: TextFragment, in context: InlineContext) -> String {
    return self.complete(context, text: Text(fragment)) { context in
      let markers = context.markers!
      switch fragment {
        case .text(let str):
          return self.escaped(String(str), context)
        case .code(let str):
          return self.codeSpan(String(str))
        case .emph(let text):
          var inner = context.nested()
          inner.parentEmphasis = (context.emphasisCharacter, false)
          let delimiter = String(context.emphasisCharacter)
          return delimiter + self.generate(text: text, in: inner) + delimiter
        case .strong(let text):
          var inner = context.nested()
          inner.parentEmphasis = (context.emphasisCharacter, true)
          let delimiter = String(repeating: context.emphasisCharacter, count: 2)
          return delimiter + self.generate(text: text, in: inner) + delimiter
        case .underline(let text):
          let inner = self.generate(text: text, in: context.nested())
          return self.syntax.contains(.underline) ? "~" + inner + "~" : inner
        case .strikethrough(let text):
          let inner = self.generate(text: text, in: context.nested())
          return self.syntax.contains(.strikethrough) ? "~~" + inner + "~~" : inner
        case .link(let text, let uri, let title):
          return String(markers.linkOpen) +
                 self.generate(text: text, in: context.inserting(.linkText)) +
                 String(markers.linkClose) + "(" +
                 self.destination(uri, hasTitle: title != nil) + self.title(title) + ")"
        case .image(let text, let uri, let title):
          return "!" + String(markers.linkOpen) +
                 self.generate(text: text, in: context.inserting(.linkText)) +
                 String(markers.linkClose) + "(" +
                 self.destination(uri, hasTitle: title != nil) + self.title(title) + ")"
        case .autolink(_, let str):
          return "<" + str + ">"
        case .html(let str):
          return "<" + str + ">"
        case .delimiter(_, _, _):
          return self.escaped(fragment.rawDescription, context)
        case .softLineBreak:
          return context.contains(.singleLine) ? " " : "\n"
        case .hardLineBreak:
          return context.contains(.singleLine) ? " " : "\\\n"
        case .custom(let custom):
          return self.generate(customFragment: custom, in: context)
      }
    }
  }

  func sourceOfCustomFragment(_ fragment: CustomTextFragment,
                              in context: InlineContext) -> String {
    var inner = context
    inner.parentEmphasis = nil
    if let source = fragment.generateSource(via: self, in: inner),
       !(context.contains(.singleLine) && source.contains("\n")) {
      return source
    }
    let res = self.escape(fragment.rawDescription, in: inner)
    return context.contains(.singleLine) ? res.replacingOccurrences(of: "\n", with: " ") : res
  }

  func escapedText(_ text: String, in context: InlineContext) -> String {
    var used = Set<UInt32>()
    Markers.record(text, in: &used)
    return self.complete(context, text: Text(Substring(text)), recorded: used) {
      self.escaped(text, $0)
    }
  }

  // MARK: Implementation

  /// Runs `body` with a context that has markers for brackets. The markers are resolved
  /// at the end if this call created them. If they exist already, the text is part of
  /// the text of an enclosing call, which resolves them.
  private func complete(_ context: InlineContext,
                        text: Text,
                        recorded: Set<UInt32> = [],
                        _ body: (InlineContext) -> String) -> String {
    guard context.markers == nil else {
      return body(context)
    }
    var used = recorded
    Markers.record(text, in: &used)
    var inner = context
    inner.markers = Markers(avoiding: used)
    return self.resolveBrackets(body(inner), inner)
  }

  /// Writes the fragments of a text.
  private func write(_ text: Text, _ context: InlineContext, lineStart: Bool) -> String {
    let fragments = Array(text.normalized)
    var res = ""
    var atLineStart = lineStart
    var afterBreak = false
    var previousEmphasis: Character? = nil
    for (i, fragment) in fragments.enumerated() {
      var fragmentContext = context
      fragmentContext.lineStart = atLineStart
      fragmentContext.emphasisCharacter = "*"
      var emphasis: Character? = nil
      switch fragment {
        case .emph(_), .strong(_):
          // Runs of the same character merge: the character differs from the character
          // of the emphasis that it touches. It is the previous fragment, and the enclosing
          // emphasis if this is its only fragment (but `***x***` is strong text in
          // emphasized text).
          var strong = false
          if case .strong(_) = fragment {
            strong = true
          }
          var forbidden = Set<Character>()
          if let parent = context.parentEmphasis,
             fragments.count == 1,
             !(strong && !parent.strong) {
            forbidden.insert(parent.character)
          }
          if let previous = previousEmphasis {
            forbidden.insert(previous)
          }
          fragmentContext.emphasisCharacter = forbidden.contains("*") ? "_" : "*"
          emphasis = fragmentContext.emphasisCharacter
        case .custom(_):
          fragmentContext.parentEmphasis = nil
        default:
          break
      }
      var piece = self.generate(textFragment: fragment, in: fragmentContext)
      switch fragment {
        case .text(_):
          // `!` and a link would be an image
          if i + 1 < fragments.count,
             case .link(_, _, _) = fragments[i + 1], piece.hasSuffix("!") {
            piece.removeLast()
            piece += "\\!"
          }
        case .html(_), .custom(_):
          // The parser removes the indentation of the lines of a paragraph before it parses the
          // inline markup. HTML and custom fragments are written as they are, so a line with
          // them could start a block; the indentation of four spaces is removed again.
          if afterBreak {
            piece = "    " + piece
          }
          if piece.contains("\n") {
            let lines = piece.components(separatedBy: "\n")
            piece = ([lines[0]] + lines.dropFirst().map { line in
              if let first = line.first, first != " ", first != "\\", !first.isLetter {
                return "    " + line
              }
              return line
            }).joined(separator: "\n")
          }
        default:
          break
      }
      res += piece
      previousEmphasis = emphasis
      switch fragment {
        case .softLineBreak, .hardLineBreak:
          atLineStart = true
          afterBreak = true
        default:
          atLineStart = false
          afterBreak = false
      }
    }
    return res
  }

  /// Escapes plain text, with markers for brackets.
  private func escaped(_ str: String, _ context: InlineContext) -> String {
    let markers = context.markers!
    let chars = Array(str)
    let n = chars.count
    // The delimiter of an ordered list item
    var delimiter = -1
    if context.lineStart && n > 0 && chars[0].isASCII && chars[0].isNumber {
      var j = 0
      while j < n && j < 9 && chars[j].isASCII && chars[j].isNumber {
        j += 1
      }
      if j < n && (chars[j] == "." || chars[j] == ")") {
        delimiter = j
      }
    }
    var res = ""
    for (i, ch) in chars.enumerated() {
      var escape = false
      switch ch {
        case "`":
          // A run of backticks is escaped by an escape in front of the first one:
          // the length of the run matters for code spans
          escape = !(i > 0 && chars[i - 1] == "`")
        case "\\", "*", "<":
          escape = true
        case "[":
          res.append(markers.litOpen)
          continue
        case "]":
          res.append(markers.litClose)
          continue
        case "~":
          escape = self.syntax.contains(.underline) ||
                   self.syntax.contains(.strikethrough) ||
                   (i == 0 && context.lineStart)
        case "$":
          escape = self.syntax.contains(.math)
        case "|":
          escape = self.syntax.contains(.tables) && !context.contains(.tableCell)
        case "_":
          // An underscore between two letters is no emphasis
          escape = !(i > 0 && i < n - 1 && SourceGenerator.isPlain(chars[i - 1]) &&
                     SourceGenerator.isPlain(chars[i + 1]))
        case "#", ">", "+", "-", "=":
          escape = i == 0 && context.lineStart
        case ":":
          escape = i == 0 && context.lineStart && self.syntax.contains(.definitionLists)
        default:
          break
      }
      if i == delimiter || self.specialCharacters.contains(ch) {
        escape = true
      }
      if escape {
        res += "\\"
      }
      res.append(ch)
    }
    return res
  }

  private static func isPlain(_ ch: Character) -> Bool {
    return !isUnicodeWhitespace(ch) && !isUnicodePunctuation(ch)
  }

  /// Replaces the markers for brackets by brackets, and by escaped brackets. A literal
  /// bracket stays bare if it cannot be part of a link, or, in the syntax with LaTeX
  /// formulas, of a formula (`\[` starts one). The brackets are matched like the parser
  /// does: the innermost opener closes first. Every literal bracket starts bare; those
  /// which are matched with something other than a literal bracket, or in a pair that
  /// is followed by `(` or `[`, that is the label of a reference definition or that
  /// contains a link, are escaped. A literal bracket which is not escaped does not take
  /// part in the matching, so this is repeated until nothing changes.
  private func resolveBrackets(_ str: String, _ context: InlineContext) -> String {
    let markers = context.markers!
    let chars = Array(str)
    let n = chars.count
    guard chars.contains(where: { $0 == markers.litOpen || $0 == markers.litClose }) else {
      return String(chars.map { ch -> Character in
        ch == markers.linkOpen ? "[" : (ch == markers.linkClose ? "]" : ch)
      })
    }
    func isOpen(_ ch: Character) -> Bool {
      return ch == markers.litOpen || ch == markers.linkOpen
    }
    var labels: Set<String>? = nil
    var bare = Set<Int>()
    for i in 0..<n where chars[i] == markers.litOpen || chars[i] == markers.litClose {
      bare.insert(i)
    }
    var changed = true
    while changed {
      changed = false
      var stack: [Int] = []
      var match: [Int: Int] = [:]
      for i in 0..<n {
        let ch = chars[i]
        if ch == markers.linkOpen || (ch == markers.litOpen && bare.contains(i)) {
          stack.append(i)
        } else if ch == markers.linkClose || (ch == markers.litClose && bare.contains(i)) {
          if let opener = stack.popLast() {
            match[opener] = i
            match[i] = opener
          }
        }
      }
      for i in bare.sorted() {
        guard let m = match[i] else {
          continue
        }
        if chars[i] == markers.litOpen {
          // The pair has to be a pair of literal brackets which cannot form a link
          var inert = chars[m] == markers.litClose
          if inert && m + 1 < n {
            let next = chars[m + 1]
            inert = !(next == "(" || next == "[" || isOpen(next))
          }
          if inert {
            let inner = chars[(i + 1)..<m]
            if inner.contains(where: { $0 == markers.linkOpen || $0 == markers.linkClose }) {
              inert = false
            } else {
              if labels == nil {
                labels = SourceGenerator.referenceLabels(context.parent)
              }
              let label = String(inner.map { $0 == markers.litOpen ? "[" :
                                              ($0 == markers.litClose ? "]" : $0) })
              inert = !labels!.contains(normalizeLinkLabel(label))
            }
          }
          if !inert {
            bare.remove(i)
            changed = true
            break
          }
        } else if chars[i] == markers.litClose && chars[m] == markers.linkOpen {
          // The bracket would close a link
          bare.remove(i)
          changed = true
          break
        }
      }
    }
    var res = ""
    for i in 0..<n {
      let ch = chars[i]
      if ch == markers.litOpen || ch == markers.litClose {
        if !bare.contains(i) {
          res += "\\"
        }
        res.append(ch == markers.litOpen ? "[" : "]")
      } else if ch == markers.linkOpen {
        res.append("[")
      } else if ch == markers.linkClose {
        res.append("]")
      } else {
        res.append(ch)
      }
    }
    return res
  }

  /// The labels of the reference definitions of the document that contains the blocks
  /// of `parent`.
  private static func referenceLabels(_ parent: Parent) -> Set<String> {
    var root: Block? = nil
    var current = parent
    while case .block(let block, let outer) = current {
      root = block
      current = outer
    }
    var labels = Set<String>()
    func collect(_ block: Block) {
      switch block {
        case .document(let blocks), .blockquote(let blocks), .list(_, _, let blocks),
             .listItem(_, _, let blocks):
          blocks.forEach(collect)
        case .definitionList(let definitions):
          definitions.forEach { $0.descriptions.forEach(collect) }
        case .referenceDef(let label, _, _):
          labels.insert(normalizeLinkLabel(label))
        default:
          break
      }
    }
    if let root = root {
      collect(root)
    }
    return labels
  }

  // MARK: Parts of fragments

  /// A code span: the delimiter is a run of backticks that is longer than all runs in
  /// the code, and the code is padded by a space if it starts or ends with a backtick,
  /// or if it starts and ends with a space and the parser would remove one space on
  /// both sides.
  private func codeSpan(_ code: String) -> String {
    var lengths = Set<Int>()
    var run = 0
    for ch in code {
      if ch == "`" {
        run += 1
      } else {
        if run > 0 {
          lengths.insert(run)
        }
        run = 0
      }
    }
    if run > 0 {
      lengths.insert(run)
    }
    var n = 1
    while lengths.contains(n) {
      n += 1
    }
    let pad = code.first == "`" || code.last == "`" ||
              (code.first == " " && code.last == " " && code.contains(where: { $0 != " " }))
    let delimiter = String(repeating: "`", count: n)
    return delimiter + (pad ? " " : "") + code + (pad ? " " : "") + delimiter
  }

  /// The destination of a link: in angle brackets if it contains white space, angle
  /// brackets or unbalanced parentheses. A link with title but without destination
  /// has the destination `<>`.
  private func destination(_ uri: String?, hasTitle: Bool) -> String {
    guard let uri = uri, !uri.isEmpty else {
      return hasTitle ? "<>" : ""
    }
    var open = 0
    var balanced = true
    var prevBackslash = false
    for ch in uri {
      if !prevBackslash {
        if ch == "(" {
          open += 1
        } else if ch == ")" {
          open -= 1
          if open < 0 {
            balanced = false
          }
        }
      }
      prevBackslash = !prevBackslash && ch == "\\"
    }
    let angle = !balanced ||
                open != 0 ||
                uri.contains(where: { isAsciiWhitespaceOrControl($0) || $0 == "<" || $0 == ">" })
    var res = ""
    for ch in uri {
      switch ch {
        case "\\", "`", "[", "]", "<", ">":
          res += "\\"
        default:
          break
      }
      res.append(ch)
    }
    return angle ? "<" + res + ">" : res
  }

  /// The title of a link, with a space in front of it.
  private func title(_ title: String?) -> String {
    guard let title = title else {
      return ""
    }
    return " \"" + title.replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\"", with: "\\\"") + "\""
  }
}
