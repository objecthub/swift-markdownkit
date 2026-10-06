//
//  EmphasisTransformer.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 16/06/2019.
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
/// An inline transformer which extracts emphasis markup and transforms it into `emph` and
/// `strong` text fragments.
///
open class EmphasisTransformer: InlineTransformer {

  /// Plugin specifying the type of emphasis. `ch` refers to the emphasis character,
  /// `special` to whether the charater is used for other use cases (e.g. "*" and "-" should
  /// be marked as "special"), and `factory` to a closure constructing the text fragment
  /// from two parameters: the first denoting whether it's double usage, and the second
  /// referring to the emphasized text.
  public struct Emphasis {
    public let ch: Character
    public let special: Bool
    public let factory: (Bool, Text) -> TextFragment
    
    public init(ch: Character, special: Bool, factory: @escaping (Bool, Text) -> TextFragment) {
      self.ch = ch
      self.special = special
      self.factory = factory
    }
  }
  
  /// Emphasis supported by default. Override this property to change what is supported.
  open class var supportedEmphasis: [Emphasis] {
    let factory = { (double: Bool, text: Text) -> TextFragment in
      double ? .strong(text) : .emph(text)
    }
    return [Emphasis(ch: "*", special: true, factory: factory),
            Emphasis(ch: "_", special: false, factory: factory)]
  }
  
  /// The emphasis map, used internally to determine how characters are used for emphasis
  /// markup.
  private var emphasis: [Character : Emphasis] = [:]

  required public init(owner: InlineParser) {
    super.init(owner: owner)
    for emph in type(of: self).supportedEmphasis {
      self.emphasis[emph.ch] = emph
    }
  }

  private struct Delimiter: CustomStringConvertible {
    let ch: Character
    let special: Bool
    let runType: DelimiterRunType
    var count: Int
    /// Identifies the node of the fragment list (see `Node`) that this delimiter refers to
    var node: Int
    /// Links of the stack of delimiters (identifiers are indices into the delimiter array;
    /// -1 is used if there is no previous/next delimiter)
    var prev: Int = -1
    var next: Int = -1

    init(_ ch: Character, _ special: Bool, _ rtype: DelimiterRunType, _ count: Int, _ node: Int) {
      self.ch = ch
      self.special = special
      self.runType = rtype
      self.count = count
      self.node = node
    }

    var isOpener: Bool {
      return self.runType.contains(.leftFlanking) &&
             (self.special ||
              !self.runType.contains(.rightFlanking) ||
              self.runType.contains(.leftPunctuation))
    }

    var isCloser: Bool {
      return self.runType.contains(.rightFlanking) &&
             (self.special ||
              !self.runType.contains(.leftFlanking) ||
              self.runType.contains(.rightPunctuation))
    }

    var countMultipleOf3: Bool {
      return self.count % 3 == 0
    }

    func isOpener(for ch: Character) -> Bool {
      return self.ch == ch && self.isOpener
    }

    func isCloser(for ch: Character) -> Bool {
      return self.ch == ch && self.isCloser
    }

    var description: String {
      return "Delimiter(\(self.ch), \(self.special), \(self.runType), \(self.count), \(self.node))"
    }
  }

  private typealias DelimiterStack = [Delimiter]

  /// The fragments of the text which gets transformed are kept in a doubly linked list. This
  /// way, replacing fragments with emphasis does not move the remaining fragments around and
  /// delimiters can refer to their fragments via stable identifiers (indices of this list).
  private struct Node {
    var fragment: TextFragment
    var prev: Int
    var next: Int
  }

  /// Key for remembering where it is pointless to search for openers
  private struct OpenersBottomKey: Hashable {
    let ch: Character
    let countMod3: Int
    let canOpen: Bool
  }

  public override func transform(_ text: Text) -> Text {
    // Compute delimiter stack
    var res: Text = Text()
    var iterator = text.makeIterator()
    var element = iterator.next()
    var delimiters = DelimiterStack()
    while let fragment = element {
      switch fragment {
        case .delimiter(let ch, let n, let type):
          delimiters.append(Delimiter(ch, self.emphasis[ch]?.special ?? false, type, n, res.count))
          res.append(fragment: fragment)
          element = iterator.next()
        default:
          element = self.transform(fragment, from: &iterator, into: &res)
      }
    }
    guard !delimiters.isEmpty else {
      return res
    }
    // The first node is a sentinel; the node of fragment `i` has the identifier `i + 1`
    var nodes = [Node]()
    nodes.reserveCapacity(res.count + 1 + delimiters.count)
    nodes.append(Node(fragment: .softLineBreak, prev: -1, next: res.isEmpty ? -1 : 1))
    var i = 0
    for fragment in res {
      nodes.append(Node(fragment: fragment, prev: i, next: i + 1 < res.count ? i + 2 : -1))
      i += 1
    }
    for i in 0..<delimiters.count {
      delimiters[i].node += 1
      delimiters[i].prev = i - 1
      delimiters[i].next = i + 1 < delimiters.count ? i + 1 : -1
    }
    self.processEmphasis(&nodes, &delimiters)
    var result = Text()
    var node = nodes[0].next
    while node >= 0 {
      result.append(fragment: nodes[node].fragment)
      node = nodes[node].next
    }
    return result
  }

