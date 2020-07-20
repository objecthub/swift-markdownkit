//
//  HtmlBlockParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 12/05/2019.
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
/// `HtmlBlockParser` is a block parser which parses HTML blocks and returns them in form of
/// `htmlBlock` cases of the `Block` enumeration. `HtmlBlockParser` does that with the help
/// of `HtmlBlockParserPlugin` objects to which it delegates detecting of the various HTML
/// block variants that are supported.
///
open class HtmlBlockParser: BlockParser {

  /// List of supported HTML block parser plugin types; override this computed property in
  /// subclasses of `HtmlBlockParser` to create customized versions.
  open class var supportedParsers: [HtmlBlockParserPlugin.Type] {
    return [ScriptBlockParserPlugin.self,
            CommentBlockParserPlugin.self,
            ProcessingInstructionBlockParserPlugin.self,
            DeclarationBlockParserPlugin.self,
            CdataBlockParserPlugin.self,
            HtmlTagBlockParserPlugin.self
    ]
  }

  /// HTML block parser plugins
  private var htmlParsers: [HtmlBlockParserPlugin]

  /// Default initializer
  public required init(docParser: DocumentParser) {
    self.htmlParsers = []
    for parserType in type(of: self).supportedParsers {
      self.htmlParsers.append(parserType.init())
    }
    super.init(docParser: docParser)
  }

  open override func parse() -> ParseResult {
    guard self.shortLineIndent, self.line[self.contentStartIndex] == "<" else {
      return .none
    }
    var cline = self.line[self.contentStartIndex..<self.contentEndIndex].lowercased()
    for parser in self.htmlParsers {
      if parser.startCondition(cline) {
        var lines: Lines = [self.line]
        while !self.finished && !parser.endCondition(cline) {
          self.readNextLine()
          if !self.finished {
            if (parser.emptyLineTerminator && self.lineEmpty) || self.lazyContinuation {
              break
            } else {
              lines.append(self.line)
            }
          }
          cline = self.lineEmpty
                    ? "" : self.line[self.contentStartIndex..<self.contentEndIndex].lowercased()
        }
        if !self.finished && !self.lazyContinuation {
          self.readNextLine()
        }
        if let last = lines.last, last.isEmpty {
          lines.removeLast()
        }
        return .block(.htmlBlock(lines))
      }
    }
    return .none
  }
}

///
/// Abstract HTML block parser plugin root class defining the interface for plugins.
///
open class HtmlBlockParserPlugin {

  public required init() {}

  public func isWhitespace(_ ch: Character) -> Bool {
    switch ch {
      case " ", "\t", "\n", "\r", "\r\n", "\u{b}", "\u{c}":
        return true
      default:
        return false
    }
  }

  open func line(_ line: String,
                 at: String.Index,
                 startsWith str: String,
                 endsWith suffix: String? = nil,
                 htmlTagSuffix: Bool = true) -> Bool {
    var strIndex: String.Index = str.startIndex
    var index = at
    while strIndex < str.endIndex {
      guard index < line.endIndex, line[index] == str[strIndex] else {
        return false
      }
      strIndex = str.index(after: strIndex)
      index = line.index(after: index)
    }
    if htmlTagSuffix {
      guard index < line.endIndex else {
        return true
      }
      switch line[index] {
        case " ", "\t", "\u{b}", "\u{c}":
          return true
        case "\n", "\r", "\r\n":
          return true
        case ">":
          return true
        default:
          if let end = suffix {
            strIndex = end.startIndex
            while strIndex < end.endIndex {
              guard index < line.endIndex, line[index] == end[strIndex] else {
                return false
              }
              strIndex = end.index(after: strIndex)
              index = line.index(after: index)
            }
            return true
          }
          return false
      }
    } else {
      return true
    }
  }

  open func startCondition(_ line: String) -> Bool {
    return false
  }

  open func endCondition(_ line: String) -> Bool {
    return false
  }

  open var emptyLineTerminator: Bool {
    return false
  }
}

public final class ScriptBlockParserPlugin: HtmlBlockParserPlugin {

  public override func startCondition(_ line: String) -> Bool {
    return self.line(line, at: line.startIndex, startsWith: "<script") ||
           self.line(line, at: line.startIndex, startsWith: "<pre") ||
           self.line(line, at: line.startIndex, startsWith: "<style")
  }

  public override func endCondition(_ line: String) -> Bool {
    return line.contains("</script>") ||
           line.contains("</pre>") ||
           line.contains("</style>")
  }
}

public final class CommentBlockParserPlugin: HtmlBlockParserPlugin {

  public override func startCondition(_ line: String) -> Bool {
    return self.line(line, at: line.startIndex, startsWith: "<!--", htmlTagSuffix: false)
  }

  public override func endCondition(_ line: String) -> Bool {
    return line.contains("-->")
  }
}

public final class ProcessingInstructionBlockParserPlugin: HtmlBlockParserPlugin {

  public override func startCondition(_ line: String) -> Bool {
    return self.line(line, at: line.startIndex, startsWith: "<?", htmlTagSuffix: false)
  }

  public override func endCondition(_ line: String) -> Bool {
    return line.contains("?>")
  }
}

public final class DeclarationBlockParserPlugin: HtmlBlockParserPlugin {

  public override func startCondition(_ line: String) -> Bool {
    var index: String.Index = line.startIndex
    guard index < line.endIndex && line[index] == "<" else {
      return false
    }
    index = line.index(after: index)
    guard index < line.endIndex && line[index] == "!" else {
      return false
    }
    index = line.index(after: index)
    guard index < line.endIndex else {
      return false
    }
    switch line[index] {
      case "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
           "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z":
        return true
      default:
        return false
    }
  }

  public override func endCondition(_ line: String) -> Bool {
    return line.contains(">")
  }
}

public final class CdataBlockParserPlugin: HtmlBlockParserPlugin {

  public override func startCondition(_ line: String) -> Bool {
    return self.line(line, at: line.startIndex, startsWith: "<![CDATA[", htmlTagSuffix: false)
  }

  public override func endCondition(_ line: String) -> Bool {
    return line.contains("]]>")
  }
}

public final class HtmlTagBlockParserPlugin: HtmlBlockParserPlugin {
  final let htmlTags = ["address", "article", "aside", "base", "basefont", "blockquote", "body",
                        "caption", "center", "col", "colgroup", "dd", "details", "dialog", "dir",
                        "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form",
                        "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header",
                        "hr", "html", "iframe", "legend", "li", "link", "main", "menu", "menuitem",
                        "nav", "noframes", "ol", "optgroup", "option", "p", "param", "section",
                        "source", "summary", "table", "tbody", "td", "tfoot", "th", "thead",
                        "title", "tr", "track", "ul"]

  public override func startCondition(_ line: String) -> Bool {
    var index = line.startIndex
    guard index < line.endIndex && line[index] == "<" else {
      return false
    }
    index = line.index(after: index)
    if index < line.endIndex && line[index] == "/" {
      index = line.index(after: index)
    }
    for htmlTag in self.htmlTags {
      if self.line(line, at: index, startsWith: htmlTag, endsWith: "/>") {
        return true
      }
    }
    return false
  }

  public override var emptyLineTerminator: Bool {
    return true
  }
}
