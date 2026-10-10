//
//  LineEmphasisTransformers.swift
//  MarkdownKit
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

import Foundation

///
/// An inline transformer which extracts delimiters like `DelimiterTransformer`, but also
/// treats the tilde `~` as an emphasis character. Runs of more than two tildes are not used
/// for emphasis (as in GitHub Flavored Markdown): they are plain text.
///
/// Use it together with `LineEmphasisTransformer`; see `FullMarkdownParser`.
///
open class LineEmphasisDelimiterTransformer: DelimiterTransformer {

  /// The emphasis characters of `DelimiterTransformer` and `~`.
  open override class var emphasisChars: [Character] {
    return super.emphasisChars + ["~"]
  }

  open override func transform(_ text: Text) -> Text {
    let result = super.transform(text)
    func isLongTildeRun(_ fragment: TextFragment) -> Bool {
      if case .delimiter("~", let n, _) = fragment {
        return n > 2
      }
      return false
    }
    guard result.contains(where: isLongTildeRun) else {
      return result
    }
    var converted = Text()
    for fragment in result {
      if case .delimiter(_, let n, _) = fragment, isLongTildeRun(fragment) {
        converted.append(fragment: .text(Substring(String(repeating: "~", count: n))))
      } else {
        converted.append(fragment: fragment)
      }
    }
    return converted
  }
}

///
/// An inline transformer which extracts emphasis markup like `EmphasisTransformer`, and also
/// supports underlined text (`~underlined~`, text fragment `underline`) and struck-through
/// text (`~~struck through~~`, text fragment `strikethrough`).
///
/// Like `*`, the tilde can be used inside of words. Use this transformer together with
/// `LineEmphasisDelimiterTransformer`; see `FullMarkdownParser`.
///
open class LineEmphasisTransformer: EmphasisTransformer {

  /// The emphasis of `EmphasisTransformer` and `~`: a double tilde starts and ends struck-through
  /// text, a single tilde underlined text.
  open override class var supportedEmphasis: [Emphasis] {
    return super.supportedEmphasis + [
      Emphasis(ch: "~", special: true, factory: { double, text in
        return double ? .strikethrough(text) : .underline(text)
      })
    ]
  }
}
