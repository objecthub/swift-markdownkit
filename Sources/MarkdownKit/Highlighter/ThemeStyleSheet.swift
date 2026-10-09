//
//  ThemeStyleSheet.swift
//  MarkdownKit
//
//  Created on 09/10/2026.
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

#if !os(watchOS)

import Foundation

///
/// The style of text in highlighted code. A style sets some of its properties (the others are
/// `nil`), so that styles can be layered.
///
protocol ThemeStyle: Sendable {

  /// The style which sets no properties
  init()

  /// The style which results from layering `inner` on top of this style: a property which
  /// `inner` sets replaces the one of this style.
  func overridden(by inner: Self) -> Self
}

///
/// A CSS declaration (a property with a value).
///
struct ThemeDeclaration: Sendable, Equatable {
  /// The name of the property in lowercase
  let name: String
  /// The value of the property, without `!important`
  let value: String
}

///
/// The rules of a highlighting theme: a style sheet which uses class selectors for the
/// `<span class="...">` elements that highlight.js generates, and a function which determines
/// the style of a piece of text from the classes of its element and the elements around it.
///
/// Supported selectors consist of classes only: `.a`, compound selectors (`.a.b`), descendant
/// selectors (`.a .b`) and child selectors (`.a > .b`). Type selectors (such as `pre code.hljs`)
/// are ignored. Selectors with other parts (ids, attributes, pseudo classes and elements,
/// sibling combinators) as well as at-rules (such as `@media`) are not supported and skipped.
/// The cascade follows CSS: the rule with the higher specificity (the number of classes of its
/// selector) wins, and for the same specificity the rule which is written last.
///
struct ThemeStyleSheet<Style: ThemeStyle>: Sendable {

  /// A selector which consists of classes only.
  struct Selector: Sendable, Equatable {
    enum Combinator: Sendable, Equatable {
      case descendant
      case child
    }

    /// The class names (without dots) of the compound selectors, starting with the outermost
    /// element. Every compound selector has at least one class.
    let compounds: [[String]]

    /// `combinators[k]` connects `compounds[k]` and `compounds[k + 1]`.
    let combinators: [Combinator]

    private let classSets: [Set<String>]

    fileprivate init(compounds: [[String]], combinators: [Combinator]) {
      self.compounds = compounds
      self.combinators = combinators
      self.classSets = compounds.map { Set($0) }
    }

    /// The number of classes in the selector
    var specificity: Int {
      return self.compounds.reduce(0) { $0 + $1.count }
    }

    /// A normalized representation of the selector as CSS
    var text: String {
      var result = ""
      for (index, compound) in self.compounds.enumerated() {
        if index > 0 {
          result += self.combinators[index - 1] == .child ? " > " : " "
        }
        result += compound.map { "." + $0 }.joined()
      }
      return result
    }

    /// Does the selector match `elements[index]`? `elements` contains the classes of the
    /// elements, starting with the outermost one, up to the element which is tested.
    func matches(_ elements: [Set<String>], at index: Int) -> Bool {
      return self.matches(self.classSets.count - 1, elements, at: index)
    }

    private func matches(_ compound: Int, _ elements: [Set<String>], at index: Int) -> Bool {
      guard self.classSets[compound].isSubset(of: elements[index]) else {
        return false
      }
      if compound == 0 {
        return true
      }
      switch self.combinators[compound - 1] {
        case .child:
          return index > 0 && self.matches(compound - 1, elements, at: index - 1)
        case .descendant:
          var ancestor = index - 1
          while ancestor >= 0 {
            if self.matches(compound - 1, elements, at: ancestor) {
              return true
            }
            ancestor -= 1
          }
          return false
      }
    }
  }

  /// A rule of the style sheet. A rule with a list of selectors results in one `Rule` for
  /// every selector.
  struct Rule: Sendable {
    let selector: Selector
    let declarations: [ThemeDeclaration]
    let style: Style
    /// The position of the rule in the style sheet
    let order: Int
  }

  /// The rules in the order in which they are written.
  let rules: [Rule]

  /// The indices of the rules by (the first) class of the last compound selector
  private let rulesBySubjectClass: [String: [Int]]
  
  /// Remembers the styles for lists of classes: the same few combinations of classes occur
  /// over and over in highlighted code. Copies of a style sheet share the cache, which is
  /// fine since a style sheet never changes.
  private let cache = StyleCache()
  
