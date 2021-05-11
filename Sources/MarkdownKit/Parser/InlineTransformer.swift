//
//  InlineTransformer.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 01/06/2019.
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
/// Class `InlineTransformer` defines a framework for plugins which transform a given
/// unstructured or semi-structured text with Markdown markup into a structured
/// representation which uses `TextFragment` objects. MarkdownKit implements a separate
/// inline transformer plugin for every class of supported inline markup.
///
open class InlineTransformer {

  public unowned let owner: InlineParser

  required public init(owner: InlineParser) {
    self.owner = owner
  }

  open func transform(_ text: Text) -> Text {
    var res: Text = Text()
    var iterator = text.makeIterator()
    var element = iterator.next()
    while let fragment = element {
      element = self.transform(fragment, from: &iterator, into: &res)
    }
    return res
  }

  open func transform(_ fragment: TextFragment,
                      from iterator: inout Text.Iterator,
                      into res: inout Text) -> TextFragment? {
    switch fragment {
      case .text(_):
        res.append(fragment: fragment)
      case .code(_):
        res.append(fragment: fragment)
      case .emph(let inner):
        res.append(fragment: .emph(self.transform(inner)))
      case .strong(let inner):
        res.append(fragment: .strong(self.transform(inner)))
      case .link(let inner, let uri, let title):
        res.append(fragment: .link(self.transform(inner), uri, title))
      case .autolink(_, _):
        res.append(fragment: fragment)
      case .image(let inner, let uri, let title):
        res.append(fragment: .image(self.transform(inner), uri, title))
      case .html(_):
        res.append(fragment: fragment)
      case .delimiter(_, _, _):
        res.append(fragment: fragment)
      case .softLineBreak, .hardLineBreak:
        res.append(fragment: fragment)
      case .custom(let customTextFragment):
        res.append(fragment: customTextFragment.transform(via: self))
    }
    return iterator.next()
  }
}
