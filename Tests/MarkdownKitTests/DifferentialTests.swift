//
//  DifferentialTests.swift
//  MarkdownKitTests
//
//  Created on 06/10/2026.
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

import XCTest
@testable import MarkdownKit

///
/// Differential tests. They compare the current inline transformers and entity helpers with
/// frozen copies of their original, straightforward (but slow) implementations on many
/// pseudo-random inputs. Performance optimizations must not change any result.
///
class DifferentialTests: XCTestCase {

  /// Deterministic random number generator (SplitMix64), so that failures are reproducible.
  struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
      self.state = seed
    }

    mutating func next() -> UInt64 {
      self.state &+= 0x9E3779B97F4A7C15
      var z = self.state
      z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
      z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
      return z ^ (z >> 31)
    }
  }

  static let pieces = [
    "*", "**", "***", "_", "__", "a", "b", "foo", "bar", " ", "  ", "\n", "\n\n", "`", "``",
    "```", "<", ">", "<a>", "</a>", "<a href=\"x>y\">", "<http://x.y>", "<me@x.org>",
    "<!-- c -->", "<!--", "-->", "<![CDATA[x]]>", "<?php?>", "[", "]", "(", ")", "![", "[foo]",
    "[foo][]", "[foo][bar]", "[bar]", "(/u)", "(/u \"t\")", "\"", "'", "\\", "\\*", "&amp;",
    "&", "&#35;", ";", "&copy;", "# ", "> ", "- ", "1. ", "|", "~"
  ]

  static let headers = ["", "[foo]: /u \"t\"\n\n", "[foo]: /u\n[bar]: <b> 'x'\n\n"]

  static func randomDocument(_ rng: inout SeededGenerator) -> String {
    var doc = headers[Int(rng.next() % UInt64(headers.count))]
    let count = 1 + Int(rng.next() % 60)
    for _ in 0..<count {
      doc += pieces[Int(rng.next() % UInt64(pieces.count))]
    }
    return doc
  }

  /// Parser using the frozen copies of the original inline transformers.
  static let legacyParser = MarkdownParser(inlineTransformers: [DelimiterTransformer.self,
                                                                LegacyCodeLinkHtmlTransformer.self,
                                                                LegacyLinkTransformer.self,
                                                                LegacyEmphasisTransformer.self,
                                                                EscapeTransformer.self])

  private func compareParsers(seed: UInt64, count: Int,
                              file: StaticString = #filePath, line: UInt = #line) {
    var rng = SeededGenerator(seed: seed)
    var failures = 0
    for i in 0..<count {
      let doc = DifferentialTests.randomDocument(&rng)
      let expected = DifferentialTests.legacyParser.parse(doc)
      let actual = MarkdownParser.standard.parse(doc)
      if expected != actual {
        XCTFail("document #\(i) (seed \(seed)) differs: \(doc.debugDescription)\n" +
                "legacy: \(expected)\ncurrent: \(actual)", file: file, line: line)
        failures += 1
        if failures >= 3 {
          return
        }
      } else if HtmlGenerator().generate(doc: expected) != HtmlGenerator().generate(doc: actual) {
        XCTFail("HTML of document #\(i) (seed \(seed)) differs: \(doc.debugDescription)",
                file: file, line: line)
        return
      }
    }
  }

  func testInlineTransformersMatchLegacyImplementations() {
    compareParsers(seed: 1, count: 3000)
    compareParsers(seed: 2, count: 3000)
  }

  func testInlineTransformersMatchLegacyImplementationsOnLongInput() {
    var rng = SeededGenerator(seed: 3)
    for i in 0..<60 {
      var doc = DifferentialTests.headers[i % DifferentialTests.headers.count]
      for _ in 0..<400 {
        doc += DifferentialTests.pieces[Int(rng.next() % UInt64(DifferentialTests.pieces.count))]
      }
      XCTAssertEqual(MarkdownParser.standard.parse(doc),
                     DifferentialTests.legacyParser.parse(doc),
                     "long document #\(i): \(doc.debugDescription)")
    }
  }

  /// Compares both parsers on random documents made of the given pieces.
  private func compareParsers(pieces: [String], seed: UInt64, count: Int, maxPieces: Int,
                              headers: [String] = [""],
                              file: StaticString = #filePath, line: UInt = #line) {
    var rng = SeededGenerator(seed: seed)
    var failures = 0
    for i in 0..<count {
      var doc = headers[Int(rng.next() % UInt64(headers.count))]
      let n = 1 + Int(rng.next() % UInt64(maxPieces))
      for _ in 0..<n {
        doc += pieces[Int(rng.next() % UInt64(pieces.count))]
      }
      let expected = DifferentialTests.legacyParser.parse(doc)
      let actual = MarkdownParser.standard.parse(doc)
      if expected != actual {
        XCTFail("document #\(i) (seed \(seed)) differs: \(doc.debugDescription)\n" +
                "legacy: \(expected)\ncurrent: \(actual)", file: file, line: line)
        failures += 1
        if failures >= 3 {
          return
        }
      }
    }
  }

  func testEmphasisMatchesLegacyImplementation() {
    let pieces = ["*", "**", "***", "****", "_", "__", "___", "a", "b", "ab", " ", " ", "\n", "(",
                  ")", ".", "!", "`a`", "[a]", "\\*", "<b>"]
    compareParsers(pieces: pieces, seed: 11, count: 12000, maxPieces: 24)
    compareParsers(pieces: pieces, seed: 12, count: 1500, maxPieces: 200)
  }

  func testLinksMatchLegacyImplementation() {
    let pieces = ["[", "]", "![", "(", ")", "[foo]", "[bar]", "[]", "(/u)", "(/u \"t\")", "(<a b>)", " ",
                  "a", "*", "_", "<", ">", "`", "\"", "'", "\\", "\n", "[foo][]", "[a][foo]"]
    let headers = ["", "[foo]: /u \"t\"\n\n", "[foo]: /u\n[bar]: <b c> 'x'\n[a b]: /d\n\n"]
    compareParsers(pieces: pieces, seed: 21, count: 12000, maxPieces: 24, headers: headers)
    compareParsers(pieces: pieces, seed: 22, count: 1500, maxPieces: 200, headers: headers)
  }

  func testCodeSpansAndInlineHtmlMatchLegacyImplementation() {
    let pieces = ["`", "``", "```", "<", ">", "<a>", "</a>", "<a ", "href=\"x\"", "\"", "'", "a", "b",
                  " ", "\n", "!", "?", "<!--", "-->", "--", "<?", "?>", "<![CDATA[", "]]>", "<!", "/",
                  "=", "http://x.y", "<http://x.y>", "<a@b.c>", "@", "*", "[", "]", "\\", "&amp;"]
    compareParsers(pieces: pieces, seed: 31, count: 12000, maxPieces: 24)
    compareParsers(pieces: pieces, seed: 32, count: 1500, maxPieces: 200)
  }

  /// Compares transformers on texts which are built directly from fragments, including kinds
  /// of fragments which the default parser does not feed into these transformers (code spans,
  /// html, nested emphasis, ...).
  func testTransformersMatchLegacyImplementationsOnArbitraryFragments() {
    let pieces: [TextFragment] = [
      .text("a"), .text(" "), .text("b c"), .text("(/u)"), .text("foo"),
      .delimiter("`", 1, []), .delimiter("`", 2, []), .delimiter("`", 1, .escaped),
      .delimiter("<", 1, []), .delimiter(">", 1, []), .delimiter("\"", 1, []),
      .delimiter("[", 1, []), .delimiter("]", 1, []), .delimiter("[", 1, .image),
      .delimiter("(", 1, []), .delimiter(")", 1, []),
      .delimiter("*", 1, [.leftFlanking]), .delimiter("*", 2, [.rightFlanking]),
      .delimiter("*", 1, [.leftFlanking, .rightFlanking]), .delimiter("_", 1, [.leftFlanking]),
      .delimiter("_", 3, [.rightFlanking]),
      .softLineBreak, .hardLineBreak,
      .code("c"), .html("b"), .autolink(.uri, "http://u"), .emph(Text(.text("x"))),
      .strong(Text(.text("y"))), .link(Text(.text("l")), "/u", nil)
    ]
    let parser = InlineParser(inlineTransformers: [], input: .document([]))
    let current: [(String, InlineTransformer, InlineTransformer)] = [
      ("code/html", CodeLinkHtmlTransformer(owner: parser), LegacyCodeLinkHtmlTransformer(owner: parser)),
      ("links", LinkTransformer(owner: parser), LegacyLinkTransformer(owner: parser)),
      ("emphasis", EmphasisTransformer(owner: parser), LegacyEmphasisTransformer(owner: parser))
    ]
    var rng = SeededGenerator(seed: 41)
    for i in 0..<20000 {
      var text = Text()
      for _ in 0..<(1 + Int(rng.next() % 16)) {
        text.append(fragment: pieces[Int(rng.next() % UInt64(pieces.count))])
      }
      for (name, new, old) in current {
        let expected = old.transform(text)
        let actual = new.transform(text)
        if expected != actual {
          XCTFail("\(name) differs for text #\(i): \(text.debugDescription)\n" +
                  "legacy: \(expected.debugDescription)\ncurrent: \(actual.debugDescription)")
          return
        }
      }
    }
  }

  // MARK: Entities

  private static let entityAlphabet: [Character] = ["&", ";", "#", "x", "X", "a", "m", "p", "l",
                                                    "t", "g", "1", "2", "3", "5", "9", "A", "F",
                                                    " ", "é", "😀", "\"", "'", "<", ">", "\n"]

  private func randomEntityString(_ rng: inout SeededGenerator, maxLength: Int) -> String {
    var res = ""
    let n = Int(rng.next() % UInt64(maxLength + 1))
    for _ in 0..<n {
      res.append(DifferentialTests.entityAlphabet[
                   Int(rng.next() % UInt64(DifferentialTests.entityAlphabet.count))])
    }
    return res
  }

  func testEntityHelpersMatchLegacyImplementations() {
    var rng = SeededGenerator(seed: 4)
    for i in 0..<20000 {
      let str = randomEntityString(&rng, maxLength: i % 10 == 0 ? 120 : 24)
      XCTAssertEqual(str.decodingNamedCharacters(), str.legacyDecodingNamedCharacters(),
                     "decoding \(str.debugDescription)")
      XCTAssertEqual(str.encodingPredefinedXmlEntities(),
                     str.legacyEncodingPredefinedXmlEntities(),
                     "encoding \(str.debugDescription)")
    }
  }

  func testEntityHelpersMatchLegacyImplementationsForAllEntities() {
    for (name, _) in NamedCharacters.namedCharacterMap {
      for str in [name, "x" + name + "y", "&" + name, name + "&", name + name,
                  String(name.dropLast()), String(name.dropFirst())] {
        XCTAssertEqual(str.decodingNamedCharacters(), str.legacyDecodingNamedCharacters(), str)
      }
    }
    // Numeric references, including boundaries of the digit limits
    for str in ["&#0;", "&#1;", "&#35;", "&#1114111;", "&#1114112;", "&#12345678;", "&#x10FFFF;",
                "&#x110000;", "&#xD800;", "&#x1F600;", "&#X41;", "&#+65;", "&#-1;", "&#;", "&#x;",
                "&#1234567;", "&#xFFFFFF;", "&#xFFFFFFF;", "a&#35;b&#x23;c", "&&amp;;", "&amp"] {
      XCTAssertEqual(str.decodingNamedCharacters(), str.legacyDecodingNamedCharacters(), str)
    }
    // Candidates around the lookahead limit of an optimized implementation
    for length in 1...80 {
      let candidate = "&" + String(repeating: "a", count: length) + ";"
      XCTAssertEqual(candidate.decodingNamedCharacters(),
                     candidate.legacyDecodingNamedCharacters(), candidate)
      XCTAssertEqual(("x" + candidate + "&amp; y").decodingNamedCharacters(),
                     ("x" + candidate + "&amp; y").legacyDecodingNamedCharacters(), candidate)
    }
  }
}

