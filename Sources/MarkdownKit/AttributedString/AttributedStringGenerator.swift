//
//  AttributedStringGenerator.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 01/08/2019.
//  Copyright © 2019-2021 Google LLC.
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

#if os(iOS) || os(watchOS) || os(tvOS)
  import UIKit
#elseif os(macOS)
  import Cocoa
#endif

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

///
/// `AttributedStringGenerator` provides functionality for converting Markdown blocks into
/// `NSAttributedString` objects that are used in macOS and iOS for displaying rich text.
/// The implementation is extensible allowing subclasses of `AttributedStringGenerator` to
/// override how individual Markdown structures are converted into attributed strings.
///
open class AttributedStringGenerator {
  
  /// Options for the attributed string generator
  public struct Options: OptionSet {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
      self.rawValue = rawValue
    }
    
    public static let tightLists = Options(rawValue: 1 << 0)
  }
  
  /// Options for the rendering of table borders
  public struct TableBorders: OptionSet {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
      self.rawValue = rawValue
    }
    
    public static let header = TableBorders(rawValue: 1 << 0)
    public static let top = TableBorders(rawValue: 1 << 1)
    public static let bottom = TableBorders(rawValue: 1 << 2)
    public static let left = TableBorders(rawValue: 1 << 3)
    public static let right = TableBorders(rawValue: 1 << 4)
    public static let rows = TableBorders(rawValue: 1 << 5)
    public static let columns = TableBorders(rawValue: 1 << 6)
  }
  
  /// Version of the attributed string generator
  public enum Version {
    case preOS26
    case OS26
    
    public func makeHtmlGenerator(for generator: AttributedStringGenerator) -> HtmlGenerator {
      switch self {
        case .preOS26:
          return InternalHtmlGenerator(outer: generator)
        case .OS26:
          return OS26HtmlGenerator(outer: generator)
      }
    }
  }
  
  /// Customized html generator to work around limitations of the current HTML to
  /// `NSAttributedString` conversion logic provided by the operating system. This
  /// should be used prior to macOS 26 and iOS 26
  open class InternalHtmlGenerator: HtmlGenerator {
    var outer: AttributedStringGenerator
    
    public init(outer: AttributedStringGenerator) {
      self.outer = outer
    }

    open override func generate(block: Block, parent: Parent, tight: Bool = false) -> String {
      switch block {
        case .list(_, _, _):
          let res = super.generate(block: block, parent: .block(block, parent), tight: tight)
          if case .block(.listItem(_, _, _), _) = parent {
            return res
          } else {
            return res + "<p style=\"margin: 0;\" />\n"
          }
        case .paragraph(let text):
          if case .block(.listItem(_, _, _), .block(.list(_, let tight, _), _)) = parent,
             tight || self.outer.options.contains(.tightLists) {
            return self.generate(text: text) + "\n"
          } else {
            return "<p>" + self.generate(text: text) + "</p>\n"
          }
        case .indentedCode(_),
             .fencedCode(_, _):
          return "<table style=\"width: 100%; margin-bottom: 3px;\"><tbody><tr>" +
                 "<td class=\"codebox\">" +
                 super.generate(block: block, parent: .block(block, parent), tight: tight) +
                 "</td></tr></tbody></table><p style=\"margin: 0;\" />\n"
        case .blockquote(let blocks):
          return "<table class=\"blockquote\"><tbody><tr>" +
                 "<td class=\"quote\" /><td style=\"width: 0.5em;\" /><td>\n" +
                 self.generate(blocks: blocks, parent: .block(block, parent)) +
                 "</td></tr><tr style=\"height: 0;\"><td /><td /><td /></tr></tbody></table>\n"
        case .thematicBreak:
          return "<p><table style=\"width: 100%; margin-bottom: 3px;\"><tbody>" +
                 "<tr><td class=\"thematic\"></td></tr></tbody></table></p>\n"
        case .table(let header, let align, let rows):
          var tagsuffix: [String] = []
          for a in align {
            switch a {
              case .undefined:
                tagsuffix.append(">")
              case .left:
                tagsuffix.append(" align=\"left\">")
              case .right:
                tagsuffix.append(" align=\"right\">")
              case .center:
                tagsuffix.append(" align=\"center\">")
            }
          }
          var html = "<table class=\"mtable\"><thead><tr>\n"
          var i = 0
          for head in header {
            html += "<th\(tagsuffix[i])\(self.generate(text: head))&nbsp;</th>"
            i += 1
          }
          html += "\n</tr></thead><tbody>\n"
          for row in rows {
            html += "<tr class=\"mrow\">"
            i = 0
            for cell in row {
              html += "<td class=\"mcell\"\(tagsuffix[i])\(self.generate(text: cell))&nbsp;</td>"
              i += 1
            }
            html += "</tr>\n"
          }
          html += "</tbody></table><p style=\"margin: 0;\" />\n"
          return html
        case .definitionList(let defs):
          var html = "<dl>\n"
          for def in defs {
            html += "<dt>" + self.generate(text: def.item) + "</dt>\n"
            for descr in def.descriptions {
              if case .listItem(_, _, let blocks) = descr {
                html += "<dd>" +
                        self.generate(blocks: blocks, parent: .block(block, parent)) +
                        "</dd>\n"
              }
            }
          }
          html += "</dl>\n"
          return html
        case .custom(let customBlock):
          return customBlock.generateHtml(via: self, and: self.outer, tight: tight)
        default:
          return super.generate(block: block, parent: parent, tight: tight)
      }
    }
    
    open override func generate(textFragment fragment: TextFragment) -> String {
      switch fragment {
        case .image(let text, let uri, let title):
          let titleAttr = title == nil ? "" : " title=\"\(title!)\""
          if let uriStr = uri {
            let url = URL(string: uriStr)
            if (url?.scheme == nil) || (url?.isFileURL ?? false),
               let baseUrl = self.outer.imageBaseUrl {
              let url = URL(fileURLWithPath: uriStr, relativeTo: baseUrl)
              if url.isFileURL {
                return "<img src=\"\(url.absoluteString)\"" +
                       " alt=\"\(text.rawDescription)\"\(titleAttr)/>"
              }
            }
            return "<img src=\"\(uriStr)\" alt=\"\(text.rawDescription)\"\(titleAttr)/>"
          } else {
            return self.generate(text: text)
          }
        case .custom(let customTextFragment):
          return customTextFragment.generateHtml(via: self, and: self.outer)
        default:
          return super.generate(textFragment: fragment)
      }
    }
  }
  
  /// Customized html generator to work around limitations of the current HTML to
  /// `NSAttributedString` conversion logic provided by the operating system. This
  /// should be used starting macOS 26 and iOS 26.
  open class OS26HtmlGenerator: InternalHtmlGenerator {
    open override func generate(block: Block, parent: Parent, tight: Bool = false) -> String {
      switch block {
        case .list(let start, let tight, let blocks):
          if case .block(.listItem(_, _, _), _) = parent {
            let clazz = start == nil ? "uln" : "oln"
            return "<table class=\"\(clazz)\"><tbody>\n" +
                   self.generate(blocks: blocks, parent: .block(block, parent), tight: tight) +
                   "</tbody></table>\n"
          } else {
            let clazz = start == nil ? "ult" : "olt"
            return "<table class=\"\(clazz)\"><tbody>\n" +
                   self.generate(blocks: blocks, parent: .block(block, parent), tight: tight) +
                   "</tbody></table><p class=\"spc\"></p>\n"
          }
        case .listItem(.ordered(let n, let ch), _, let blocks):
          if tight, let text = blocks.text {
            return "<tr class=\"srow\">" +
                   "<td class=\"lnumber\">\(n)\(ch)</td>" +
                   "<td class=\"sitem\">\(self.generate(text: text))</td></tr>\n"
          } else {
            return "<tr class=\"crow\">" +
                   "<td class=\"lnumber\">\(n)\(ch)</td>" +
                   "<td class=\"citem\">" +
                   self.generate(blocks: blocks, parent: .block(block, parent), tight: tight) +
                   "</td></tr>\n"
          }
        case .listItem(_, _, let blocks):
          if tight, let text = blocks.text {
            return "<tr class=\"srow\">" +
                   "<td class=\"lbullet\"><b>•</b></td>" +
                   "<td class=\"sitem\">\(self.generate(text: text))</td></tr>\n"
          } else {
            return "<tr class=\"crow\">" +
                   "<td class=\"lbullet\"><b>•</b></td>" +
                   "<td class=\"citem\">" +
                   self.generate(blocks: blocks, parent: .block(block, parent), tight: tight) +
                   "</td></tr>\n"
          }
        default:
          return super.generate(block: block, parent: parent, tight: tight)
      }
    }
  }

  /// Default `AttributedStringGenerator` implementation.
  public static let standard: AttributedStringGenerator = AttributedStringGenerator()
  
  /// The generator version used.
  public let version: Version
  
  /// The generator options.
  public let options: Options
  
  /// The base font size.
  public let fontSize: Float

  /// The base font family.
  public let fontFamily: String

  /// The base font color.
  public let fontColor: String

  /// The code font size.
  public let codeFontSize: Float

  /// The code font family.
  public let codeFontFamily: String

  /// The code font color.
  public let codeFontColor: String

  /// The code block font size.
  public let codeBlockFontSize: Float

  /// The code block font color.
  public let codeBlockFontColor: String

  /// The code block background color.
  public let codeBlockBackground: String

  /// The border color (used for code blocks and for thematic breaks).
  public let borderColor: String

  /// The blockquote color.
  public let blockquoteColor: String

  /// The color of H1 headers.
  public let h1Color: String

  /// The color of H2 headers.
  public let h2Color: String

  /// The color of H3 headers.
  public let h3Color: String

  /// The color of H4 headers.
  public let h4Color: String

  /// The maximum width of an image
  public let maxImageWidth: String?
  
  /// The maximum height of an image
  public let maxImageHeight: String?
  
  /// Custom CSS style
  public let customStyle: String
  
  /// If provided, this URL is used as a base URL for relative image links
  public let imageBaseUrl: URL?
  
  /// Constructor providing customization options for the generated `NSAttributedString` markup.
  public init(version: Version? = nil,
              options: Options = [],
              fontSize: Float = 14.0,
              fontFamily: String = "\"Times New Roman\",Times,serif",
              fontColor: String = mdDefaultColor,
              codeFontSize: Float = 13.0,
              codeFontFamily: String =
                                "\"Consolas\",\"Andale Mono\",\"Courier New\",Courier,monospace",
              codeFontColor: String = mdDefaultColor,
              codeBlockFontSize: Float = 12.0,
              codeBlockFontColor: String = mdDefaultColor,
              codeBlockBackground: String = mdDefaultBackgroundColor,
              borderColor: String = "#bbb",
              blockquoteColor: String = "#99c",
              h1Color: String = mdDefaultColor,
              h2Color: String = mdDefaultColor,
              h3Color: String = mdDefaultColor,
              h4Color: String = mdDefaultColor,
              maxImageWidth: String? = nil,
              maxImageHeight: String? = nil,
              customStyle: String = "",
              imageBaseUrl: URL? = nil) {
    if let version {
      self.version = version
    } else if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, visionOS 26, macCatalyst 26, *) {
      self.version = .OS26
    } else {
      self.version = .preOS26
    }
    self.options = options
    self.fontSize = fontSize
    self.fontFamily = fontFamily
    self.fontColor = fontColor
    self.codeFontSize = codeFontSize
    self.codeFontFamily = codeFontFamily
    self.codeFontColor = codeFontColor
    self.codeBlockFontSize = codeBlockFontSize
    self.codeBlockFontColor = codeBlockFontColor
    self.codeBlockBackground = codeBlockBackground
    self.borderColor = borderColor
    self.blockquoteColor = blockquoteColor
    self.h1Color = h1Color
    self.h2Color = h2Color
    self.h3Color = h3Color
    self.h4Color = h4Color
    self.maxImageWidth = maxImageWidth
    self.maxImageHeight = maxImageHeight
    self.customStyle = customStyle
    self.imageBaseUrl = imageBaseUrl
  }

  /// Generates an attributed string from the given Markdown document
  open func generate(doc: Block) -> NSAttributedString? {
    return self.generateAttributedString(self.htmlGenerator.generate(doc: doc))
  }

  /// Generates an attributed string from the given Markdown blocks
  open func generate(block: Block) -> NSAttributedString? {
    return self.generateAttributedString(self.htmlGenerator.generate(block: block, parent: .none))
  }

  /// Generates an attributed string from the given Markdown blocks
  open func generate(blocks: Blocks) -> NSAttributedString? {
    return self.generateAttributedString(self.htmlGenerator.generate(blocks: blocks, parent: .none))
  }
  
  private func generateAttributedString(_ htmlBody: String) -> NSAttributedString? {
    if let httpData = self.generateHtml(htmlBody).data(using: .utf8) {
      return try? NSAttributedString(data: httpData,
                                     options: [.documentType: NSAttributedString.DocumentType.html,
                                               .characterEncoding: String.Encoding.utf8.rawValue],
                                     documentAttributes: nil)
    } else {
      return nil
    }
  }
  
  open var htmlGenerator: HtmlGenerator {
    return self.version.makeHtmlGenerator(for: self)
  }
  
  open func generateHtml(_ htmlBody: String) -> String {
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
    return "body             { \(self.bodyStyle) }\n" +
           "h1               { \(self.h1Style) }\n" +
           "h2               { \(self.h2Style) }\n" +
           "h3               { \(self.h3Style) }\n" +
           "h4               { \(self.h4Style) }\n" +
           "p                { \(self.pStyle) }\n" +
           "ul               { \(self.ulStyle) }\n" +
           "ol               { \(self.olStyle) }\n" +
           "li               { \(self.liStyle) }\n" +
           "table.blockquote { \(self.blockquoteStyle) }\n" +
           "table.ult        { \(self.ulStyle) }\n" +
           "table.olt        { \(self.olStyle) }\n" +
           "table.uln        { \(self.ulNestedStyle) }\n" +
           "table.oln        { \(self.olNestedStyle) }\n" +
           "table.mtable     { \(self.tableStyle) }\n" +
           "table.mtable thead th { \(self.tableHeaderStyle) }\n" +
           "pre              { \(self.preStyle) }\n" +
           "code             { \(self.codeStyle) }\n" +
           "pre code         { \(self.preCodeStyle) }\n" +
           "tr.srow          { \(self.simpleItemStyle) }\n" +
           "tr.crow          { \(self.itemStyle) }\n" +
           "td.lnumber       { \(self.numberStyle) }\n" +
           "td.lbullet       { \(self.bulletStyle) }\n" +
           "td.sitem         { \(self.simpleLiStyle) }\n" +
           "td.citem         { \(self.liStyle) }\n" +
           "td.codebox       { \(self.codeBoxStyle) }\n" +
           "td.thematic      { \(self.thematicBreakStyle) }\n" +
           "td.quote         { \(self.quoteStyle) }\n" +
           "td.mrow          { \(self.tableRowStyle) }\n" +
           "td.mcell         { \(self.tableCellStyle) }\n" +
           "img              { \(self.imgStyle) }\n" +
           "p.spc            {\n" +
           "  font-size: \((self.fontSize / 2) + 1)px;\n" +
           "  margin: 0em;\n" +
           "  padding: 0em;\n" +
           "}\n" +
           "dt {\n" +
           "  font-weight: bold;\n" +
           "  margin: 0.6em 0 0.4em 0;\n" +
           "}\n" +
           "dd {\n" +
           "  margin: 0.5em 0 1em 2em;\n" +
           "  padding: 0.5em 0 1em 2em;\n" +
           "}\n" +
           "\(self.customStyle)\n"
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
           "margin: 0.6em 0 0.4em 0;"
  }

  open var h3Style: String {
    return "font-size: \(self.fontSize + 2)px;" +
           "color: \(self.h3Color);" +
           "margin: 0.5em 0 0.3em 0;"
  }

  open var h4Style: String {
    return "font-size: \(self.fontSize + 1)px;" +
           "color: \(self.h4Color);" +
           "margin: 0.5em 0 0.3em 0;"
  }

  open var pStyle: String {
    return "margin: 0.7em 0em;"
  }

  open var ulStyle: String {
    switch self.version {
      case .preOS26:
        return "margin: 0.7em 0em;"
      case .OS26:
        return "width: 100%;" +
               "border-collapse: collapse;" +
               "margin: 0em;" +
               "padding: 0em;" +
               "font-size: \(self.fontSize)px;"
    }
  }
  
  open var ulNestedStyle: String {
    return "width: 100%;" +
           "border-collapse: collapse;" +
           "margin: 0em;" +
           "padding: 0em;" +
           "font-size: \(self.fontSize)px;"
  }

  open var olStyle: String {
    switch self.version {
      case .preOS26:
        return "margin: 0.7em 0em;"
      case .OS26:
        return "width: 100%;" +
               "border-collapse: collapse;" +
               "margin: 0em;" +
               "padding: 0em;" +
               "font-size: \(self.fontSize)px;"
    }
  }

  open var olNestedStyle: String {
    return "width: 100%;" +
           "border-collapse: collapse;" +
           "margin: 0em;" +
           "padding: 0em;" +
           "font-size: \(self.fontSize)px;"
  }
  
  open var simpleItemStyle: String {
    return """
      width: 100%;
    """
  }
  
  open var itemStyle: String {
    return """
      width: 100%;
    """
  }
  
  open var bulletStyle: String {
    return """
      width: 2em;
      padding: 0em 0.8em;
      vertical-align: top;
      text-align: center;
    """
  }
  
  open var numberStyle: String {
    return """
      width: 4em;
      padding: 0em 0.4em 0em 0em;
      vertical-align: top;
      text-align: right;
    """
  }
  
  open var simpleLiStyle: String {
    return """
      margin: 0em;
      padding: 0em 0em 0.2em 0em;
      vertical-align: top;
      text-align: left;
    """
  }
  
  open var liStyle: String {
    switch self.version {
      case .preOS26:
        return """
          margin-left: 0.25em;
          margin-bottom: 0.1em;
        """
      case .OS26:
        return """
          margin: 0em;
          padding: 0em 0em 0.6em 0em;
          vertical-align: top;
          text-align: left;
        """
    }
  }
  
  open var preStyle: String {
    return "background: \(self.codeBlockBackground);"
  }

  open var codeStyle: String {
    return "font-size: \(self.codeFontSize)px;" +
           "font-family: \(self.codeFontFamily);" +
           "color: \(self.codeFontColor);"
  }

  open var preCodeStyle: String {
    return "font-size: \(self.codeBlockFontSize)px;" +
           "font-family: \(self.codeFontFamily);" +
           "color: \(self.codeBlockFontColor);"
  }

  open var codeBoxStyle: String {
    return "background: \(self.codeBlockBackground);" +
           "width: 100%;" +
           "border: 1px solid \(self.borderColor);" +
           "padding: 0.5em;"
  }

  open var thematicBreakStyle: String {
    return "border-bottom: 1px solid \(self.borderColor);"
  }

  open var blockquoteStyle: String {
    return "width: 100%;" +
           "margin: 0.3em 0;" +
           "font-size: \(self.fontSize)px;"
  }
  
  open var quoteStyle: String {
    return "background: \(self.blockquoteColor);" +
           "width: 0.4em;"
  }
  
  open var imgStyle: String {
    if let maxWidth = self.maxImageWidth {
      if let maxHeight = self.maxImageHeight {
        return "max-width: \(maxWidth) !important;max-height: \(maxHeight) !important;" +
               "width: auto;height: auto;"
      } else {
        return "max-height: 100%;max-width: \(maxWidth) !important;width: auto;height: auto;"
      }
    } else if let maxHeight = self.maxImageHeight {
      return "max-width: 100%;max-height: \(maxHeight) !important;width: auto;height: auto;"
    } else {
      return ""
    }
  }
  
  open var tableStyle: String {
    var res = "border-collapse: collapse;" +
              "margin: 0.3em 0;" +
              "padding: 3px;" +
              "font-size: \(self.fontSize)px;\n"
    let borders = self.tableBorders
    if borders.contains(.top) {
      res += "border-top: \(self.tableBorderSpec);\n"
    }
    if borders.contains(.bottom) {
      res += "border-bottom: \(self.tableBorderSpec);\n"
    }
    if borders.contains(.left) {
      res += "border-left: \(self.tableBorderSpec);\n"
    }
    if borders.contains(.right) {
      res += "border-right: \(self.tableBorderSpec);\n"
    }
    return res
  }
  
  open var tableHeaderStyle: String {
    let borders = self.tableBorders
    var res = borders.contains(.header) ? "border-bottom: \(self.tableBorderSpec);\n" : ""
    if borders.contains(.columns) {
      res += "border-right: \(self.tableBorderSpec);\n"
      res += "border-left: \(self.tableBorderSpec);\n"
    }
    if let rowPadding = self.tableHeaderPadding {
      return res + "padding: \(rowPadding)px \(self.tableCellPadding)px;"
    } else {
      return res + "padding: \(self.tableCellPadding)px;"
    }
  }
  
  open var tableRowStyle: String {
    if self.tableBorders.contains(.rows) {
      return "border-bottom: \(self.tableBorderSpec);"
    } else {
      return ""
    }
  }
  
  open var tableCellStyle: String {
    let borders = self.tableBorders
    var res = ""
    if borders.contains(.rows) {
      res += "border-top: \(self.tableBorderSpec);\n"
      res += "border-bottom: \(self.tableBorderSpec);\n"
    }
    if borders.contains(.columns) {
      res += "border-right: \(self.tableBorderSpec);\n"
      res += "border-left: \(self.tableBorderSpec);\n"
    }
    if let rowPadding = self.tableRowPadding {
      return res +
             "padding: \(rowPadding)px \(self.tableCellPadding)px;\n" +
             "vertical-align: top;"
    } else {
      return res +
             "padding: \(self.tableCellPadding)px;\n" +
             "vertical-align: top;"
    }
  }
  
  open var tableBorders: TableBorders {
    return .header
  }
  
  open var tableBorderSpec: String {
    return "1px solid #aaa"
  }
  
  open var tableHeaderPadding: Int? {
    switch self.version {
      case .preOS26:
        return nil
      case .OS26:
        return 4
    }
  }
  
  open var tableRowPadding: Int? {
    switch self.version {
      case .preOS26:
        return nil
      case .OS26:
        return 3
    }
  }
  
  open var tableCellPadding: Int {
    switch self.version {
      case .preOS26:
        return 2
      case .OS26:
        return 6
    }
  }
}

#endif
