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
  public enum ParseResult {
    case none
    case block(Block)
    case container((Container) -> Container)
  }

  unowned let docParser: DocumentParser
  
  public required init(docParser: DocumentParser) {
    self.docParser = docParser
  }
  
  public var finished: Bool {
    return self.docParser.finished
  }

  public var prevParagraphLines: Text? {
    return self.docParser.prevParagraphLines
  }

  public func consumeParagraphLines() {
    self.docParser.prevParagraphLines = nil
  }
  
  public var line: Substring {
    return self.docParser.line
  }
  
  public var contentStartIndex: Substring.Index {
    return self.docParser.contentStartIndex
  }
  
  public var contentEndIndex: Substring.Index {
    return self.docParser.contentEndIndex
  }
  
  public var lineIndent: Int {
    return self.docParser.lineIndent
  }
  
  public var lineEmpty: Bool {
    return self.docParser.lineEmpty
  }

  public var prevLineEmpty: Bool {
    return self.docParser.prevLineEmpty
  }
  
  public var shortLineIndent: Bool {
    return self.docParser.shortLineIndent
  }

  public var lazyContinuation: Bool {
    return self.docParser.lazyContinuation
  }
  
  open func readNextLine() {
    self.docParser.readNextLine()
  }

  open var mayInterruptParagraph: Bool {
    return true
  }
  
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

  public required init(docParser: DocumentParser) {
    self.docParserState = DocumentParserState(docParser)
    super.init(docParser: docParser)
  }

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

  open func tryParse() -> ParseResult {
    return .none
  }
}
