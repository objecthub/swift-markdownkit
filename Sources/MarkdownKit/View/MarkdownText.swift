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

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct MarkdownText: View {
  
  /// Creates the attributed string generator for dark mode with the given rendering options.
  private static func makeDarkGenerator(
                        _ renderingOptions: AttributedStringGenerator.RenderingOptions)
                      -> AttributedStringGenerator {
    return AttributedStringGenerator(
      fontColor: "#FFF",
      codeFontColor: "#FFF",
      codeBlockFontColor: "#FF6",
      codeBlockBackground: "#333",
      syntaxHighlighting: .defaultDark,
      borderColor: "#BBB",
      h1Color: "#FFF",
      h2Color: "#FFF",
      h3Color: "#FFF",
      h4Color: "#FFF",
      renderingOptions: renderingOptions)
  }
  
  /// Default `AttributedStringGenerator` implementation for dark mode
  private static let darkGenerator = MarkdownText.makeDarkGenerator(.trusted)
  
  /// Returns the function which generates attributed strings with the default generators for
  /// the given rendering options. This is `internal` so that tests can call it.
  static func defaultGenerator(
                        _ renderingOptions: AttributedStringGenerator.RenderingOptions)
                      -> (Block, ColorScheme) -> NSAttributedString? {
    if renderingOptions == .trusted {
      return { doc, colorScheme in
        switch colorScheme {
          case .dark:
            return MarkdownText.darkGenerator.generate(doc: doc)
          default:
            return AttributedStringGenerator.standard.generate(doc: doc)
        }
      }
    } else {
      let lightGenerator = AttributedStringGenerator(renderingOptions: renderingOptions)
      let darkGenerator = MarkdownText.makeDarkGenerator(renderingOptions)
      return { doc, colorScheme in
        switch colorScheme {
          case .dark:
            return darkGenerator.generate(doc: doc)
          default:
            return lightGenerator.generate(doc: doc)
        }
      }
    }
  }
  
  @Environment(\.colorScheme) var colorScheme
  
  /// The Markdown document that is displayed. The view is updated if this changes.
  private let content: Block
  
  /// The generator for turning markdown into a `NSAttributedString` object
  private let generator: (Block, ColorScheme) -> NSAttributedString?
  
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
  
  /// The designated initializer.
  private init(content: Block,
               waitingMessage: NSAttributedString,
               generator: @escaping (Block, ColorScheme) -> NSAttributedString?) {
    self.content = content
    self.waitingMessage = waitingMessage
    self.generator = generator
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
  /// - Parameters:
  ///   - text: The Markdown document.
  ///   - waitingMessage: What is displayed until the document has been converted.
  ///   - renderingOptions: The options for rendering the generated HTML.
  public init(_ text: Block,
              waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
              renderingOptions: AttributedStringGenerator.RenderingOptions = .trusted) {
    self.init(content: text,
              waitingMessage: waitingMessage,
              generator: MarkdownText.defaultGenerator(renderingOptions))
  }
  
  /// Creates a Markdown text view for the specified Markdown document. `generator` creates
  /// the attributed string that is displayed for a document and a color scheme. If it is
  /// `nil`, the default generators are used (see `init(_:waitingMessage:renderingOptions:)`).
  public init(_ text: Block,
              waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
              generator: ((Block, ColorScheme) -> NSAttributedString?)?) {
    self.init(content: text,
              waitingMessage: waitingMessage,
              generator: generator ?? MarkdownText.defaultGenerator(.trusted))
  }
  
  /// Creates a Markdown text view for the specified Markdown document as a string. See
  /// `init(_:waitingMessage:renderingOptions:)`.
  public init(string: String,
              waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
              renderingOptions: AttributedStringGenerator.RenderingOptions = .trusted) {
    self.init(ExtendedMarkdownParser.standard.parse(string),
              waitingMessage: waitingMessage,
              renderingOptions: renderingOptions)
  }
  
  /// Creates a Markdown text view for the specified Markdown document as a string.
  /// `generator` creates the attributed string that is displayed for a document and a color
  /// scheme. If it is `nil`, the default generators are used (see
  /// `init(string:waitingMessage:renderingOptions:)`).
  public init(string: String,
              waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
              generator: ((Block, ColorScheme) -> NSAttributedString?)?) {
    self.init(ExtendedMarkdownParser.standard.parse(string),
              waitingMessage: waitingMessage,
              generator: generator)
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
  }
}

#endif
