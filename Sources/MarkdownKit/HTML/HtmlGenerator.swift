//
//  HtmlGenerator.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 15/07/2019.
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

import Foundation

///
/// `HtmlGenerator` provides functionality for converting Markdown blocks into HTML. The
/// implementation is extensible allowing subclasses of `HtmlGenerator` to override how
/// individual Markdown structures are converted into HTML.
///
/// Instances are immutable once they have been created and conform to `Sendable`, so a
/// single instance (such as `HtmlGenerator.standard`) can be used from several threads or tasks
/// at the same time. The conformance is `@unchecked` because the class is `open`: a
/// subclass which adds mutable state has to synchronize it itself, and has to restate
/// the conformance as `@unchecked Sendable`.
///
open class HtmlGenerator: @unchecked Sendable {
  
  public enum Parent: Sendable {
    case none
    indirect case block(Block, Parent)
  }
  
  /// Default `HtmlGenerator` implementation
  public static let standard = HtmlGenerator()

  /// If `safeMode` is true, raw HTML is omitted from the output and links and images with URLs
  /// that use unsafe schemes, such as `javascript:`, are rendered with an empty URL. Use this
  /// when generating HTML from untrusted Markdown.
  public let safeMode: Bool
  
  public init(safeMode: Bool = false) {
    self.safeMode = safeMode
  }

  /// `generate` takes a block representing a Markdown document and returns a corresponding
  /// representation in HTML as a string.
  open func generate(doc: Block) -> String {
    // A block which is not a document is handled like a document consisting of this block
    guard case .document(let blocks) = doc else {
      return self.generate(blocks: [doc], parent: .none)
    }
    return self.generate(blocks: blocks, parent: .none)
  }

  open func generate(blocks: Blocks, parent: Parent, tight: Bool = false) -> String {
    var res = ""
    for block in blocks {
      res += self.generate(block: block, parent: parent, tight: tight)
    }
    return res
  }
  
  open func generate(block: Block, parent: Parent, tight: Bool = false) -> String {
    switch block {
      case .document(let blocks):
        return self.generate(blocks: blocks, parent: parent, tight: tight)
      case .blockquote(let blocks):
        return "<blockquote>\n" +
               self.generate(blocks: blocks, parent: .block(block, parent)) +
               "</blockquote>\n"
      case .list(let start, let tight, let blocks):
        if let startNumber = start {
          return "<ol start=\"\(startNumber)\">\n" +
                 self.generate(blocks: blocks, parent: .block(block, parent), tight: tight) +
                 "</ol>\n"
        } else {
          return "<ul>\n" +
                 self.generate(blocks: blocks, parent: .block(block, parent), tight: tight) +
                 "</ul>\n"
        }
      case .listItem(_, _, let blocks):
        if tight, let text = blocks.text {
          return "<li>" + self.generate(text: text) + "</li>\n"
        } else {
          return "<li>" +
                 self.generate(blocks: blocks, parent: .block(block, parent), tight: tight) +
                 "</li>\n"
        }
      case .paragraph(let text):
        if tight {
          return self.generate(text: text) + "\n"
        } else {
          return "<p>" + self.generate(text: text) + "</p>\n"
        }
      case .heading(let n, let text):
        let tag = "h\(n > 0 && n < 7 ? n : 1)>"
        return "<\(tag)\(self.generate(text: text))</\(tag)\n"
      case .indentedCode(let lines):
        return "<pre><code>" + self.codeContent(lines) + "</code></pre>\n"
      case .fencedCode(let lang, let lines):
        if let lang {
          if lang == "mermaid" {
            return "<pre class=\"mermaid\">" +
                   self.generate(lines: lines, separator: "").encodingPredefinedXmlEntities() +
                   "</pre>\n"
          } else if let clazz = Sanitizer.languageClass(for: lang) {
            return "<pre><code class=\"language-\(clazz)\">" + self.codeContent(lines) +
                   "</code></pre>\n"
          } else {
            return "<pre><code>" + self.codeContent(lines) + "</code></pre>\n"
          }
        } else {
          return "<pre><code>" + self.codeContent(lines) + "</code></pre>\n"
        }
      case .htmlBlock(let lines):
        if self.safeMode {
          return "<!-- raw HTML omitted -->\n"
        }
        // The lines include their line terminators
        let html = self.generate(lines: lines, separator: "")
        return html.isEmpty || html.hasSuffix("\n") ? html : html + "\n"
      case .referenceDef(_, _, _):
        return ""
      case .thematicBreak:
        return "<hr />\n"
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
        // Rows with more cells than there are column alignments are tolerated
        func suffix(_ i: Int) -> String {
          return i < tagsuffix.count ? tagsuffix[i] : ">"
        }
        var html = "<table><thead><tr>\n"
        var i = 0
        for head in header {
          html += "<th\(suffix(i))\(self.generate(text: head))</th>"
          i += 1
        }
        html += "\n</tr></thead>"
        // A table without rows has no body
        if !rows.isEmpty {
          html += "<tbody>\n"
          for row in rows {
            html += "<tr>"
            i = 0
            for cell in row {
              html += "<td\(suffix(i))\(self.generate(text: cell))</td>"
              i += 1
            }
            html += "</tr>\n"
          }
          html += "</tbody>"
        }
        html += "</table>\n"
        return html
      case .definitionList(let defs):
        var html = "<dl>\n"
        for def in defs {
          html += "<dt>" + self.generate(text: def.item) + "</dt>\n"
          for descr in def.descriptions {
            if case .listItem(_, _, let blocks) = descr {
              if blocks.count == 1,
                 case .paragraph(let text) = blocks.first! {
                html += "<dd>" + self.generate(text: text) + "</dd>\n"
              } else {
                html += "<dd>" +
                        self.generate(blocks: blocks, parent: .block(block, parent)) +
                        "</dd>\n"
              }
            }
          }
        }
        html += "</dl>\n"
        return html
      case .custom(let customBlock):
        return customBlock.generateHtml(via: self, tight: tight)
    }
  }

