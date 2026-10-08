//
//  CodeBlockParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 01/05/2019.
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
/// Block parsers for parsing different types of code blocks. `CodeBlockParser` implements
/// shared logic between two concrete implementations, `IndentedCodeBlockParser` and
/// `FencedCodeBlockParser`.
///
open class CodeBlockParser: BlockParser {
  
  /// Returns the current line without `n` columns of indentation. Tabs expand to the next tab
  /// stop. If a tab spans more columns than are left to be removed, the remaining columns
  /// stay as spaces.
  public func formatIndentedLine(_ n: Int = 4) -> Substring {
    let line = self.line
    let start = LinePosition(index: line.startIndex,
                             column: self.docParser.lineColumn,
                             partialTab: self.docParser.linePartialTab)
    let (position, _) = start.consumingWhitespace(in: line, endIndex: line.endIndex, columns: n)
    if position.partialTab > 0 {
      let remaining = LinePosition.tabWidth(at: position.column) - position.partialTab
      let rest = line[line.index(after: position.index)..<line.endIndex]
      return Substring(String(repeating: " ", count: remaining) + rest)
    }
    return line[position.index..<line.endIndex]
  }
}

///
/// A code block parser which parses indented code blocks returning `indentedCode` blocks.
///
public final class IndentedCodeBlockParser: CodeBlockParser {

  public override var mayInterruptParagraph: Bool {
    return false
  }

  public override func parse() -> ParseResult {
    guard !self.shortLineIndent else {
      return .none
    }
    var code: Lines = [self.formatIndentedLine()]
    var emptyLines: Lines = []
    self.readNextLine()
    while !self.finished && !self.lineLeavesContainer && (!self.shortLineIndent || self.lineEmpty) {
      if self.lineEmpty {
        emptyLines.append(self.formatIndentedLine())
      } else {
        if emptyLines.count > 0 {
          code.append(contentsOf: emptyLines)
          emptyLines.removeAll()
        }
        code.append(self.formatIndentedLine())
      }
      self.readNextLine()
    }
    return .block(.indentedCode(code))
  }
}

///
/// A code block parser which parses fenced code blocks returning `fencedCode` blocks.
///
public final class FencedCodeBlockParser: CodeBlockParser {
  
  public override func parse() -> ParseResult {
    guard self.shortLineIndent else {
      return .none
    }
    guard let fenceChar = self.firstContentCharacter,
          fenceChar == "`" || fenceChar == "~" else {
      return .none
    }
    let fenceIndent = self.lineIndent
    var fenceLength = 1
    var index = self.line.index(after: self.contentStartIndex)
    while index < self.contentEndIndex && self.line[index] == fenceChar {
      fenceLength += 1
      index = self.line.index(after: index)
    }
    guard fenceLength >= 3 else {
      return .none
    }
    let rawInfo = self.line[index..<self.contentEndIndex]
                      .trimmingCharacters(in: CharacterSet.whitespaces)
    // The info string of a backtick fence cannot contain backticks (the line would be a
    // code span); there is no such restriction for tilde fences.
    guard fenceChar != "`" || !rawInfo.contains("`") else {
      return .none
    }
    let info = FencedCodeBlockParser.resolveEscapesAndEntities(in: rawInfo)
    self.readNextLine()
    var code: Lines = []
    var closed = false
    while !self.finished && !self.lineLeavesContainer {
      if !self.lineEmpty && self.shortLineIndent {
        var fenceCloseLength = 0
        index = self.contentStartIndex
        while index < self.contentEndIndex && self.line[index] == fenceChar {
          fenceCloseLength += 1
          index = self.line.index(after: index)
        }
        if fenceCloseLength >= fenceLength {
          while index < self.contentEndIndex && isUnicodeWhitespace(self.line[index]) {
            index = self.line.index(after: index)
          }
          if index == self.contentEndIndex {
            closed = true
            break
          }
        }
      }
      code.append(self.formatIndentedLine(fenceIndent))
      self.readNextLine()
    }
    if closed {
      // skip the closing fence
      self.readNextLine()
    } else {
      // Blank lines at the end of a code block which is not closed belong to the code; they do
      // not separate the code block from the block that follows
      self.docParser.clearPrecedingBlankLine()
    }
    return .block(.fencedCode(info.isEmpty ? nil : info, code))
  }
  
  /// Backslash escapes and entity references (like `&ouml;` or `&#246;`) are processed in the
  /// info string of a fenced code block, as they are in other text. This returns the info
  /// string with backslashes in front of ASCII punctuation characters removed and with all
  /// entity references (that are not escaped) replaced by the characters they stand for.
  static func resolveEscapesAndEntities(in info: String) -> String {
    guard info.contains("\\") || info.contains("&") else {
      return info
    }
    var result = ""
    var pending = ""  // text which is not escaped and might contain entity references
    var i = info.startIndex
    while i < info.endIndex {
      let next = info.index(after: i)
      if info[i] == "\\" && next < info.endIndex && isAsciiPunctuation(info[next]) {
        result.append(pending.decodingNamedCharacters())
        pending = ""
        result.append(info[next])
        i = info.index(after: next)
      } else {
        pending.append(info[i])
        i = next
      }
    }
    result.append(pending.decodingNamedCharacters())
    return result
  }
}
