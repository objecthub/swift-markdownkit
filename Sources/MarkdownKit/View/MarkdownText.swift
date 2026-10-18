//
//  MarkdownText.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 01/03/2026.
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

#if os(iOS) || os(macOS)

import SwiftUI

///
/// A SwiftUI view that displays a Markdown document as formatted text. The view converts the
/// document into an attributed string with an ``AttributedStringGenerator``, using different
/// generators for light and dark mode, and shows the result in a read-only text view whose text
/// can be selected. The view scrolls vertically.
///
/// ```swift
/// struct ContentView: View {
///   var body: some View {
///     MarkdownText(string: "# Title\n\nSome **bold** text and a [link](https://objecthub.com).")
///       .padding()
///   }
/// }
/// ```
///
/// The initializers take a parsed document (``Block``) or a string, which is parsed with the
/// standard parser of a ``MarkdownDialect``. The default generators are configured with
/// ``AttributedStringGenerator/RenderingOptions``; to restrict what a document from an untrusted
/// source can load, pass `.untrusted`. The parameters `mermaid` and `math` enable diagrams and
/// formulas, which are rendered in the background. A custom `generator` function decides how a
/// document is converted into an attributed string for a given color scheme. See
/// <doc:DisplayingMarkdownWithSwiftUI> for details.
///
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct MarkdownText: View {
  
  @Environment(\.colorScheme) var colorScheme
  
  /// The Markdown document that is displayed. The view is updated if this changes.
  private let content: Block
  
  /// The generator for turning markdown into a `NSAttributedString` object
  private let generator: (Block, ColorScheme) -> NSAttributedString?
  
  /// Renders the Mermaid diagrams and the formulas of the markdown document (which takes some
  /// time) so that the generator can include them. Returns `true` if the attributed string has
  /// to be generated again. `nil` if the view does not show diagrams or formulas.
  private let prepare: (@Sendable (Block, ColorScheme) async -> Bool)?
  
  /// What to display until the markdown document has been converted into an
  /// attributed string.
  private let waitingMessage: NSAttributedString
  
  /// The attributed string generated from the markdown document.
  @State private var attributedText: NSAttributedString? = nil
  
  /// The height of the markdown content when displayed.
  @State private var contentHeight: CGFloat = .zero
  
  /// The color scheme propagated back from the UITextView as well as the last color
  /// scheme used to generate the attributed string from the markdown text.
  /// This is a hack since `onChange(of: colorScheme)` triggers false positives.
  @State private var cachedColorScheme: ColorScheme? = nil
  @State private var lastUsedColorScheme: ColorScheme? = nil
  
  /// The designated initializer. Creates a Markdown text view for the specified Markdown
  /// document. `generator` creates the attributed string that is displayed for a document
  /// and a color scheme. If it is `nil`, the default generators are used (see
  /// `init(_:waitingMessage:renderingOptions:mermaid:math:)`).
  ///
  /// Some content of an attributed string takes time to create, for example Mermaid diagrams
  /// and formulas. A view that shows such content passes a `prepare` function. It is called in
  /// the background, after the view has shown the text for the first time, and for each document
  /// and color scheme; it renders the content so that `generator` can include it, and returns
  /// `true` if the text has to be generated again. The default generators of the other
  /// initializers use `AttributedStringGenerator.prepareDiagrams(in:)` and
  /// `MathAttributedStringGenerator.prepareMath(in:)` for this.
  ///
  /// - Parameters:
  ///   - content: The Markdown document.
  ///   - waitingMessage: What is displayed until the document has been converted.
  ///   - generator: Creates the attributed string for a document and a color scheme, or `nil`
  ///                to use the default generators.
  ///   - prepare: Prepares the content of a document for a color scheme, or `nil` (the default)
  ///              if the generator does not need to prepare anything.
  public init(_ content: Block,
              waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
              generator: ((Block, ColorScheme) -> NSAttributedString?)?,
              prepare: (@Sendable (Block, ColorScheme) async -> Bool)? = nil) {
    self.content = content
    self.waitingMessage = waitingMessage
    self.generator = generator ?? MarkdownText.defaultGenerator(.trusted)
    self.prepare = prepare
  }
  
  /// Creates a Markdown text view for the specified Markdown document. The view uses the
  /// default attributed string generators for light and dark mode, which are configured with
  /// `renderingOptions`.
  ///
  /// The attributed string is generated synchronously (see
  /// `AttributedStringGenerator.generate(doc:)`). Therefore, only the rendering options
  /// `baseUrl`, `localImages`, `imageExtensions`, `safeMode` and `textSizeMultiplier` have an
  /// effect; remote images are never loaded. Use `RenderingOptions.untrusted` if the
  /// Markdown does not come from a trusted source.
  ///
  /// If `mermaid` is not `nil`, fenced code blocks with language `mermaid` are shown as
  /// diagrams. They are rendered in the background: the view first shows the diagram as code
  /// and replaces it with the diagram once it has been rendered. In dark mode,
  /// `MermaidConfig.darkVariant` is used. Diagrams are only supported on macOS and iOS.
  ///
  /// If `math` is not `nil`, the formulas of the document (which a parser such as
  /// ``MathMarkdownParser`` recognizes) are shown as images, in the colour of the text around
  /// them (see ``MathAttributedStringGenerator``). Like diagrams, they are drawn in the
  /// background: the view first shows the LaTeX of a formula as code and replaces it with the
  /// formula once it has been rendered. Formulas are only supported on macOS and iOS.
  ///
  /// - Parameters:
  ///   - text: The Markdown document.
  ///   - waitingMessage: What is displayed until the document has been converted.
  ///   - renderingOptions: The options for rendering the generated HTML.
  ///   - mermaid: The configuration for drawing Mermaid diagrams, or `nil` (the default) to
  ///              show them as code like any other code block.
  ///   - math: The configuration for showing formulas, or `nil` (the default) to show the
  ///           LaTeX as code.
  public init(_ text: Block,
              waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
              renderingOptions: AttributedStringGenerator.RenderingOptions = .trusted,
              mermaid: MermaidConfig? = nil,
              math: MathConfig? = nil) {
    self.init(text,
              waitingMessage: waitingMessage,
              generator: Self.defaultGenerator(renderingOptions, mermaid: mermaid, math: math),
              prepare: Self.defaultPreparer(renderingOptions, mermaid: mermaid, math: math))
  }
  
  /// Creates a Markdown text view for the specified Markdown document as a string.
  /// `generator` creates the attributed string that is displayed for a document and a color
  /// scheme. If it is `nil`, the default generators are used (see
  /// `init(string:dialect:waitingMessage:renderingOptions:mermaid:math:)`). The string is
  /// parsed with the standard parser of `dialect`, which is ``MarkdownDialect/extendedCommonMark``
  /// by default. See `init(_:waitingMessage:generator:prepare:)` for `prepare`.
  public init(string: String,
              dialect: MarkdownDialect? = nil,
              waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
              generator: ((Block, ColorScheme) -> NSAttributedString?)?,
              prepare: (@Sendable (Block, ColorScheme) async -> Bool)? = nil) {
    self.init((dialect ?? .extendedCommonMark).parser.parse(string),
              waitingMessage: waitingMessage,
              generator: generator,
              prepare: prepare)
  }
  
  /// Creates a Markdown text view for the specified Markdown document as a string. See
  /// `init(_:waitingMessage:renderingOptions:mermaid:math:)`. The string is parsed with the
  /// standard parser of `dialect`. If `dialect` is `nil`, it is ``MarkdownDialect/fullMath`` (which
  /// recognizes formulas between dollar signs) if `math` is not `nil`, and
  /// ``MarkdownDialect/extendedCommonMark`` otherwise; pass ``MarkdownDialect/fullLaTeX`` for formulas
  /// between `\(` and `\)` or `\[` and `\]` as well. Pass a dialect to choose a different parser: formulas in a document that is
  /// parsed by a parser that does not know them stay text, whatever `math` says.
  public init(string: String,
              dialect: MarkdownDialect? = nil,
              waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
              renderingOptions: AttributedStringGenerator.RenderingOptions = .trusted,
              mermaid: MermaidConfig? = nil,
              math: MathConfig? = nil) {
    self.init((math == nil ? (dialect ?? .extendedCommonMark) : (dialect ?? .fullMath))
                .parser.parse(string),
              waitingMessage: waitingMessage,
              renderingOptions: renderingOptions,
              mermaid: mermaid,
              math: math)
  }
  
  public var body: some View {
    GeometryReader { geometry in
      ScrollView(.vertical) {
        AttributedTextView(attributedText: self.attributedText ?? self.waitingMessage,
                           availableWidth: geometry.size.width,
                           contentHeight: self.$contentHeight,
                           colorScheme: self.$cachedColorScheme)
        .frame(width: geometry.size.width, height: contentHeight)
      }
    }
    .onChange(of: self.cachedColorScheme, initial: true) {
      if self.cachedColorScheme == nil {
        self.cachedColorScheme = self.colorScheme
      }
      if self.lastUsedColorScheme != self.colorScheme {
        self.lastUsedColorScheme = self.colorScheme
        self.attributedText = self.generator(self.content, self.colorScheme)
      }
    }
    // The state of this view survives the creation of a new `MarkdownText` value for a different
    // document; the text needs to be generated again in this case.
    .onChange(of: self.content) {
      self.lastUsedColorScheme = self.colorScheme
      self.attributedText = self.generator(self.content, self.colorScheme)
    }
    // Mermaid diagrams and formulas take time to render. They are rendered after the text has been
    // shown for the first time; the text is generated again once there are new images.
    .task(id: PreparationRequest(content: self.content, colorScheme: self.colorScheme)) {
      if let prepare = self.prepare,
         await prepare(self.content, self.colorScheme),
         !Task.isCancelled {
        self.attributedText = self.generator(self.content, self.colorScheme)
      }
    }
  }
  
  /// Creates the attributed string generator for dark mode with the given rendering options. If
  /// `math` is not `nil`, it is a `MathAttributedStringGenerator`.
  private static func makeDarkGenerator(
                        _ renderingOptions: AttributedStringGenerator.RenderingOptions,
                        mermaid: MermaidConfig? = nil,
                        math: MathConfig? = nil)
                      -> AttributedStringGenerator {
    if let math {
      return MathAttributedStringGenerator(
        fontColor: "#FFF",
        codeFontColor: "#FFF",
        codeBlockFontColor: "#FF6",
        codeBlockBackground: "#333",
        syntaxHighlighting: .defaultDark,
        mermaid: mermaid?.darkVariant,
        math: math,
        borderColor: "#BBB",
        h1Color: "#FFF",
        h2Color: "#FFF",
        h3Color: "#FFF",
        h4Color: "#FFF",
        renderingOptions: renderingOptions)
    } else {
      return AttributedStringGenerator(
        fontColor: "#FFF",
        codeFontColor: "#FFF",
        codeBlockFontColor: "#FF6",
        codeBlockBackground: "#333",
        syntaxHighlighting: .defaultDark,
        mermaid: mermaid?.darkVariant,
        borderColor: "#BBB",
        h1Color: "#FFF",
        h2Color: "#FFF",
        h3Color: "#FFF",
        h4Color: "#FFF",
        renderingOptions: renderingOptions)
    }
  }
  
  /// Default `AttributedStringGenerator` implementation for dark mode
  private static let darkGenerator = MarkdownText.makeDarkGenerator(.trusted)
  
  /// Returns the default generators for light and dark mode for the given rendering options,
  /// Mermaid configuration and math configuration.
  private static func makeGenerators(
                        _ renderingOptions: AttributedStringGenerator.RenderingOptions,
                        mermaid: MermaidConfig?,
                        math: MathConfig? = nil)
                      -> (light: AttributedStringGenerator, dark: AttributedStringGenerator) {
    if let math {
      return (MathAttributedStringGenerator(mermaid: mermaid,
                                            math: math,
                                            renderingOptions: renderingOptions),
              MarkdownText.makeDarkGenerator(renderingOptions, mermaid: mermaid, math: math))
    } else if mermaid == nil && renderingOptions == .trusted {
      return (AttributedStringGenerator.standard,
              MarkdownText.darkGenerator)
    } else {
      return (AttributedStringGenerator(mermaid: mermaid, renderingOptions: renderingOptions),
              MarkdownText.makeDarkGenerator(renderingOptions, mermaid: mermaid))
    }
  }
  
  /// Returns the function which generates attributed strings with the default generators for
  /// the given rendering options. This is `internal` so that tests can call it.
  static func defaultGenerator(
                        _ renderingOptions: AttributedStringGenerator.RenderingOptions,
                        mermaid: MermaidConfig? = nil,
                        math: MathConfig? = nil)
                      -> (Block, ColorScheme) -> NSAttributedString? {
    let generators = MarkdownText.makeGenerators(renderingOptions, mermaid: mermaid, math: math)
    return { doc, colorScheme in
      switch colorScheme {
        case .dark:
          return generators.dark.generate(doc: doc)
        default:
          return generators.light.generate(doc: doc)
      }
    }
  }
  
  /// Returns the function which renders the Mermaid diagrams and the formulas of a document for
  /// the default generators with the given rendering options. It returns `true` if something was
  /// rendered, i.e. if the document needs to be generated again. Returns `nil` if neither diagrams
  /// nor formulas are enabled. This is `internal` so that tests can call it.
  static func defaultPreparer(
                        _ renderingOptions: AttributedStringGenerator.RenderingOptions,
                        mermaid: MermaidConfig?,
                        math: MathConfig? = nil)
                      -> (@Sendable (Block, ColorScheme) async -> Bool)? {
    guard mermaid != nil || math != nil else {
      return nil
    }
    let generators = MarkdownText.makeGenerators(renderingOptions, mermaid: mermaid, math: math)
    return { doc, colorScheme in
      let generator = colorScheme == .dark ? generators.dark : generators.light
      let diagrams = await generator.prepareDiagrams(in: doc)
      var formulas = false
      if let generator = generator as? MathAttributedStringGenerator {
        formulas = await generator.prepareMath(in: doc)
      }
      return diagrams || formulas
    }
  }
  
  /// Identifies the diagrams and formulas that need to be rendered: those of a document for a
  /// color scheme.
  private struct PreparationRequest: Equatable {
    let content: Block
    let colorScheme: ColorScheme
  }
}

#endif
