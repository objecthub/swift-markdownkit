//
//  DocumentParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 20/04/2019.
//  Copyright © 2019-2020 Google LLC.
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
/// A `DocumentParser` implements Markdown block parsing for a list of `BlockParsers` and
/// and an input string. `DocumentParser` objects are stateful and can be used for parsing
/// only a single document/string in Markdown format.
///
open class DocumentParser {

  /// Sequence of block parsers which implement the document parsing functionality.
  internal private(set) var blockParsers: [BlockParser]

  /// The input string which gets parsed.
  private let input: String

  fileprivate var index: String.Index?
  fileprivate var container: Container
  fileprivate var currentContainer: Container

  internal var prevParagraphLines: Text?
  internal var line: Substring
  internal var contentStartIndex: Substring.Index
  internal var contentEndIndex: Substring.Index
  internal var lineIndent: Int
  internal var lineEmpty: Bool
  internal var prevLineEmpty: Bool

  /// Initializer
  public init(blockParsers: [BlockParser.Type], input: String) {
    let docContainer = Container()
    self.input = input
    self.index = input.startIndex
    self.blockParsers = []
    self.container = docContainer
    self.currentContainer = docContainer
    self.prevParagraphLines = nil
    self.line = input[input.startIndex..<input.startIndex]
    self.contentStartIndex = self.line.startIndex
    self.contentEndIndex = self.line.endIndex
    self.lineIndent = 0
    self.lineEmpty = true
    self.prevLineEmpty = false
    for parserType in blockParsers {
      self.blockParsers.append(parserType.init(docParser: self))
    }
    self.readNextLine()
  }

  internal func copyState(_ state: inout DocumentParserState) {
    state.index = self.index
    state.container = self.container
    state.currentContainer = self.currentContainer
    state.prevParagraphLines = self.prevParagraphLines
    state.line = self.line
    state.contentStartIndex = self.contentStartIndex
    state.contentEndIndex = self.contentEndIndex
    state.lineIndent = self.lineIndent
    state.lineEmpty = self.lineEmpty
    state.prevLineEmpty = self.prevLineEmpty
  }

  internal func restoreState(_ state: DocumentParserState) {
    self.index = state.index
    self.container = state.container
    self.currentContainer = state.currentContainer
    self.prevParagraphLines = state.prevParagraphLines
    self.line = state.line
    self.contentStartIndex = state.contentStartIndex
    self.contentEndIndex = state.contentEndIndex
    self.lineIndent = state.lineIndent
    self.lineEmpty = state.lineEmpty
    self.prevLineEmpty = state.prevLineEmpty
  }
  
  public var finished: Bool {
    return self.index == nil
  }
  
  public func readNextLine() {
    guard self.index != nil else {
      return
    }
    if let lines = self.prevParagraphLines {
      self.container.content.append(.paragraph(lines.finalized()))
      self.container = self.container.return(to: self.currentContainer, for: self)
      self.prevParagraphLines = nil
    }
    guard self.index! < self.input.endIndex else {
      self.index = nil
      self.line = self.input[self.input.endIndex..<self.input.endIndex]
      self.contentStartIndex = self.line.startIndex
      self.contentEndIndex = self.line.endIndex
      self.lineIndent = 0
      self.prevLineEmpty = self.lineEmpty
      self.lineEmpty = true
      return
    }
    var index = self.index!
    var endIndex = self.input.endIndex
    while index < endIndex {
      switch self.input[index] {
        case "\n", "\r", "\r\n":
          endIndex = index
        default:
          index = self.input.index(after: index)
      }
    }
    let startIndex = self.index!
    if index < self.input.endIndex {
      self.index = self.input.index(after: index)
    } else {
      self.index = self.input.endIndex
    }
    let (newstart, container) = self.container.parseIndent(input: self.input,
                                                           startIndex: startIndex,
                                                           endIndex: self.index!)
    self.currentContainer = container
    self.line = self.input[newstart..<self.index!]
    if index < self.input.endIndex {
      self.contentEndIndex = self.line.index(before: self.line.endIndex)
    } else {
      self.contentEndIndex = self.line.endIndex
    }
    self.prevLineEmpty = self.lineEmpty
    self.resetLineStart(self.line.startIndex)
  }
  
  public func resetLineStart(_ startIndex: Substring.Index) {
    if startIndex > self.line.startIndex {
      self.line = self.line[startIndex..<self.line.endIndex]
    }
    self.lineIndent = 0
    self.contentStartIndex = self.line.startIndex
    self.lineEmpty = true
    loop: while self.contentStartIndex < self.contentEndIndex {
      switch self.line[self.contentStartIndex] {
        case " ":
          self.lineIndent += 1
        case "\t":
          self.lineIndent += 4
        default:
          self.lineEmpty = false
          break loop
      }
      self.contentStartIndex = self.line.index(after: self.contentStartIndex)
    }
  }
  
  internal var shortLineIndent: Bool {
    return self.lineIndent < 4
  }

