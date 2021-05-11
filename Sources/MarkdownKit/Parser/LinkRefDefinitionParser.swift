//
//  LinkRefDefinitionParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 11/05/2019.
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
/// A block parser which parses link reference definitions returning `referenceDef` blocks.
///
open class LinkRefDefinitionParser: RestorableBlockParser {

  public override var mayInterruptParagraph: Bool {
    return false
  }

  public override func parse() -> BlockParser.ParseResult {
    guard self.shortLineIndent && self.line[self.contentStartIndex] == "[" else {
      return .none
    }
    return super.parse()
  }

  public override func tryParse() -> ParseResult {
    var index = self.contentStartIndex
    guard let label = self.parseLabel(index: &index),
          index < self.contentEndIndex,
          self.line[index] == ":" else {
      return .none
    }
    index = self.line.index(after: index)
    guard self.skipSpace(index: &index) != nil else {
      return .none
    }
    let destination: Substring
    if self.line[index] == "<" {
      var prevBackslash = false
      index = self.line.index(after: index)
      let destStart = index
      while index < self.contentEndIndex && (prevBackslash || self.line[index] != ">") {
        guard prevBackslash || self.line[index] != "<" else {
          return .none
        }
        prevBackslash = !prevBackslash && self.line[index] == "\\"
        index = self.line.index(after: index)
      }
      guard index < self.contentEndIndex else {
        return .none
      }
      destination = self.line[destStart..<index]
      index = self.line.index(after: index)
    } else {
      let destStart = index
      while index < self.contentEndIndex {
        if let ascii = self.line[index].asciiValue, ascii <= 32 {
          break
        }
        index = self.line.index(after: index)
      }
      destination = self.line[destStart..<index]
      guard LinkRefDefinitionParser.balanced(destination) else {
        return .none
      }
    }
    guard index >= self.contentEndIndex || isWhitespace(self.line[index]) else {
      return .none
    }
    let onNewLine = self.skipSpace(index: &index)
    guard onNewLine != nil else {
      return .block(.referenceDef(label, destination, []))
    }
    let title: Lines
    switch self.line[index] {
      case "\"":
        title = self.parseMultiLine(index: &index, closing: "\"", requireWhitespaces: true)
      case "'":
        title = self.parseMultiLine(index: &index, closing: "'", requireWhitespaces: true)
      case "(":
        title = self.parseMultiLine(index: &index, closing: ")", requireWhitespaces: true)
      default:
        guard index == self.contentStartIndex else {
          return .none
        }
        return .block(.referenceDef(label, destination, []))
    }
    if title.isEmpty {
      if onNewLine == true {
        return .block(.referenceDef(label, destination, []))
      } else {
        return .none
      }
    }
    skipWhitespace(in: self.line, from: &index, to: self.contentEndIndex)
    guard index >= self.contentEndIndex else {
      return .none
    }
    self.readNextLine()
    return .block(.referenceDef(label, destination, title))
  }

  public static func balanced(_ str: Substring) -> Bool {
    var open = 0
    var index = str.startIndex
    var prevBackslash = false
    while index < str.endIndex {
      switch str[index] {
        case "(":
          if !prevBackslash {
            open += 1
          }
        case ")":
          if !prevBackslash {
            open -= 1
            guard open >= 0 else {
              return false
            }
          }
        case "\\":
          prevBackslash = !prevBackslash && str[index] == "\\"
        default:
          break
      }
      index = str.index(after: index)
    }
    return open == 0
  }

  private func skipSpace(index: inout Substring.Index) -> Bool? {
    var newline = false
    skipWhitespace(in: self.line, from: &index, to: self.contentEndIndex)
    if index >= self.contentEndIndex {
      self.readNextLine()
      newline = true
      if self.finished {
        return nil
      }
      index = self.contentStartIndex
      skipWhitespace(in: self.line, from: &index, to: self.contentEndIndex)
      if index >= self.contentEndIndex {
        return nil
      }
    }
    return newline
  }

  private func parseLabel(index: inout Substring.Index) -> String? {
    let labelLines = self.parseMultiLine(index: &index, closing: "]", requireWhitespaces: false)
    var res = ""
    for line in labelLines {
      let components = line.components(separatedBy: .whitespaces)
      let newLine = components.filter { !$0.isEmpty }.joined(separator: " ")
      if !newLine.isEmpty {
        if res.isEmpty {
          res = newLine
        } else {
          res.append(" ")
          res.append(newLine)
        }
      }
    }
    let length = res.count
    return length > 0 && length < 1000 ? res : nil
  }

  private func parseMultiLine(index: inout Substring.Index,
                              closing closeCh: Character,
                              requireWhitespaces: Bool) -> Lines {
    let openCh = self.line[index]
    index = self.line.index(after: index)
    var start = index
    var prevBackslash = false
    var res: Lines = []
    while !self.finished && !self.lineEmpty {
      while index < self.contentEndIndex &&
            (prevBackslash || self.line[index] != closeCh) {
        if !prevBackslash && self.line[index] == openCh {
          return []
        }
        prevBackslash = !prevBackslash && self.line[index] == "\\"
        index = self.line.index(after: index)
      }
      if index >= self.contentEndIndex {
        res.append(self.line[start..<self.contentEndIndex])
        self.readNextLine()
        if self.finished {
          return []
        }
        index = self.contentStartIndex
        start = index
      } else {
        res.append(self.line[start..<index])
        index = self.line.index(after: index)
        if requireWhitespaces {
          skipWhitespace(in: self.line, from: &index, to: self.contentEndIndex)
          guard index >= self.contentEndIndex else {
            return []
          }
        }
        return res
      }
    }
    return []
  }
}