  private final class StyleCache: @unchecked Sendable {
    private let lock = NSLock()
    private var styles: [[String]: Style] = [:]
    
    func style(for classes: [String], compute: () -> Style) -> Style {
      self.lock.lock()
      let cached = self.styles[classes]
      self.lock.unlock()
      if let cached {
        return cached
      }
      let style = compute()
      self.lock.lock()
      if self.styles.count >= 1000 {
        self.styles.removeAll(keepingCapacity: true)
      }
      self.styles[classes] = style
      self.lock.unlock()
      return style
    }
  }

  /// Creates a style sheet from CSS. `makeStyle` determines the style of a rule from its
  /// declarations (in the order in which they are written).
  init(css: String, makeStyle: ([ThemeDeclaration]) -> Style) {
    var rules: [Rule] = []
    var bySubjectClass: [String: [Int]] = [:]
    for (selectors, body) in Self.cssRules(in: css) {
      let declarations = Self.cssDeclarations(in: body)
      if declarations.isEmpty {
        continue
      }
      let style = makeStyle(declarations)
      for text in selectors.components(separatedBy: ",") {
        if let selector = Self.parseSelector(text) {
          bySubjectClass[selector.compounds[selector.compounds.count - 1][0], default: []]
            .append(rules.count)
          rules.append(Rule(selector: selector,
                            declarations: declarations,
                            style: style,
                            order: rules.count))
        }
      }
    }
    self.rules = rules
    self.rulesBySubjectClass = bySubjectClass
  }

  /// Returns the style of text within nested elements. `classes` contains the value of the
  /// class attribute of each element, starting with the outermost one (like `hljs-title
  /// function_`). The result combines the styles that the rules give to each of the elements:
  /// the style of an inner element replaces the properties of the outer ones.
  func style(forClasses classes: [String]) -> Style {
    return self.cache.style(for: classes) {
      self.computeStyle(forClasses: classes)
    }
  }
  
  private func computeStyle(forClasses classes: [String]) -> Style {
    let elements = classes.map { Set($0.split(whereSeparator: \.isWhitespace).map(String.init)) }
    var result = Style()
    for index in elements.indices {
      var matching: [Rule] = []
      for name in elements[index] {
        for ruleIndex in self.rulesBySubjectClass[name] ?? [] {
          let rule = self.rules[ruleIndex]
          if rule.selector.matches(elements, at: index) {
            matching.append(rule)
          }
        }
      }
      if matching.isEmpty {
        continue
      }
      // The cascade: increasing specificity, and for the same specificity the source order
      matching.sort {
        let (lhs, rhs) = ($0.selector.specificity, $1.selector.specificity)
        return lhs != rhs ? lhs < rhs : $0.order < $1.order
      }
      var elementStyle = Style()
      for rule in matching {
        elementStyle = elementStyle.overridden(by: rule.style)
      }
      result = result.overridden(by: elementStyle)
    }
    return result
  }

  /// Returns the rules as CSS, in the order in which they are written. Declarations for which
  /// `include` returns `false` are left out, and so are rules without declarations.
  func css(including include: (Rule, ThemeDeclaration) -> Bool = { _, _ in true }) -> String {
    var result = ""
    for rule in self.rules {
      let declarations = rule.declarations.filter { include(rule, $0) }
      if !declarations.isEmpty {
        result += rule.selector.text + "{" +
                  declarations.map { "\($0.name):\($0.value);" }.joined() + "}"
      }
    }
    return result
  }

  // MARK: Parsing CSS

