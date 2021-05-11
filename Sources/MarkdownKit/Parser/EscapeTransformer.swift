//
//  EscapeTransformer.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 18/10/2019.
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
/// An inline transformer which removes backslash escapes.
///
open class EscapeTransformer: InlineTransformer {

  public override func transform(_ fragment: TextFragment,
                                 from iterator: inout Text.Iterator,
                                 into res: inout Text) -> TextFragment? {
    switch fragment {
      case .text(let str):
        res.append(fragment: .text(self.resolveEscapes(str)))
      case .link(let inner, let uri, let title):
        res.append(fragment: .link(self.transform(inner), uri, self.resolveEscapes(title)))
      case .image(let inner, let uri, let title):
        res.append(fragment: .image(self.transform(inner), uri, self.resolveEscapes(title)))
      default:
        return super.transform(fragment, from: &iterator, into: &res)
    }
    return iterator.next()
  }

  private func resolveEscapes(_ str: String?) -> String? {
    if let str = str {
      return String(self.resolveEscapes(Substring(str)))
    } else {
      return nil
    }
  }

  private func resolveEscapes(_ str: Substring) -> Substring {
    guard !str.isEmpty else {
      return str
    }
    var res: String? = nil
    var i = str.startIndex
    while i < str.endIndex {
      if str[i] == "\\" {
        if res == nil {
          res = String(str[str.startIndex..<i])
        }
        i = str.index(after: i)
        guard i < str.endIndex else {
          break
        }
      }
      res?.append(str[i])
      i = str.index(after: i)
    }
    guard res == nil else {
      return Substring(res!)
    }
    return str
  }
}
