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
    }
  }
}