extension String {

  fileprivate static let legacyPredefinedEntities: CharacterSet = {
    var set = CharacterSet()
    set.insert(charactersIn: "\"&'<>")
    return set
  }()

  func legacyEncodingPredefinedXmlEntities() -> String {
    var res = ""
    var pos = self.startIndex
    // find the first character that requires encoding
    while pos < self.endIndex,
          let index = self.rangeOfCharacter(from: String.legacyPredefinedEntities,
                                            range: pos..<self.endIndex) {
      // append the range of unproblematic characters
      res.append(contentsOf: self[pos..<index.lowerBound])
      // encode the character
      switch self[index.lowerBound] {
        case "\"":
          res.append(contentsOf: "&quot;")
        case "&":
          res.append(contentsOf: "&amp;")
        case "'":
          res.append(contentsOf: "&#39;")
        case "<":
          res.append(contentsOf: "&lt;")
        case ">":
          res.append(contentsOf: "&gt;")
        default:
          res.append(self[index.lowerBound])
      }
      pos = self.index(after: index.lowerBound)
    }
    if res.isEmpty {
      return self
    } else {
      res.append(contentsOf: self[pos..<self.endIndex])
      return res
    }
  }
  
  func legacyEncodingNamedCharacters() -> String {
    var res = ""
    for ch in self {
      if let charRef = NamedCharacters.characterNameMap[ch] {
        res.append(contentsOf: charRef)
      } else {
        res.append(ch)
      }
    }
    return res
  }
  
