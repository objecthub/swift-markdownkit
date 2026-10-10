//
//  FullMarkdownParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 10/10/2026.
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
/// `FullMarkdownParser` objects are used to parse Markdown text represented as a string using
/// all features of MarkdownKit: the syntax of the CommonMark specification and all extensions
/// that MarkdownKit implements.
///
/// - Tables and definition lists (like `ExtendedMarkdownParser`)
/// - Underlined text: `~underlined~`, represented as `TextFragment.underline`
/// - Struck-through text: `~~struck through~~`, represented as `TextFragment.strikethrough`
/// - Task list items: `- [ ] to do` and `- [x] done`, represented by `ListType.task`
///
/// The syntax of tables, struck-through text and task lists is the one of GitHub Flavored Markdown
/// (GFM), with two differences: GFM also treats a single tilde as strikethrough, whereas
/// `FullMarkdownParser` uses it for underlined text; and `FullMarkdownParser` also supports
/// definition lists, which GFM does not.
///
/// `FullMarkdownParser` is a subclass of `ExtendedMarkdownParser`, so it can be used wherever a
/// `MarkdownParser` is expected. `MarkdownParser` and `ExtendedMarkdownParser` themselves do
/// not recognize the additional markup. It is the parser of choice if everything MarkdownKit
/// understands should be used; new Markdown features will be added to this parser.
///
open class FullMarkdownParser: ExtendedMarkdownParser, @unchecked Sendable {

  /// The default list of inline transformers. The order of this list matters; in particular,
  /// `EscapeTransformer` has to be the last transformer (see its documentation).
  override open class var defaultInlineTransformers: [InlineTransformer.Type] {
    return self.fullInlineTransformers
  }

  private static let fullInlineTransformers: [InlineTransformer.Type] = [
    LineEmphasisDelimiterTransformer.self,
    CodeLinkHtmlTransformer.self,
    LinkTransformer.self,
    LineEmphasisTransformer.self,
    EscapeTransformer.self
  ]

  /// Defines a default implementation
  override open class var standard: FullMarkdownParser {
    return self.singleton
  }

  private static let singleton: FullMarkdownParser = FullMarkdownParser()

  /// Factory method for inline parsing: the inline parser also recognizes task list items.
  open override func inlineParser(inlineTransformers: [InlineTransformer.Type],
                                  input: Block) -> InlineParser {
    return TaskListInlineParser(inlineTransformers: inlineTransformers, input: input)
  }
}
