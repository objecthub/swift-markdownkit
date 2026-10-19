//
//  AttributedStringStyleTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 19/10/2026.
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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

import XCTest
#if os(macOS) || os(iOS)
import SwiftUI
#endif
@testable import MarkdownKit

/// Tests for `AttributedStringGenerator.Style` and for the places which take a style: the
/// generators, `MarkdownUtil` and `MarkdownText`.
final class AttributedStringStyleTests: XCTestCase {

  typealias Style = AttributedStringGenerator.Style

  /// A style which differs from the default in every property.
  private var customStyle: Style {
    return Style(fontSize: 12,
                 fontFamily: "Georgia, serif",
                 fontColor: "#123456",
                 lineSpacing: 1.3,
                 codeFontSize: 11,
                 codeFontFamily: "Menlo, monospace",
                 codeFontColor: "#222222",
                 codeBlockFontSize: 10,
                 codeBlockFontColor: "#333333",
                 codeBlockLineSpacing: 1.2,
                 codeBlockBackground: "#eeeeee",
                 syntaxHighlighting: nil,
                 borderColor: "#dddddd",
                 blockquoteColor: "#ccddee",
                 headerFont: "Palatino, serif",
                 h1Color: "#110000",
                 h1FontSize: 30,
                 h2Color: "#220000",
                 h2FontSize: 26,
                 h3Color: "#330000",
                 h3FontSize: 22,
                 h4Color: "#440000",
                 h4FontSize: 18,
                 maxImageWidth: "300px",
                 maxImageHeight: "200px",
                 customStyle: "p { margin: 0 }")
  }

  /// The generator with the elements of `customStyle` as individual parameters.
  private func oldGenerator(version: AttributedStringGenerator.Version = .OS26) -> AttributedStringGenerator {
    return AttributedStringGenerator(version: version,
                                     fontSize: 12,
                                     fontFamily: "Georgia, serif",
                                     fontColor: "#123456",
                                     lineSpacing: 1.3,
                                     codeFontSize: 11,
                                     codeFontFamily: "Menlo, monospace",
                                     codeFontColor: "#222222",
                                     codeBlockFontSize: 10,
                                     codeBlockFontColor: "#333333",
                                     codeBlockLineSpacing: 1.2,
                                     codeBlockBackground: "#eeeeee",
                                     syntaxHighlighting: nil,
                                     borderColor: "#dddddd",
                                     blockquoteColor: "#ccddee",
                                     headerFont: "Palatino, serif",
                                     h1Color: "#110000",
                                     h1FontSize: 30,
                                     h2Color: "#220000",
                                     h2FontSize: 26,
                                     h3Color: "#330000",
                                     h3FontSize: 22,
                                     h4Color: "#440000",
                                     h4FontSize: 18,
                                     maxImageWidth: "300px",
                                     maxImageHeight: "200px",
                                     customStyle: "p { margin: 0 }")
  }

  private let sample = ExtendedMarkdownParser.standard.parse("""
    # Title

    Some *text* with `code`, and a [link](https://example.org/).

    > A quote

    ```swift
    let x = 1
    ```

    | A | B |
    | - | - |
    | 1 | 2 |
    """)

  // MARK: The style as a value

  func testTheDefaultsOfAStyleAreTheDefaultsOfAGenerator() {
    let style = Style()
    let generator = AttributedStringGenerator()
    XCTAssertEqual(style.fontSize, generator.fontSize)
    XCTAssertNil(style.fontFamily)
    XCTAssertEqual(style.fontColor, generator.fontColor)
    XCTAssertEqual(style.lineSpacing, generator.lineSpacing)
    XCTAssertEqual(style.codeFontSize, generator.codeFontSize)
    XCTAssertNil(style.codeFontFamily)
    XCTAssertEqual(style.codeFontColor, generator.codeFontColor)
    XCTAssertEqual(style.codeBlockFontSize, generator.codeBlockFontSize)
    XCTAssertEqual(style.codeBlockFontColor, generator.codeBlockFontColor)
    XCTAssertEqual(style.codeBlockLineSpacing, generator.codeBlockLineSpacing)
    XCTAssertEqual(style.codeBlockBackground, generator.codeBlockBackground)
    XCTAssertNotNil(style.syntaxHighlighting)
    XCTAssertEqual(style.borderColor, generator.borderColor)
    XCTAssertEqual(style.blockquoteColor, generator.blockquoteColor)
    XCTAssertEqual([style.h1Color, style.h2Color, style.h3Color, style.h4Color],
                   [generator.h1Color, generator.h2Color, generator.h3Color, generator.h4Color])
    XCTAssertNil(style.headerFont)
    XCTAssertNil(generator.headerFont)
    XCTAssertEqual([style.h1FontSize, style.h2FontSize, style.h3FontSize, style.h4FontSize],
                   [Float?](repeating: nil, count: 4))
    XCTAssertEqual([generator.h1FontSize, generator.h2FontSize, generator.h3FontSize, generator.h4FontSize],
                   [Float?](repeating: nil, count: 4))
    XCTAssertNil(style.maxImageWidth)
    XCTAssertNil(style.maxImageHeight)
    XCTAssertEqual(style.customStyle, "")
    XCTAssertEqual(generator.docStyle, AttributedStringGenerator(style: style).docStyle)
    XCTAssertEqual(generator.docStyle, AttributedStringGenerator(style: .default).docStyle)
  }

