//
//  ExtendedDocumentParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 19/07/2020.
//  Copyright © 2020 Google LLC.
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
/// A `DocumentParser` implements Markdown block parsing for a list of `BlockParsers` and
/// and an input string. `DocumentParser` objects are stateful and can be used for parsing
/// only a single document/string in Markdown format.
///
open class ExtendedDocumentParser: DocumentParser {
  
  /// Normalizes a given array of `Block` objects and returns it in a `Blocks` object.
  open override func bundle(blocks: [Block]) -> Blocks {
    // First, bundle lists as previously
    let bundled = super.bundle(blocks: blocks)
    if bundled.count < 2 {
      return bundled
    }
    // Next, bundle lists of descriptions with their corresponding items into definition lists
    var res: Blocks = []
    var definitions: Definitions = []
    var i = 1
    while i < bundled.count {
      guard case .paragraph(let text) = bundled[i - 1],
            case .list(_, _, let listItems) = bundled[i],
            case .some(.listItem(.bullet(":"), _, _)) = listItems.first else {
        if definitions.count > 0 {
          res.append(.definitionList(definitions))
          definitions.removeAll()
        }
        res.append(bundled[i - 1])
        i += 1
        continue
      }
      definitions.append(Definition(item: text, descriptions: listItems))
      i += 2
    }
    if definitions.count > 0 {
      res.append(.definitionList(definitions))
      definitions.removeAll()
    }
    if i < bundled.count + 1 {
      res.append(bundled[i - 1])
    }
    return res
  }
}
