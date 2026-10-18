//
//  MathAttributedStringGenerator.swift
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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

///
/// An ``AttributedStringGenerator`` that shows LaTeX formulas (see ``MathMarkdownParser``) as
/// images, typeset by [KaTeX](https://katex.org) in a web view. A formula within a line of text
/// sits on the baseline of the text, has the colour of the text around it, and is as large as
/// the text. A formula that is a block of its own is centered in a paragraph.
///
/// ```swift
/// let parser = MathMarkdownParser.standard
/// let generator = MathAttributedStringGenerator(fontSize: 16)
/// let doc = parser.parse("The area is $\\pi r^2$.")
/// let text = await generator.generateAsync(doc: doc)
/// ```
///
/// Drawing formulas takes a moment, so they are rendered before the attributed string is
/// created: the asynchronous methods ``AttributedStringGenerator/generateAsync(doc:options:)``
/// and the others do this, as does ``prepareMath(in:)-(Block)``. The synchronous method
/// ``AttributedStringGenerator/generate(doc:)`` shows the formulas which have been rendered before
/// and are still in the cache of the ``MathRenderer``; the others are shown as code. A formula which
/// KaTeX does not understand is shown as code as well (a block formula has a note).
///
/// This generator uses the HTML importer of the system just like its superclass; a
/// formula is a placeholder in the HTML which is replaced by an `NSTextAttachment` once the
/// attributed string exists. Mermaid diagrams (parameter `mermaid`) work as they do in the
/// superclass. Images of formulas are only supported on macOS and iOS: on the other platforms,
/// formulas are shown as code.
///
/// The attachment of a formula has the attribute ``Foundation/NSAttributedString/Key/mathSource``,
/// which holds the formula as it was written. Formulas are drawn in the font size of the generator;
/// text in a different size (headings, or text which the rendering option `textSizeMultiplier`
/// enlarged) scales them.
///
open class MathAttributedStringGenerator: AttributedStringGenerator, @unchecked Sendable {

  /// The HTML generator of the version `preOS26` that puts placeholders for formulas into the
  /// HTML.
  open class MathInternalHtmlGenerator: InternalHtmlGenerator, MathContextProviding,
                                        @unchecked Sendable {

    /// The formulas which this generator has put into the HTML (as placeholders).
    /// `MathAttributedStringGenerator` replaces the placeholders with images once the system has
    /// created the attributed string.
    public let math: MathContext

    /// Creates an HTML generator for `outer`, which should be a `MathAttributedStringGenerator`.
    public override init(outer: AttributedStringGenerator, renderingOptions: RenderingOptions) {
      self.math = MathContext(for: outer)
      super.init(outer: outer, renderingOptions: renderingOptions)
    }
  }

  /// The HTML generator of the version `OS26` that puts placeholders for formulas into the HTML.
  open class MathOS26HtmlGenerator: OS26HtmlGenerator, MathContextProviding,
                                    @unchecked Sendable {

    /// The formulas which this generator has put into the HTML (as placeholders).
    /// `MathAttributedStringGenerator` replaces the placeholders with images once the system has
    /// created the attributed string.
    public let math: MathContext

    /// Creates an HTML generator for `outer`, which should be a `MathAttributedStringGenerator`.
    public override init(outer: AttributedStringGenerator, renderingOptions: RenderingOptions) {
      self.math = MathContext(for: outer)
      super.init(outer: outer, renderingOptions: renderingOptions)
    }
  }

  /// Configures how formulas are rendered.
  public let mathConfig: MathConfig

  /// The renderer that draws the formulas. If `nil`, `MathRenderer.shared` is used.
  public let mathRenderer: MathRenderer?

