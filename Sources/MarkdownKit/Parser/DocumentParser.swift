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
/// only a single document/string in Markdown format. They are not `Sendable`: a
/// `MarkdownParser` creates a new object for every parse, which is used by one thread only.
///
open class DocumentParser {
  
  /// The part of the state of the current line which block parsers change when they start
  /// a container. It is used for undoing this if a container is not supposed to be created.
  private struct LineState {
    let line: Substring
    let lineColumn: Int
    let linePartialTab: Int
    let contentStartIndex: Substring.Index
    let lineIndent: Int
    let lineEmpty: Bool
  }
  
  /// The default for the maximal nesting depth of containers (block quotes and list items).
  /// Deeper nesting is not recognized: the markup of containers beyond this depth is treated
  /// like any other text. This protects against stack overflows when processing the (deeply
  /// nested) resulting syntax tree, e.g. for input consisting of many `>` characters. The
  /// value makes sure that processing works even in debug builds on threads with a small
  /// stack (512 KB); it is far deeper than what real documents need.
  public static let defaultMaxContainerDepth = 24
  
  /// Sequence of block parsers which implement the document parsing functionality.
  internal private(set) var blockParsers: [BlockParser]

  /// The input string which gets parsed.
  private let input: String

  fileprivate var index: String.Index?
  fileprivate var container: Container
  fileprivate var currentContainer: Container

  internal var prevParagraphLines: Text?
  internal var prevParagraphLinesTight: Bool
  
  /// Current line being parsed
  internal fileprivate(set) var line: Substring
  
  /// Start index on `line` where the content is (indentation was skipped)
  internal fileprivate(set) var contentStartIndex: Substring.Index
  
  /// End index on `line` where the content is
  internal fileprivate(set) var contentEndIndex: Substring.Index
  
  /// The column at which `line` starts. Tabs advance to the next tab stop (a multiple of 4).
  internal fileprivate(set) var lineColumn: Int
  
  /// If `line` starts with a tab, this is the number of columns of the tab which were already
  /// consumed (e.g. as part of a block quote marker). The remaining columns are indentation.
  internal fileprivate(set) var linePartialTab: Int
  
  /// Number of columns of indentation at beginning of line
  internal fileprivate(set) var lineIndent: Int
  
  /// Is the line empty?
  internal fileprivate(set) var lineEmpty: Bool
  
  /// Was the previous line empty?
  internal fileprivate(set) var prevLineEmpty: Bool
  
  /// Was a container started on the current line? If so, the remainder of the line (which
  /// may be blank) belongs to the container's marker and is not a blank line of its own.
  private var containerStartedOnLine = false
  
  /// The maximal nesting depth of containers (block quotes and list items).
  public var maxContainerDepth: Int = DocumentParser.defaultMaxContainerDepth
  
  /// Initializer
  public init(blockParsers: [BlockParser.Type], input: String) {
    let docContainer = Container()
    self.input = input
    self.index = input.startIndex
    self.blockParsers = []
    self.container = docContainer
    self.currentContainer = docContainer
    self.prevParagraphLines = nil
    self.prevParagraphLinesTight = false
    self.line = input[input.startIndex..<input.startIndex]
    self.contentStartIndex = self.line.startIndex
    self.contentEndIndex = self.line.endIndex
    self.lineColumn = 0
    self.linePartialTab = 0
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
    state.prevParagraphLinesTight = self.prevParagraphLinesTight
    state.line = self.line
    state.contentStartIndex = self.contentStartIndex
    state.contentEndIndex = self.contentEndIndex
    state.lineColumn = self.lineColumn
    state.linePartialTab = self.linePartialTab
    state.lineIndent = self.lineIndent
    state.lineEmpty = self.lineEmpty
    state.prevLineEmpty = self.prevLineEmpty
    state.containers = self.container.snapshot()
  }

  internal func restoreState(_ state: DocumentParserState) {
    // Undo changes to containers (e.g. paragraphs and nested containers which got flushed)
    for snapshot in state.containers {
      snapshot.restore()
    }
    self.index = state.index
    self.container = state.container
    self.currentContainer = state.currentContainer
    self.prevParagraphLines = state.prevParagraphLines
    self.prevParagraphLinesTight = state.prevParagraphLinesTight
    self.line = state.line
    self.contentStartIndex = state.contentStartIndex
    self.contentEndIndex = state.contentEndIndex
    self.lineColumn = state.lineColumn
    self.linePartialTab = state.linePartialTab
    self.lineIndent = state.lineIndent
    self.lineEmpty = state.lineEmpty
    self.prevLineEmpty = state.prevLineEmpty
  }
  
  public var finished: Bool {
    return self.index == nil
  }
  
  /// Declares that the line preceding the current line is not a blank line which separates
  /// blocks. Block parsers which consume blank lines as part of their content (like fenced
  /// code blocks which are not closed) call this when they are done.
  internal func clearPrecedingBlankLine() {
    self.prevLineEmpty = false
  }
  
