//
//  MermaidConfig.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 12/10/2026.
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
/// Configures how `MermaidRenderer` draws Mermaid diagrams, and how
/// `AttributedStringGenerator` places them in an attributed string. Passing a
/// `MermaidConfig` to the `mermaid:` parameter of `AttributedStringGenerator.init` enables
/// the rendering of fenced code blocks with the language `mermaid`.
///
/// Example:
/// ```swift
/// let generator = AttributedStringGenerator(mermaid: .default)
/// let text = try await generator.generateAsync(doc: document)
/// ```
///
public struct MermaidConfig: Hashable, Sendable {

  /// The Mermaid themes.
  public enum Theme: String, Hashable, Sendable {
    case `default`
    case neutral
    case dark
    case forest
    case base
  }

  /// The Mermaid theme. Diagrams are drawn on a transparent background, so use `.dark` (or
  /// `darkVariant`) for text views with a dark background and `.default` for light backgrounds.
  public var theme: Theme

  /// Overrides for Mermaid's theme variables (e.g. `["primaryColor": "#ffcc00"]`). See the
  /// Mermaid documentation for the supported names; the values are CSS colors.
  public var themeVariables: [String: String]

  /// The CSS font family used by the diagrams. If `nil`, Mermaid's default is used.
  public var fontFamily: String?

  /// The number of pixels per point of the images that are created. The default is 2.
  public var scale: CGFloat

  /// The width in points of the page which the diagrams are laid out on. Diagrams are never
  /// scaled up; a diagram that is wider than this gets scaled down to fit (the image is wider
  /// by the `margin` on both sides). The default is 800.
  public var width: CGFloat

  /// The margin in points around the diagram. Mermaid leaves empty space around its diagrams
  /// which depends on the type of the diagram (a sequence diagram that starts with an actor,
  /// for example, has about 100 points of it on the left). It is removed from the image, and
  /// this margin, which stops antialiased edges from being cut off, is added instead. If `nil`,
  /// the image keeps the margins that Mermaid has created. The default is 8.
  public var margin: CGFloat?

  /// If not `nil`, diagrams wider than this many points are scaled down to this width when
  /// they are placed into an attributed string. This does not change the image itself.
  public var maxWidth: CGFloat?

  /// The least space in points between a diagram in an attributed string and the text above
  /// and below it. As between the paragraphs of a web page, the space which the neighboring
  /// paragraphs have anyway counts: the distance is the larger one of this value and the
  /// paragraph spacing of the text. The default is 16.
  public var spacing: CGFloat

  /// The maximal time in seconds that rendering one diagram may take. The default is 5.
  public var timeout: TimeInterval

  /// Creates a configuration. All parameters have default values.
  public init(theme: Theme = .default,
              themeVariables: [String: String] = [:],
              fontFamily: String? = nil,
              scale: CGFloat = 2,
              width: CGFloat = 800,
              margin: CGFloat? = 8,
              maxWidth: CGFloat? = nil,
              spacing: CGFloat = 16,
              timeout: TimeInterval = 5) {
    self.theme = theme
    self.themeVariables = themeVariables
    self.fontFamily = fontFamily
    self.scale = scale
    self.width = width
    self.margin = margin
    self.maxWidth = maxWidth
    self.spacing = spacing
    self.timeout = timeout
  }

  /// The default configuration: Mermaid's default theme, for light backgrounds.
  public static let `default` = MermaidConfig()

  /// A configuration for dark backgrounds: Mermaid's dark theme.
  public static let dark = MermaidConfig(theme: .dark)

  /// The configuration to use for dark backgrounds if this one is meant for light backgrounds:
  /// it uses the dark theme instead of `.default`, `.neutral` and `.forest`. A configuration
  /// which already uses `.dark` or `.base` (a theme for which the colors are set explicitly
  /// via `themeVariables`) is returned unchanged.
  public var darkVariant: MermaidConfig {
    switch self.theme {
      case .default, .neutral, .forest:
        var result = self
        result.theme = .dark
        return result
      case .dark, .base:
        return self
    }
  }

  /// The parts of the configuration which determine what a rendered diagram looks like. The
  /// others (`maxWidth`, `spacing` and `timeout`) do not change the image.
  internal struct RenderKey: Hashable, Sendable {
    let theme: Theme
    let themeVariables: [String: String]
    let fontFamily: String?
    let scale: CGFloat
    let width: CGFloat
    let margin: CGFloat?
  }

  internal var renderKey: RenderKey {
    return RenderKey(theme: self.theme,
                     themeVariables: self.themeVariables,
                     fontFamily: self.fontFamily,
                     scale: self.scale > 0 ? self.scale : 2,
                     width: self.width > 0 ? self.width : 800,
                     margin: self.margin.map { max(0, $0) })
  }
}
