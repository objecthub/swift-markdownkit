//
//  HtmlGenerator.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 15/07/2019.
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

import Foundation

///
/// `HtmlGenerator` provides functionality for converting Markdown blocks into HTML. The
/// implementation is extensible allowing subclasses of `HtmlGenerator` to override how
/// individual Markdown structures are converted into HTML.
///
open class HtmlGenerator {

  /// Default `HtmlGenerator` implementation
  public static let standard = HtmlGenerator()

  public init() {}

  /// `generate` takes a block representing a Markdown document and returns a corresponding
  /// representation in HTML as a string.
  open func generate(doc: Block) -> String {
    guard case .document(let blocks) = doc else {
      preconditionFailure("cannot generate HTML from \(doc)")
    }
    return self.generate(blocks: blocks)
  }

  open func generate(blocks: Blocks, tight: Bool = false) -> String {
    var res = ""
    for block in blocks {
      res += self.generate(block: block, tight: tight)
    }
    return res
  }

  open func generate(block: Block, tight: Bool = false) -> String {
    switch block {
      case .document(_):
        preconditionFailure("broken block \(block)")
      case .blockquote(let blocks):
        return "<blockquote>\n" + self.generate(blocks: blocks) + "</blockquote>\n"
      case .list(let start, let tight, let blocks):
        if let startNumber = start {
          return "<ol start=\"\(startNumber)\">\n" + self.generate(blocks: blocks, tight: tight) +
                 "</ol>\n"
        } else {
          return "<ul>\n" + self.generate(blocks: blocks, tight: tight) + "</ul>\n"
        }
      case .listItem(_, _, let blocks):
        if tight, let text = blocks.text {
          return "<li>" + self.generate(text: text) + "</li>\n"
        } else {
          return "<li>" + self.generate(blocks: blocks) + "</li>\n"
        }
      case .paragraph(let text):
        return "<p>" + self.generate(text: text) + "</p>\n"
      case .heading(let n, let text):
        let tag = "h\(n > 0 && n < 7 ? n : 1)>"
        return "<\(tag)\(self.generate(text: text))</\(tag)\n"
      case .indentedCode(let lines):
        return "<pre><code>" + self.generate(lines: lines) + "</code></pre>\n"
      case .fencedCode(let lang, let lines):
        if let language = lang {
          return "<pre><code class=\"\(language)\">" +
                 self.generate(lines: lines, separator: "") +
                 "</code></pre>\n"
        } else {
          return "<pre><code>" + self.generate(lines: lines, separator: "") + "</code></pre>\n"
        }
      case .htmlBlock(let lines):
        return self.generate(lines: lines)
      case .referenceDef(_, _, _):
        return ""
      case .thematicBreak:
        return "<hr />\n"
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
        return String(str)
      case .code(let str):
        return "<code>" + str + "</code>"
      case .emph(let text):
        return "<em>" + self.generate(text: text) + "</em>"
      case .strong(let text):
        return "<strong>" + self.generate(text: text) + "</strong>"
      case .link(let text, let uri, let title):
        let titleAttr = title == nil ? "" : " title=\"\(title!)\""
        return "<a href=\"\(uri ?? "")\"\(titleAttr)>" + self.generate(text: text) + "</a>"
      case .autolink(let type, let str):
        switch type {
          case .uri:
            return "<a href=\"\(str)\">\(str)</a>"
          case .email:
            return "<a href=\"mailto:\(str)\">\(str)</a>"
        }
      case .image(let text, let uri, let title):
        let titleAttr = title == nil ? "" : " title=\"\(title!)\""
        if let uri = uri {
          return "<img src=\"\(uri)\" alt=\"\(text.rawDescription)\"\(titleAttr)/>"
        } else {
          return self.generate(text: text)
        }
      case .html(let tag):
        return "<\(tag.description)>"
      case .delimiter(_, _, _):
        return fragment.rawDescription
      case .softLineBreak:
        return "\n"
      case .hardLineBreak:
        return "<br/>"
    }
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
