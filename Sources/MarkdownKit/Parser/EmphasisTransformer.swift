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
    let ch: Character
    let special: Bool
    let factory: (Bool, Text) -> TextFragment
  }
  
  /// Emphasis supported by default. Override this property to change the what gets
  /// supported.
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
    var index: Int

    init(_ ch: Character, _ special: Bool, _ rtype: DelimiterRunType, _ count: Int, _ index: Int) {
      self.ch = ch
      self.special = special
      self.runType = rtype
      self.count = count
      self.index = index
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
      return "Delimiter(\(self.ch), \(self.special), \(self.runType), \(self.count), \(self.index))"
    }
  }

  private typealias DelimiterStack = [Delimiter]

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
    self.processEmphasis(&res, &delimiters)
    return res
  }

  private func isSupportedEmphasisCloser(_ delimiter: Delimiter) -> Bool {
    for ch in self.emphasis.keys {
      if delimiter.isCloser(for: ch) {
        return true
      }
    }
    return false
  }

  private func processEmphasis(_ res: inout Text, _ delimiters: inout DelimiterStack) {
    var currentPos = 0
    loop: while currentPos < delimiters.count {
      var potentialCloser = delimiters[currentPos]
      if self.isSupportedEmphasisCloser(potentialCloser) {
        var i = currentPos - 1
        while i >= 0 {
          var potentialOpener = delimiters[i]
          if potentialOpener.isOpener(for: potentialCloser.ch) &&
             ((!potentialCloser.isOpener && !potentialOpener.isCloser) ||
              (potentialCloser.countMultipleOf3 && potentialOpener.countMultipleOf3) ||
              ((potentialOpener.count + potentialCloser.count) % 3 != 0)) {
            // Deduct counts
            let delta = potentialOpener.count > 1 && potentialCloser.count > 1 ? 2 : 1
            delimiters[i].count -= delta
            delimiters[currentPos].count -= delta
            potentialOpener = delimiters[i]
            potentialCloser = delimiters[currentPos]
            // Collect fragments
            var nestedText = Text()
            for fragment in res[potentialOpener.index+1..<potentialCloser.index] {
              nestedText.append(fragment: fragment)
            }
            // Replace existing fragments
            var range = [TextFragment]()
            if potentialOpener.count > 0 {
              range.append(.delimiter(potentialOpener.ch,
                                      potentialOpener.count,
                                      potentialOpener.runType))
            }
            if let factory = self.emphasis[potentialOpener.ch]?.factory {
              range.append(factory(delta > 1, nestedText))
            } else {
              for fragment in nestedText {
                range.append(fragment)
              }
            }
            if potentialCloser.count > 0 {
              range.append(.delimiter(potentialCloser.ch,
                                      potentialCloser.count,
                                      potentialCloser.runType))
            }
            let shift = range.count - potentialCloser.index + potentialOpener.index - 1
            res.replace(from: potentialOpener.index, to: potentialCloser.index, with: range)
            // Update delimiter stack
            if potentialCloser.count == 0 {
              delimiters.remove(at: currentPos)
            }
            if potentialOpener.count == 0 {
              delimiters.remove(at: i)
              currentPos -= 1
            } else {
              i += 1
            }
            var j = i
            while j < currentPos {
              delimiters.remove(at: i)
              j += 1
            }
            currentPos = i
            while i < delimiters.count {
              delimiters[i].index += shift
              i += 1
            }
            continue loop
          }
          i -= 1
        }
        if !potentialCloser.isOpener {
          delimiters.remove(at: currentPos)
          continue loop
        }
      }
      currentPos += 1
    }
  }
}