  func legacyDecodingNamedCharacters() -> String {
    var res = ""
    var pos = self.startIndex
    // find the next `&`
    while let ampPos = self.range(of: "&", range: pos..<self.endIndex) {
      res.append(contentsOf: self[pos..<ampPos.lowerBound])
      pos = ampPos.lowerBound
      // find the next ';'
      if let semiPos = self.range(of: ";", range: pos..<self.endIndex) {
        if let nextAmpPos = self.range(of: "&", range: self.index(after: pos)..<self.endIndex),
           nextAmpPos.upperBound < semiPos.upperBound {
          res.append("&")
          pos = self.index(after: ampPos.lowerBound)
        } else {
          let charRef = String(self[pos..<semiPos.upperBound])
          if let decoded = NamedCharacters.decode(entity: charRef) {
            res.append(decoded)
          } else {
            res.append(charRef)
          }
          pos = semiPos.upperBound
        }
      // no more ';'
      } else {
        break
      }
    }
    if res.isEmpty {
      return self
    } else {
      res.append(contentsOf: self[pos..<self.endIndex])
      return res
    }
  }
}

// MARK: - Frozen copies of the original inline transformers

class LegacyEmphasisTransformer: InlineTransformer {

  /// Plugin specifying the type of emphasis. `ch` refers to the emphasis character,
  /// `special` to whether the charater is used for other use cases (e.g. "*" and "-" should
  /// be marked as "special"), and `factory` to a closure constructing the text fragment
  /// from two parameters: the first denoting whether it's double usage, and the second
  /// referring to the emphasized text.
  public struct Emphasis {
    public let ch: Character
    public let special: Bool
    public let factory: (Bool, Text) -> TextFragment
    
