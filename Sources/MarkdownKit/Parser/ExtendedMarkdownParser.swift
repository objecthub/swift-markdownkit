//
//  ExtendedMarkdownParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 17/07/2020.
//  Copyright © 2020 Google LLC.
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
/// `ExtendedMarkdownParser` objects are used to parse Markdown text represented as a string
/// using all extensions to the CommonMark specification implemented by MarkdownKit.
/// 
/// The `ExtendedMarkdownParser` object itself defines the configuration of the parser.
/// It is stateless in the sense that it can be used for parsing many input strings. This
/// is done via the `parse` function. `parse` returns an abstract syntac tree representing
/// the Markdown text for the given input string.
///
/// The `parse` method of the `ExtendedMarkdownParser` object delegates parsing of the input
/// string to two types of processors: a `BlockParser` object and an `InlineTransformer`
/// object. A `BlockParser` parses the Markdown block structure returning an abstract
/// syntax tree ignoring inline markup. An `InlineTransformer` object is used to parse
/// a particular type of inline markup within text of Markdown blocks, replacing the
/// matching text with an abstract syntax tree representing the markup.
///
/// The `parse` method of `ExtendedMarkdownParser` operates in two phases: in the first
/// phase, the block structure of an input string is identified via the `BlockParser`s.
/// In the second phase, the block structure gets traversed and markup within raw text
/// gets replaced with a structured representation.
///
open class ExtendedMarkdownParser: MarkdownParser {

  /// The default list of block parsers. The order of this list matters.
  override open class var defaultBlockParsers: [BlockParser.Type] {
    return self.blockParsers
  }

  private static let blockParsers: [BlockParser.Type] = MarkdownParser.headingParsers + [
    IndentedCodeBlockParser.self,
    FencedCodeBlockParser.self,
    HtmlBlockParser.self,
    LinkRefDefinitionParser.self,
    BlockquoteParser.self,
    ExtendedListItemParser.self,
    TableParser.self
  ]
  
  /// Defines a default implementation
  override open class var standard: ExtendedMarkdownParser {
    return self.singleton
  }
  
  private static let singleton: ExtendedMarkdownParser = ExtendedMarkdownParser()
  
  /// Factory method to customize document parsing in subclasses.
  open override func documentParser(blockParsers: [BlockParser.Type],
                                    input: String) -> DocumentParser {
    return ExtendedDocumentParser(blockParsers: blockParsers, input: input)
  }
}