  /// Splits CSS into its style rules. Returns the selectors and the declarations (without
  /// braces) of every rule in the order in which they are written. Comments and at-rules
  /// (including their nested rules) are skipped.
  private static func cssRules(in css: String) -> [(selectors: String, body: String)] {
    let withoutComments = css.replacingOccurrences(of: #"(?s)/\*.*?(?:\*/|\z)"#,
                                                   with: " ",
                                                   options: .regularExpression)
    // The delimiters are ASCII, so it is safe to scan the UTF-8 bytes
    let bytes = Array(withoutComments.utf8)
    func text(_ range: Range<Int>) -> String {
      return String(decoding: bytes[range], as: UTF8.self)
    }
    var rules: [(selectors: String, body: String)] = []
    var preludeStart = 0
    var i = 0
    while i < bytes.count {
      switch bytes[i] {
        case UInt8(ascii: "{"):
          // Find the matching closing brace
          var depth = 1
          var end = i + 1
          while end < bytes.count {
            if bytes[end] == UInt8(ascii: "{") {
              depth += 1
            } else if bytes[end] == UInt8(ascii: "}") {
              depth -= 1
              if depth == 0 {
                break
              }
            }
            end += 1
          }
          let prelude = text(preludeStart..<i).trimmingCharacters(in: .whitespacesAndNewlines)
          if !prelude.hasPrefix("@") {
            // Nested rules are not supported; only the declarations before them are used
            var bodyEnd = i + 1
            while bodyEnd < end && bytes[bodyEnd] != UInt8(ascii: "{") {
              bodyEnd += 1
            }
            rules.append((selectors: prelude, body: text((i + 1)..<bodyEnd)))
          }
          i = end + 1
          preludeStart = i
        case UInt8(ascii: ";"), UInt8(ascii: "}"):
          // A statement without a block (like `@import`), or a stray closing brace
          i += 1
          preludeStart = i
        default:
          i += 1
      }
    }
    return rules
  }

  /// Returns the declarations of a declaration block; the names are in lowercase. Values with
  /// a colon are not supported and skipped.
  private static func cssDeclarations(in body: String) -> [ThemeDeclaration] {
    var result: [ThemeDeclaration] = []
    for declaration in body.components(separatedBy: ";") {
      let parts = declaration.components(separatedBy: ":")
      guard parts.count == 2 else {
        continue
      }
      let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
      if let important = value.range(of: #"\s*!\s*important$"#,
                                     options: [.regularExpression, .caseInsensitive]) {
        value.removeSubrange(important)
      }
      if !name.isEmpty && !value.isEmpty {
        result.append(ThemeDeclaration(name: name, value: value))
      }
    }
    return result
  }

  /// Parses a selector. Returns `nil` if it is not supported.
  private static func parseSelector(_ text: String) -> Selector? {
    let scalars = Array(text.unicodeScalars)
    func isNameScalar(_ scalar: Unicode.Scalar) -> Bool {
      return (scalar >= "a" && scalar <= "z") || (scalar >= "A" && scalar <= "Z") ||
             (scalar >= "0" && scalar <= "9") || scalar == "-" || scalar == "_"
    }
    // The compound selectors with the combinator that connects them to the previous one
    var parts: [(classes: [String], combinator: Selector.Combinator)] = []
    var classes: [String] = []
    var open = false
    var nextCombinator = Selector.Combinator.descendant
    func close() {
      if open {
        parts.append((classes: classes, combinator: nextCombinator))
        classes = []
        open = false
        nextCombinator = .descendant
      }
    }
    var i = 0
    while i < scalars.count {
      let scalar = scalars[i]
      switch scalar {
        case " ", "\t", "\n", "\r", "\u{0C}":
          close()
          i += 1
        case ">":
          close()
          guard !parts.isEmpty, nextCombinator == .descendant else {
            return nil
          }
          nextCombinator = .child
          i += 1
        case ".":
          var end = i + 1
          while end < scalars.count && isNameScalar(scalars[end]) {
            end += 1
          }
          guard end > i + 1 else {
            return nil
          }
          var name = String.UnicodeScalarView()
          name.append(contentsOf: scalars[(i + 1)..<end])
          if !classes.contains(String(name)) {
            classes.append(String(name))
          }
          open = true
          i = end
        case "*":
          // Matches every element; only at the start of a compound selector
          guard !open else {
            return nil
          }
          open = true
          i += 1
        default:
          // A type selector is only allowed at the start of a compound selector
          guard isNameScalar(scalar), !open else {
            return nil
          }
          while i < scalars.count && isNameScalar(scalars[i]) {
            i += 1
          }
          open = true
      }
    }
    close()
    // A combinator needs a compound selector after it
    guard nextCombinator == .descendant, let subject = parts.last, !subject.classes.isEmpty else {
      return nil
    }
    // Compound selectors without classes (such as the `pre` of `pre code.hljs`) are dropped
    var compounds: [[String]] = []
    var combinators: [Selector.Combinator] = []
    var dropped = false
    for part in parts {
      if part.classes.isEmpty {
        dropped = true
      } else {
        if !compounds.isEmpty {
          combinators.append(dropped ? .descendant : part.combinator)
        }
        compounds.append(part.classes)
        dropped = false
      }
    }
    return Selector(compounds: compounds, combinators: combinators)
  }
}

#endif