    public init(ch: Character, special: Bool, factory: @escaping (Bool, Text) -> TextFragment) {
      self.ch = ch
      self.special = special
      self.factory = factory
    }
  }
  
  /// Emphasis supported by default. Override this property to change what is supported.
  open class var supportedEmphasis: [Emphasis] {
    let factory = { (double: Bool, text: Text) -> TextFragment in
      double ? .strong(text) : .emph(text)
    }
    return [Emphasis(ch: "*", special: true, factory: factory),
            Emphasis(ch: "_", special: false, factory: factory)]
  }
  
  /// The emphasis map, used internally to determine how characters are used for emphasis
  /// markup.
  private var emphasis: [Character : Emphasis] = [:]

  required public init(owner: InlineParser) {
    super.init(owner: owner)
    for emph in type(of: self).supportedEmphasis {
      self.emphasis[emph.ch] = emph
    }
  }

  private struct Delimiter: CustomStringConvertible {
    let ch: Character
    let special: Bool
    let runType: DelimiterRunType
    var count: Int
    var index: Int

    init(_ ch: Character, _ special: Bool, _ rtype: DelimiterRunType, _ count: Int, _ index: Int) {
      self.ch = ch
      self.special = special
      self.runType = rtype
      self.count = count
      self.index = index
    }

    var isOpener: Bool {
      return self.runType.contains(.leftFlanking) &&
             (self.special ||
              !self.runType.contains(.rightFlanking) ||
              self.runType.contains(.leftPunctuation))
    }

