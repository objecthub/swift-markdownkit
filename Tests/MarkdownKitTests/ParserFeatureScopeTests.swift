//
//  ParserFeatureScopeTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 10/10/2026.
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

/// Tests which pin down which Markdown features each of the standard parsers supports:
/// `MarkdownParser` implements CommonMark and nothing else, `ExtendedMarkdownParser` adds
/// tables and definition lists, and `FullMarkdownParser` supports all features of MarkdownKit.
/// A new feature needs a row in `Feature`, and a decision in which parser it is available.
final class ParserFeatureScopeTests: XCTestCase {

  /// The features which are not part of CommonMark
  private enum Feature: CaseIterable, CustomStringConvertible {
    case table
    case definitionList
    case underline
    case strikethrough
    case taskList

    /// Markdown which uses the feature
    var markdown: String {
      switch self {
        case .table:
          return "a | b\n--- | ---\nc | d"
        case .definitionList:
          return "Term\n: Definition"
        case .underline:
          return "Some ~under~ text"
        case .strikethrough:
          return "Some ~~gone~~ text"
        case .taskList:
          return "- [ ] todo\n- [x] done"
      }
    }

    /// Text of `markdown` which a parser without the feature leaves as it is
    var literal: String {
      switch self {
        case .table:
          return "--- | ---"
        case .definitionList:
          return ": Definition"
        case .underline:
          return "~under~"
        case .strikethrough:
          return "~~gone~~"
        case .taskList:
          return "[ ] todo"
      }
    }

    var description: String {
      switch self {
        case .table:
          return "table"
        case .definitionList:
          return "definition list"
        case .underline:
          return "underline"
        case .strikethrough:
          return "strikethrough"
        case .taskList:
          return "task list"
      }
    }

    /// Does `block` contain the syntax tree element for this feature?
    func isUsed(in block: Block) -> Bool {
      switch block {
        case .document(let blocks), .blockquote(let blocks), .list(_, _, let blocks):
          return blocks.contains { self.isUsed(in: $0) }
        case .listItem(let type, _, let blocks):
          return (self == .taskList && type.isTask) || blocks.contains { self.isUsed(in: $0) }
        case .paragraph(let text), .heading(_, let text):
          return self.isUsed(in: text)
        case .table(let header, _, let rows):
          return self == .table || header.contains { self.isUsed(in: $0) } ||
                 rows.contains { $0.contains { self.isUsed(in: $0) } }
        case .definitionList(let definitions):
          return self == .definitionList || definitions.contains { definition in
            self.isUsed(in: definition.item) ||
            definition.descriptions.contains { self.isUsed(in: $0) }
          }
        default:
          return false
      }
    }

    private func isUsed(in text: Text) -> Bool {
      return text.contains { fragment in
        switch fragment {
          case .underline(let inner):
            return self == .underline || self.isUsed(in: inner)
          case .strikethrough(let inner):
            return self == .strikethrough || self.isUsed(in: inner)
          case .emph(let inner), .strong(let inner), .link(let inner, _, _), .image(let inner, _, _):
            return self.isUsed(in: inner)
          default:
            return false
        }
      }
    }
  }

  private struct ParserScope {
    let name: String
    let parser: MarkdownParser
    let features: Set<Feature>
  }

  private static let scopes: [ParserScope] = [
    ParserScope(name: "MarkdownParser", parser: MarkdownParser.standard, features: []),
    ParserScope(name: "ExtendedMarkdownParser", parser: ExtendedMarkdownParser.standard,
                features: [.table, .definitionList]),
    ParserScope(name: "FullMarkdownParser", parser: FullMarkdownParser.standard,
                features: Set(Feature.allCases))
  ]

  func testEveryParserSupportsExactlyItsFeatures() {
    for scope in Self.scopes {
      for feature in Feature.allCases {
        let doc = scope.parser.parse(feature.markdown)
        let html = HtmlGenerator.standard.generate(doc: doc)
        if scope.features.contains(feature) {
          XCTAssertTrue(feature.isUsed(in: doc),
                        "\(scope.name) does not support \(feature): \(doc.debugDescription)")
          XCTAssertFalse(html.contains(feature.literal),
                         "\(scope.name) does not process \(feature): \(html)")
        } else {
          for other in Feature.allCases {
            XCTAssertFalse(other.isUsed(in: doc),
                           "\(scope.name) supports \(feature) (as \(other)): \(doc.debugDescription)")
          }
          XCTAssertTrue(html.contains(feature.literal),
                        "\(scope.name) changes the text of a \(feature): \(html)")
          XCTAssertFalse(html.contains("<table") || html.contains("<dl") ||
                         html.contains("<u>") || html.contains("<del>") ||
                         html.contains("<input"),
                         "\(scope.name) generates HTML for a \(feature): \(html)")
        }
      }
    }
  }