  internal var lazyContinuation: Bool {
    return self.container !== self.currentContainer
  }

  public func parse() -> Block {
    loop: while !self.finished {
      if self.lineEmpty {
        if let encl = self.container.outermostIndentRequired(upto: self.currentContainer) {
          // print("container <- \(encl) | \(self.currentContainer)")
          self.container = self.container.return(to: encl, for: self)
        }
        self.readNextLine()
      } else {
        // print("container <= \(self.currentContainer)")
        self.container = self.container.return(to: self.currentContainer, for: self)
        self.currentContainer = self.container
        for blockParser in self.blockParsers {
          switch blockParser.parse() {
            case .none:
              break
            case .block(let block):
              self.container.content.append(block)
              continue loop
            case .container(let constr):
              self.currentContainer = constr(self.container)
              self.container = self.currentContainer
              continue loop
          }
        }
        var lines = Text()
        lines.append(line: self.trimLine(), withHardLineBreak: self.hasHardLineBreak())
        self.readNextLine()
        while !self.finished && !self.lineEmpty {
          self.prevParagraphLines = lines
          for blockParser in self.blockParsers {
            if blockParser.mayInterruptParagraph {
              switch blockParser.parse() {
                case .none:
                  break
                case .block(let block):
                  self.container.content.append(block)
                  self.prevParagraphLines = nil
                  continue loop
                case .container(let constr):
                  if let plines = self.prevParagraphLines {
                    self.container.content.append(.paragraph(plines.finalized()))
                    self.container = constr(
                                       self.container.return(to: self.currentContainer, for: self))
                    self.currentContainer = self.container
                  } else {
                    self.currentContainer = constr(self.container)
                    self.container = self.currentContainer
                  }
                  self.prevParagraphLines = nil
                  continue loop
              }
            }
          }
          self.prevParagraphLines = nil
          lines.append(line: self.trimLine(), withHardLineBreak: self.hasHardLineBreak())
          self.readNextLine()
        }
        self.container.content.append(.paragraph(lines.finalized()))
      }
    }
    self.container = self.container.return(for: self)
    return .document(self.bundle(blocks: self.container.content))
  }
  
  /// Normalizes a given array of `Block` objects and returns it in a `Blocks` object.
  open func bundle(blocks: [Block]) -> Blocks {
    var res: Blocks = []
    var items: Blocks = []
    var listType: ListType? = nil
    var tight: Bool = true
    for block in blocks {
      switch block {
        case .listItem(let type, let t, let nested):
          if let ltype = listType {
            if type.compatible(with: ltype) {
              items.append(block)
              if !t || !nested.isSingleton {
                tight = false
              }
            } else {
              res.append(.list(ltype.startNumber, tight, items))
              items.removeAll()
              tight = nested.isSingleton
              listType = type
              items.append(block)
            }
          } else {
            listType = type
            items.append(block)
            if !nested.isSingleton {
              tight = false
            }
          }
        default:
          if let ltype = listType {
            res.append(.list(ltype.startNumber, tight, items))
            items.removeAll()
            tight = true
            listType = nil
          }
          res.append(block)
      }
    }
    if let ltype = listType {
      res.append(.list(ltype.startNumber, tight, items))
      items.removeAll()
      tight = true
      listType = nil
    }
    return res
  }

  private func trimLine() -> Substring {
    var i = self.line.index(before: self.contentEndIndex)
    while i >= self.contentStartIndex && (self.line[i] == " " || self.line[i] == "\t") {
      i = self.line.index(before: i)
    }
    return self.line[self.contentStartIndex...i]
  }

  private func hasHardLineBreak() -> Bool {
    var i = self.line.index(before: self.contentEndIndex)
    guard i >= self.line.startIndex && self.line[i] == " " else {
      return false
    }
    i = self.line.index(before: i)
    guard i >= self.line.startIndex && self.line[i] == " " else {
      return false
    }
    return true
  }
}

/// Represents a snapshot of the current `DocumentParser`'s state.
internal struct DocumentParserState {
  fileprivate var index: String.Index?
  fileprivate var container: Container
  fileprivate var currentContainer: Container
  fileprivate var prevParagraphLines: Text?
  fileprivate var line: Substring
  fileprivate var contentStartIndex: Substring.Index
  fileprivate var contentEndIndex: Substring.Index
  fileprivate var lineIndent: Int
  fileprivate var lineEmpty: Bool
  fileprivate var prevLineEmpty: Bool

  internal init(_ docParser: DocumentParser) {
    self.index = docParser.index
    self.container = docParser.container
    self.currentContainer = docParser.currentContainer
    self.prevParagraphLines = docParser.prevParagraphLines
    self.line = docParser.line
    self.contentStartIndex = docParser.contentStartIndex
    self.contentEndIndex = docParser.contentEndIndex
    self.lineIndent = docParser.lineIndent
    self.lineEmpty = docParser.lineEmpty
    self.prevLineEmpty = docParser.prevLineEmpty
  }
}