    var isCloser: Bool {
      return self.runType.contains(.rightFlanking) &&
             (self.special ||
              !self.runType.contains(.leftFlanking) ||
              self.runType.contains(.rightPunctuation))
    }

    var countMultipleOf3: Bool {
      return self.count % 3 == 0
    }

    func isOpener(for ch: Character) -> Bool {
      return self.ch == ch && self.isOpener
    }

    func isCloser(for ch: Character) -> Bool {
      return self.ch == ch && self.isCloser
    }

    var description: String {
      return "Delimiter(\(self.ch), \(self.special), \(self.runType), \(self.count), \(self.index))"
    }
  }

  private typealias DelimiterStack = [Delimiter]

  public override func transform(_ text: Text) -> Text {
    // Compute delimiter stack
    var res: Text = Text()
    var iterator = text.makeIterator()
    var element = iterator.next()
    var delimiters = DelimiterStack()
    while let fragment = element {
      switch fragment {
        case .delimiter(let ch, let n, let type):
          delimiters.append(Delimiter(ch, self.emphasis[ch]?.special ?? false, type, n, res.count))
          res.append(fragment: fragment)
          element = iterator.next()
        default:
          element = self.transform(fragment, from: &iterator, into: &res)
      }
    }
    self.processEmphasis(&res, &delimiters)
    return res
  }

  private func isSupportedEmphasisCloser(_ delimiter: Delimiter) -> Bool {
    for ch in self.emphasis.keys {
      if delimiter.isCloser(for: ch) {
        return true
      }
    }
    return false
  }

  private func processEmphasis(_ res: inout Text, _ delimiters: inout DelimiterStack) {
    var currentPos = 0
    loop: while currentPos < delimiters.count {
      var potentialCloser = delimiters[currentPos]
      if self.isSupportedEmphasisCloser(potentialCloser) {
        var i = currentPos - 1
        while i >= 0 {
          var potentialOpener = delimiters[i]
          if potentialOpener.isOpener(for: potentialCloser.ch) &&
             ((!potentialCloser.isOpener && !potentialOpener.isCloser) ||
              (potentialCloser.countMultipleOf3 && potentialOpener.countMultipleOf3) ||
              ((potentialOpener.count + potentialCloser.count) % 3 != 0)) {
            // Deduct counts
            let delta = potentialOpener.count > 1 && potentialCloser.count > 1 ? 2 : 1
            delimiters[i].count -= delta
            delimiters[currentPos].count -= delta
            potentialOpener = delimiters[i]
            potentialCloser = delimiters[currentPos]
            // Collect fragments
            var nestedText = Text()
            for fragment in res[potentialOpener.index+1..<potentialCloser.index] {
              nestedText.append(fragment: fragment)
            }
            // Replace existing fragments
            var range = [TextFragment]()
            if potentialOpener.count > 0 {
              range.append(.delimiter(potentialOpener.ch,
                                      potentialOpener.count,
                                      potentialOpener.runType))
            }
            if let factory = self.emphasis[potentialOpener.ch]?.factory {
              range.append(factory(delta > 1, nestedText))
            } else {
              for fragment in nestedText {
                range.append(fragment)
              }
            }
            if potentialCloser.count > 0 {
              range.append(.delimiter(potentialCloser.ch,
                                      potentialCloser.count,
                                      potentialCloser.runType))
            }
            let shift = range.count - potentialCloser.index + potentialOpener.index - 1
            res.replace(from: potentialOpener.index, to: potentialCloser.index, with: range)
            // Update delimiter stack
            if potentialCloser.count == 0 {
              delimiters.remove(at: currentPos)
            }
            if potentialOpener.count == 0 {
              delimiters.remove(at: i)
              currentPos -= 1
            } else {
              i += 1
            }
            var j = i
            while j < currentPos {
              delimiters.remove(at: i)
              j += 1
            }
            currentPos = i
            while i < delimiters.count {
              delimiters[i].index += shift
              i += 1
            }
            continue loop
          }
          i -= 1
        }
        if !potentialCloser.isOpener {
          delimiters.remove(at: currentPos)
          continue loop
        }
      }
      currentPos += 1
    }
  }
}

