//
//  MathBlock.swift
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
/// A formula which is a block of its own: LaTeX between lines with double dollar signs
/// (`$$` … `$$`), a single line `$$ … $$`, or the content of a fenced code block with the info
/// string `math`. The syntax is only recognized by the parsers that support math, such as
/// ``MathMarkdownParser``.
///
/// The generators show the formula as it was written:
/// - ``HtmlGenerator`` creates `<div class="math display">\[…\]</div>` with the LaTeX escaped,
///   which libraries such as KaTeX and MathJax can typeset in a web page. A
///   ``MathHtmlGenerator`` can typeset the formula itself.
/// - The text generators and ``TerminalGenerator`` show the LaTeX between lines with `$$`.
/// - ``AttributedStringGenerator`` shows the LaTeX as a code block. A
///   ``MathAttributedStringGenerator`` shows an image of the typeset formula.
///
public struct MathBlock: CustomBlock {

  /// The LaTeX of the formula, without the dollar signs. It consists of the lines of the
  /// block, separated by line breaks.
  public let tex: String

  /// Creates a block with the given LaTeX.
  public init(tex: String) {
    self.tex = tex
  }

  /// The LaTeX of the formula.
  public var string: String {
    return self.tex
  }

  public func equals(to other: CustomBlock) -> Bool {
    guard let that = other as? MathBlock else {
      return false
    }
    return self.tex == that.tex
  }

  /// The formula is not changed by the inline parser: it does not contain Markdown.
  public func parse(via parser: InlineParser) -> Block {
    return .custom(self)
  }

  public func generateHtml(via htmlGen: HtmlGenerator, tight: Bool) -> String {
    if let html = (htmlGen as? MathHtmlRendering)?.mathHtml(tex: self.tex, display: true,
                                                            block: true) {
      return html
    }
    return "<div class=\"math display\">\\[\(self.tex.encodingPredefinedXmlEntities())\\]</div>\n"
  }

  #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
  public func generateHtml(via htmlGen: HtmlGenerator,
                           and attGen: AttributedStringGenerator?,
                           tight: Bool) -> String {
    guard attGen != nil else {
      return self.generateHtml(via: htmlGen, tight: tight)
    }
    // The system's HTML importer cannot typeset formulas: a MathAttributedStringGenerator puts
    // a placeholder for the image of the formula into the HTML, every other generator shows
    // the LaTeX as a code block
    if let provider = htmlGen as? MathContextProviding {
      return provider.mathHtml(for: self, tight: tight)
    }
    let lines = Lines(self.tex.split(separator: "\n", omittingEmptySubsequences: false)
                              .map { Substring($0 + "\n") })
    return htmlGen.generate(block: .fencedCode(nil, lines), parent: .none, tight: tight)
  }
  #endif

  /// The source of the formula: `$$` on its own lines, around the lines of the LaTeX. If the LaTeX
  /// cannot be written like this, because it has an empty line, a line with white space at an
  /// end, or `$$` (which can happen if it comes from a fenced code block), or if the syntax has
  /// no formulas, the source is a fenced code block with the info string `math`.
  public func generateSource(via generator: SourceGenerator,
                             parent: SourceGenerator.Parent) -> [String]? {
    let tex = self.tex.replacingOccurrences(of: "\r\n", with: "\n")
                      .replacingOccurrences(of: "\r", with: "\n")
    let lines = tex.components(separatedBy: "\n")
    if generator.syntax.contains(.math) && !tex.isEmpty && !tex.contains("$$") &&
       !lines.contains(where: { $0.isEmpty || $0.trimmingCharacters(in: .whitespaces) != $0 }) {
      return ["$$"] + lines + ["$$"]
    }
    return generator.generate(block: .fencedCode("math", Lines(lines.map { Substring($0 + "\n") })),
                              parent: parent)
  }

  /// The formula between lines with `$$`, as it is shown by the text generators. Control
  /// characters of the LaTeX are replaced.
  public var description: String {
    return "$$\n\(self.tex.sanitizingControlCharacters())\n$$"
  }

  public var debugDescription: String {
    return "math(\(self.tex.debugDescription), block)"
  }
}
