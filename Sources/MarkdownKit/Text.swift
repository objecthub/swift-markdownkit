//
//  Text.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 30/05/2019.
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
/// Struct `Text` is used to represent inline text. A `Text` struct consists of a sequence
/// of `TextFragment` objects.
///
public struct Text: Collection, Equatable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
  public typealias Index = ContiguousArray<TextFragment>.Index
  public typealias Iterator = ContiguousArray<TextFragment>.Iterator

  private var fragments: ContiguousArray<TextFragment> = []

  /// Creates a text with a single plain text fragment for `str`, or an empty text if `str` is
  /// `nil`.
  public init(_ str: Substring? = nil) {
    if let str = str {
      self.fragments.append(.text(str))
    }
  }

  /// Creates a text with the given fragment as its only fragment.
  public init(_ fragment: TextFragment) {
    self.fragments.append(fragment)
  }

  /// Returns `true` if the text is empty.
  public var isEmpty: Bool {
    return self.fragments.isEmpty
  }

  /// Returns the number of text fragments. (Without this, `Collection` would compute the
  /// count by traversing the whole text, which makes loops that use it quadratic.)
  public var count: Int {
    return self.fragments.count
  }

  /// Returns the first text fragment if available.
  public var first: TextFragment? {
    return self.fragments.first
  }

  /// Returns the last text fragment if available.
  public var last: TextFragment? {
    return self.fragments.last
  }

  /// Appends a line of text, potentially followed by a hard line break. If the last fragment
  /// is a text (as opposed to a line break), a soft line break gets inserted in front of the
  /// line. The line is appended as it is; in particular, trailing spaces and a trailing
  /// backslash are not interpreted here. Whether a line ending is a hard line break is only
  /// known once the inline markup is parsed (a backslash or spaces at the end of a line are
  /// part of a code span or an HTML tag, and are no line break in this case).
  mutating public func append(line: Substring, withHardLineBreak: Bool) {
    if case .text(_)? = self.fragments.last {
      self.fragments.append(.softLineBreak)
    }
    self.fragments.append(.text(line))
    if withHardLineBreak {
      self.fragments.append(.hardLineBreak)
    }
  }

  /// Appends a given text fragment.
  mutating public func append(fragment: TextFragment) {
    self.fragments.append(fragment)
  }

  /// Replaces the text fragments between `from` and `to` with a given array of text
  /// fragments.
  mutating public func replace(from: Int, to: Int, with fragments: [TextFragment]) {
    self.fragments.replaceSubrange(from...to, with: fragments)
  }

  /// Returns an iterator over all text fragments.
  public func makeIterator() -> Iterator {
    return self.fragments.makeIterator()
  }

  /// Returns the start index.
  public var startIndex: Index {
    return self.fragments.startIndex
  }

  /// Returns the end index.
  public var endIndex: Index {
    return self.fragments.endIndex
  }

  /// Returns the text fragment at the given index.
  public subscript (position: Index) -> Iterator.Element {
    return self.fragments[position]
  }

  /// Advances the given index by one place.
  public func index(after i: Index) -> Index {
    return self.fragments.index(after: i)
  }

  /// Returns a description of this `Text` object as a string as if the text would be
  /// represented in Markdown.
  public var description: String {
    var res = ""
    for fragment in self.fragments {
      res.append(fragment.description)
    }
    return res
  }

  /// Returns a raw description of this `Text` object as a string, i.e. as if the text
  /// would be represented in Markdown but ignoring all markup.
  public var rawDescription: String {
    return self.fragments.map { $0.rawDescription }.joined()
  }
  
  /// Returns a raw description of this `Text` object as a string for which all markup
  /// gets ignored.
  public var string: String {
    return self.fragments.map { $0.string }.joined()
  }
  
  /// Returns a debug description of this `Text` object.
  public var debugDescription: String {
    var res = ""
    for fragment in self.fragments {
      if res.isEmpty {
        res = fragment.debugDescription
      } else {
        res.append(", ")
        res.append(fragment.debugDescription)
      }
    }
    return res
  }

  /// Finalizes the `Text` object by removing trailing line breaks and trailing white space.
  public func finalized() -> Text {
    var res = self
    switch res.fragments.last {
      case .hardLineBreak?, .softLineBreak?:
        res.fragments.removeLast()
      default:
        break
    }
    if case .text(let str)? = res.fragments.last,
       let last = str.lastIndex(where: { $0 != " " && $0 != "\t" }) {
      let end = str.index(after: last)
      if end < str.endIndex {
        res.fragments[res.fragments.count - 1] = .text(str[str.startIndex..<end])
      }
    } else if case .text(let str)? = res.fragments.last, !str.isEmpty {
      // The last text consists of white space only
      res.fragments.removeLast()
    }
    return res
  }
  
  /// The text in its normal form, for comparing syntax trees.
  ///
  /// The parser splits text at every character that may start markup, also if the character is
  /// escaped: `a (b) c` is `"a "`, `"("`, `"b"`, `")"`, `" c"`, whereas `a \(b\) c` is the one
  /// fragment `"a (b) c"`. Both are the same text, but ``Text`` compares fragments. In the normal
  /// form, every run of adjacent text and delimiter fragments is one text fragment and empty text
  /// is gone; the text inside of emphasis, links and images is normalized as well.
  public var normalized: Text {
    var res = Text()
    var pending = ""
    func flush() {
      if !pending.isEmpty {
        res.append(fragment: .text(Substring(pending)))
        pending = ""
      }
    }
    for fragment in self {
      switch fragment {
        case .text(let str):
          pending += str
        case .delimiter(_, _, _):
          pending += fragment.rawDescription
        case .emph(let text):
          flush()
          res.append(fragment: .emph(text.normalized))
        case .strong(let text):
          flush()
          res.append(fragment: .strong(text.normalized))
        case .underline(let text):
          flush()
          res.append(fragment: .underline(text.normalized))
        case .strikethrough(let text):
          flush()
          res.append(fragment: .strikethrough(text.normalized))
        case .link(let text, let uri, let title):
          flush()
          res.append(fragment: .link(text.normalized, uri, title))
        case .image(let text, let uri, let title):
          flush()
          res.append(fragment: .image(text.normalized, uri, title))
        default:
          flush()
          res.append(fragment: fragment)
      }
    }
    flush()
    return res
  }
  
  /// Defines an equality relationship for `Text` objects.
  public static func == (lhs: Text, rhs: Text) -> Bool {
    return lhs.fragments == rhs.fragments
  }
}
