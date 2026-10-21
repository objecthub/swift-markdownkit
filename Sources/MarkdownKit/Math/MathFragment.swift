//
//  MathFragment.swift
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
/// A formula within a line of text: LaTeX between dollar signs (`$a^2$`), or, as display math,
/// between double dollar signs (`$$a^2$$`). The syntax is only recognized by the parsers that
/// support math, such as ``MathMarkdownParser``.
///
/// The generators show the formula as it was written:
/// - ``HtmlGenerator`` creates `<span class="math inline">\(…\)</span>` (or
///   `<span class="math display">\[…\]</span>` for display math) with the LaTeX escaped, which
///   libraries such as KaTeX and MathJax can typeset in a web page. A ``MathHtmlGenerator``
///   can typeset the formula itself.
/// - The text generators and ``TerminalGenerator`` show the LaTeX with its dollar signs.
/// - ``AttributedStringGenerator`` shows the LaTeX with its dollar signs as code. A
///   ``MathAttributedStringGenerator`` shows an image of the typeset formula.
///
public struct MathFragment: CustomTextFragment {

  /// The LaTeX of the formula, without the dollar signs.
  public let tex: String

  /// True for display math, which is written between double dollar signs.
  public let display: Bool

  /// The formula as it was written, including the dollar signs (or, for the form with a code
  /// span between dollar signs, the dollar signs and backticks).
  public let source: String

  /// Creates a formula with the given LaTeX. If `source` is `nil`, it is the LaTeX between
  /// dollar signs.
  public init(tex: String, display: Bool, source: String? = nil) {
    self.tex = tex
    self.display = display
    self.source = source ?? (display ? "$$\(tex)$$" : "$\(tex)$")
  }

  public func equals(to other: CustomTextFragment) -> Bool {
    guard let that = other as? MathFragment else {
      return false
    }
    return self.tex == that.tex && self.display == that.display && self.source == that.source
  }

  /// The formula is not changed by inline transformers: it does not contain Markdown.
  public func transform(via transformer: InlineTransformer) -> TextFragment {
    return .custom(self)
  }

  public func generateHtml(via htmlGen: HtmlGenerator) -> String {
    if let html = (htmlGen as? MathHtmlRendering)?.mathHtml(tex: self.tex, display: self.display,
                                                            block: false) {
      return html
    }
    let tex = self.tex.encodingPredefinedXmlEntities()
    return self.display ? "<span class=\"math display\">\\[\(tex)\\]</span>"
                        : "<span class=\"math inline\">\\(\(tex)\\)</span>"
  }

  #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
  public func generateHtml(via htmlGen: HtmlGenerator,
                           and attrGen: AttributedStringGenerator?) -> String {
    guard attrGen != nil else {
      return self.generateHtml(via: htmlGen)
    }
    // The system's HTML importer cannot typeset formulas: a MathAttributedStringGenerator puts
    // a placeholder for the image of the formula into the HTML, every other generator shows
    // the LaTeX as code
    if let provider = htmlGen as? MathContextProviding {
      return provider.mathHtml(for: self)
    }
    return "<code>" + self.source.encodingPredefinedXmlEntities() + "</code>"
  }
  #endif

  /// The source of the formula: `source`, if the syntax has the delimiters of the formula. The
  /// delimiters of LaTeX are replaced by dollar signs, if the syntax has formulas, but not these
  /// delimiters, and the LaTeX allows it. The result is `nil` if the syntax has no formulas, if
  /// the formula cannot be written with dollar signs, and if it has a line break where the text
  /// has to be a single line.
  public func generateSource(via generator: SourceGenerator,
                             in context: SourceGenerator.InlineContext) -> String? {
    guard generator.syntax.contains(.math) else {
      return nil
    }
    var source = self.source
    if (source.hasPrefix("\\(") || source.hasPrefix("\\[")) &&
       !generator.syntax.contains(.latexMath) {
      guard !self.tex.contains("$") else {
        return nil
      }
      source = self.display ? "$$\(self.tex)$$" : "$\(self.tex)$"
    }
    if context.contains(.singleLine) && source.contains("\n") {
      return nil
    }
    return source
  }

  /// The formula as it was written, including its delimiters.
  public var rawDescription: String {
    return self.source
  }

  /// The formula as it was written, including its delimiters.
  public var description: String {
    return self.source
  }

  public var debugDescription: String {
    return "math(\(self.tex.debugDescription)\(self.display ? ", display" : ""))"
  }
}
