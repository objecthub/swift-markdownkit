//
//  BlockParser.swift
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
/// A `BlockParser` parses one particular type of Markdown blocks. Class `BlockParser` defines
/// a framework for such block parsers. Every different block type comes with its own subclass
/// of `BlockParser`.
///
open class BlockParser {

  /// The result of calling the `parse` method.
  /// The result of calling the `parse` method of a block parser.
  public enum ParseResult {
    /// The current line does not start a block of this parser. The document parser then tries the
    /// next block parser.
    case none
    /// The parser recognized a block and consumed its lines. The block is added to the document.
    case block(Block)
    /// The parser recognized the start of a container (such as a block quote or a list item). The
    /// function creates the container, which is nested in the container it is given; the rest of
    /// the line is parsed as part of the new container.
    case container((Container) -> Container)
  }

  unowned let docParser: DocumentParser
  
  /// Creates a block parser for `docParser`. A document parser creates one instance of each
  /// block parser of its configuration, and uses it for the whole document.
  public required init(docParser: DocumentParser) {
    self.docParser = docParser
  }
  
  /// True if all lines of the input have been read.
  public var finished: Bool {
    return self.docParser.finished
  }

  /// The lines of the paragraph that the document parser is collecting while it reads the
  /// current line, or `nil` if the previous line did not belong to a paragraph.
  public var prevParagraphLines: Text? {
    return self.docParser.prevParagraphLines
  }

  /// Discards the collected lines of the paragraph. A block parser calls this method if it
  /// used these lines for the block it creates, such as the text of a setext heading.
  public func consumeParagraphLines() {
    self.docParser.prevParagraphLines = nil
    self.docParser.prevParagraphLinesTight = false
  }
  
  /// The current line without the markers of the containers that have been recognized (such as
  /// `>` of a block quote). It includes its line terminator.
  public var line: Substring {
    return self.docParser.line
  }
  
  /// The index of the first character of the content of `line`, after its indentation.
  public var contentStartIndex: Substring.Index {
    return self.docParser.contentStartIndex
  }
  
  /// The index after the last character of the content of `line`, which is the end of the line
  /// without its line terminator.
  public var contentEndIndex: Substring.Index {
    return self.docParser.contentEndIndex
  }
  
  /// The number of columns by which the current line is indented. A tab advances to the next
  /// multiple of four.
  public var lineIndent: Int {
    return self.docParser.lineIndent
  }
  
  /// The first character of the content of the current line (the first character after the
  /// indentation), or `nil` if the line has no content. Block parsers need to use this
  /// instead of subscripting `line` with `contentStartIndex`, because `contentStartIndex` is
  /// out of bounds for a blank line at the very end of the input (one without a line
  /// terminator).
  public var firstContentCharacter: Character? {
    let start = self.docParser.contentStartIndex
    return start < self.docParser.contentEndIndex ? self.docParser.line[start] : nil
  }
  
  /// True if the current line is blank: it consists of whitespace only.
  public var lineEmpty: Bool {
    return self.docParser.lineEmpty
  }

  /// True if the previous line was blank.
  public var prevLineEmpty: Bool {
    return self.docParser.prevLineEmpty
  }
  
  /// True if the current line is indented by less than four columns, so it cannot be a line of an
  /// indented code block.
  public var shortLineIndent: Bool {
    return self.docParser.shortLineIndent
  }

  /// True if the current line has not the markers of the container that is open, but may still
  /// continue its paragraph (for example a line of a block quote without `>`).
  public var lazyContinuation: Bool {
    return self.docParser.lazyContinuation
  }
  
  /// True if the current line is not part of the container that was open when the parser
  /// started parsing a block (e.g. a block quote that does not continue on this line).
  public var lineLeavesContainer: Bool {
    return self.docParser.lineLeavesContainer
  }

  /// Advances to the next line. A block parser calls this method when it has consumed the current
  /// line.
  open func readNextLine() {
    self.docParser.readNextLine()
  }

  /// Makes the current line start at `startIndex`. Block parsers which start a container (like a
  /// block quote or a list item) call this after they determined the end of the marker of the
  /// container, so that the remainder of the line is parsed as content of the container. If
  /// the character at `startIndex` is a tab, `partialTab` is the number of columns of this tab
  /// that are part of the marker.
  public func resetLineStart(_ startIndex: Substring.Index, partialTab: Int = 0) {
    self.docParser.resetLineStart(startIndex, partialTab: partialTab)
  }

  /// True if a line that this parser recognizes can interrupt a paragraph. This is the default.
  /// Parsers for syntax that is part of a paragraph when it follows its text, such as indented
  /// code, return `false`.
  open var mayInterruptParagraph: Bool {
    return true
  }
  
  /// Tries to parse a block, or the start of a container, at the current line. The default
  /// implementation returns `.none`. A parser that recognizes its syntax consumes the lines of
  /// the block with `readNextLine()` and returns the block.
  open func parse() -> ParseResult {
    return .none
  }
}

///
/// `RestorableBlockParser` objects are `BlockParser` objects which restore the
/// `DocumentParser` state in case their `parse` method fails (the `ParseResult` is `.none`).
/// 
open class RestorableBlockParser: BlockParser {
  private var docParserState: DocumentParserState

  /// Creates a block parser for `docParser`, and saves the state of the document parser for
  /// restoring it.
  public required init(docParser: DocumentParser) {
    self.docParserState = DocumentParserState(docParser)
    super.init(docParser: docParser)
  }

  /// Calls `tryParse()`. If it returns `.none`, the state of the document parser is restored, so
  /// that the next block parser sees the unchanged input.
  open override func parse() -> ParseResult {
    self.docParser.copyState(&self.docParserState)
    let res = self.tryParse()
    if case .none = res {
      self.docParser.restoreState(self.docParserState)
      return .none
    } else {
      return res
    }
  }

  /// Tries to parse a block, or the start of a container, like `parse()`. A subclass overrides
  /// this method instead of `parse()`: it can consume lines before it finds out that its syntax is
  /// not present, because the document parser is restored if the result is `.none`.
  open func tryParse() -> ParseResult {
    return .none
  }
}
