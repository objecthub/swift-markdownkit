//
//  MathHtmlGenerator.swift
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
/// An ``HtmlGenerator`` that conforms to `MathHtmlRendering` decides how ``MathFragment`` and
/// ``MathBlock`` objects become HTML. ``MathHtmlGenerator`` is a generator that does this;
/// adopt the protocol in your own subclass of ``HtmlGenerator`` to typeset formulas differently.
/// Other generators write the LaTeX between delimiters, which a script in the web page, such as
/// KaTeX or MathJax, can typeset.
///
public protocol MathHtmlRendering {

  /// Returns the HTML for a formula, or `nil` if the formula should be written with delimiters.
  ///
  /// - Parameters:
  ///   - tex: The LaTeX of the formula, without dollar signs.
  ///   - display: True for display math.
  ///   - block: True if the formula is a block of its own (``MathBlock``), in which case the
  ///            HTML is a block element and ends with a line break; otherwise, it is inline
  ///            content.
  func mathHtml(tex: String, display: Bool, block: Bool) -> String?
}

///
/// An HTML generator that writes formulas (``MathFragment`` and ``MathBlock``) as specified by
/// ``MathHtmlGenerator/Output``. By default, it writes the LaTeX between delimiters, like any other HTML
/// generator, and the page typesets it. With KaTeX output, the markup of the typeset formula
/// is part of the HTML:
///
/// ```swift
/// let doc = MathMarkdownParser.standard.parse("The area is $\\pi r^2$.")
/// let generator = MathHtmlGenerator(math: .mathml)
/// print(generator.generate(doc: doc))
/// ```
///
/// A formula in a line of text becomes `<span class="math inline">`, a display formula in a line
/// `<span class="math display">`, and a block `<div class="math display">` with the markup of
/// KaTeX (or the delimiters and the LaTeX) inside. The LaTeX is always escaped, and KaTeX is
/// not allowed to create links or images, so the output of untrusted Markdown is safe, also if
/// `safeMode` is not set.
///
open class MathHtmlGenerator: HtmlGenerator, MathHtmlRendering, @unchecked Sendable {

  /// How ``MathHtmlGenerator`` writes formulas.
  public enum Output: Sendable, Equatable {
    
    /// The LaTeX is written between the delimiters `\(` and `\)` (or `\[` and `\]` for display
    /// math), inside of an element with the class `math`. A script in the web page, such as
    /// the auto-render extension of KaTeX or MathJax, typesets it. This needs no engine.
    case delimiters
    
    /// KaTeX typesets the formula in JavaScriptCore (see ``KaTeXEngine``), and the HTML contains
    /// the markup it creates, with the given options. If the formula is invalid, the source is
    /// shown in an element with the class `katex-error`, with the message as its title.
    case katex(KaTeXOptions)

    /// KaTeX creates HTML for a visual rendering. The web page needs the style sheet and the
    /// fonts of KaTeX (``KaTeXEngine/stylesheetURL``).
    public static var html: Output {
      return .katex(KaTeXOptions(output: .html))
    }

    /// KaTeX creates MathML only, which browsers display without a style sheet.
    public static var mathml: Output {
      return .katex(KaTeXOptions(output: .mathml))
    }

    /// KaTeX creates HTML for a visual rendering and MathML for accessibility. The web page
    /// needs the style sheet and the fonts of KaTeX (``KaTeXEngine/stylesheetURL``).
    public static var htmlAndMathml: Output {
      return .katex(KaTeXOptions(output: .htmlAndMathml))
    }
  }

  /// How formulas are written.
  public let math: Output

  /// The engine which typesets formulas for ``MathHtmlGenerator/Output/katex(_:)``. If it is `nil`, which
  /// is the case if KaTeX cannot be loaded or on watchOS, formulas are written with delimiters.
  public let engine: KaTeXEngine?

  /// Creates an HTML generator.
  ///
  /// - Parameters:
  ///   - math: How formulas are written; the default is with delimiters.
  ///   - engine: The engine that typesets formulas, `KaTeXEngine.shared` by default.
  ///   - safeMode: See ``HtmlGenerator``.
  public init(math: Output = .delimiters,
              engine: KaTeXEngine? = KaTeXEngine.shared,
              safeMode: Bool = false) {
    self.math = math
    self.engine = engine
    super.init(safeMode: safeMode)
  }

  open func mathHtml(tex: String, display: Bool, block: Bool) -> String? {
    guard case .katex(let options) = self.math, let engine = self.engine else {
      return nil
    }
    let content: String
    do {
      content = try engine.render(tex, display: display || block, options: options)
    } catch {
      let source = (display || block) ? "$$\(tex)$$" : "$\(tex)$"
      let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
      content = "<span class=\"katex-error\" title=\"\(message.encodingPredefinedXmlEntities())\">" +
                source.encodingPredefinedXmlEntities() + "</span>"
    }
    if block {
      return "<div class=\"math display\">\(content)</div>\n"
    } else {
      return "<span class=\"math \(display ? "display" : "inline")\">\(content)</span>"
    }
  }
}