class LegacyLinkTransformer: InlineTransformer {

  public override func transform(_ text: Text) -> Text {
    var res = Text()
    var iterator = text.makeIterator()
    var element = iterator.next()
    loop: while let fragment = element {
      if case .delimiter("[", _, let type) = fragment {
        var scanner = iterator
        var next = scanner.next()
        var open = 0
        var inner = Text()
        scan: while let lookahead = next {
          switch lookahead {
            case .delimiter("]", _, _):
              if open == 0 {
                let afterBracket = scanner
                var transformed: Text? = nil
                if let link = self.complete(link: type.isEmpty,
                                            inner,
                                            with: &scanner,
                                            transformed: &transformed) {
                  res.append(fragment: link)
                  iterator = scanner
                  element = iterator.next()
                  continue loop
                }
                if let transformed {
                  // `complete` already transformed the text between the brackets before it
                  // gave up. Since the brackets inside of it are balanced, this is the same
                  // result as processing these fragments one by one. Reusing it avoids
                  // transforming nested brackets repeatedly (which is exponential for nested
                  // links).
                  res.append(fragment: fragment)
                  for transformedFragment in transformed {
                    res.append(fragment: transformedFragment)
                  }
                  res.append(fragment: lookahead)
                  iterator = afterBracket
                  element = iterator.next()
                  continue loop
                }
                break scan
              }
              open -= 1
            case .delimiter("[", _, _):
              open += 1
            default:
              break
          }
          // if type.isEmpty {
            inner.append(fragment: lookahead)
            next = scanner.next()
          // } else {
          //  next = self.transform(lookahead, from: &scanner, into: &inner)
          // }
        }
        res.append(fragment: fragment)
        element = iterator.next()
      } else {
        element = self.transform(fragment, from: &iterator, into: &res)
      }
    }
    return res
  }

  /// Tries to complete a link or image for the given description `text`. If the description
  /// gets transformed in the process, the result is also stored in `transformed`; this is
  /// also the case if no link or image could be completed.
  private func complete(link: Bool,
                        _ text: Text,
                        with iterator: inout Text.Iterator,
                        transformed: inout Text?) -> TextFragment? {
    let initial = iterator
    // Inline links and full/collapsed references; they need a following fragment
    if let element = iterator.next() {
      switch element {
        case .delimiter("(", _, _):
          if let res = self.completeInline(link: link,
                                           text,
                                           with: &iterator,
                                           transformed: &transformed) {
            return res
          }
        case .delimiter("[", _, _):
          var undefinedLabel = false
          if let res = self.completeRef(link: link,
                                        text,
                                        with: &iterator,
                                        transformed: &transformed,
                                        undefinedLabel: &undefinedLabel) {
            return res
          }
          // A shortcut reference must not be followed by a link label
          if undefinedLabel {
            return nil
          }
        default:
          break
      }
    }
    // Shortcut references; they are also valid at the very end of the text
    let label = normalizeLinkLabel(text.description)
    if label.count < 1000,
       let (uri, title) = self.owner.linkRefDef[label] {
      let text = transformed ?? self.transform(text)
      transformed = text
      if link && self.containsLink(text) {
        return nil
      }
      iterator = initial
      return link ? .link(text, uri, title) : .image(text, uri, title)
    } else {
      return nil
    }
  }

