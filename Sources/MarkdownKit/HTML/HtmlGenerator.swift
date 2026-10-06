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
open class HtmlGenerator {
  
  public enum Parent {
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
    guard case .document(let blocks) = doc else {
      preconditionFailure("cannot generate HTML from \(doc)")
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
      case .document(_):
        preconditionFailure("broken block \(block)")
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
        return "<pre><code>" +
               self.generate(lines: lines).encodingPredefinedXmlEntities() +
               "</code></pre>\n"
      case .fencedCode(let lang, let lines):
        if let lang {
          if lang == "mermaid" {
            return "<pre class=\"mermaid\">" +
                   self.generate(lines: lines, separator: "").encodingPredefinedXmlEntities() +
                   "</pre>\n"
          } else if let clazz = Sanitizer.languageClass(for: lang) {
            return "<pre><code class=\"language-\(clazz)\">" +
                   self.generate(lines: lines, separator: "").encodingPredefinedXmlEntities() +
                   "</code></pre>\n"
          } else {
            return "<pre><code>" +
                   self.generate(lines: lines, separator: "").encodingPredefinedXmlEntities() +
                   "</code></pre>\n"
          }
        } else {
          return "<pre><code>" +
                 self.generate(lines: lines, separator: "").encodingPredefinedXmlEntities() +
                 "</code></pre>\n"
        }
      case .htmlBlock(let lines):
        return self.safeMode ? "<!-- raw HTML omitted -->\n" : self.generate(lines: lines)
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
        var html = "<table><thead><tr>\n"
        var i = 0
        for head in header {
          html += "<th\(tagsuffix[i])\(self.generate(text: head))</th>"
          i += 1
        }
        html += "\n</tr></thead><tbody>\n"
        for row in rows {
          html += "<tr>"
          i = 0
          for cell in row {
            html += "<td\(tagsuffix[i])\(self.generate(text: cell))</td>"
            i += 1
          }
          html += "</tr>\n"
        }
        html += "</tbody></table>\n"
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
      case .delimiter(let ch, let n, _):
        let char: String
        switch ch {
          case "<":
            char = "&lt;"
          case ">":
            char = "&gt;"
          default:
            char = String(ch)
        }
        var res = char
        for _ in 1..<n {
          res.append(char)
        }
        return res
      case .softLineBreak:
        return "\n"
      case .hardLineBreak:
        return "<br/>"
      case .custom(let customTextFragment):
        return customTextFragment.generateHtml(via: self)
    }
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
