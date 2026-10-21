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
            HtmlTagBlockParserPlugin.self,
            CompleteTagBlockParserPlugin.self
    ]
  }

  /// HTML block parser plugins
  private var htmlParsers: [HtmlBlockParserPlugin]

  /// Default initializer
  /// Creates the parser for `docParser`, with an instance of each plugin in `supportedParsers`.
  public required init(docParser: DocumentParser) {
    self.htmlParsers = []
    for parserType in type(of: self).supportedParsers {
      self.htmlParsers.append(parserType.init())
    }
    super.init(docParser: docParser)
  }

  /// Parses an HTML block if the current line starts with a start condition of one of the
  /// plugins. The plugins are tried in order. The block ends as soon as the end condition of the
  /// plugin holds, at a blank line if the plugin ends at one, or at the end of the container.
  open override func parse() -> ParseResult {
    guard self.shortLineIndent, self.firstContentCharacter == "<" else {
      return .none
    }
    var cline = self.line[self.contentStartIndex..<self.contentEndIndex].lowercased()
    for parser in self.htmlParsers {
      if parser.startCondition(cline) {
        // Some HTML blocks cannot interrupt a paragraph (unless the paragraph is part of an
        // enclosing container which does not continue on this line)
        if !parser.canInterruptParagraph && self.prevParagraphLines != nil &&
           !self.lazyContinuation {
          continue
        }
        var lines: Lines = [self.line]
        var readMore = false
        while !self.finished && !parser.endCondition(cline) {
          self.readNextLine()
          readMore = true
          if !self.finished {
            if (parser.emptyLineTerminator && self.lineEmpty) || self.lineLeavesContainer {
              break
            } else {
              lines.append(self.line)
            }
          }
          cline = self.lineEmpty
                    ? "" : self.line[self.contentStartIndex..<self.contentEndIndex].lowercased()
        }
        // The line that was read last belongs to the block unless it is the line that made the
        // loop stop because it leaves the container. If the first line already satisfies the end
        // condition, no line was read: the first line is part of the block (also if it is a lazy
        // continuation line of a paragraph, which `readNextLine` closes) and has to be consumed.
        if !self.finished && (!readMore || !self.lineLeavesContainer) {
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

  /// Creates a plugin.
  public required init() {}

  /// Returns true if `ch` is a space, a tab, a vertical tab, a form feed or a line ending.
  public func isWhitespace(_ ch: Character) -> Bool {
    switch ch {
      case " ", "\t", "\n", "\r", "\r\n", "\u{b}", "\u{c}":
        return true
      default:
        return false
    }
  }

  /// Returns true if `line` contains `str` at the index `at`. If `htmlTagSuffix` is true, `str`
  /// also has to be followed by whitespace, `>`, the end of the line, or `suffix`, so that `str`
  /// is the name of a tag and not just the beginning of a longer name.
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

  /// Returns true if the (lowercased) content of `line` starts an HTML block of this kind. The
  /// default implementation returns `false`.
  open func startCondition(_ line: String) -> Bool {
    return false
  }

  /// Returns true if the (lowercased) content of `line` ends an HTML block of this kind. The
  /// line that satisfies the condition is the last line of the block. The default
  /// implementation returns `false`.
  open func endCondition(_ line: String) -> Bool {
    return false
  }

  /// True if a blank line ends an HTML block of this kind. The blank line is not part of the
  /// block. The default is `false`: the block continues up to the line that satisfies
  /// `endCondition(_:)`.
  open var emptyLineTerminator: Bool {
    return false
  }

  /// Can this kind of HTML block interrupt a paragraph?
  open var canInterruptParagraph: Bool {
    return true
  }
}

/// HTML blocks which start with `<script`, `<pre`, `<style` or `<textarea`, and end with the
/// line that contains the corresponding closing tag (HTML block type 1 in CommonMark).
public final class ScriptBlockParserPlugin: HtmlBlockParserPlugin {

  /// Returns true if the line starts with one of the opening tags.
  public override func startCondition(_ line: String) -> Bool {
    return self.line(line, at: line.startIndex, startsWith: "<script") ||
           self.line(line, at: line.startIndex, startsWith: "<pre") ||
           self.line(line, at: line.startIndex, startsWith: "<style") ||
           self.line(line, at: line.startIndex, startsWith: "<textarea")
  }

  /// Returns true if the line contains one of the closing tags.
  public override func endCondition(_ line: String) -> Bool {
    return line.contains("</script>") ||
           line.contains("</pre>") ||
           line.contains("</style>") ||
           line.contains("</textarea>")
  }
}

/// HTML blocks which start with `<!--` and end with the line that contains `-->` (HTML block
/// type 2 in CommonMark).
public final class CommentBlockParserPlugin: HtmlBlockParserPlugin {

  /// Returns true if the line starts with `<!--`.
  public override func startCondition(_ line: String) -> Bool {
    return self.line(line, at: line.startIndex, startsWith: "<!--", htmlTagSuffix: false)
  }

  /// Returns true if the line contains `-->`.
  public override func endCondition(_ line: String) -> Bool {
    return line.contains("-->")
  }
}

/// HTML blocks which start with `<?` and end with the line that contains `?>` (HTML block
/// type 3 in CommonMark).
public final class ProcessingInstructionBlockParserPlugin: HtmlBlockParserPlugin {

  /// Returns true if the line starts with `<?`.
  public override func startCondition(_ line: String) -> Bool {
    return self.line(line, at: line.startIndex, startsWith: "<?", htmlTagSuffix: false)
  }

  /// Returns true if the line contains `?>`.
  public override func endCondition(_ line: String) -> Bool {
    return line.contains("?>")
  }
}

/// HTML blocks which start with `<!` followed by a letter, such as a document type
/// declaration, and end with the line that contains `>` (HTML block type 4 in CommonMark).
public final class DeclarationBlockParserPlugin: HtmlBlockParserPlugin {

  /// Returns true if the line starts with `<!` and a letter.
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
    // The parser passes lowercased lines to its plugins, but this also accepts uppercase
    switch line[index] {
      case "a"..."z", "A"..."Z":
        return true
      default:
        return false
    }
  }

  /// Returns true if the line contains `>`.
  public override func endCondition(_ line: String) -> Bool {
    return line.contains(">")
  }
}

/// HTML blocks which start with `<![CDATA[` and end with the line that contains `]]>` (HTML
/// block type 5 in CommonMark).
public final class CdataBlockParserPlugin: HtmlBlockParserPlugin {

  /// Returns true if the line starts with `<![CDATA[`.
  public override func startCondition(_ line: String) -> Bool {
    return self.line(line, at: line.startIndex, startsWith: "<![cdata[", htmlTagSuffix: false)
  }

  /// Returns true if the line contains `]]>`.
  public override func endCondition(_ line: String) -> Bool {
    return line.contains("]]>")
  }
}

/// HTML blocks which start with an opening or closing tag of a block-level element, such as
/// `div`, `table` or `ul`. They end in front of the next blank line (HTML block type 6 in
/// CommonMark).
public final class HtmlTagBlockParserPlugin: HtmlBlockParserPlugin {
  final let htmlTags = ["address", "article", "aside", "base", "basefont", "blockquote", "body",
                        "caption", "center", "col", "colgroup", "dd", "details", "dialog", "dir",
                        "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form",
                        "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header",
                        "hr", "html", "iframe", "legend", "li", "link", "main", "menu", "menuitem",
                        "nav", "noframes", "ol", "optgroup", "option", "p", "param", "search",
                        "section", "source", "summary", "table", "tbody", "td", "tfoot", "th", "thead",
                        "title", "tr", "track", "ul"]

  /// Returns true if the line starts with the tag of a block-level element.
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

  /// Blocks of this kind end at a blank line.
  public override var emptyLineTerminator: Bool {
    return true
  }
}

///
/// HTML blocks which start with a complete open or closing tag (of any tag name) that is
/// followed only by whitespace on the same line. Such blocks cannot interrupt a paragraph.
///
public final class CompleteTagBlockParserPlugin: HtmlBlockParserPlugin {

  /// Returns true if the line starts with a complete opening or closing tag which is followed
  /// by whitespace only.
  public override func startCondition(_ line: String) -> Bool {
    guard line.hasPrefix("<") else {
      return false
    }
    let body = line.dropFirst()
    guard let first = body.first, first == "/" || (first.isASCII && first.isLetter) else {
      return false
    }
    // Look for the end of the tag. `>` may also occur inside of attribute values.
    var index = body.startIndex
    while let close = body[index...].firstIndex(of: ">") {
      if isHtmlTag(String(body[body.startIndex..<close])) {
        return body[body.index(after: close)...].allSatisfy { self.isWhitespace($0) }
      }
      index = body.index(after: close)
    }
    return false
  }

  /// Blocks of this kind end at a blank line.
  public override var emptyLineTerminator: Bool {
    return true
  }

  public override var canInterruptParagraph: Bool {
    return false
  }
}
