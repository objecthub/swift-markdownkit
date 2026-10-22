//
//  MarkdownUtil+Documents.swift
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

#if os(macOS) || os(iOS)

import Foundation

// The methods which turn a Markdown document into RTF and RTFD documents (macOS and iOS).
extension MarkdownUtil {

  /// Returns the document as an RTF document. RTF files cannot contain images, so
  /// diagrams are shown as code and formulas as they were written (there is no
  /// `MermaidConfig` or `MathConfig` for this method); use
  /// ``rtfd(_:title:author:maxImageWidth:mermaid:math:imageBaseUrl:renderingOptions:)``
  /// for a document with images. The result is the content of an `.rtf` file.
  ///
  /// This method is available on macOS and iOS. It renders the document as the asynchronous
  /// methods of ``AttributedStringGenerator`` do, so it also loads the images of the Markdown
  /// text that `renderingOptions` allow.
  ///
  /// - Parameters:
  ///   - doc: The Markdown document, or a part of it.
  ///   - title: The title of the document, which becomes one of its properties (on macOS; iOS
  ///            does not write the properties of a document).
  ///   - author: The author of the document, which becomes one of its properties (on macOS; iOS
  ///             does not write the properties of a document).
  ///   - imageBaseUrl: The URL against which the relative paths of images are resolved, see
  ///                   ``AttributedStringGenerator/imageBaseUrl``. Use a URL with a trailing
  ///                   slash for a directory. If `nil`, they are resolved against the `baseUrl`
  ///                   of `renderingOptions`.
  ///   - renderingOptions: The options for rendering the document, which restrict what it can
  ///                       load (see <doc:RenderingUntrustedMarkdown>).
  /// - Throws: A ``AttributedStringGenerator/RenderingError`` if the document cannot be
  ///           rendered, or an error of the system if it cannot be exported.
  public func rtf(_ doc: Block,
                  title: String? = nil,
                  author: String? = nil,
                  imageBaseUrl: URL? = nil,
                  renderingOptions: AttributedStringGenerator.RenderingOptions = .trusted)
                async throws -> Data {
    let generator = AttributedStringGenerator(style: self.style,
                                              syntaxHighlighter: self.syntaxHighlighter,
                                              imageBaseUrl: imageBaseUrl,
                                              renderingOptions: renderingOptions)
    let string = try await generator.generateAsync(doc: doc)
    return try string.data(
      from: NSRange(location: 0, length: string.length),
      documentAttributes: Self.documentAttributes(.rtf, title: title, author: author))
  }

  /// Returns the document as an RTFD document: a file package, which contains the text and the
  /// images, which is the content of an `.rtfd` directory (write it with `FileWrapper.write(to:options:originalContentsURL:)`).
  /// Diagrams (see <doc:DrawingMermaidDiagrams>) and formulas (see <doc:MathematicalFormulas>)
  /// are drawn as images, in files that are called `Image 1.png` and `Formula 1.png`.
  ///
  /// The string that results from rendering the document is prepared with
  /// ``Foundation/NSAttributedString/preparedForRTFD()``: the images have the size they have in
  /// a text view, and formulas within a line are aligned with the text. A viewer does not make
  /// an image smaller if it is wider than the text, so `maxImageWidth` limits the width of
  /// diagrams and formulas.
  ///
  /// This method is available on macOS and iOS. It draws diagrams and formulas with the renderers
  /// of the utility, which take a moment for the first image.
  ///
  /// - Parameters:
  ///   - doc: The Markdown document, or a part of it.
  ///   - title: The title of the document, which becomes one of its properties (on macOS; iOS
  ///            does not write the properties of a document).
  ///   - author: The author of the document, which becomes one of its properties (on macOS; iOS
  ///             does not write the properties of a document).
  ///   - maxImageWidth: The width in points up to which diagrams and formulas are shown at their
  ///                    natural size; wider ones are scaled down. The default, 400, fits into a
  ///                    page of the size US Letter or A4 with margins of one inch, also within
  ///                    lists and block quotes. If `mermaid` or `math` has a `maxWidth` of its
  ///                    own, the smaller width counts.
  ///   - mermaid: How diagrams are drawn: theme, scale, the width of the page they are laid out
  ///              on, and more (see <doc:DrawingMermaidDiagrams>). The default draws them for a
  ///              light background. If `nil`, diagrams are shown as code.
  ///   - math: How formulas are typeset and shown: macros, scale, and more (see
  ///           <doc:MathematicalFormulas>). If `nil`, formulas are shown as they were written.
  ///   - imageBaseUrl: The URL against which the relative paths of images are resolved, see
  ///                   ``AttributedStringGenerator/imageBaseUrl``. Use a URL with a trailing slash
  ///                   for a directory. If `nil`, they are resolved against the `baseUrl` of
  ///                   `renderingOptions`.
  ///   - renderingOptions: The options for rendering the document, which restrict what it
  ///                       can load (see <doc:RenderingUntrustedMarkdown>).
  /// - Throws: A ``AttributedStringGenerator/RenderingError`` if the document cannot be rendered,
  ///           or an error of the system if it cannot be exported.
  public func rtfd(_ doc: Block,
                   title: String? = nil,
                   author: String? = nil,
                   maxImageWidth: CGFloat = 400,
                   mermaid: MermaidConfig? = .default,
                   math: MathConfig? = .default,
                   imageBaseUrl: URL? = nil,
                   renderingOptions: AttributedStringGenerator.RenderingOptions = .trusted)
                 async throws -> sending FileWrapper {
    let generator = self.documentGenerator(maxImageWidth: maxImageWidth,
                                           diagramMaxWidth: maxImageWidth,
                                           mermaid: mermaid,
                                           math: math,
                                           imageBaseUrl: imageBaseUrl,
                                           renderingOptions: renderingOptions)
    let string = try await generator.generateAsync(doc: doc).preparedForRTFD()
    return try string.fileWrapper(
      from: NSRange(location: 0, length: string.length),
      documentAttributes: Self.documentAttributes(.rtfd, title: title, author: author))
  }