  open func generate(text: Text) -> String {
    var res = ""
    for fragment in text {
      res += self.generate(textFragment: fragment)
    }
    return res
  }

  open func generate(textFragment fragment: TextFragment) -> String {
    switch fragment {
      case .text(let str):
        return String(str).decodingNamedCharacters().encodingPredefinedXmlEntities()
      case .code(let str):
        return "<code>" + String(str).encodingPredefinedXmlEntities() + "</code>"
      case .emph(let text):
        return "<em>" + self.generate(text: text) + "</em>"
      case .strong(let text):
        return "<strong>" + self.generate(text: text) + "</strong>"
      case .underline(let text):
        return "<u>" + self.generate(text: text) + "</u>"
      case .strikethrough(let text):
        return "<del>" + self.generate(text: text) + "</del>"
      case .link(let text, let uri, let title):
        return "<a href=\"\(self.hrefAttribute(uri ?? ""))\"\(self.titleAttribute(title))>" +
               self.generate(text: text) + "</a>"
      case .autolink(let type, let substr):
        let str = String(substr)
        switch type {
          case .uri:
            return "<a href=\"\(self.hrefAttribute(str, decode: false))\">" +
                   "\(str.encodingPredefinedXmlEntities())</a>"
          case .email:
            return "<a href=\"mailto:\(str.encodingPredefinedXmlEntities())\">" +
                   "\(str.encodingPredefinedXmlEntities())</a>"
        }
      case .image(let text, let uri, let title):
        if let uri = uri {
          return "<img src=\"\(self.hrefAttribute(uri, image: true))\" " +
                 "alt=\"\(Sanitizer.attribute(text.rawDescription))\"" +
                 "\(self.titleAttribute(title))/>"
        } else {
          return self.generate(text: text)
        }
      case .html(let tag):
        return self.safeMode ? "<!-- raw HTML omitted -->" : "<\(tag.description)>"
      case .delimiter(let ch, let n, let type):
        let char: String
        switch ch {
          case "<":
            char = "&lt;"
          case ">":
            char = "&gt;"
          default:
            char = String(ch)
        }
        // The opening bracket of an image, which was not completed, comes with its `!`
        return (type.contains(.image) ? "!" : "") + String(repeating: char, count: max(n, 0))
      case .softLineBreak:
        return "\n"
      case .hardLineBreak:
        return "<br/>"
      case .custom(let customTextFragment):
        return customTextFragment.generateHtml(via: self)
    }
  }

  /// Returns the escaped content of a code block. The lines of code blocks include their line
  /// terminators (except possibly for the last line of the input). The result always ends
  /// with a newline unless it is empty.
  private func codeContent(_ lines: Lines) -> String {
    var code = self.generate(lines: lines, separator: "")
    if !code.isEmpty && !code.hasSuffix("\n") {
      code += "\n"
    }
    return code.encodingPredefinedXmlEntities()
  }

  /// Returns the escaped value for the `href` or `src` attribute for the given URL. In safe mode,
  /// URLs with unsafe schemes are replaced with the empty string. If `decode` is true, entities
  /// in `url` get decoded first.
  open func hrefAttribute(_ url: String, decode: Bool = true, image: Bool = false) -> String {
    let decoded = decode ? url.decodingNamedCharacters() : url
    if self.safeMode && !Sanitizer.isSafeURL(decoded, image: image) {
      return ""
    }
    return decoded.encodingPredefinedXmlEntities()
  }

  /// Returns the title attribute (including a leading space) or the empty string.
  open func titleAttribute(_ title: String?) -> String {
    guard let title else {
      return ""
    }
    return " title=\"\(Sanitizer.attribute(title))\""
  }

  open func generate(lines: Lines, separator: String = "\n") -> String {
    var res = ""
    for line in lines {
      if res.isEmpty {
        res = String(line)
      } else {
        res += separator + line
      }
    }
    return res
  }
}
