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

import SwiftUI

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct MarkdownText: View {
  /// Default `AttributedStringGenerator` implementation for dark mode
  private static let darkGenerator = AttributedStringGenerator(
      fontColor: "#FFF",
      codeFontColor: "#FFF",
      codeBlockFontColor: "#FF6",
      codeBlockBackground: "#333",
      borderColor: "#BBB",
      h1Color: "#FFF",
      h2Color: "#FFF",
      h3Color: "#FFF",
      h4Color: "#FFF")
  
  @Environment(\.colorScheme) var colorScheme
  
  /// The generator for turning markdown into a `NSAttributedString` object
  private let generator: (ColorScheme) -> NSAttributedString?
  
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
  
  /// Creates a Markdown text view for the specified Markdown document.
  public init(_ text: Block,
              generator: ((Block, ColorScheme) -> NSAttributedString?)? = nil,
              waitingMessage: NSAttributedString = NSAttributedString(string: "⏳")) {
    if let generator {
      self.generator = { colorScheme in generator(text, colorScheme) }
    } else {
      self.generator = { colorScheme in
        switch colorScheme {
          case .dark:
            return MarkdownText.darkGenerator.generate(doc: text)
          default:
            return AttributedStringGenerator.standard.generate(doc: text)
        }
      }
    }
    self.waitingMessage = waitingMessage
  }
  
  /// Creates a Markdown text view for the specified Markdown document as a string.
  public init(string: String,
              generator: ((Block, ColorScheme) -> NSAttributedString?)? = nil,
              waitingMessage: NSAttributedString = NSAttributedString(string: "⏳")) {
    self.init(ExtendedMarkdownParser.standard.parse(string),
              generator: generator,
              waitingMessage: waitingMessage)
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
        self.attributedText = self.generator(self.colorScheme)
      }
    }
  }
}