  private func types(_ parsers: [BlockParser.Type]) -> [ObjectIdentifier] {
    return parsers.map { ObjectIdentifier($0) }
  }

  private func types(_ transformers: [InlineTransformer.Type]) -> [ObjectIdentifier] {
    return transformers.map { ObjectIdentifier($0) }
  }

  private let commonMarkBlockParsers: [BlockParser.Type] = [
    AtxHeadingParser.self, SetextHeadingParser.self, ThematicBreakParser.self,
    IndentedCodeBlockParser.self, FencedCodeBlockParser.self, HtmlBlockParser.self,
    LinkRefDefinitionParser.self, BlockquoteParser.self, ListItemParser.self
  ]

  func testConfigurationOfTheBlockParsers() {
    // CommonMark only
    XCTAssertEqual(types(MarkdownParser.defaultBlockParsers), types(commonMarkBlockParsers))
    XCTAssertEqual(MarkdownParser.standard.documentParser(input: "").blockParsers.count, 9)
    // The extended parser replaces the list item parser and adds the table parser
    let extended: [BlockParser.Type] = Array(commonMarkBlockParsers.dropLast()) +
                                       [ExtendedListItemParser.self, TableParser.self]
    XCTAssertEqual(types(ExtendedMarkdownParser.defaultBlockParsers), types(extended))
    XCTAssertEqual(ExtendedMarkdownParser.standard.documentParser(input: "").blockParsers.count, 10)
    // The full parser has the block parsers of the extended parser
    XCTAssertEqual(types(FullMarkdownParser.defaultBlockParsers), types(extended))
    XCTAssertEqual(FullMarkdownParser.standard.documentParser(input: "").blockParsers.count, 10)
    // Document parsers
    XCTAssertTrue(type(of: MarkdownParser.standard.documentParser(input: "")) == DocumentParser.self)
    XCTAssertTrue(type(of: ExtendedMarkdownParser.standard.documentParser(input: ""))
                    == ExtendedDocumentParser.self)
    XCTAssertTrue(type(of: FullMarkdownParser.standard.documentParser(input: ""))
                    == ExtendedDocumentParser.self)
  }

  func testConfigurationOfTheInlineTransformers() {
    let commonMark: [InlineTransformer.Type] = [
      DelimiterTransformer.self, CodeLinkHtmlTransformer.self, LinkTransformer.self,
      EmphasisTransformer.self, EscapeTransformer.self
    ]
    XCTAssertEqual(types(MarkdownParser.defaultInlineTransformers), types(commonMark))
    XCTAssertEqual(types(ExtendedMarkdownParser.defaultInlineTransformers), types(commonMark))
    XCTAssertEqual(types(FullMarkdownParser.defaultInlineTransformers),
                   types([LineEmphasisDelimiterTransformer.self, CodeLinkHtmlTransformer.self,
                          LinkTransformer.self, LineEmphasisTransformer.self,
                          EscapeTransformer.self]))
    // The escape transformer is always the last one
    for scope in Self.scopes {
      XCTAssertTrue(type(of: scope.parser).defaultInlineTransformers.last == EscapeTransformer.self,
                    scope.name)
    }
  }

  func testInlineParsers() {
    // Only the full parser creates an inline parser which recognizes task list items
    XCTAssertTrue(type(of: MarkdownParser.standard.inlineParser(input: .document([]))) == InlineParser.self)
    XCTAssertTrue(type(of: ExtendedMarkdownParser.standard.inlineParser(input: .document([])))
                    == InlineParser.self)
    XCTAssertTrue(type(of: FullMarkdownParser.standard.inlineParser(input: .document([])))
                    == TaskListInlineParser.self)
  }

  func testAConfigurationReplacesTheListsOfParsersOnly() {
    // The configuration given to the initializer replaces the default lists of block parsers
    // and inline transformers, but not what the factory methods of the parser create
    let plain = FullMarkdownParser(inlineTransformers: [EscapeTransformer.self])
    XCTAssertEqual(HtmlGenerator.standard.generate(doc: plain.parse("~~a~~")), "<p>~~a~~</p>\n")
    XCTAssertEqual(HtmlGenerator.standard.generate(doc: plain.parse("- [x] a")),
                   "<ul>\n<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> a</li>\n</ul>\n")
    let onlyBlocks = MarkdownParser(blockParsers: [AtxHeadingParser.self])
    XCTAssertEqual(HtmlGenerator.standard.generate(doc: onlyBlocks.parse("# a\n- b")),
                   "<h1>a</h1>\n<p>- b</p>\n")
  }
}
