//
//  LinkTransformer.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 24/06/2019.
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
/// An inline transformer which extracts link and image link markup and transforms it into
/// `link` and `image` text fragments.
///
open class LinkTransformer: InlineTransformer {

  /// Iterates over the fragments of a text, starting at an arbitrary position, while keeping
  /// track of the position (which a `Text.Iterator` doesn't).
  /// The current nesting depth of links and images (while transforming their text)
  private var nesting = 0

  /// Transforms the text of a link or image
  private func transformNested(_ text: Text) -> Text {
    self.nesting += 1
    defer {
      self.nesting -= 1
    }
    return self.transform(text)
  }

  private struct Cursor {
    let text: Text
    /// Position of the fragment which `next` returns next
    var position: Int

    mutating func next() -> TextFragment? {
      guard self.position < self.text.count else {
        return nil
      }
      let fragment = self.text[self.position]
      self.position += 1
      return fragment
    }
  }

  /// Returns an array with the position of the matching `]` delimiter for every `[` delimiter
  /// of `text` (and -1 for all other positions, including `[` delimiters without a match).
  private func matchingBrackets(in text: Text) -> [Int] {
    var matches = [Int](repeating: -1, count: text.count)
    var open: [Int] = []
    var i = 0
    for fragment in text {
      switch fragment {
        case .delimiter("[", _, _):
          open.append(i)
        case .delimiter("]", _, _):
          if let opener = open.popLast() {
            matches[opener] = i
          }
        default:
          break
      }
      i += 1
    }
    return matches
  }

  public override func transform(_ text: Text) -> Text {
    // Brackets are matched upfront. This avoids scanning the rest of the text for every `[`,
    // which is quadratic for texts with many unmatched brackets.
    let hasBrackets = text.contains { fragment in
      if case .delimiter("[", _, _) = fragment {
        return true
      }
      return false
    }
    let matches = hasBrackets ? self.matchingBrackets(in: text) : []
    var res = Text()
    var iterator = text.makeIterator()
    var element = iterator.next()
    // Position of `element` in `text`
    var pos = 0
    loop: while let fragment = element {
      if case .delimiter("[", _, let type) = fragment {
        let closing = matches[pos]
        if closing >= 0 && self.nesting < self.owner.maxNestingDepth &&
           self.mayCompleteLink(in: text, closingBracket: closing) {
          var inner = Text()
          for i in (pos + 1)..<closing {
            inner.append(fragment: text[i])
          }
          // The cursor is positioned after the closing bracket
          var cursor = Cursor(text: text, position: closing + 1)
          let afterBracket = cursor
          var transformed: Text? = nil
          if let link = self.complete(link: type.isEmpty,
                                      inner,
                                      with: &cursor,
                                      transformed: &transformed) {
            res.append(fragment: link)
            self.skip(cursor.position - (pos + 1), in: &iterator)
            element = iterator.next()
            pos = cursor.position
            continue loop
          }
          if let transformed {
            // `complete` already transformed the text between the brackets before it
            // gave up. Since the brackets inside of it are balanced, this is the same
            // result as processing these fragments one by one. Reusing it avoids
            // transforming nested brackets repeatedly (which is exponential for nested
            // links).
            res.append(fragment: fragment)
            for transformedFragment in transformed {
              res.append(fragment: transformedFragment)
            }
            res.append(fragment: text[closing])
            self.skip(afterBracket.position - (pos + 1), in: &iterator)
            element = iterator.next()
            pos = afterBracket.position
            continue loop
          }
        }
        res.append(fragment: fragment)
        element = iterator.next()
        pos += 1
      } else {
        // Note: this assumes that `transform` does not consume further fragments
        element = self.transform(fragment, from: &iterator, into: &res)
        pos += 1
      }
    }
    return res
  }

  private func skip(_ count: Int, in iterator: inout Text.Iterator) {
    for _ in 0..<count {
      _ = iterator.next()
    }
  }

  /// Returns false if the brackets in `text` ending at position `closing` cannot form a link
  /// or image: neither an inline link (`(`) or a reference (`[`) follows, and there are no
  /// link reference definitions for a shortcut reference. This allows skipping the
  /// (potentially expensive) attempt to complete the link.
  private func mayCompleteLink(in text: Text, closingBracket closing: Int) -> Bool {
    if !self.owner.linkRefDef.isEmpty {
      return true
    }
    guard closing + 1 < text.count else {
      return false
    }
    switch text[closing + 1] {
      case .delimiter("(", _, _), .delimiter("[", _, _):
        return true
      default:
        return false
    }
  }