  private func completeInline(link: Bool,
                              _ text: Text,
                              with iterator: inout Text.Iterator,
                              transformed: inout Text?) -> TextFragment? {
    // Skip whitespace
    var element = self.skipWhitespace(for: &iterator)
    guard let dest = element else {
      return nil
    }
    // Transform link description
    let text = transformed ?? self.transform(text)
    transformed = text
    if link && self.containsLink(text) {
      return nil
    }
    // Parse destination
    var destination = ""
    // Is the destination followed by whitespace (as needed for a title)?
    var whitespaceAfterDestination = false
    choose: switch dest {
      // Is this a link destination surrounded by `<` and `>`
      case .delimiter("<", _, _):
        element = iterator.next()
        loop: while let fragment = element {
          switch fragment {
            case .delimiter(">", _, _):
              break loop
            case .delimiter("<", _, _):
              return nil
            case .hardLineBreak, .softLineBreak:
              return nil
            default:
              destination += fragment.rawDescription
          }
          element = iterator.next()
        }
      case .html(let str):
        if str.contains("\n") {
          return nil
        }
        destination += str
      case .autolink(_, let str):
        if str.contains("\n") {
          return nil
        }
        destination += str
      // Parsing regular destinations
      default:
        var open = 0
        if case .some(.text(let str)) = element,
           let index = str.firstIndex(where: { ch in !isAsciiWhitespaceOrControl(ch) }),
           index < str.endIndex {
          destination += str[index..<str.endIndex]
          if let lastIndex = destination.firstIndex(where: isAsciiWhitespaceOrControl) {
            guard isWhitespaceString(destination[lastIndex..<destination.endIndex]) else {
              return nil
            }
            destination = String(destination[destination.startIndex..<lastIndex])
            whitespaceAfterDestination = true
            break choose
          }
          element = iterator.next()
        }
        loop: while let fragment = element {
          switch fragment {
            case .delimiter("(", _, _):
              open += 1
            case .delimiter(")", _, _):
              open -= 1
              if open < 0 {
                return link ? .link(text, destination.isEmpty ? nil : destination, nil)
                            : .image(text, destination.isEmpty ? nil : destination, nil)
              }
            case .text(let str):
              if let index = str.firstIndex(where: isAsciiWhitespaceOrControl) {
                guard isWhitespaceString(str[index..<str.endIndex]) else {
                  return nil
                }
                destination += str[str.startIndex..<index]
                whitespaceAfterDestination = true
                break loop
              }
            case .hardLineBreak, .softLineBreak:
              whitespaceAfterDestination = true
              break loop
            default:
              break
          }
          destination += fragment.rawDescription
          element = iterator.next()
      }
    }
    if element == nil {
      return nil
    }
    // Parse title
    guard let fragment = self.skipWhitespace(for: &iterator,
                                             skipped: &whitespaceAfterDestination) else {
      return nil
    }
    var optTitle: String?
    switch fragment {
      case .delimiter("\"", _, _):
        guard whitespaceAfterDestination else {
          return nil
        }
        optTitle = self.completeTitle("\"", for: &iterator)
      case .delimiter("'", _, _):
        guard whitespaceAfterDestination else {
          return nil
        }
        optTitle = self.completeTitle("'", for: &iterator)
      case .delimiter("(", _, _):
        guard whitespaceAfterDestination else {
          return nil
        }
        optTitle = self.completeTitle(")", for: &iterator)
      case .delimiter(")", _, _):
        return link ? .link(text, destination.isEmpty ? nil : destination, nil)
                    : .image(text, destination.isEmpty ? nil : destination, nil)
      default:
        return nil
    }
    guard let title = optTitle else {
      return nil
    }
    // Expect `)` character
    element = self.skipWhitespace(for: &iterator)
    guard case .some(.delimiter(")", _, _)) = element else {
      return nil
    }
    return link ? .link(text, destination.isEmpty ? nil : destination, title.isEmpty ? nil : title)
                : .image(text, destination.isEmpty ? nil : destination, title.isEmpty ? nil : title)
  }

  private func completeTitle(_ ch: Character, for iterator: inout Text.Iterator) -> String? {
    var element = iterator.next()
    var title = ""
    while let fragment = element {
      switch fragment {
        case .delimiter(ch, _, _):
          return title
        default:
          title += fragment.description
      }
      element = iterator.next()
    }
    return nil
  }

  private func skipWhitespace(for iterator: inout Text.Iterator) -> TextFragment? {
    var skipped = false
    return self.skipWhitespace(for: &iterator, skipped: &skipped)
  }

  /// Skips whitespace fragments and returns the next fragment. `skipped` is set to true if
  /// any whitespace was skipped.
  private func skipWhitespace(for iterator: inout Text.Iterator,
                              skipped: inout Bool) -> TextFragment? {
    var element = iterator.next()
    while let fragment = element {
      switch fragment {
        case .hardLineBreak, .softLineBreak:
          skipped = true
        case .text(let str) where isWhitespaceString(str):
          skipped = true
        default:
          return element
      }
      element = iterator.next()
    }
    return nil
  }