  /// Creates a generator. The parameters are those of ``AttributedStringGenerator`` plus `math`
  /// and `mathRenderer`, which follow `mermaidRenderer`. The parameter `math` says how formulas
  /// are typeset and shown (see ``MathConfig``), and `mathRenderer` is the renderer that
  /// draws them; if it is `nil`, the default, ``MathRenderer/shared`` is used.
  public init(version: Version = .OS26,
              options: Options = [],
              fontSize: Float = 14.0,
              fontFamily: String = "",
              fontColor: String = mdDefaultColor,
              lineSpacing: Float = 1.1,
              codeFontSize: Float = 13.0,
              codeFontFamily: String = "",
              codeFontColor: String = mdDefaultColor,
              codeBlockFontSize: Float = 12.0,
              codeBlockFontColor: String = mdDefaultColor,
              codeBlockLineSpacing: Float = 1.0,
              codeBlockBackground: String = mdDefaultBackgroundColor,
              syntaxHighlighting: SyntaxHighlightingConfig? = .default,
              syntaxHighlighter: SyntaxHighlighter? = nil,
              mermaid: MermaidConfig? = nil,
              mermaidRenderer: MermaidRenderer? = nil,
              math: MathConfig = MathConfig(),
              mathRenderer: MathRenderer? = nil,
              borderColor: String = "#cccccc",
              blockquoteColor: String = "#abe",
              h1Color: String = mdDefaultColor,
              h2Color: String = mdDefaultColor,
              h3Color: String = mdDefaultColor,
              h4Color: String = mdDefaultColor,
              maxImageWidth: String? = nil,
              maxImageHeight: String? = nil,
              customStyle: String = "",
              imageBaseUrl: URL? = nil,
              renderingOptions: RenderingOptions = RenderingOptions()) {
    self.mathConfig = math
    self.mathRenderer = mathRenderer
    super.init(version: version,
               options: options,
               fontSize: fontSize,
               fontFamily: fontFamily,
               fontColor: fontColor,
               lineSpacing: lineSpacing,
               codeFontSize: codeFontSize,
               codeFontFamily: codeFontFamily,
               codeFontColor: codeFontColor,
               codeBlockFontSize: codeBlockFontSize,
               codeBlockFontColor: codeBlockFontColor,
               codeBlockLineSpacing: codeBlockLineSpacing,
               codeBlockBackground: codeBlockBackground,
               syntaxHighlighting: syntaxHighlighting,
               syntaxHighlighter: syntaxHighlighter,
               mermaid: mermaid,
               mermaidRenderer: mermaidRenderer,
               borderColor: borderColor,
               blockquoteColor: blockquoteColor,
               h1Color: h1Color,
               h2Color: h2Color,
               h3Color: h3Color,
               h4Color: h4Color,
               maxImageWidth: maxImageWidth,
               maxImageHeight: maxImageHeight,
               customStyle: customStyle,
               imageBaseUrl: imageBaseUrl,
               renderingOptions: renderingOptions)
  }

  /// The renderer used for formulas: `mathRenderer`, or the shared renderer. It is `nil` if the
  /// platform cannot render formulas or the resources of KaTeX are missing; formulas are then
  /// shown as code.
  public var formulaRenderer: MathRenderer? {
    return self.mathRenderer ?? MathRenderer.shared
  }

  // MARK: Extension points

  /// Returns an HTML generator that puts placeholders for formulas into the HTML.
  open override func htmlGenerator(options: RenderingOptions? = nil) -> InternalHtmlGenerator {
    let options = options ?? self.renderingOptions
    switch self.version {
      case .preOS26:
        return MathInternalHtmlGenerator(outer: self, renderingOptions: options)
      case .OS26:
        return MathOS26HtmlGenerator(outer: self, renderingOptions: options)
    }
  }

  /// Replaces the placeholders of Mermaid diagrams and of formulas with their images.
  open override func finishAttributedString(_ string: NSAttributedString,
                                            from generator: InternalHtmlGenerator) -> NSAttributedString {
    let string = super.finishAttributedString(string, from: generator)
    guard let math = (generator as? MathContextProviding)?.math else {
      return string
    }
    return math.replacePlaceholders(in: string)
  }

  /// True if formulas can be rendered, or if the superclass needs to prepare.
  open override var needsPreparation: Bool {
    return self.formulaRenderer != nil || super.needsPreparation
  }

  /// Renders the formulas of `block` (and the Mermaid diagrams), and returns an HTML generator
  /// that shows all of them, whatever the size of the cache of the renderer.
  open override func preparedHtmlGenerator(for block: Block,
                                           options: RenderingOptions?) async -> InternalHtmlGenerator {
    let results = await self.mathResults(formulas: block.mathFormulas)
    let generator = await super.preparedHtmlGenerator(for: block, options: options)
    (generator as? MathContextProviding)?.math.pin(results)
    return generator
  }

  /// Renders the formulas of `blocks` (and the Mermaid diagrams), and returns an HTML generator
  /// that shows all of them, whatever the size of the cache of the renderer.
  open override func preparedHtmlGenerator(for blocks: Blocks,
                                           options: RenderingOptions?) async -> InternalHtmlGenerator {
    let results = await self.mathResults(formulas: blocks.mathFormulas)
    let generator = await super.preparedHtmlGenerator(for: blocks, options: options)
    (generator as? MathContextProviding)?.math.pin(results)
    return generator
  }

  // MARK: Preparing

  /// Renders the formulas in `doc` so that `generate(doc:)`, which cannot wait for a formula to be
  /// drawn, can include them. The images are kept in the cache of the generator's
  /// ``MathRenderer``, as far as it has room for them: `generate(doc:)` only shows the formulas
  /// that are in the cache.
  ///
  /// Formulas which KaTeX does not understand are skipped (they are shown as code), so this never
  /// fails. The asynchronous methods `generateAsync(doc:)` etc. call this themselves. Code which
  /// does not use Swift concurrency can use ``prepareMath(in:completionHandler:)-(Block,_)``.
  ///
  /// - Returns: `true` if at least one formula was rendered by this call, i.e. if the result of
  ///            `generate(doc:)` is different from before.
  @discardableResult
  public func prepareMath(in doc: Block) async -> Bool {
    return await self.mathResults(formulas: doc.mathFormulas).rendered
  }

