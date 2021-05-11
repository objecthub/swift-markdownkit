//
//  InlineParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 30/05/2019.
//  Copyright © 2019-2020 Google LLC.
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
/// An `InlineParser` implements Markdown inline text markup parsing given a list of
/// `InlineTransformer` classes as its configuration. `InlineParser` objects are not
/// stateful and can be reused to parse the inline text of many Markdown blocks.
///
open class InlineParser {

  /// Sequence of inline transformers which implement the inline parsing functionality.
  private var inlineTransformers: [InlineTransformer]

  /// Blocks of input document
  private let block: Block

  /// Link reference declarations
  public private(set) var linkRefDef: [String : (String, String?)]

  /// Initializer
  init(inlineTransformers: [InlineTransformer.Type], input: Block) {
    self.block = input
    self.linkRefDef = [:]
    self.inlineTransformers = []
    for transformerType in inlineTransformers {
      self.inlineTransformers.append(transformerType.init(owner: self))
    }
  }

  /// Traverses the input block and applies all inline transformers to all text.
  open func parse() -> Block {
    // First, collect all link reference definitions
    self.collectLinkRefDef(self.block)
    // Second, apply inline transformers
    return self.parse(self.block)
  }

  /// Traverses a Markdown block and enters link reference definitions into `linkRefDef`.
  public func collectLinkRefDef(_ block: Block) {
    switch block {
      case .document(let blocks):
        self.collectLinkRefDef(blocks)
      case .blockquote(let blocks):
        self.collectLinkRefDef(blocks)
      case .list(_, _, let blocks):
        self.collectLinkRefDef(blocks)
      case .listItem(_, _, let blocks):
        self.collectLinkRefDef(blocks)
      case .referenceDef(let label, let dest, let title):
        if title.isEmpty {
          let canonical = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
          self.linkRefDef[canonical] = (String(dest), nil)
        } else {
          var str = ""
          for line in title {
            str += line.description
          }
          self.linkRefDef[label] = (String(dest), str)
        }
      default:
        break
    }
  }

  /// Traverses an array of Markdown blocks and enters link reference definitions
  /// into `linkRefDef`.
  public func collectLinkRefDef(_ blocks: Blocks) {
    for block in blocks {
      self.collectLinkRefDef(block)
    }
  }

  /// Parses a Markdown block and returns a new block in which all inline text markup
  /// is represented using `TextFragment` objects.
  open func parse(_ block: Block) -> Block {
    switch block {
      case .document(let blocks):
        return .document(self.parse(blocks))
      case .blockquote(let blocks):
        return .blockquote(self.parse(blocks))
      case .list(let start, let tight, let blocks):
        return .list(start, tight, self.parse(blocks))
      case .listItem(let type, let tight, let blocks):
        return .listItem(type, tight, self.parse(blocks))
      case .paragraph(let lines):
        return .paragraph(self.transform(lines))
      case .thematicBreak:
        return .thematicBreak
      case .heading(let level, let lines):
        return .heading(level, self.transform(lines))
      case .indentedCode(let lines):
        return .indentedCode(lines)
      case .fencedCode(let info, let lines):
        return .fencedCode(info, lines)
      case .htmlBlock(let lines):
        return .htmlBlock(lines)
      case .referenceDef(let label, let dest, let title):
        return .referenceDef(label, dest, title)
      case .table(let header, let align, let rows):
        return .table(self.transform(header), align, self.transform(rows))
      case .definitionList(let defs):
        return .definitionList(self.transform(defs))
      case .custom(let customBlock):
        return customBlock.parse(via: self)
    }
  }

  /// Parses a sequence of Markdown blocks and returns a new sequence in which all inline
  /// text markup is represented using `TextFragment` objects.
  public func parse(_ blocks: Blocks) -> Blocks {
    var res: Blocks = []
    for block in blocks {
      res.append(self.parse(block))
    }
    return res
  }

  /// Transforms raw Markdown text and returns a new `Text` object in which all inline markup
  /// is represented using `TextFragment` objects.
  public func transform(_ text: Text) -> Text {
    var res = text
    for transformer in self.inlineTransformers {
      res = transformer.transform(res)
    }
    return res
  }
  
  /// Transforms raw Markdown rows and returns a new `Row` object in which all inline markup
  /// is represented using `TextFragment` objects.
  public func transform(_ row: Row) -> Row {
    var res = Row()
    for cell in row {
      res.append(self.transform(cell))
    }
    return res
  }
  
  /// Transforms raw Markdown tables and returns a new `Rows` object in which all inline markup
  /// is represented using `TextFragment` objects.
  public func transform(_ rows: Rows) -> Rows {
    var res = Rows()
    for row in rows {
      res.append(self.transform(row))
    }
    return res
  }
  
  public func transform(_ defs: Definitions) -> Definitions {
    var res = Definitions()
    for def in defs {
      res.append(Definition(item: self.transform(def.item),
                            descriptions: self.parse(def.descriptions)))
    }
    return res
  }
}