  func testAStyleIsCustomizedByChangingIt() {
    var style = Style.light
    style.fontSize = 17
    style.fontFamily = "Courier"
    style.h1Color = "#ff0000"
    style.customStyle = "em { color: green }"
    let generator = AttributedStringGenerator(style: style)
    XCTAssertEqual(generator.fontSize, 17)
    XCTAssertEqual(generator.fontFamily, "Courier")
    XCTAssertEqual(generator.h1Color, "#ff0000")
    XCTAssertEqual(generator.fontColor, "#000000")
    XCTAssertTrue(generator.docStyle.contains("font-size: 17.0px;"), generator.docStyle)
    XCTAssertTrue(generator.docStyle.contains("font-family: Courier;"), generator.docStyle)
    XCTAssertTrue(generator.docStyle.hasSuffix("em { color: green }\n"), generator.docStyle)
    // The style of the generator is the one it was created with
    XCTAssertEqual(generator.style.fontSize, 17)
    XCTAssertEqual(generator.style.fontFamily, "Courier")
  }

  func testThePresets() {
    // The colors of the presets are explicit (not those of the system), whatever the appearance is.
    // The palettes are free to change; what the presets stand for is the color of the text, the
    // theme of the syntax highlighting, and the sizes of the default style.
    let light = Style.light
    XCTAssertEqual(light.fontColor, "#000000")
    XCTAssertEqual(light.syntaxHighlighting?.theme, AttributedStringGenerator.SyntaxHighlightingConfig.default.theme)
    let dark = Style.dark
    XCTAssertEqual(dark.fontColor, "#FFF")
    XCTAssertEqual(dark.syntaxHighlighting?.theme, AttributedStringGenerator.SyntaxHighlightingConfig.defaultDark.theme)
    XCTAssertNotEqual(light.codeBlockBackground, dark.codeBlockBackground)
    for preset in [light, dark] {
      XCTAssertEqual(preset.fontSize, Style().fontSize)
      XCTAssertEqual(preset.codeFontSize, Style().codeFontSize)
      XCTAssertEqual(preset.codeBlockFontSize, Style().codeBlockFontSize)
      XCTAssertEqual(preset.lineSpacing, Style().lineSpacing)
      XCTAssertNil(preset.headerFont)
      XCTAssertNil(preset.h1FontSize)
    }
  }

  // MARK: Generators

