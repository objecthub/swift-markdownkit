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

  public override func transform(_ text: Text) -> Text {
    var res = Text()
    var iterator = text.makeIterator()
    var element = iterator.next()
    loop: while let fragment = element {
      if case .delimiter("[", _, let type) = fragment {
        var scanner = iterator
        var next = scanner.next()
        var open = 0
        var inner = Text()
        scan: while let lookahead = next {
          switch lookahead {
            case .delimiter("]", _, _):
              if open == 0 {
                let afterBracket = scanner
                var transformed: Text? = nil
                if let link = self.complete(link: type.isEmpty,
                                            inner,
                                            with: &scanner,
                                            transformed: &transformed) {
                  res.append(fragment: link)
                  iterator = scanner
                  element = iterator.next()
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
                  res.append(fragment: lookahead)
                  iterator = afterBracket
                  element = iterator.next()
                  continue loop
                }
                break scan
              }
              open -= 1
            case .delimiter("[", _, _):
              open += 1
            default:
              break
          }
          // if type.isEmpty {
            inner.append(fragment: lookahead)
            next = scanner.next()
          // } else {
          //  next = self.transform(lookahead, from: &scanner, into: &inner)
          // }
        }
        res.append(fragment: fragment)
        element = iterator.next()
      } else {
        element = self.transform(fragment, from: &iterator, into: &res)
      }
    }
    return res
  }

  /// Tries to complete a link or image for the given description `text`. If the description
  /// gets transformed in the process, the result is also stored in `transformed`; this is
  /// also the case if no link or image could be completed.
  private func complete(link: Bool,
                        _ text: Text,
                        with iterator: inout Text.Iterator,
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
      let text = transformed ?? self.transform(text)
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
                              with iterator: inout Text.Iterator,
                              transformed: inout Text?) -> TextFragment? {
    // Skip whitespace
    var element = self.skipWhitespace(for: &iterator)
    guard let dest = element else {
      return nil
    }
    // Transform link description
    let text = transformed ?? self.transform(text)
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
            case .delimiter(">", _, _):
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

  private func completeTitle(_ ch: Character, for iterator: inout Text.Iterator) -> String? {
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

  private func skipWhitespace(for iterator: inout Text.Iterator) -> TextFragment? {
    var skipped = false
    return self.skipWhitespace(for: &iterator, skipped: &skipped)
  }

  /// Skips whitespace fragments and returns the next fragment. `skipped` is set to true if
  /// any whitespace was skipped.
  private func skipWhitespace(for iterator: inout Text.Iterator,
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
                           with iterator: inout Text.Iterator,
                           transformed: inout Text?,
                           undefinedLabel: inout Bool) -> TextFragment? {
    // Skip whitespace
    var element = self.skipWhitespace(for: &iterator)
    // Transform link description
    let text = transformed ?? self.transform(text)
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
