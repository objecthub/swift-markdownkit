//
//  MathConfig.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 17/10/2026.
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
/// The configuration for showing formulas as images in attributed strings (see
/// ``MathAttributedStringGenerator``).
///
public struct MathConfig: Sendable, Equatable {
  
  /// The default `MathConfig`.
  public static let `default` = MathConfig()

  /// The options for KaTeX: macros and limits. The kind of markup (`output`) is irrelevant: the
  /// formulas are always typeset as HTML, which is drawn into an image.
  public var katex: KaTeXOptions

  /// The number of pixels per point of the images that are created for formulas. The default is
  /// 3, which is sharp on all displays; the images are small (about 10 KB each).
  public var scale: CGFloat

  /// The least distance in points between a display formula, which is a block of its own, and the
  /// text above and below it. The system's HTML importer ignores the top margin of a paragraph,
  /// so the generator makes sure of this distance when it replaces the placeholder of the formula.
  /// The default is 8.
  public var spacing: CGFloat

  /// Formulas which are wider than this (in points) are scaled down to this width. The text view
  /// also scales a formula down to the width of its line if it does not fit. If `nil`, which is
  /// the default, only the latter happens.
  public var maxWidth: CGFloat?

  /// The longest time in seconds that rendering a batch of formulas may take (including loading
  /// the web view, if there is none yet). A formula that is not rendered in time is shown as
  /// code. The default is 15; at most 0 means no limit.
  public var timeout: TimeInterval

  /// Creates a configuration. See the properties for the meaning of the parameters.
  public init(katex: KaTeXOptions = KaTeXOptions(),
              scale: CGFloat = 3,
              spacing: CGFloat = 8,
              maxWidth: CGFloat? = nil,
              timeout: TimeInterval = 15) {
    self.katex = katex
    self.scale = scale
    self.spacing = spacing
    self.maxWidth = maxWidth
    self.timeout = timeout
  }

  /// What determines the image of a formula; the other properties only matter when the image is
  /// shown.
  struct RenderKey: Hashable, Sendable {
    let katex: KaTeXOptions
    let scale: CGFloat
  }

  var renderKey: RenderKey {
    var options = self.katex
    options.output = .html
    return RenderKey(katex: options, scale: max(self.scale, 1))
  }
}

///
/// The reasons why a formula cannot be rendered as an image.
///
public enum MathError: Error, Equatable, LocalizedError, Sendable {
  
  /// Images of formulas are only supported on macOS and iOS.
  case unsupportedPlatform
  
  /// The resources of KaTeX (the script, style sheet and fonts) were not found.
  case resourcesMissing
  
  /// KaTeX does not understand the formula. The parameter is its message.
  case syntaxError(String)
  
  /// The formula is longer than the given number of bytes, see ``KaTeXOptions/maxLength``.
  case tooLong(Int)
  
  /// Rendering took longer than ``MathConfig/timeout``.
  case timedOut
  
  /// The task that was rendering the formula was cancelled.
  case cancelled
  
  /// The web view failed. The parameter describes the failure.
  case renderingFailed(String)

  public var errorDescription: String? {
    switch self {
      case .unsupportedPlatform:
        return "Formulas can only be rendered on macOS and iOS"
      case .resourcesMissing:
        return "The resources of KaTeX are missing"
      case .syntaxError(let message):
        return message
      case .tooLong(let maxLength):
        return "The formula is longer than \(maxLength) bytes"
      case .timedOut:
        return "Rendering the formula timed out"
      case .cancelled:
        return "Rendering the formula was cancelled"
      case .renderingFailed(let message):
        return "Rendering the formula failed: \(message)"
    }
  }

  /// A short description for a note: the first line of the message of KaTeX.
  var summary: String {
    return (self.errorDescription ?? "").split(separator: "\n").first.map(String.init) ?? ""
  }
}

///
/// A formula: its LaTeX and whether it is typeset as display math.
///
public struct MathFormula: Hashable, Sendable {

  /// The LaTeX of the formula, without dollar signs.
  public let tex: String

  /// True for display math.
  public let display: Bool

  /// Creates a formula.
  public init(tex: String, display: Bool) {
    self.tex = tex
    self.display = display
  }
}

///
/// The image of a formula as ``MathRenderer`` creates it: black on a transparent background. The
/// colour of the formula is applied when it is shown in an attributed string (see
/// ``MathAttributedStringGenerator``).
///
public struct MathImage: Sendable, Equatable {

  /// The image as PNG data: the formula in black on a transparent background, with a margin.
  public let pngData: Data

  /// The size of the image in points, for the font size it was rendered with.
  public let size: CGSize

  /// The distance in points from the lower edge of the image up to the baseline of the formula.
  /// A formula within a line of text is shown that much below the baseline of the text.
  public let depth: CGFloat

  /// The number of pixels per point of the image.
  public let scale: CGFloat

  /// Creates an image.
  public init(pngData: Data, size: CGSize, depth: CGFloat, scale: CGFloat) {
    self.pngData = pngData
    self.size = size
    self.depth = depth
    self.scale = scale
  }
}

// MARK: - Finding formulas in Markdown

extension Block {

  /// The formulas in this block, in document order, without duplicates.
  var mathFormulas: [MathFormula] {
    var formulas: [MathFormula] = []
    var seen = Set<MathFormula>()
    self.collectMathFormulas(into: &formulas, seen: &seen)
    return formulas
  }

  /// Appends the formulas in this block and its sub-blocks to `formulas` in document order.
  /// Formulas that are in `seen` are skipped.
  func collectMathFormulas(into formulas: inout [MathFormula], seen: inout Set<MathFormula>) {
    func add(_ formula: MathFormula) {
      if seen.insert(formula).inserted {
        formulas.append(formula)
      }
    }
    func collect(_ text: Text) {
      for fragment in text {
        switch fragment {
          case .custom(let custom):
            if let math = custom as? MathFragment {
              add(MathFormula(tex: math.tex, display: math.display))
            }
          case .emph(let inner), .strong(let inner), .underline(let inner),
               .strikethrough(let inner), .link(let inner, _, _), .image(let inner, _, _):
            collect(inner)
          default:
            break
        }
      }
    }
    switch self {
      case .document(let blocks),
           .blockquote(let blocks),
           .list(_, _, let blocks),
           .listItem(_, _, let blocks):
        for block in blocks {
          block.collectMathFormulas(into: &formulas, seen: &seen)
        }
      case .paragraph(let text), .heading(_, let text):
        collect(text)
      case .table(let header, _, let rows):
        for cell in header {
          collect(cell)
        }
        for row in rows {
          for cell in row {
            collect(cell)
          }
        }
      case .definitionList(let definitions):
        for definition in definitions {
          collect(definition.item)
          for block in definition.descriptions {
            block.collectMathFormulas(into: &formulas, seen: &seen)
          }
        }
      case .custom(let custom):
        if let math = custom as? MathBlock {
          add(MathFormula(tex: math.tex, display: true))
        }
      default:
        break
    }
  }
}

extension ContiguousArray where Element == Block {

  /// The formulas in these blocks, in document order, without duplicates.
  var mathFormulas: [MathFormula] {
    var formulas: [MathFormula] = []
    var seen = Set<MathFormula>()
    for block in self {
      block.collectMathFormulas(into: &formulas, seen: &seen)
    }
    return formulas
  }
}