  /// Tries to complete a link or image for the given description `text`. If the description
  /// gets transformed in the process, the result is also stored in `transformed`; this is
  /// also the case if no link or image could be completed.
  private func complete(link: Bool,
                        _ text: Text,
                        with iterator: inout Cursor,
                        transformed: inout Text?) -> TextFragment? {
    let initial = iterator
    // Inline links and full/collapsed references; they need a following fragment
    if let element = iterator.next() {
      switch element {
        case .delimiter("(", _, _):
          if let res = self.completeInline(link: link,
                                           text,
                                           with: &iterator,
                                           transformed: &transformed) {
            return res
          }
        case .delimiter("[", _, _):
          var undefinedLabel = false
          if let res = self.completeRef(link: link,
                                        text,
                                        with: &iterator,
                                        transformed: &transformed,
                                        undefinedLabel: &undefinedLabel) {
            return res
          }
          // A shortcut reference must not be followed by a link label
          if undefinedLabel {
            return nil
          }
        default:
          break
      }
    }
    // Shortcut references; they are also valid at the very end of the text
    let label = normalizeLinkLabel(text.description)
    if label.count < 1000,
       let (uri, title) = self.owner.linkRefDef[label] {
      let text = transformed ?? self.transformNested(text)
      transformed = text
      if link && self.containsLink(text) {
        return nil
      }
      iterator = initial
      return link ? .link(text, uri, title) : .image(text, uri, title)
    } else {
      return nil
    }
  }

  private func completeInline(link: Bool,
                              _ text: Text,
                              with iterator: inout Cursor,
                              transformed: inout Text?) -> TextFragment? {
    // Skip whitespace
    var element = self.skipWhitespace(for: &iterator)
    guard let dest = element else {
      return nil
    }
    // Transform link description
    let text = transformed ?? self.transformNested(text)
    transformed = text
    if link && self.containsLink(text) {
      return nil
    }
    // Parse destination
    var destination = ""
    // Is the destination followed by whitespace (as needed for a title)?
    var whitespaceAfterDestination = false
    choose: switch dest {
      // Is this a link destination surrounded by `<` and `>`
      case .delimiter("<", _, _):
        element = iterator.next()
        loop: while let fragment = element {
          switch fragment {
            case .delimiter(">", _, let type) where !type.contains(.escaped):
              break loop
            case .delimiter("<", _, _):
              return nil
            case .hardLineBreak, .softLineBreak:
              return nil
            default:
              destination += fragment.rawDescription
          }
          element = iterator.next()
        }
      case .html(let str):
        if str.contains("\n") {
          return nil
        }
        destination += str
      case .autolink(_, let str):
        if str.contains("\n") {
          return nil
        }
        destination += str
      // Parsing regular destinations
      default:
        var open = 0
        if case .some(.text(let str)) = element,
           let index = str.firstIndex(where: { ch in !isAsciiWhitespaceOrControl(ch) }),
           index < str.endIndex {
          destination += str[index..<str.endIndex]
          if let lastIndex = destination.firstIndex(where: isAsciiWhitespaceOrControl) {
            guard isWhitespaceString(destination[lastIndex..<destination.endIndex]) else {
              return nil
            }
            destination = String(destination[destination.startIndex..<lastIndex])
            whitespaceAfterDestination = true
            break choose
          }
          element = iterator.next()
        }
        loop: while let fragment = element {
          switch fragment {
            case .delimiter("(", _, _):
              open += 1
            case .delimiter(")", _, _):
              open -= 1
              if open < 0 {
                return link ? .link(text, destination.isEmpty ? nil : destination, nil)
                            : .image(text, destination.isEmpty ? nil : destination, nil)
              }
            case .text(let str):
              if let index = str.firstIndex(where: isAsciiWhitespaceOrControl) {
                guard isWhitespaceString(str[index..<str.endIndex]) else {
                  return nil
                }
                destination += str[str.startIndex..<index]
                whitespaceAfterDestination = true
                break loop
              }
            case .hardLineBreak, .softLineBreak:
              whitespaceAfterDestination = true
              break loop
            default:
              break
          }
          destination += fragment.rawDescription
          element = iterator.next()
      }
    }
    if element == nil {
      return nil
    }
    // Parse title
    guard let fragment = self.skipWhitespace(for: &iterator,
                                             skipped: &whitespaceAfterDestination) else {
      return nil
    }
    var optTitle: String?
    switch fragment {
      case .delimiter("\"", _, _):
        guard whitespaceAfterDestination else {
          return nil
        }
        optTitle = self.completeTitle("\"", for: &iterator)
      case .delimiter("'", _, _):
        guard whitespaceAfterDestination else {
          return nil
        }
        optTitle = self.completeTitle("'", for: &iterator)
      case .delimiter("(", _, _):
        guard whitespaceAfterDestination else {
          return nil
        }
        optTitle = self.completeTitle(")", for: &iterator)
      case .delimiter(")", _, _):
        return link ? .link(text, destination.isEmpty ? nil : destination, nil)
                    : .image(text, destination.isEmpty ? nil : destination, nil)
      default:
        return nil
    }
    guard let title = optTitle else {
      return nil
    }
    // Expect `)` character
    element = self.skipWhitespace(for: &iterator)
    guard case .some(.delimiter(")", _, _)) = element else {
      return nil
    }
    return link ? .link(text, destination.isEmpty ? nil : destination, title.isEmpty ? nil : title)
                : .image(text, destination.isEmpty ? nil : destination, title.isEmpty ? nil : title)
  }

