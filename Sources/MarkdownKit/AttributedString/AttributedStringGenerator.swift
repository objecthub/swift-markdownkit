//
//  AttributedStringGenerator.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 01/08/2019.
//  Copyright © 2019 Google LLC.
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

import Cocoa

///
/// `AttributedStringGenerator` provides functionality for converting Markdown blocks into
/// `NSAttributedString` objects that are used in macOS and iOS for displaying rich text.
/// The implementation is extensible allowing subclasses of `AttributedStringGenerator` to
/// override how individual Markdown structures are converted into attributed strings.
///
open class AttributedStringGenerator {

  /// Customized html generator to work around limitations of the current HTML to
  /// `NSAttributedString` conversion logic provided by the operating system.
  open class InternalHtmlGenerator: HtmlGenerator {
    open override func generate(block: Block, tight: Bool = false) -> String {
      switch block {
        case .list(_, _, _),
             .indentedCode(_),
             .fencedCode(_, _):
          return super.generate(block: block, tight: tight) + "<p style=\"margin: 0;\" />\n"
        case .blockquote(let blocks):
          return "<table><tbody><tr><td style=\"background: #bbb; width: 0.2em;\"  />" +
                 "<td style=\"width: 0.2em;\" /><td>\n" +
                 self.generate(blocks: blocks) +
                 "</td></tr><tr style=\"height: 0;\"><td /><td /><td /></tr></tbody></table>\n"
        default:
          return super.generate(block: block, tight: tight)
      }
    }
  }

  /// Default `AttributedStringGenerator` implementation.
  public static let standard: AttributedStringGenerator = AttributedStringGenerator()

  /// Internal HTML generator.
  private static let internalHtmlGenerator: InternalHtmlGenerator = InternalHtmlGenerator()

  /// Override this class property if `InternalHtmlGenerator` gets extended in a subclass of
  /// `AttributedStringGenerator`.
  open class var htmlGenerator: HtmlGenerator {
    return AttributedStringGenerator.internalHtmlGenerator
  }

  /// The base font size.
  let fontSize: Int

  /// The base font family.
  let fontFamily: String

  /// The base font color.
  let fontColor: String

  /// The code font size.
  let codeFontSize: Int

  /// The code font family.
  let codeFontFamily: String

  /// The code font color.
  let codeFontColor: String

  /// The code background color.
  let codeBackground: String

  /// The color of H1 headers.
  let h1Color: String

  /// The color of H2 headers.
  let h2Color: String

  /// The color of H3 headers.
  let h3Color: String

  /// The color of H4 headers.
  let h4Color: String

  /// Constructor providing customization options for the generated `NSAttributedString` markup.
  public init(fontSize: Int = 14,
              fontFamily: String = "\"Times New Roman\",Times,serif",
              fontColor: String = "#000",
              codeFontSize: Int = 13,
              codeFontFamily: String =
                                "\"Consolas\",\"Andale Mono\",\"Courier New\",Courier,monospace",
              codeFontColor: String = "#666",
              codeBackground: String = "#fff",
              h1Color: String = "#000",
              h2Color: String = "#000",
              h3Color: String = "#000",
              h4Color: String = "#000") {
    self.fontSize = fontSize
    self.fontFamily = fontFamily
    self.fontColor = fontColor
    self.codeFontSize = codeFontSize
    self.codeFontFamily = codeFontFamily
    self.codeFontColor = codeFontColor
    self.codeBackground = codeBackground
    self.h1Color = h1Color
    self.h2Color = h2Color
    self.h3Color = h3Color
    self.h4Color = h4Color
  }

  /// Generates an attributed string from the given Markdown document
  open func generate(doc: Block) -> NSAttributedString? {
    return self.generateAttributedString(type(of: self).htmlGenerator.generate(doc: doc))
  }

  /// Generates an attributed string from the given Markdown blocks
  open func generate(block: Block) -> NSAttributedString? {
    return self.generateAttributedString(type(of: self).htmlGenerator.generate(block: block))
  }

  /// Generates an attributed string from the given Markdown blocks
  open func generate(blocks: Blocks) -> NSAttributedString? {
    return self.generateAttributedString(type(of: self).htmlGenerator.generate(blocks: blocks))
  }

  private func generateAttributedString(_ htmlBody: String) -> NSAttributedString? {
    let htmlDoc = self.generateHtml(htmlBody)
    let httpData = Data(htmlDoc.utf8)
    return try? NSAttributedString(data: httpData,
                                   options: [.documentType: NSAttributedString.DocumentType.html,
                                             .characterEncoding: String.Encoding.utf8.rawValue],
                                   documentAttributes: nil)
  }

  private func generateHtml(_ htmlBody: String) -> String {
    return "<html>\n\(self.htmlHead)\n\(self.htmlBody(htmlBody))\n</html>"
  }

  open var htmlHead: String {
    return "<head><meta charset=\"utf-8\"/><style type=\"text/css\">\n" +
           self.docStyle +
           "\n</style></head>\n"
  }

  open func htmlBody(_ body: String) -> String {
    return "<body>\n\(body)\n</body>"
  }

  open var docStyle: String {
    return "body  { \(self.bodyStyle) }\n" +
           "h1    { \(self.h1Style) }\n" +
           "h2    { \(self.h2Style) }\n" +
           "h3    { \(self.h3Style) }\n" +
           "h4    { \(self.h4Style) }\n" +
           "p     { \(self.pStyle) }\n" +
           "ul    { \(self.ulStyle) }\n" +
           "ol    { \(self.olStyle) }\n" +
           "li    { \(self.liStyle) }\n" +
           "table { \(self.tableStyle) }\n" +
           "code  { \(self.codeStyle) }\n" +
           "pre   { \(self.preStyle) }\n"
  }

  open var bodyStyle: String {
    return "font-size: \(self.fontSize)px;" +
           "font-family: \(self.fontFamily);" +
           "color: \(self.fontColor);"
  }

  open var h1Style: String {
    return "font-size: \(self.fontSize + 6)px;" +
           "color: \(self.h1Color);" +
           "margin: 0.7em 0 0.5em 0;"
  }

  open var h2Style: String {
    return "font-size: \(self.fontSize + 4)px;" +
           "color: \(self.h2Color);" +
           "margin: 0.6em 0 0.6em 0;"
  }

  open var h3Style: String {
    return "font-size: \(self.fontSize + 2)px;" +
           "color: \(self.h3Color);" +
           "margin: 0.6em 0 0.6em 0;"
  }

  open var h4Style: String {
    return "font-size: \(self.fontSize + 1)px;" +
           "color: \(self.h4Color);" +
           "margin: 0.7em 0 0.6em 0;"
  }

  open var pStyle: String {
    return "margin: 0.7em 0;"
  }

  open var ulStyle: String {
    return "margin: 0.7em 0;"
  }

  open var olStyle: String {
    return "margin: 0.7em 0;"
  }

  open var liStyle: String {
    return "margin-left: 0.25em;" +
           "margin-bottom: 0.1em;"
  }

  open var tableStyle: String {
    return "margin: 0.2em 0;" +
           "font-size: \(self.fontSize)px;"
  }

  open var codeStyle: String {
    return "font-size: \(self.codeFontSize)px;" +
           "font-family: \(self.codeFontFamily);" +
           "color: \(self.codeFontColor);"
  }

  open var preStyle: String {
    return "background: \(self.codeBackground);" +
           "margin: 0.9em 0;" +
           "padding: 0.5em;" +
           "word-wrap: break-word;" +
           "border-radius: 4px;" +
           "border: 0.6px solid #292929;" +
           "border-color: #bbb;"
  }
}
