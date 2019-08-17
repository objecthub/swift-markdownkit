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
public struct Text: Collection, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
  public typealias Index = ContiguousArray<TextFragment>.Index
  public typealias Iterator = ContiguousArray<TextFragment>.Iterator

  private var fragments: ContiguousArray<TextFragment> = []

  public init(_ str: Substring? = nil) {
    if let str = str {
      self.fragments.append(.text(str))
    }
  }

  public init(_ fragment: TextFragment) {
    self.fragments.append(fragment)
  }

  /// Returns `true` if the text is empty.
  public var isEmpty: Bool {
    return self.fragments.isEmpty
  }

  /// Returns the first text fragment if available.
  public var first: TextFragment? {
    return self.fragments.first
  }

  /// Returns the last text fragment if available.
  public var last: TextFragment? {
    return self.fragments.last
  }

  /// Appends a line of text, potentially followed by a hard line break
  mutating public func append(line: Substring, withHardLineBreak: Bool) {
    let n = self.fragments.count
    if n > 0, case .text(let str) = self.fragments[n - 1] {
      if str.last == "\\" {
        let newline = str[str.startIndex..<str.index(before: str.endIndex)]
        if newline.isEmpty {
          self.fragments[n - 1] = .hardLineBreak
        } else {
          self.fragments[n - 1] = .text(newline)
          self.fragments.append(.hardLineBreak)
        }
      } else {
        self.fragments.append(.softLineBreak)
      }
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
      res = res + fragment.description
    }
    return res
  }

  /// Returns a raw description of this `Text` object as a string, i.e. as if the text
  /// would be represented in Markdown but ignoring all markup.
  public var rawDescription: String {
    var res = ""
    for fragment in self.fragments {
      res = res + fragment.rawDescription
    }
    return res
  }

  /// Returns a debug description of this `Text` object.
  public var debugDescription: String {
    var res = ""
    for fragment in self.fragments {
      if res.isEmpty {
        res = fragment.debugDescription
      } else {
        res = res + ", \(fragment.debugDescription)"
      }
    }
    return res
  }

  /// Finalizes the `Text` object by removing trailing line breaks.
  public func finalized() -> Text {
    if let lastLine = self.fragments.last {
      switch lastLine {
        case .hardLineBreak, .softLineBreak:
          var plines = self
          plines.fragments.removeLast()
          return plines
        default:
          return self
      }
    } else {
      return self
    }
  }

  /// Defines an equality relationship for `Text` objects.
  public static func == (lhs: Text, rhs: Text) -> Bool {
    return lhs.fragments == rhs.fragments
  }
}