  private func completeTitle(_ ch: Character, for iterator: inout Cursor) -> String? {
    var element = iterator.next()
    var title = ""
    while let fragment = element {
      switch fragment {
        case .delimiter(ch, _, _):
          return title
        default:
          title += fragment.description
      }
      element = iterator.next()
    }
    return nil
  }

  private func skipWhitespace(for iterator: inout Cursor) -> TextFragment? {
    var skipped = false
    return self.skipWhitespace(for: &iterator, skipped: &skipped)
  }

  /// Skips whitespace fragments and returns the next fragment. `skipped` is set to true if
  /// any whitespace was skipped.
  private func skipWhitespace(for iterator: inout Cursor,
                              skipped: inout Bool) -> TextFragment? {
    var element = iterator.next()
    while let fragment = element {
      switch fragment {
        case .hardLineBreak, .softLineBreak:
          skipped = true
        case .text(let str) where isWhitespaceString(str):
          skipped = true
        default:
          return element
      }
      element = iterator.next()
    }
    return nil
  }

  private func containsLink(_ text: Text) -> Bool {
    for fragment in text {
      switch fragment {
        case .emph(let inner):
          if self.containsLink(inner) {
            return true
          }
        case .strong(let inner):
          if self.containsLink(inner) {
            return true
          }
        case .link(_, _, _):
          return true
        case .autolink(_, _):
          return true
        case .image(let inner, _, _):
          if self.containsLink(inner) {
            return true
          }
        default:
          break
      }
    }
    return false
  }

  private func completeRef(link: Bool,
                           _ text: Text,
                           with iterator: inout Cursor,
                           transformed: inout Text?,
                           undefinedLabel: inout Bool) -> TextFragment? {
    // Skip whitespace
    var element = self.skipWhitespace(for: &iterator)
    // Transform link description
    let text = transformed ?? self.transformNested(text)
    transformed = text
    if link && self.containsLink(text) {
      return nil
    }
    // Parse label
    var label = ""
    while let fragment = element {
      switch fragment {
        case .delimiter("]", _, _):
          // A collapsed reference (`[foo][]`) uses the link text as its label
          label = normalizeLinkLabel(label.isEmpty ? text.description : label)
          if let (uri, title) = self.owner.linkRefDef[label] {
            return link ? .link(text, uri, title) : .image(text, uri, title)
          } else {
            undefinedLabel = true
            return nil
          }
        case .softLineBreak, .hardLineBreak:
          label.append(" ")
        default:
          let components = fragment.description.components(separatedBy: .whitespaces)
          label.append(components.filter { !$0.isEmpty }.joined(separator: " "))
          if label.count > 999 {
            return nil
          }
      }
      element = iterator.next()
    }
    return nil
  }
}
