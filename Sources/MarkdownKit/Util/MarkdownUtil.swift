//
//  MarkdownUtil.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 19/10/2026.
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
/// `MarkdownUtil` is the place to start if you want to use MarkdownKit for a task without
/// assembling parsers and generators yourself. It has two groups of methods:
///
/// - **Converting Markdown into documents.** ``text(_:width:)``, ``ansi(_:width:)`` and
///   ``html(_:math:safeMode:)`` turn a parsed document into text, text with ANSI escape codes
///   and HTML on every platform. ``rtf(_:title:author:imageBaseUrl:renderingOptions:)`` and
///   ``rtfd(_:title:author:maxImageWidth:mermaid:math:imageBaseUrl:renderingOptions:)``
///   create RTF and RTFD documents, and 
///   ``pdf(_:title:author:pageSize:margins:mermaid:math:imageBaseUrl:renderingOptions:)``
///   a PDF document, on macOS and iOS; RTFD and PDF documents contain the diagrams and
///   formulas as images. The ``style`` of the utility determines how these documents look.
///   See <doc:ConvertingMarkdownIntoDocuments>.
/// - **Drawing diagrams and formulas as images.** ``mermaidImage(_:config:)`` and
///   ``mathImage(_:display:fontSize:color:config:)`` turn the source of a Mermaid diagram
///   or the LaTeX of a formula into an `NSImage` (macOS) or a `UIImage` (iOS), without any
///   Markdown, and ``image(_:withInsets:transparentAlpha:)`` gives an image uniform
///   transparent insets. These methods are available on macOS and iOS. See
///   <doc:DrawingImagesOfDiagramsAndFormulas>.
///
/// ```swift
/// let util = MarkdownUtil.standard
/// let doc = LaTeXMarkdownParser.standard.parse("The area is $\\pi r^2$.")
/// let document = try await util.rtfd(doc)                 // a FileWrapper
/// let formula = try await util.mathImage("\\pi r^2", fontSize: 16)   // an NSImage or UIImage
/// ```
///
/// Diagrams and formulas are drawn by a ``MermaidRenderer`` and a ``MathRenderer``, which
/// cache their results, and code is colored by a ``SyntaxHighlighter``. A utility uses the
/// shared instances (``MermaidRenderer/shared``, ``MathRenderer/shared`` and
/// ``SyntaxHighlighter/proxy``) unless it is created with ones of your own.
///
public struct MarkdownUtil: Sendable {

  /// The utility which uses the shared renderers (``MermaidRenderer/shared`` and
  /// ``MathRenderer/shared``).
  public static let standard = MarkdownUtil()

  /// The renderer that draws diagrams. If `nil`, ``MermaidRenderer/shared`` is used.
  public let mermaidRenderer: MermaidRenderer?

  /// The renderer that draws formulas. If `nil`, ``MathRenderer/shared`` is used.
  public let mathRenderer: MathRenderer?

  /// The highlighter that colors the code of fenced code blocks in ``ansi(_:width:)``,
  /// ``rtf(_:title:author:imageBaseUrl:renderingOptions:)``,
  /// ``rtfd(_:title:author:maxImageWidth:mermaid:math:imageBaseUrl:renderingOptions:)`` and
  /// ``pdf(_:title:author:pageSize:margins:mermaid:math:imageBaseUrl:renderingOptions:)``.
  /// If `nil`, ``SyntaxHighlighter/proxy`` is used. The theme and the other options of
  /// highlighting are part of the ``style``. Code is not colored on watchOS, where the
  /// highlighter does not exist.
  public let syntaxHighlighter: SyntaxHighlighter?

  /// The appearance of the documents that ``rtf(_:title:author:imageBaseUrl:renderingOptions:)``,
  /// ``rtfd(_:title:author:maxImageWidth:mermaid:math:imageBaseUrl:renderingOptions:)`` and
  /// ``pdf(_:title:author:pageSize:margins:mermaid:math:imageBaseUrl:renderingOptions:)``
  /// create: fonts, colors, spacing and CSS. The default is
  /// ``AttributedStringGenerator/Style/light``: the colors for a white page, whatever the
  /// appearance of the system is.
  public let style: AttributedStringGenerator.Style

  /// Creates a utility that draws diagrams and formulas with the given renderers, colors
  /// code with the given highlighter, and creates documents in the given style. A renderer
  /// of your own lets you choose the limits of its cache and the time after which its web
  /// view is released, and a highlighter of your own lets you use another version of
  /// Highlight.js or themes of your own (see <doc:SyntaxHighlighting>).
  ///
  /// ```swift
  /// var style = AttributedStringGenerator.Style.light
  /// style.fontSize = 15
  /// style.fontFamily = "Georgia, serif"
  /// let pdf = try await MarkdownUtil(style: style).pdf(doc)
  /// ```
  ///
  /// - Parameters:
  ///   - mermaidRenderer: The renderer for diagrams, or `nil` to use the shared one.
  ///   - mathRenderer: The renderer for formulas, or `nil` to use the shared one.
  ///   - syntaxHighlighter: The highlighter for code, or `nil` to use the shared one.
  ///   - style: The appearance of RTF, RTFD and PDF documents.
  public init(mermaidRenderer: MermaidRenderer? = nil,
              mathRenderer: MathRenderer? = nil,
              syntaxHighlighter: SyntaxHighlighter? = nil,
              style: AttributedStringGenerator.Style = .light) {
    self.mermaidRenderer = mermaidRenderer
    self.mathRenderer = mathRenderer
    self.syntaxHighlighter = syntaxHighlighter
    self.style = style
  }

  // MARK: Text and HTML

  /// Returns the document as plain text, formatted for lines of `width` columns (at least 10).
  /// Diagrams are shown as code and formulas as they were written. This method is available
  /// on all platforms.
  ///
  /// - Parameters:
  ///   - doc: The Markdown document, or a part of it.
  ///   - width: The width of a line in columns.
  public func text(_ doc: Block, width: Int = 80) -> String {
    return StringGenerator(numColumns: width).generate(doc: doc)
  }

  /// Returns the document as text which is marked up with ANSI escape codes (colors, bold and
  /// italic text, ...), formatted for lines of `width` columns (at least 10), so that an
  /// ANSI-compliant terminal shows it formatted. Diagrams are shown as code and formulas as they
  /// were written; code is colored by the ``syntaxHighlighter`` of the utility. This method is
  /// available on all platforms.
  ///
  /// - Parameters:
  ///   - doc: The Markdown document, or a part of it.
  ///   - width: The width of a line in columns.
  public func ansi(_ doc: Block, width: Int = 80) -> String {
    return TerminalGenerator(numColumns: width, syntaxHighlighter: self.syntaxHighlighter)
             .generate(doc: doc)
             .encodedString
  }

  /// Returns the document as HTML. Formulas are typeset (by KaTeX) as MathML, which browsers
  /// display without a style sheet or fonts; use `math` to select another form. This method is
  /// available on all platforms, but KaTeX does not run on watchOS: formulas are written with
  /// delimiters there.
  ///
  /// - Parameters:
  ///   - doc: The Markdown document, or a part of it.
  ///   - math: How formulas are written, see ``MathHtmlGenerator/Output``.
  ///   - safeMode: If true, raw HTML is omitted and links are limited to the schemes `http`,
  ///               `https` and `mailto` (see ``HtmlGenerator``).
  public func html(_ doc: Block,
                   math: MathHtmlGenerator.Output = .mathml,
                   safeMode: Bool = false) -> String {
    return MathHtmlGenerator(math: math, safeMode: safeMode).generate(doc: doc)
  }
}
