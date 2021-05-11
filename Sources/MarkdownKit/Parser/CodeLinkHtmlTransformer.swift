//
//  CodeLinkHtmlTransformer.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 09/06/2019.
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
/// An inline transformer which extracts code spans, auto-links and html tags and transforms
/// them into `code`, `autolinks`, and `html` text fragments.
///
open class CodeLinkHtmlTransformer: InlineTransformer {
  
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