  /// Returns the generator for documents with images (RTFD, for example), which has the style
  /// and the highlighter of the utility: diagrams and formulas are not wider than `maxImageWidth`.
  /// The widths that `maxImageWidth`, `diagramMaxWidth` and the configurations ask for are all
  /// limits: the smallest counts. Without a `MermaidConfig`, diagrams are code, and without a
  /// `MathConfig`, formulas are text: the generator is an ``AttributedStringGenerator``, not a
  /// ``MathAttributedStringGenerator``, then.
  func documentGenerator(maxImageWidth: CGFloat,
                         diagramMaxWidth: CGFloat?,
                         mermaid: MermaidConfig? = .default,
                         math: MathConfig? = .default,
                         imageBaseUrl: URL? = nil,
                         renderingOptions: AttributedStringGenerator.RenderingOptions)
                       -> AttributedStringGenerator {
    let diagramLimit = Self.narrowest(mermaid?.maxWidth, diagramMaxWidth)
    var mermaid = mermaid
    mermaid?.maxWidth = diagramLimit
    guard var math else {
      return AttributedStringGenerator(style: self.style,
                                       syntaxHighlighter: self.syntaxHighlighter,
                                       mermaid: mermaid,
                                       mermaidRenderer: self.mermaidRenderer,
                                       imageBaseUrl: imageBaseUrl,
                                       renderingOptions: renderingOptions)
    }
    math.maxWidth = Self.narrowest(math.maxWidth, maxImageWidth)
    return MathAttributedStringGenerator(style: self.style,
                                         syntaxHighlighter: self.syntaxHighlighter,
                                         mermaid: mermaid,
                                         mermaidRenderer: self.mermaidRenderer,
                                         math: math,
                                         mathRenderer: self.mathRenderer,
                                         imageBaseUrl: imageBaseUrl,
                                         renderingOptions: renderingOptions)
  }

  /// Returns the smallest of the limits for a width, or `nil` if there is none. A limit which
  /// is not greater than 0 is no limit (the configurations treat it so).
  static func narrowest(_ limits: CGFloat?...) -> CGFloat? {
    return limits.compactMap { $0 }.filter { $0 > 0 }.min()
  }

  /// The attributes of an RTF or RTFD document.
  private static func documentAttributes(_ type: NSAttributedString.DocumentType,
                                         title: String?,
                                         author: String?)
                                      -> [NSAttributedString.DocumentAttributeKey: Any] {
    var attributes: [NSAttributedString.DocumentAttributeKey: Any] = [.documentType: type]
    // UIKit does not write the properties of a document
    #if os(macOS)
    attributes[.creationTime] = Date()
    if let title {
      attributes[.title] = title
    }
    if let author {
      attributes[.author] = author
    }
    #endif
    return attributes
  }
}

#endif