  func testTheStyleInitializerIsTheSameAsTheInitializerWithAllTheElements() {
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      let old = self.oldGenerator(version: version)
      let new = AttributedStringGenerator(version: version, style: self.customStyle)
      XCTAssertEqual(old.docStyle, new.docStyle, "\(version)")
      XCTAssertTrue(new.docStyle.contains("font-size: 30.0px;font-family: Palatino, serif;color: #110000;"),
                    new.docStyle)
      XCTAssertEqual(old.headerFont, new.headerFont)
      XCTAssertEqual([old.h1FontSize, old.h2FontSize, old.h3FontSize, old.h4FontSize],
                     [new.h1FontSize, new.h2FontSize, new.h3FontSize, new.h4FontSize])
      XCTAssertEqual(new.h3FontSize, 22)
      XCTAssertEqual(old.fontFamily, new.fontFamily)
      XCTAssertEqual(old.codeFontFamily, new.codeFontFamily)
      XCTAssertEqual(old.maxImageWidth, new.maxImageWidth)
      XCTAssertEqual(old.maxImageHeight, new.maxImageHeight)
      XCTAssertEqual(old.style.customStyle, new.style.customStyle)
    }
  }

  func testTheStyleInitializerOfTheMathGenerator() {
    let old = MathAttributedStringGenerator(fontSize: 12, fontFamily: "Georgia, serif", fontColor: "#123456",
                                            headerFont: "Palatino", h1Color: "#110000", h1FontSize: 30,
                                            h4FontSize: 15, customStyle: "p { margin: 0 }")
    var style = Style()
    style.fontSize = 12
    style.fontFamily = "Georgia, serif"
    style.fontColor = "#123456"
    style.headerFont = "Palatino"
    style.h1Color = "#110000"
    style.h1FontSize = 30
    style.h4FontSize = 15
    style.customStyle = "p { margin: 0 }"
    let new = MathAttributedStringGenerator(style: style)
    XCTAssertEqual(old.docStyle, new.docStyle)
    XCTAssertEqual(new.fontSize, 12)
    XCTAssertEqual(new.fontColor, "#123456")
    XCTAssertEqual(new.style.h1Color, "#110000")
    XCTAssertEqual(new.headerFont, "Palatino")
    XCTAssertEqual(new.h1FontSize, 30)
    XCTAssertNil(new.h2FontSize)
  }

  func testAnEmptyFontFamilyAndNoFontFamilyAreTheDefaultOfTheVersion() {
    let system = "system-ui, -apple-system, 'Helvetica Neue', Helvetica, sans-serif"
    XCTAssertEqual(AttributedStringGenerator(style: Style()).fontFamily, system)
    XCTAssertEqual(AttributedStringGenerator(style: Style(fontFamily: "")).fontFamily, system)
    XCTAssertEqual(AttributedStringGenerator(fontFamily: "").fontFamily, system)
    XCTAssertEqual(AttributedStringGenerator(version: .preOS26, style: Style()).fontFamily,
                   "\"Times New Roman\",Times,serif")
    XCTAssertEqual(AttributedStringGenerator(version: .preOS26, style: Style(fontFamily: "Palatino")).fontFamily,
                   "Palatino")
    XCTAssertTrue(AttributedStringGenerator(style: Style()).codeFontFamily.contains("monospace"))
    XCTAssertEqual(AttributedStringGenerator(style: Style(codeFontFamily: "Menlo")).codeFontFamily, "Menlo")
  }

  func testTheSyntaxHighlightingOfAStyleIsUsed() {
    XCTAssertNil(AttributedStringGenerator(style: Style(syntaxHighlighting: nil)).codeBlockHighlightingConfig)
    let highlighted = AttributedStringGenerator(style: Style(syntaxHighlighting: .init(theme: ".hljs{color:#f00}",
                                                                                         ignoredLanguages: ["foo"])))
    XCTAssertNotNil(highlighted.codeBlockHighlightingConfig)
    XCTAssertEqual(highlighted.ignoredLanguages, ["foo"])
    XCTAssertTrue(highlighted.highlightIndentedCodeBlocks)
  }

  func testStylePropertiesAreInTheStyleSheet() {
    var style = Style()
    style.blockquoteColor = "#ab1234"
    style.codeBlockBackground = "#012345"
    let sheet = AttributedStringGenerator(style: style).docStyle
    XCTAssertTrue(sheet.contains("#ab1234"), sheet)
    XCTAssertTrue(sheet.contains("#012345"), sheet)
    XCTAssertNotEqual(sheet, AttributedStringGenerator().docStyle)
  }

  func testTheFontSizesOfHeadingsAreRelativeToTheBaseFontSizeUnlessTheyAreSet() {
    var style = Style()
    style.fontSize = 20
    let relative = AttributedStringGenerator(style: style)
    XCTAssertTrue(relative.h1Style.hasPrefix("font-size: 26.0px;"), relative.h1Style)
    XCTAssertTrue(relative.h2Style.hasPrefix("font-size: 24.0px;"), relative.h2Style)
    XCTAssertTrue(relative.h3Style.hasPrefix("font-size: 22.0px;"), relative.h3Style)
    XCTAssertTrue(relative.h4Style.hasPrefix("font-size: 21.0px;"), relative.h4Style)
    style.h2FontSize = 40
    style.h4FontSize = 12.5
    let custom = AttributedStringGenerator(style: style)
    XCTAssertTrue(custom.h1Style.hasPrefix("font-size: 26.0px;"), custom.h1Style)
    XCTAssertTrue(custom.h2Style.hasPrefix("font-size: 40.0px;"), custom.h2Style)
    XCTAssertTrue(custom.h3Style.hasPrefix("font-size: 22.0px;"), custom.h3Style)
    XCTAssertTrue(custom.h4Style.hasPrefix("font-size: 12.5px;"), custom.h4Style)
    XCTAssertNil(custom.h1FontSize)
    XCTAssertEqual(custom.h2FontSize, 40)
    // No declaration is repeated or empty
    for sheet in [custom.h1Style, custom.h2Style, custom.h3Style, custom.h4Style] {
      XCTAssertFalse(sheet.contains(";;"), sheet)
    }
  }

  func testHeadingsHaveNoFontUnlessTheStyleHasOne() {
    let plain = AttributedStringGenerator(style: Style())
    let headings = { (generator: AttributedStringGenerator) in
      [generator.h1Style, generator.h2Style, generator.h3Style, generator.h4Style]
    }
    for sheet in headings(plain) {
      XCTAssertFalse(sheet.contains("font-family"), sheet)
    }
    // An empty font is no font
    XCTAssertEqual(AttributedStringGenerator(style: Style(headerFont: "")).docStyle, plain.docStyle)
    // A font is set for all four levels, and only for them
    let styled = AttributedStringGenerator(style: Style(headerFont: "Palatino, serif"))
    XCTAssertEqual(styled.headerFont, "Palatino, serif")
    for sheet in headings(styled) {
      XCTAssertTrue(sheet.contains("font-family: Palatino, serif;"), sheet)
    }
    XCTAssertEqual(styled.docStyle.components(separatedBy: "font-family: Palatino, serif;").count - 1, 4)
    XCTAssertFalse(styled.bodyStyle.contains("Palatino"))
    XCTAssertFalse(styled.codeStyle.contains("Palatino"))
    // The rest of the style sheet is the same
    XCTAssertEqual(styled.docStyle.replacingOccurrences(of: "font-family: Palatino, serif;", with: ""),
                   plain.docStyle)
  }

  // MARK: Generated attributed strings

  #if os(macOS) || os(iOS)

  /// The red, green and blue components of a color (0 to 1).
  private func components(of color: HRColor?) -> [Double]? {
    guard let color else {
      return nil
    }
    #if os(macOS)
    guard let rgb = color.usingColorSpace(.sRGB) else {
      return nil
    }
    return [Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent)]
    #else
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
      return nil
    }
    return [Double(red), Double(green), Double(blue)]
    #endif
  }

  /// The font size and the color of the first occurrence of `text` in `string`. Black text has no
  /// color attribute (it is the default of attributed strings), which is why it is reported as black.
  private func attributes(of text: String, in string: NSAttributedString) throws -> (size: CGFloat, color: [Double]) {
    let range = (string.string as NSString).range(of: text)
    XCTAssertNotEqual(range.location, NSNotFound, text)
    let font = try XCTUnwrap(string.attribute(.font, at: range.location, effectiveRange: nil) as? HRFont)
    let color = string.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? HRColor
    return (font.pointSize, color == nil ? [0, 0, 0] : try XCTUnwrap(self.components(of: color), "color"))
  }

  /// What the attributes of a string say about its look: font, colors and the numbers of the
  /// paragraphs, per run. (Strings are not compared with `isEqual`: the text blocks and the
  /// lists of paragraph styles are objects that equal only themselves.)
  private func signature(of string: NSAttributedString) -> [String] {
    var result: [String] = []
    string.enumerateAttributes(in: NSRange(location: 0, length: string.length)) { attributes, range, _ in
      var parts = ["\(range)"]
      if let font = attributes[.font] as? HRFont {
        parts.append("\(font.fontName) \(font.pointSize)")
      }
      for key in [NSAttributedString.Key.foregroundColor, .backgroundColor] {
        parts.append("\(String(describing: self.components(of: attributes[key] as? HRColor)))")
      }
      if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle {
        parts.append("\(paragraph.lineHeightMultiple) \(paragraph.paragraphSpacing) \(paragraph.headIndent) "
                     + "\(paragraph.firstLineHeadIndent) \(paragraph.textBlocks.count)")
      }
      result.append(parts.joined(separator: " | "))
    }
    return result
  }

  @MainActor
  func testHeadingsHaveTheSizesAndTheFontOfTheStyle() throws {
    var style = Style.light
    style.headerFont = "Courier"
    style.h1FontSize = 30
    style.h3FontSize = 17
    let doc = ExtendedMarkdownParser.standard.parse("# One\n\n## Two\n\n### Three\n\n#### Four\n\nBody text\n")
    func font(_ text: String, in string: NSAttributedString) throws -> HRFont {
      let range = (string.string as NSString).range(of: text)
      XCTAssertNotEqual(range.location, NSNotFound, text)
      return try XCTUnwrap(string.attribute(.font, at: range.location, effectiveRange: nil) as? HRFont)
    }
    let string = try XCTUnwrap(AttributedStringGenerator(style: style).generate(doc: doc))
    // The sizes are set (One, Three) or relative to the base size of 14 (Two, Four)
    XCTAssertEqual(try font("One", in: string).pointSize, 30, accuracy: 0.5)
    XCTAssertEqual(try font("Two", in: string).pointSize, 18, accuracy: 0.5)
    XCTAssertEqual(try font("Three", in: string).pointSize, 17, accuracy: 0.5)
    XCTAssertEqual(try font("Four", in: string).pointSize, 15, accuracy: 0.5)
    for heading in ["One", "Two", "Three", "Four"] {
      XCTAssertTrue(try font(heading, in: string).fontName.contains("Courier"), heading)
    }
    XCTAssertFalse(try font("Body", in: string).fontName.contains("Courier"))
    XCTAssertEqual(try font("Body", in: string).pointSize, 14, accuracy: 0.5)
    // Without a header font, the headings have the font of the text
    let plain = try XCTUnwrap(AttributedStringGenerator(style: .light).generate(doc: doc))
    for heading in ["One", "Two", "Three", "Four"] {
      XCTAssertFalse(try font(heading, in: plain).fontName.contains("Courier"), heading)
    }
    XCTAssertEqual(try font("One", in: plain).pointSize, 20, accuracy: 0.5)
  }

  @MainActor
  func testTheStyleInitializerGeneratesTheSameStringsAsTheInitializerWithAllTheElements() throws {
    let old = try XCTUnwrap(self.oldGenerator().generate(doc: self.sample))
    let new = try XCTUnwrap(AttributedStringGenerator(style: self.customStyle).generate(doc: self.sample))
    XCTAssertEqual(old.string, new.string)
    XCTAssertEqual(self.signature(of: old), self.signature(of: new))
    let plain = try XCTUnwrap(AttributedStringGenerator().generate(doc: self.sample))
    XCTAssertNotEqual(self.signature(of: plain), self.signature(of: new))
    let explicitDefault = try XCTUnwrap(AttributedStringGenerator(style: .default).generate(doc: self.sample))
    XCTAssertEqual(self.signature(of: plain), self.signature(of: explicitDefault))
  }

  @MainActor
  func testAStyleDeterminesSizeAndColorOfTheText() throws {
    var style = Style.light
    style.fontSize = 20
    style.fontColor = "#ff0000"
    let doc = ExtendedMarkdownParser.standard.parse("Plain paragraph.\n")
    let generated = try attributes(of: "Plain", in: try XCTUnwrap(AttributedStringGenerator(style: style).generate(doc: doc)))
    XCTAssertEqual(generated.size, 20, accuracy: 0.5)
    XCTAssertEqual(generated.color, [1, 0, 0])
    let defaults = try attributes(of: "Plain", in: try XCTUnwrap(AttributedStringGenerator(style: .light).generate(doc: doc)))
    XCTAssertEqual(defaults.size, 14, accuracy: 0.5)
    XCTAssertEqual(defaults.color, [0, 0, 0])
  }

  // MARK: MarkdownUtil

  func testTheStyleOfAUtilityIsLight() {
    XCTAssertEqual(MarkdownUtil.standard.style.fontColor, "#000000")
    XCTAssertEqual(MarkdownUtil().style.codeBlockBackground, Style.light.codeBlockBackground)
  }

  func testTheStyleOfAUtilityDeterminesItsDocuments() async throws {
    var style = Style.light
    style.fontSize = 20
    style.fontColor = "#00ff00"
    let doc = ExtendedMarkdownParser.standard.parse("Plain paragraph.\n")
    let options = AttributedStringGenerator.RenderingOptions(remoteImages: .none)
    // RTF: read back
    let rtf = try await MarkdownUtil(style: style).rtf(doc, renderingOptions: options)
    let readBack = try NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                          documentAttributes: nil)
    let fromRtf = try self.attributes(of: "Plain", in: readBack)
    XCTAssertEqual(fromRtf.size, 20, accuracy: 0.5)
    XCTAssertEqual(fromRtf.color[1], 1, accuracy: 0.02)
    XCTAssertEqual(fromRtf.color[0], 0, accuracy: 0.02)
    // The default style gives black text
    let plain = try await MarkdownUtil.standard.rtf(doc, renderingOptions: options)
    let plainRead = try NSAttributedString(data: plain, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                           documentAttributes: nil)
    XCTAssertEqual(try self.attributes(of: "Plain", in: plainRead).color, [0, 0, 0])
    // The generators of RTFD and PDF documents have the style
    let generator = MarkdownUtil(style: style).documentGenerator(maxImageWidth: 400, diagramMaxWidth: 400,
                                                                 renderingOptions: options)
    XCTAssertEqual(generator.fontSize, 20)
    XCTAssertEqual(generator.fontColor, "#00ff00")
  }

  // MARK: MarkdownText

  @available(macOS 14.0, iOS 17.0, *)
  @MainActor
  func testMarkdownTextUsesTheStylesForLightAndDarkMode() throws {
    let doc = ExtendedMarkdownParser.standard.parse("Plain paragraph.\n")
    var light = Style.light
    light.fontSize = 18
    light.fontColor = "#0000ff"
    var dark = Style.dark
    dark.fontSize = 22
    dark.fontColor = "#ffff00"
    let generate = MarkdownText.defaultGenerator(.trusted, style: light, darkStyle: dark)
    let inLightMode = try attributes(of: "Plain", in: try XCTUnwrap(generate(doc, .light)))
    XCTAssertEqual(inLightMode.size, 18, accuracy: 0.5)
    XCTAssertEqual(inLightMode.color, [0, 0, 1])
    let inDarkMode = try attributes(of: "Plain", in: try XCTUnwrap(generate(doc, .dark)))
    XCTAssertEqual(inDarkMode.size, 22, accuracy: 0.5)
    XCTAssertEqual(inDarkMode.color, [1, 1, 0])
  }

  @available(macOS 14.0, iOS 17.0, *)
  @MainActor
  func testMarkdownTextHasTheDefaultStylesWithoutStyles() throws {
    let doc = ExtendedMarkdownParser.standard.parse("Plain paragraph.\n")
    let generate = MarkdownText.defaultGenerator(.trusted)
    let dark = try attributes(of: "Plain", in: try XCTUnwrap(generate(doc, .dark)))
    XCTAssertEqual(dark.size, 14, accuracy: 0.5)
    XCTAssertEqual(dark.color, [1, 1, 1])
    // Only one of the styles can be given
    let onlyLight = MarkdownText.defaultGenerator(.trusted, style: Style(fontSize: 19))
    XCTAssertEqual(try attributes(of: "Plain", in: try XCTUnwrap(onlyLight(doc, .light))).size, 19, accuracy: 0.5)
    XCTAssertEqual(try attributes(of: "Plain", in: try XCTUnwrap(onlyLight(doc, .dark))).size, 14, accuracy: 0.5)
    let onlyDark = MarkdownText.defaultGenerator(.trusted, darkStyle: Style.dark.with(fontSize: 21))
    XCTAssertEqual(try attributes(of: "Plain", in: try XCTUnwrap(onlyDark(doc, .dark))).size, 21, accuracy: 0.5)
    XCTAssertEqual(try attributes(of: "Plain", in: try XCTUnwrap(onlyDark(doc, .light))).size, 14, accuracy: 0.5)
  }

  @available(macOS 14.0, iOS 17.0, *)
  @MainActor
  func testMarkdownTextTakesStylesInItsInitializers() {
    let doc = ExtendedMarkdownParser.standard.parse("Text")
    _ = MarkdownText(doc, style: .light, darkStyle: .dark)
    _ = MarkdownText(string: "Text", style: Style(fontSize: 16))
  }

  #endif
}

private extension AttributedStringGenerator.Style {
  /// This style with another font size.
  func with(fontSize: Float) -> AttributedStringGenerator.Style {
    var copy = self
    copy.fontSize = fontSize
    return copy
  }
}

#endif
