//
//  MarkdownParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 03/05/2019.
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
/// `MarkdownParser` objects are used to parse Markdown text represented as a string.
/// The `MarkdownParser` object itself defines the configuration of the parser. It is
/// stateless in the sense that it can be used for parsing many input strings. This is
/// done via the `parse` function. `parse` returns an abstract syntac tree representing
/// the Markdown text for the given input string.
///
/// The `parse` method of the `MarkdownParser` object delegates parsing of the input
/// string to two types of processors: a `BlockParser` object and an `InlineTransformer`
/// object. A `BlockParser` parses the Markdown block structure returning an abstract
/// syntax tree ignoring inline markup. An `InlineTransformer` object is used to parse
/// a particular type of inline markup within text of Markdown blocks, replacing the
/// matching text with an abstract syntax tree representing the markup.
///
/// The `parse` method of `MarkdownParser` operates in two phases: in the first phase,
/// the block structure of an input string is identified via the `BlockParser`s. In the
/// second phase, the block structure gets traversed and markup within raw text gets
/// replaced with a structured representation.
///
open class MarkdownParser {

  /// The default list of block parsers. The order of this list matters.
  open class var defaultBlockParsers: [BlockParser.Type] {
    return self.blockParsers
  }

  private static let blockParsers: [BlockParser.Type] = MarkdownParser.headingParsers + [
    IndentedCodeBlockParser.self,
    FencedCodeBlockParser.self,
    HtmlBlockParser.self,
    LinkRefDefinitionParser.self,
    BlockquoteParser.self,
    ListItemParser.self
  ]
  
  public static let headingParsers: [BlockParser.Type] = [
    AtxHeadingParser.self,
    SetextHeadingParser.self,
    ThematicBreakParser.self
  ]

  /// The default list of inline transformers. The order of this list matters.
  open class var defaultInlineTransformers: [InlineTransformer.Type] {
    return self.inlineTransformers
  }

  private static let inlineTransformers: [InlineTransformer.Type] = [
    DelimiterTransformer.self,
    CodeLinkHtmlTransformer.self,
    LinkTransformer.self,
    EmphasisTransformer.self,
    EscapeTransformer.self
  ]

  /// Defines a default implementation
  open class var standard: MarkdownParser {
    return self.singleton
  }
  
  private static let singleton: MarkdownParser = MarkdownParser()
  
  /// A custom list of block parsers; if this is provided via the constructor, it overrides
  /// the `defaultBlockParsers`.
  private let customBlockParsers: [BlockParser.Type]?

  /// A custom list of inline transformers; if this is provided via the constructor, it overrides
  /// the `defaultInlineTransformers`.
  private let customInlineTransformers: [InlineTransformer.Type]?

  /// Block parsing gets delegated to a stateful `DocumentParser` object which implements a
  /// protocol for invoking the `BlockParser` objects that its initializer is creating based
  /// on the types provided in the `blockParsers` parameter.
  public func documentParser(input: String) -> DocumentParser {
    return self.documentParser(blockParsers: self.customBlockParsers ??
                                             type(of: self).defaultBlockParsers,
                               input: input)
  }
  
  /// Factory method to customize document parsing in subclasses.
  open func documentParser(blockParsers: [BlockParser.Type], input: String) -> DocumentParser {
    return DocumentParser(blockParsers: blockParsers, input: input)
  }
  
  /// Inline parsing is performed via a stateless `InlineParser` object which implements a
  /// protocol for invoking the `InlineTransformer` objects. Since the inline parser is stateless,
  /// a single object gets created lazily and reused for parsing all input.
  public func inlineParser(input: Block) -> InlineParser {
    return self.inlineParser(inlineTransformers: self.customInlineTransformers ??
                                                 type(of: self).defaultInlineTransformers,
                             input: input)
  }
  
  /// Factory method to customize inline parsing in subclasses.
  open func inlineParser(inlineTransformers: [InlineTransformer.Type],
                         input: Block) -> InlineParser {
    return InlineParser(inlineTransformers: inlineTransformers, input: input)
  }
  
  /// Constructor of `MarkdownParser` objects; it takes a list of block parsers, a list of
  /// inline transformers as well as an input string as its parameters.
  public init(blockParsers: [BlockParser.Type]? = nil,
              inlineTransformers: [InlineTransformer.Type]? = nil) {
    self.customBlockParsers = blockParsers
    self.customInlineTransformers = inlineTransformers
  }

  /// Invokes the parser and returns an abstract syntx tree of the Markdown syntax.
  /// If `blockOnly` is set to `true` (default is `false`), only the block parsers are
  /// invoked and no inline parsing gets performed.
  public func parse(_ str: String, blockOnly: Bool = false) -> Block {
    let doc = self.documentParser(input: str).parse()
    if blockOnly {
      return doc
    } else {
      return self.inlineParser(input: doc).parse()
    }
  }
}