  /// Renders the formulas in `blocks`. See ``prepareMath(in:)-(Block)``.
  @discardableResult
  public func prepareMath(in blocks: Blocks) async -> Bool {
    return await self.mathResults(formulas: blocks.mathFormulas).rendered
  }

  /// Renders the formulas in `doc` without blocking the calling thread and reports the result
  /// via a completion handler. This is the variant of ``prepareMath(in:)-(Block)`` for code which does
  /// not use Swift concurrency; see there for details. Once the handler has been called,
  /// `generate(doc:)` includes the formulas.
  ///
  /// `completionHandler` is called exactly once, asynchronously (also if all formulas are
  /// rendered already), and always on the main thread, so it is safe to update the user
  /// interface or state which is confined to the main thread from it.
  ///
  /// - Parameters:
  ///   - doc: The Markdown document.
  ///   - completionHandler: Called with `true` if at least one formula was rendered by this call,
  ///                        i.e. if the result of `generate(doc:)` is different from before.
  public func prepareMath(in doc: Block, completionHandler: @escaping (Bool) -> Void) {
    let deliver = MainThreadHandler(completionHandler)
    Task {
      deliver(await self.prepareMath(in: doc))
    }
  }

  /// Renders the formulas in `blocks` and reports the result via a completion handler. See
  /// ``prepareMath(in:completionHandler:)-(Block,_)``.
  public func prepareMath(in blocks: Blocks, completionHandler: @escaping (Bool) -> Void) {
    let deliver = MainThreadHandler(completionHandler)
    Task {
      deliver(await self.prepareMath(in: blocks))
    }
  }

  /// Renders the formulas which are not in the cache of the renderer yet, and returns the results
  /// for all of them. They are also kept in the cache (as far as it has room for them).
  func mathResults(formulas: [MathFormula]) async -> MathFormulaResults {
    var results = MathFormulaResults()
    #if canImport(WebKit) && (os(macOS) || os(iOS))
    guard !formulas.isEmpty, let renderer = self.formulaRenderer else {
      return results
    }
    let outcome = await renderer.renderFormulas(formulas, fontSize: self.fontSize, config: self.mathConfig)
    results.rendered = outcome.rendered
    for (formula, result) in outcome.results {
      switch result {
        case .success(let image):
          results.images[formula] = image
        case .failure(let error):
          // Only the errors of the formulas are remembered; the formula is shown as code
          switch error {
            case .syntaxError, .tooLong:
              results.failures[formula] = error
            default:
              break
          }
      }
    }
    #endif
    return results
  }
}

///
/// The HTML generators of ``MathAttributedStringGenerator``: they have a context for the
/// formulas that they put into the HTML.
///
protocol MathContextProviding: AttributedStringGenerator.InternalHtmlGenerator {

  /// The formulas which this generator has put into the HTML.
  var math: MathContext { get }
}

extension MathContextProviding {

  /// The HTML for a formula within a line of text: a placeholder for its image, or the source
  /// of the formula as code if there is no image.
  func mathHtml(for fragment: MathFragment) -> String {
    let formula = MathFormula(tex: fragment.tex, display: fragment.display)
    guard let image = self.math.image(for: formula) else {
      return "<code>" + fragment.source.encodingPredefinedXmlEntities() + "</code>"
    }
    return self.math.placeholder(for: formula, image: image, source: fragment.source, block: false)
  }

  /// The HTML for a formula that is a block: a paragraph with a placeholder for its image, or a
  /// code block (with a note if KaTeX did not understand the formula) if there is no image.
  func mathHtml(for block: MathBlock, tight: Bool) -> String {
    let formula = MathFormula(tex: block.tex, display: true)
    if let image = self.math.image(for: formula) {
      return "<p style=\"text-align: center;\">" +
             self.math.placeholder(for: formula, image: image, source: block.description, block: true) +
             "</p>\n"
    }
    var note = ""
    if let failure = self.math.failure(for: formula) {
      note = "<p><i>Formula could not be rendered: " +
             failure.summary.encodingPredefinedXmlEntities() + "</i></p>\n"
    }
    let lines = Lines(block.tex.split(separator: "\n", omittingEmptySubsequences: false)
                              .map { Substring($0 + "\n") })
    return note + self.generate(block: .fencedCode(nil, lines), parent: .none, tight: tight)
  }
}

#endif