  public func readNextLine() {
    guard self.index != nil else {
      return
    }
    // The blank remainder of a line which started a container is not a blank line, and neither
    // is a blank line within a block quote (it does not separate the blocks around the quote)
    let lineWasEmpty = self.lineEmpty && !self.containerStartedOnLine &&
                       self.container.blankLinesSeparateBlocks
    self.containerStartedOnLine = false
    if let lines = self.prevParagraphLines {
      self.container.append(block: .paragraph(lines.finalized()), tight: self.prevParagraphLinesTight)
      self.container = self.container.return(to: self.currentContainer, for: self)
      self.prevParagraphLines = nil
      self.prevParagraphLinesTight = false
    }
    guard self.index! < self.input.endIndex else {
      self.index = nil
      self.line = self.input[self.input.endIndex..<self.input.endIndex]
      self.contentStartIndex = self.line.startIndex
      self.contentEndIndex = self.line.endIndex
      self.lineColumn = 0
      self.linePartialTab = 0
      self.lineIndent = 0
      self.prevLineEmpty = lineWasEmpty
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
    let (position, container) = self.container.parseIndent(
                                  input: self.input,
                                  position: LinePosition(index: startIndex, column: 0),
                                  endIndex: self.index!)
    self.currentContainer = container
    self.line = self.input[position.index..<self.index!]
    self.lineColumn = position.column
    self.linePartialTab = position.partialTab
    if index < self.input.endIndex {
      self.contentEndIndex = self.line.index(before: self.line.endIndex)
    } else {
      self.contentEndIndex = self.line.endIndex
    }
    self.prevLineEmpty = lineWasEmpty
    self.updateLineStart()
  }
  
  /// Makes the line start at `startIndex`, which is typically behind the marker of a
  /// container that was just started. If the character at `startIndex` is a tab, `partialTab`
  /// is the number of columns of the tab which are part of the marker.
  public func resetLineStart(_ startIndex: Substring.Index, partialTab: Int = 0) {
    if startIndex > self.line.startIndex {
      // Skipping characters advances the column
      var i = self.line.startIndex
      while i < startIndex {
        self.lineColumn += self.line[i] == "\t" ? LinePosition.tabWidth(at: self.lineColumn) : 1
        i = self.line.index(after: i)
      }
      self.line = self.line[startIndex..<self.line.endIndex]
    }
    self.linePartialTab = partialTab
    self.updateLineStart()
  }
  
  /// Determines the indentation of the line and where its content starts.
  private func updateLineStart() {
    self.lineIndent = 0
    self.contentStartIndex = self.line.startIndex
    self.lineEmpty = true
    var column = self.lineColumn
    var partialTab = self.linePartialTab
    loop: while self.contentStartIndex < self.contentEndIndex {
      switch self.line[self.contentStartIndex] {
        case " ":
          self.lineIndent += 1
          column += 1
        case "\t":
          let width = LinePosition.tabWidth(at: column)
          self.lineIndent += width - partialTab
          column += width
          partialTab = 0
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

  /// Returns true if the current line is not part of the container that is currently open.
  /// This is the case if the line lacks the markup required by the container (e.g. `>`), or,
  /// for blank lines, if the container requires such markup.
  internal var lineLeavesContainer: Bool {
    if self.lineEmpty {
      return self.container.outermostIndentRequired(upto: self.currentContainer) != nil
    } else {
      return self.container !== self.currentContainer
    }
  }
  
  private var lineState: LineState {
    return LineState(line: self.line,
                     lineColumn: self.lineColumn,
                     linePartialTab: self.linePartialTab,
                     contentStartIndex: self.contentStartIndex,
                     lineIndent: self.lineIndent,
                     lineEmpty: self.lineEmpty)
  }

  private func restore(_ state: LineState) {
    self.line = state.line
    self.lineColumn = state.lineColumn
    self.linePartialTab = state.linePartialTab
    self.contentStartIndex = state.contentStartIndex
    self.lineIndent = state.lineIndent
    self.lineEmpty = state.lineEmpty
  }

  open func parse() -> Block {
    loop: while !self.finished {
      if self.lineEmpty {
        if let encl = self.container.outermostIndentRequired(upto: self.currentContainer) {
          // print("container <- \(encl) | \(self.currentContainer)")
          self.container = self.container.return(to: encl, for: self)
        }
        // A list item can begin with at most one blank line
        while !self.containerStartedOnLine,
              self.container.endsAtBlankLineIfEmpty && self.container.content.isEmpty,
              let outer = self.container.enclosing {
          self.container = self.container.return(to: outer, for: self)
        }
        self.readNextLine()
      } else {
        // print("container <= \(self.currentContainer)")
        self.container = self.container.return(to: self.currentContainer, for: self)
        self.currentContainer = self.container
        for blockParser in self.blockParsers {
          let tight = !self.prevLineEmpty
          let saved: LineState? = self.container.depth >= self.maxContainerDepth
                                    ? self.lineState : nil
          switch blockParser.parse() {
            case .none:
              break
            case .block(let block):
              self.container.append(block: block, tight: tight)
              continue loop
            case .container(_) where saved != nil:
              // Containers are nested too deeply: the line start is not a container marker
              self.restore(saved!)
            case .container(let constr):
              self.currentContainer = constr(self.container)
              self.currentContainer.startedTight = tight
              self.container = self.currentContainer
              self.containerStartedOnLine = true
              continue loop
          }
        }
        var lines = Text()
        let linesTight = !self.prevLineEmpty
        lines.append(line: self.lineContent(), withHardLineBreak: false)
        self.readNextLine()
        while !self.finished && !self.lineEmpty {
          self.prevParagraphLines = lines
          self.prevParagraphLinesTight = linesTight
          let tight = !self.prevLineEmpty
          for blockParser in self.blockParsers {
            if blockParser.mayInterruptParagraph {
              // The container which a new container would be nested in
              let base = self.prevParagraphLines != nil ? self.currentContainer : self.container
              let saved: LineState? = base.depth >= self.maxContainerDepth ? self.lineState : nil
              switch blockParser.parse() {
                case .none:
                  break
                case .block(let block):
                  self.container.append(block: block, tight: tight)
                  self.prevParagraphLines = nil
                  self.prevParagraphLinesTight = false
                  continue loop
                case .container(_) where saved != nil:
                  // Containers are nested too deeply: the line start is not a container marker
                  self.restore(saved!)
                case .container(let constr):
                  if let plines = self.prevParagraphLines {
                    self.container.append(block: .paragraph(plines.finalized()),
                                          tight: self.prevParagraphLinesTight)
                    self.container = constr(
                                       self.container.return(to: self.currentContainer, for: self))
                    self.currentContainer = self.container
                  } else {
                    self.currentContainer = constr(self.container)
                    self.container = self.currentContainer
                  }
                  self.currentContainer.startedTight = tight
                  self.containerStartedOnLine = true
                  self.prevParagraphLines = nil
                  self.prevParagraphLinesTight = false
                  continue loop
              }
            }
          }
          self.prevParagraphLines = nil
          self.prevParagraphLinesTight = false
          lines.append(line: self.lineContent(), withHardLineBreak: false)
          self.readNextLine()
        }
        self.container.append(block: .paragraph(lines.finalized()), tight: linesTight)
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
        case .listItem(let type, let t, _):
          if let ltype = listType {
            if type.compatible(with: ltype) {
              items.append(block)
              if !t.isTight {
                tight = false
              }
            } else {
              res.append(.list(ltype.startNumber, tight, items))
              items.removeAll()
              tight = t.isTightInitially
              listType = type
              items.append(block)
            }
          } else {
            listType = type
            items.append(block)
            if !t.isTightInitially {
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

  /// The content of the current line, i.e. the line without indentation and line terminator.
  /// Trailing spaces and a trailing backslash are part of the content. They are only
  /// interpreted when parsing the inline markup, because they are no line break inside of code
  /// spans and HTML tags.
  private func lineContent() -> Substring {
    return self.line[self.contentStartIndex..<self.contentEndIndex]
  }
}

/// Represents a snapshot of the current `DocumentParser`'s state.
internal struct DocumentParserState {
  fileprivate var index: String.Index?
  fileprivate var container: Container
  fileprivate var currentContainer: Container
  fileprivate var prevParagraphLines: Text?
  fileprivate var prevParagraphLinesTight: Bool
  fileprivate var line: Substring
  fileprivate var contentStartIndex: Substring.Index
  fileprivate var contentEndIndex: Substring.Index
  fileprivate var lineColumn: Int
  fileprivate var linePartialTab: Int
  fileprivate var lineIndent: Int
  fileprivate var lineEmpty: Bool
  fileprivate var prevLineEmpty: Bool
  fileprivate var containers: [ContainerSnapshot]

  internal init(_ docParser: DocumentParser) {
    self.index = docParser.index
    self.container = docParser.container
    self.currentContainer = docParser.currentContainer
    self.prevParagraphLines = docParser.prevParagraphLines
    self.prevParagraphLinesTight = docParser.prevParagraphLinesTight
    self.line = docParser.line
    self.contentStartIndex = docParser.contentStartIndex
    self.contentEndIndex = docParser.contentEndIndex
    self.lineColumn = docParser.lineColumn
    self.linePartialTab = docParser.linePartialTab
    self.lineIndent = docParser.lineIndent
    self.lineEmpty = docParser.lineEmpty
    self.prevLineEmpty = docParser.prevLineEmpty
    self.containers = []
  }
}
