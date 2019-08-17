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
public final class EmphasisTransformer: InlineTransformer {

  private struct Delimiter: CustomStringConvertible {
    let ch: Character
    let runType: DelimiterRunType
    var count: Int
    var index: Int

    init(_ ch: Character, _ runType: DelimiterRunType, _ count: Int, _ index: Int) {
      self.ch = ch
      self.runType = runType
      self.count = count
      self.index = index
    }

    var isOpener: Bool {
      return self.runType.contains(.leftFlanking) &&
             (self.ch == "*" ||
              !self.runType.contains(.rightFlanking) ||
              self.runType.contains(.leftPunctuation))
    }

    var isCloser: Bool {
      return self.runType.contains(.rightFlanking) &&
             (self.ch == "*" ||
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
      return "Delimiter(\(self.ch), \(self.runType), \(self.count), \(self.index))"
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
          delimiters.append(Delimiter(ch, type, n, res.count))
          res.append(fragment: fragment)
          element = iterator.next()
        default:
          element = self.transform(fragment, from: &iterator, into: &res)
      }
    }
    self.processEmphasis(&res, &delimiters)
    return res
  }

  private func processEmphasis(_ res: inout Text, _ delimiters: inout DelimiterStack) {
    var currentPos = 0
    loop: while currentPos < delimiters.count {
      var potentialCloser = delimiters[currentPos]
      // print("DELIMITER at \(currentPos) of \(delimiters.count): \(potentialCloser)")
      if potentialCloser.isCloser(for: "*") || potentialCloser.isCloser(for: "_") {
        // print("potential closer: \(potentialCloser)")
        var i = currentPos - 1
        while i >= 0 {
          var potentialOpener = delimiters[i]
          if potentialOpener.isOpener(for: potentialCloser.ch) &&
             ((!potentialCloser.isOpener && !potentialOpener.isCloser) ||
              (potentialCloser.countMultipleOf3 && potentialOpener.countMultipleOf3) ||
              ((potentialOpener.count + potentialCloser.count) % 3 != 0)) {
            // print("  potential opener: \(potentialOpener)")
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
            range.append(delta > 1 ? .strong(nestedText) : .emph(nestedText))
            if potentialCloser.count > 0 {
              range.append(.delimiter(potentialCloser.ch,
                                      potentialCloser.count,
                                      potentialCloser.runType))
            }
            let shift = range.count - potentialCloser.index + potentialOpener.index - 1
            res.replace(from: potentialOpener.index, to: potentialCloser.index, with: range)
            // Update delimiter stack
            // print("  update delimiter stack: \(currentPos) of \(delimiters.count)")
            if potentialCloser.count == 0 {
              delimiters.remove(at: currentPos)
            }
            if potentialOpener.count == 0 {
              delimiters.remove(at: i)
              currentPos -= 1
            } else {
              i += 1
            }
            // print("  openers and closers removed: \(currentPos) of \(delimiters.count); \(i)")
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
            // print("  finished delimiter stack: \(currentPos) of \(delimiters.count)")
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
