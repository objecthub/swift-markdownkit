//
//  MarkdownDialect.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 18/10/2026.
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
/// The Markdown dialects that MarkdownKit supports out of the box, each with its standard
/// parser. ``MarkdownText`` uses a dialect to choose how it parses a string.
///
/// ```swift
/// let doc = MarkdownDialect.full.parser.parse("Some ~~old~~ and ~new~ text")
/// ```
///
public enum MarkdownDialect: Sendable, Equatable, CaseIterable {
  
  ///
  /// The features of Markdown that a ``SourceGenerator`` may use when it writes source:
  /// the syntax of the parser that will read the source again. A tree can only be written
  /// back faithfully if the syntax has the features that the tree uses. The syntax also
  /// decides which characters of plain text have to be escaped: `$` only needs an escape
  /// if the syntax has math.
  /// 
  /// The standard parsers have these syntaxes (see ``MarkdownDialect/syntax``):
  /// - ``commonMark``: no features
  /// - ``extendedCommonMark``: ``tables`` and ``definitionLists``
  /// - ``full``: additionally ``underline``, ``strikethrough`` and ``taskLists``
  /// - ``fullMath``: additionally ``math``
  /// - ``fullLaTeX``: additionally ``latexMath``
  ///
  public struct Syntax: OptionSet, Hashable, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
      self.rawValue = rawValue
    }

    /// Tables (`| a | b |`).
    public static let tables = Syntax(rawValue: 1 << 0)

    /// Definition lists (a term followed by lines that start with `:`).
    public static let definitionLists = Syntax(rawValue: 1 << 1)

    /// Underlined text (`~text~`).
    public static let underline = Syntax(rawValue: 1 << 2)

    /// Struck-through text (`~~text~~`).
    public static let strikethrough = Syntax(rawValue: 1 << 3)

    /// Task list items (`- [ ] to do`).
    public static let taskLists = Syntax(rawValue: 1 << 4)

    /// Formulas between dollar signs (`$x$`, `$$x$$`) and in fenced code blocks
    /// with the info string `math`.
    public static let math = Syntax(rawValue: 1 << 5)
    
    /// Formulas between the delimiters of LaTeX (`\(x\)`, `\[x\]`).
    public static let latexMath = Syntax(rawValue: 1 << 6)

    /// The syntax of ``MarkdownParser``: CommonMark.
    public static let commonMark: Syntax = []

    /// The syntax of ``ExtendedMarkdownParser``.
    public static let extendedCommonMark: Syntax = [.tables, .definitionLists]

    /// The syntax of ``FullMarkdownParser``.
    public static let full: Syntax = [.tables, .definitionLists, .underline, .strikethrough,
                                      .taskLists]

    /// The syntax of ``MathMarkdownParser``.
    public static let fullMath: Syntax = [.tables, .definitionLists, .underline, .strikethrough,
                                          .taskLists, .math]

    /// The syntax of ``LaTeXMarkdownParser``: everything that MarkdownKit supports.
    public static let fullLaTeX: Syntax = [.tables, .definitionLists, .underline, .strikethrough,
                                           .taskLists, .math, .latexMath]
  }

  /// CommonMark, parsed by ``MarkdownParser``.
  case commonMark

  /// CommonMark with tables and definition lists, parsed by ``ExtendedMarkdownParser``.
  case extendedCommonMark

  /// Everything that MarkdownKit supports but LaTeX math: additionally underline,
  /// strikethrough and task lists, parsed by ``FullMarkdownParser``.
  case full

  /// Everything that MarkdownKit supports, including LaTeX formulas between dollar signs,
  /// parsed by ``MathMarkdownParser``.
  case fullMath

  /// Everything that MarkdownKit supports, including LaTeX formulas between dollar signs and
  /// between the delimiters of LaTeX (`\(`…`\)` and `\[`…`\]`), parsed by
  /// ``LaTeXMarkdownParser``.
  case fullLaTeX
  

  /// The standard parser of this dialect, e.g. ``MarkdownParser/standard`` for
  /// ``commonMark``.
  public var parser: MarkdownParser {
    switch self {
      case .commonMark:
        return MarkdownParser.standard
      case .extendedCommonMark:
        return ExtendedMarkdownParser.standard
      case .full:
        return FullMarkdownParser.standard
      case .fullMath:
        return MathMarkdownParser.standard
      case .fullLaTeX:
        return LaTeXMarkdownParser.standard
    }
  }
  
  /// The syntax of the standard parser of this dialect, for a ``SourceGenerator``.
  public var syntax: Syntax {
    switch self {
      case .commonMark:
        return .commonMark
      case .extendedCommonMark:
        return .extendedCommonMark
      case .full:
        return .full
      case .fullMath:
        return .fullMath
      case .fullLaTeX:
        return .fullLaTeX
    }
  }
  
  /// A source generator for this dialect: it writes Markdown that this dialect's ``parser``
  /// reads back into the same syntax tree.
  public var sourceGenerator: SourceGenerator {
    return SourceGenerator(dialect: self)
  }
}