  private func containsLink(_ text: Text) -> Bool {
    for fragment in text {
      switch fragment {
        case .emph(let inner):
          if self.containsLink(inner) {
            return true
          }
        case .strong(let inner):
          if self.containsLink(inner) {
            return true
          }
        case .link(_, _, _):
          return true
        case .autolink(_, _):
          return true
        case .image(let inner, _, _):
          if self.containsLink(inner) {
            return true
          }
        default:
          break
      }
    }
    return false
  }

  private func completeRef(link: Bool,
                           _ text: Text,
                           with iterator: inout Text.Iterator,
                           transformed: inout Text?,
                           undefinedLabel: inout Bool) -> TextFragment? {
    // Skip whitespace
    var element = self.skipWhitespace(for: &iterator)
    // Transform link description
    let text = transformed ?? self.transform(text)
    transformed = text
    if link && self.containsLink(text) {
      return nil
    }
    // Parse label
    var label = ""
    while let fragment = element {
      switch fragment {
        case .delimiter("]", _, _):
          // A collapsed reference (`[foo][]`) uses the link text as its label
          label = normalizeLinkLabel(label.isEmpty ? text.description : label)
          if let (uri, title) = self.owner.linkRefDef[label] {
            return link ? .link(text, uri, title) : .image(text, uri, title)
          } else {
            undefinedLabel = true
            return nil
          }
        case .softLineBreak, .hardLineBreak:
          label.append(" ")
        default:
          let components = fragment.description.components(separatedBy: .whitespaces)
          label.append(components.filter { !$0.isEmpty }.joined(separator: " "))
          if label.count > 999 {
            return nil
          }
      }
      element = iterator.next()
    }
    return nil
  }
}

class LegacyCodeLinkHtmlTransformer: InlineTransformer {
  
  public override func transform(_ text: Text) -> Text {
    var res: Text = Text()
    var iterator = text.makeIterator()
    var element = iterator.next()
    loop: while let fragment = element {
      switch fragment {
        case .delimiter("`", let n, []):
          var scanner = iterator
          var next = scanner.next()
          var count = 0
          while let lookahead = next {
            count += 1
            switch lookahead {
              case .delimiter("`", n, _):
                var scanner2 = iterator
                var code = ""
                for _ in 1..<count {
                  code += scanner2.next()?.rawDescription ?? ""
                }
                // If the content both starts and ends with a space, but does not consist
                // only of spaces, one space is removed on each side.
                if code.count >= 2 && code.first == " " && code.last == " " &&
                   code.contains(where: { $0 != " " }) {
                  code = String(code.dropFirst().dropLast())
                }
                res.append(fragment: .code(Substring(code)))
                iterator = scanner
                element = iterator.next()
                continue loop
              case .delimiter(_, _, _), .text(_), .softLineBreak, .hardLineBreak:
                next = scanner.next()
              default:
                res.append(fragment: fragment)
                element = iterator.next()
                continue loop
            }
          }
          res.append(fragment: fragment)
          element = iterator.next()
        case .delimiter("<", let n, []):
          var scanner = iterator
          var next = scanner.next()
          var count = 0
          while let lookahead = next {
            count += 1
            switch lookahead {
              case .delimiter(">", n, _):
                var scanner2 = iterator
                var content = ""
                for _ in 1..<count {
                  content += scanner2.next()?.rawDescription ?? ""
                }
                if isURI(content) {
                  res.append(fragment: .autolink(.uri, Substring(content)))
                  iterator = scanner
                  element = iterator.next()
                  continue loop
                } else if isEmailAddress(content) {
                  res.append(fragment: .autolink(.email, Substring(content)))
                  iterator = scanner
                  element = iterator.next()
                  continue loop
                } else if isHtmlTag(content) {
                  res.append(fragment: .html(Substring(content)))
                  iterator = scanner
                  element = iterator.next()
                  continue loop
                }
                next = scanner.next()
              case .delimiter(_, _, _), .text(_), .softLineBreak, .hardLineBreak:
                next = scanner.next()
              default:
                res.append(fragment: fragment)
                element = iterator.next()
                continue loop
            }
          }
          res.append(fragment: fragment)
          element = iterator.next()
        default:
          element = self.transform(fragment, from: &iterator, into: &res)
      }
    }
    return res
  }
}
