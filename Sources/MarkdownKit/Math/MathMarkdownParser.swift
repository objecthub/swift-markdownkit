//
//  MathMarkdownParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 17/10/2026.
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
/// `MathMarkdownParser` is a ``FullMarkdownParser`` which also recognizes LaTeX math:
///
/// - `$a^2$` is a formula within a line of text, `$$a^2$$` a display formula within a line
///   (see ``MathTransformer`` for the rules).
/// - `$$` on its own lines encloses a formula which is a block of its own, as does a fenced code
///   block with the info string `math` (see ``MathBlockParser`` and ``MathInlineParser``).
///
/// The formulas are represented by ``MathFragment`` and ``MathBlock`` objects. Use
/// ``LaTeXMarkdownParser`` for the delimiters `\(…\)` and `\[…\]` as well. The other parsers
/// of MarkdownKit leave dollar signs alone, so a text such as `costs $5 and $6` is the same
/// for all of them; use this parser if the Markdown can contain formulas. How a formula is shown
/// is up to the generator: see ``MathFragment``.
///
/// ```swift
/// let doc = MathMarkdownParser.standard.parse("The area is $\\pi r^2$.")
/// ```
///
open class MathMarkdownParser: FullMarkdownParser, @unchecked Sendable {

  /// The block parsers of ``FullMarkdownParser`` and ``MathBlockParser``, which comes before
  /// the parser for tables: that parser looks at the lines of the blocks which follow.
  override open class var defaultBlockParsers: [BlockParser.Type] {
    return self.mathBlockParsers
  }

  private static let mathBlockParsers: [BlockParser.Type] = {
    var parsers = FullMarkdownParser.defaultBlockParsers
    let index = parsers.firstIndex { $0 == TableParser.self } ?? parsers.endIndex
    parsers.insert(MathBlockParser.self, at: index)
    return parsers
  }()

  /// The inline transformers of ``FullMarkdownParser`` and ``MathTransformer``, which comes
  /// after the transformer for code, HTML and autolinks (so code stays code) and before the
  /// transformers for links and emphasis (so they do not change the LaTeX).
  override open class var defaultInlineTransformers: [InlineTransformer.Type] {
    return self.mathInlineTransformers
  }

  private static let mathInlineTransformers: [InlineTransformer.Type] = {
    var transformers = FullMarkdownParser.defaultInlineTransformers
    let index = transformers.firstIndex { $0 == CodeLinkHtmlTransformer.self }
    transformers.insert(MathTransformer.self, at: index.map { $0 + 1 } ?? transformers.endIndex)
    return transformers
  }()

  /// Defines a default implementation
  override open class var standard: MathMarkdownParser {
    return self.singleton
  }

  private static let singleton: MathMarkdownParser = MathMarkdownParser()

  /// Factory method for inline parsing: the inline parser also turns fenced code blocks with the
  /// info string `math` into formulas.
  open override func inlineParser(inlineTransformers: [InlineTransformer.Type],
                                  input: Block) -> InlineParser {
    return MathInlineParser(inlineTransformers: inlineTransformers, input: input)
  }
}

///
/// `LaTeXMarkdownParser` is a ``MathMarkdownParser`` which also recognizes the delimiters of
/// LaTeX for formulas:
///
/// - `\(a^2\)` is a formula within a line of text, `\[a^2\]` a display formula within a line
///   (see ``LaTeXMathTransformer``).
/// - `\[` and `\]` on their own lines enclose a formula which is a block of its own (see
///   ``LaTeXMathBlockParser``), like `$$` does.
///
/// Everything else is as in ``MathMarkdownParser``: the formulas with dollar signs and the fenced
/// code blocks with the info string `math` are recognized as well, and the formulas are
/// represented by ``MathFragment`` and ``MathBlock`` objects. Large language models, for example,
/// often write formulas with `\(…\)` and `\[…\]`.
///
/// This is a class of its own because these forms change the meaning of existing text: a
/// backslash in front of a parenthesis or a bracket makes it an ordinary character in
/// Markdown, so that `\(a\)` is the text `(a)` for all other parsers (including
/// ``MathMarkdownParser``).
///
/// ```swift
/// let doc = LaTeXMarkdownParser.standard.parse("The area is \\(\\pi r^2\\).")
/// ```
///
open class LaTeXMarkdownParser: MathMarkdownParser, @unchecked Sendable {

  /// The block parsers of ``MathMarkdownParser`` and ``LaTeXMathBlockParser``, which comes right
  /// after the parser for formulas between `$$`.
  override open class var defaultBlockParsers: [BlockParser.Type] {
    return self.latexBlockParsers
  }

  private static let latexBlockParsers: [BlockParser.Type] = {
    var parsers = MathMarkdownParser.defaultBlockParsers
    let index = parsers.firstIndex { $0 == MathBlockParser.self }
    parsers.insert(LaTeXMathBlockParser.self, at: index.map { $0 + 1 } ?? parsers.endIndex)
    return parsers
  }()

  /// The inline transformers of ``MathMarkdownParser`` with ``LaTeXMathTransformer`` instead of
  /// ``MathTransformer``.
  override open class var defaultInlineTransformers: [InlineTransformer.Type] {
    return self.latexInlineTransformers
  }

  private static let latexInlineTransformers: [InlineTransformer.Type] = {
    var transformers = MathMarkdownParser.defaultInlineTransformers
    if let index = transformers.firstIndex(where: { $0 == MathTransformer.self }) {
      transformers[index] = LaTeXMathTransformer.self
    }
    return transformers
  }()

  /// Defines a default implementation
  override open class var standard: LaTeXMarkdownParser {
    return self.latexSingleton
  }

  private static let latexSingleton: LaTeXMarkdownParser = LaTeXMarkdownParser()
}

///
/// An `InlineParser` which turns fenced code blocks with the info string `math` into
/// ``MathBlock`` blocks, in addition to the task list items that ``TaskListInlineParser``
/// recognizes. ``MathMarkdownParser`` uses this class.
///
/// A parser that only runs the block parsers (`parse(_:blockOnly: true)`) keeps the code blocks.
///
open class MathInlineParser: TaskListInlineParser {

  open override func parse(_ block: Block) -> Block {
    guard case .fencedCode(let info, let lines) = block,
          let language = info?.split(whereSeparator: { $0.isWhitespace }).first,
          language == "math" else {
      return super.parse(block)
    }
    let tex = lines.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    return .custom(MathBlock(tex: tex))
  }
}
