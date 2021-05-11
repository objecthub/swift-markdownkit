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
                if let link = self.complete(link: type.isEmpty, inner, with: &scanner) {
                  res.append(fragment: link)
                  iterator = scanner
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

  private func complete(link: Bool,
                        _ text: Text,
                        with iterator: inout Text.Iterator) -> TextFragment? {
    let initial = iterator
    let next = iterator.next()
    guard let element = next else {
      return nil
    }
    switch element {
      case .delimiter("(", _, _):
        if let res = self.completeInline(link: link, text, with: &iterator) {
          return res
        }
      case .delimiter("[", _, _):
        if let res = self.completeRef(link: link, text, with: &iterator) {
          return res
        }
      default:
        break
    }
    let components = text.description.components(separatedBy: .whitespacesAndNewlines)
    let label = components.filter { !$0.isEmpty }.joined(separator: " ").lowercased()
    if label.count < 1000,
       let (uri, title) = self.owner.linkRefDef[label] {
      let text = self.transform(text)
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
                              with iterator: inout Text.Iterator) -> TextFragment? {
    // Skip whitespace
    var element = self.skipWhitespace(for: &iterator)
    guard let dest = element else {
      return nil
    }
    // Transform link description
    let text = self.transform(text)
    if link && self.containsLink(text) {
      return nil
    }
    // Parse destination
    var destination = ""
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
                break loop
              }
            case .hardLineBreak, .softLineBreak:
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
    guard let fragment = self.skipWhitespace(for: &iterator) else {
      return nil
    }
    var optTitle: String?
    switch fragment {
      case .delimiter("\"", _, _):
        optTitle = self.completeTitle("\"", for: &iterator)
      case .delimiter("'", _, _):
        optTitle = self.completeTitle("'", for: &iterator)
      case .delimiter("(", _, _):
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
    var element = iterator.next()
    while let fragment = element {
      switch fragment {
        case .hardLineBreak, .softLineBreak:
          break
        case .text(let str) where isWhitespaceString(str):
          break
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
                           with iterator: inout Text.Iterator) -> TextFragment? {
    // Skip whitespace
    var element = self.skipWhitespace(for: &iterator)
    // Transform link description
    let text = self.transform(text)
    if link && self.containsLink(text) {
      return nil
    }
    // Parse label
    var label = ""
    while let fragment = element {
      switch fragment {
        case .delimiter("]", _, _):
          label = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
          if let (uri, title) = self.owner.linkRefDef[label] {
            return link ? .link(text, uri, title) : .image(text, uri, title)
          } else {
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
