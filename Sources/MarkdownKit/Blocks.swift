//
//  Blocks.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 11/05/2019.
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
/// A normalized sequence of blocks, represented as an array.
///
public typealias Blocks = ContiguousArray<Block>

extension Blocks {

  /// Returns the text of a singleton `Blocks` object. A singleton `Blocks` object contains a
  /// single paragraph. This property returns `nil` if this object is not a singleton `Blocks`
  /// object.
  public var text: Text? {
    if self.count == 1,
       case .paragraph(let text) = self[0] {
      return text
    } else {
      return nil
    }
  }

  /// Returns true if this is a singleton `Blocks` object.
  public var isSingleton: Bool {
    return self.count == 1
  }

  /// Normalizes a given array of `Block` objects and returns it in a `Blocks` object.
  public static func bundle(_ blocks: [Block]) -> Blocks {
    var res: Blocks = []
    var items: Blocks = []
    var listType: ListType? = nil
    var tight: Bool = true
    for block in blocks {
      switch block {
        case .listItem(let type, let t, let nested):
          if let ltype = listType {
            if type.compatible(with: ltype) {
              items.append(block)
              if !t || !nested.isSingleton {
                tight = false
              }
            } else {
              res.append(.list(ltype.startNumber, tight, items))
              items.removeAll()
              tight = nested.isSingleton
              listType = type
              items.append(block)
            }
          } else {
            listType = type
            items.append(block)
            if !nested.isSingleton {
              tight = false
            }
          }
        default:
          if let ltype = listType {
            res.append(.list(ltype.startNumber, tight, items))
            items.removeAll()
            tight = true
            listType = nil
          }
          res.append(block)
      }
    }
    if let ltype = listType {
      res.append(.list(ltype.startNumber, tight, items))
      items.removeAll()
      tight = true
      listType = nil
    }
    return res
  }
}