  private func isSupportedEmphasisCloser(_ delimiter: Delimiter) -> Bool {
    for ch in self.emphasis.keys {
      if delimiter.isCloser(for: ch) {
        return true
      }
    }
    return false
  }

  private func processEmphasis(_ nodes: inout [Node], _ delimiters: inout DelimiterStack) {
    // For a kind of closer, the identifier of the delimiter below which no opener exists
    // (as long as the openers below do not change)
    var openersBottom: [OpenersBottomKey : Int] = [:]
    var current = 0
    loop: while current >= 0 {
      let potentialCloser = delimiters[current]
      if self.isSupportedEmphasisCloser(potentialCloser) {
        let key = OpenersBottomKey(ch: potentialCloser.ch,
                                   countMod3: potentialCloser.count % 3,
                                   canOpen: potentialCloser.isOpener)
        let bottom = openersBottom[key] ?? -1
        var i = potentialCloser.prev
        while i > bottom {
          let potentialOpener = delimiters[i]
          if potentialOpener.isOpener(for: potentialCloser.ch) &&
             ((!potentialCloser.isOpener && !potentialOpener.isCloser) ||
              (potentialCloser.countMultipleOf3 && potentialOpener.countMultipleOf3) ||
              ((potentialOpener.count + potentialCloser.count) % 3 != 0)) {
            // Deduct counts
            let delta = potentialOpener.count > 1 && potentialCloser.count > 1 ? 2 : 1
            delimiters[i].count -= delta
            delimiters[current].count -= delta
            let opener = delimiters[i]
            let closer = delimiters[current]
            // Collect fragments between the two delimiters
            var nestedText = Text()
            var node = nodes[opener.node].next
            while node != closer.node {
              nestedText.append(fragment: nodes[node].fragment)
              node = nodes[node].next
            }
            // Replace the fragments of the delimiters and everything between them
            var replacement = [Int]()
            if opener.count > 0 {
              nodes[opener.node].fragment = .delimiter(opener.ch, opener.count, opener.runType)
              replacement.append(opener.node)
            }
            if let factory = self.emphasis[opener.ch]?.factory {
              nodes.append(Node(fragment: factory(delta > 1, nestedText), prev: -1, next: -1))
              replacement.append(nodes.count - 1)
            } else {
              for fragment in nestedText {
                nodes.append(Node(fragment: fragment, prev: -1, next: -1))
                replacement.append(nodes.count - 1)
              }
            }
            if closer.count > 0 {
              nodes[closer.node].fragment = .delimiter(closer.ch, closer.count, closer.runType)
              replacement.append(closer.node)
            }
            var previous = nodes[opener.node].prev
            let after = nodes[closer.node].next
            for node in replacement {
              nodes[previous].next = node
              nodes[node].prev = previous
              previous = node
            }
            nodes[previous].next = after
            if after >= 0 {
              nodes[after].prev = previous
            }
            // Update the stack: remove the delimiters between opener and closer as well as
            // opener and closer if they have no characters left
            let stackBefore = opener.count > 0 ? i : delimiters[i].prev
            let stackAfter = closer.count > 0 ? current : delimiters[current].next
            if stackBefore >= 0 {
              delimiters[stackBefore].next = stackAfter
            }
            if stackAfter >= 0 {
              delimiters[stackAfter].prev = stackBefore
            }
            // The count of the opener changed, which might make it match closers which did
            // not match before
            openersBottom = openersBottom.filter { $0.value < i }
            current = stackAfter
            continue loop
          }
          i = potentialOpener.prev
        }
        openersBottom[key] = potentialCloser.prev
        if !potentialCloser.isOpener {
          // Remove the closer from the stack
          if potentialCloser.prev >= 0 {
            delimiters[potentialCloser.prev].next = potentialCloser.next
          }
          if potentialCloser.next >= 0 {
            delimiters[potentialCloser.next].prev = potentialCloser.prev
          }
          current = potentialCloser.next
          continue loop
        }
      }
      current = potentialCloser.next
    }
  }
}
