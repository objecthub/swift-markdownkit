//
//  MarkdownUtil+PDF.swift
//  MarkdownKit
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

#if os(macOS) || os(iOS)

import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// The method which turns a Markdown document into a PDF document (macOS and iOS).
extension MarkdownUtil {

  /// The reasons why a PDF document cannot be created.
  public enum PDFError: Error, Equatable, LocalizedError {
    /// The page is too small for the margins: there is no room for the text.
    case noRoomForText
    /// The system could not create a PDF document.
    case cannotCreateDocument

    public var errorDescription: String? {
      switch self {
        case .noRoomForText:
          return "The page is not large enough for its margins"
        case .cannotCreateDocument:
          return "The PDF document cannot be created"
      }
    }
  }

  /// The size in points of a page of the format US Letter, which is the default size of the pages
  /// of ``pdf(_:title:author:pageSize:margins:mermaid:math:imageBaseUrl:renderingOptions:)``.
  public static let usLetter = CGSize(width: 612, height: 792)

  /// The size in points of a page of the format A4.
  public static let a4 = CGSize(width: 595, height: 842)

  /// The number of points of the units that `pageSize(_:)` and `Insets.init(_:)` accept.
  fileprivate static let lengthUnits: [(suffix: String, points: Double)] = [
    ("pt", 1), ("in", 72), ("mm", 72 / 25.4), ("cm", 72 / 2.54)
  ]

  /// Returns the number of points of `text`: a number, with a unit (`pt`, `in`, `mm` or `cm`)
  /// or without one (points). `nil` if it is no length, or less than 0.
  internal static func length(_ text: String,
                              defaultPoints: Double = 1) -> (value: Double, unit: Double?)? {
    let text = text.trimmingCharacters(in: .whitespaces).lowercased()
    var number = text
    var unit: Double?
    for candidate in MarkdownUtil.lengthUnits where text.hasSuffix(candidate.suffix) {
      number = String(text.dropLast(candidate.suffix.count))
      unit = candidate.points
      break
    }
    guard let value = Double(number.trimmingCharacters(in: .whitespaces)),
          value.isFinite,
          value >= 0 else {
      return nil
    }
    return (value * (unit ?? defaultPoints), unit)
  }

  /// Returns the size of the pages of a PDF document that `description` stands for, or `nil` if
  /// it does not describe a size. It is the name of a page format, `letter` (``usLetter``) or
  /// `a4` (``a4``), or a width and a height separated by `x`, in points, or in the unit that
  /// follows the numbers: `pt`, `in`, `mm` or `cm`. The unit of the height is the one of the
  /// width, if the width has none (`210x297mm`).
  ///
  /// ```swift
  /// MarkdownUtil.pageSize("a4")          // 595 x 842 points
  /// MarkdownUtil.pageSize("8.5x11in")    // 612 x 792 points
  /// MarkdownUtil.pageSize("200x300")     // 200 x 300 points
  /// ```
  public static func pageSize(_ description: String) -> CGSize? {
    switch description.trimmingCharacters(in: .whitespaces).lowercased() {
      case "letter", "usletter", "us-letter":
        return MarkdownUtil.usLetter
      case "a4":
        return MarkdownUtil.a4
      case let text:
        let parts = text.split(separator: "x", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2,
              let height = MarkdownUtil.length(parts[1]),
              let width = MarkdownUtil.length(parts[0], defaultPoints: height.unit ?? 1),
              width.value > 0, height.value > 0 else {
          return nil
        }
        return CGSize(width: width.value, height: height.value)
    }
  }

  /// The size of the text of a PDF document relative to the other formats: the text of a page
  /// that is printed is smaller than the text of a text view (14 points become about 10 points).
  static let pdfTextScale = 0.7071

  /// Returns the document as a PDF document: the content of a `.pdf` file. The text, lists,
  /// tables, quotes and code blocks are laid out as they are in a text view, in the width of
  /// the pages, and are broken into pages. Diagrams (see <doc:DrawingMermaidDiagrams>) and
  /// formulas (see <doc:MathematicalFormulas>) are drawn as images. All diagrams are scaled
  /// alike, so that a diagram of the width of a page for which Mermaid draws (the `width` of
  /// `mermaid`, 800 points by default) fills the text of a page; formulas are scaled down if
  /// they are wider than the text.
  /// The numbers and bullets of lists sit on the baseline of the first line of their items.
  /// Links are clickable (except those to a place in the same document, `#name`).
  ///
  /// This method is available on macOS and iOS. It draws diagrams and formulas with the
  /// renderers of the utility, which take a moment for the first image.
  ///
  /// - Parameters:
  ///   - doc: The Markdown document, or a part of it.
  ///   - title: The title of the document, which becomes one of its properties.
  ///   - author: The author of the document, which becomes one of its properties.
  ///   - pageSize: The size of a page in points: ``usLetter`` (the default) or ``a4``,
  ///               for example; ``pageSize(_:)`` reads a size from text, such as `210x297mm`.
  ///   - margins: The space in points between the text and the edges of a page. The default is
  ///              one inch on each edge. `Insets("20mm")` reads margins from text.
  ///   - mermaid: How diagrams are drawn: theme, scale, the width of the page they are laid out
  ///              on, and more (see <doc:DrawingMermaidDiagrams>). The default draws them for a
  ///              light background. The `maxWidth` of the configuration is the greatest width
  ///              in points that a diagram has on the pages of the document, after the scaling
  ///              that all diagrams get.
  ///   - math: How formulas are typeset and shown: macros, scale, and more (see
  ///           <doc:MathematicalFormulas>). Its `maxWidth` limits the width of a formula on the
  ///           pages; formulas are never wider than the text.
  ///   - imageBaseUrl: The URL against which the relative paths of images are resolved, see
  ///                   ``AttributedStringGenerator/imageBaseUrl``. Use a URL with a trailing slash
  ///                   for a directory. If `nil`, they are resolved against the `baseUrl` of
  ///                   `renderingOptions`.
  ///   - renderingOptions: The options for rendering the document, which restrict what it can
  ///                       load (see <doc:RenderingUntrustedMarkdown>). The text of a PDF
  ///                       document is about 70% as large as in the other formats (the text of
  ///                       a page is smaller than the text of a view: 14 points become about
  ///                       10 points), and so are the formulas; its `textSizeMultiplier` scales
  ///                       it further.
  /// - Throws: A ``PDFError`` if the pages have no room for text or the system cannot create
  ///           the document, or a ``AttributedStringGenerator/RenderingError`` if the document
  ///           cannot be rendered.
  public func pdf(_ doc: Block,
                  title: String? = nil,
                  author: String? = nil,
                  pageSize: CGSize = MarkdownUtil.usLetter,
                  margins: Insets = Insets(72),
                  mermaid: MermaidConfig = .default,
                  math: MathConfig = .default,
                  imageBaseUrl: URL? = nil,
                  renderingOptions: AttributedStringGenerator.RenderingOptions = .trusted)
                async throws -> Data {
    let textSize = CGSize(width: pageSize.width - margins.left - margins.right,
                          height: pageSize.height - margins.top - margins.bottom)
    guard textSize.width >= 36, textSize.height >= 36 else {
      throw PDFError.noRoomForText
    }
    let string = try await self.pdfAttributedString(doc,
                                                    textWidth: textSize.width,
                                                    mermaid: mermaid,
                                                    math: math,
                                                    imageBaseUrl: imageBaseUrl,
                                                    renderingOptions: renderingOptions)
    return try Self.pdfData(from: string,
                            title: title,
                            author: author,
                            pageSize: pageSize,
                            margins: margins,
                            textSize: textSize)
  }

  /// Returns the attributed string for the pages of a PDF document: the text is about 70%
  /// as large as in the other formats, the diagrams have one scale, and formulas are not
  /// wider than the text.
  ///
  /// Mermaid draws a diagram for a page of `mermaid.width` points (800 by default),
  /// where it has the size which the diagram needs. All diagrams get the same scale, which
  /// is the one that makes a diagram that fills such a page fill the text of a page: they
  /// are shown at one size relative to each other (a diagram which is wider than another
  /// one has smaller text only if it is also wider on the page), and the text of a diagram
  /// is a little smaller than the text of the document. A diagram is never made larger
  /// than it is, and it is scaled down further if it is wider than the room which the text
  /// has for it (in a list or a quote), or than `mermaid.maxWidth`. The latter is the width
  /// on the page, so the generator does not apply it: it comes after the scale of the page.
  func pdfAttributedString(_ doc: Block,
                           textWidth: CGFloat,
                           mermaid: MermaidConfig = .default,
                           math: MathConfig = .default,
                           imageBaseUrl: URL? = nil,
                           renderingOptions: AttributedStringGenerator.RenderingOptions)
                         async throws -> NSAttributedString {
    var diagrams = mermaid
    diagrams.maxWidth = nil
    let generator = self.documentGenerator(
      maxImageWidth: textWidth,
      diagramMaxWidth: nil,
      mermaid: diagrams,
      math: math,
      imageBaseUrl: imageBaseUrl,
      renderingOptions: renderingOptions.scalingText(by: Self.pdfTextScale))
    let string = try await generator.generateAsync(doc: doc)
    Self.scalingDiagrams(in: string,
                         by: min(1, textWidth / mermaid.renderKey.width),
                         maxWidth: Self.narrowest(mermaid.maxWidth))
    return string
  }

  /// Scales the diagrams (not the other images) in `string` by `factor`, and then down to
  /// `maxWidth` if they are wider. They are the attachments of a string that the generator
  /// has just created, which nobody else uses.
  static func scalingDiagrams(in string: NSAttributedString,
                              by factor: CGFloat,
                              maxWidth: CGFloat? = nil) {
    string.enumerateAttribute(.attachment, in: NSRange(location: 0, length: string.length)) {
      value, _, _ in
        guard let diagram = value as? MermaidDiagramContext.MermaidTextAttachment,
              diagram.diagramSize.width > 0 else {
          return
        }
        var size = CGSize(width: diagram.diagramSize.width * factor,
                          height: diagram.diagramSize.height * factor)
        if let maxWidth, size.width > maxWidth {
          size = CGSize(width: maxWidth, height: size.height * maxWidth / size.width)
        }
        diagram.diagramSize = size
        diagram.bounds = CGRect(origin: .zero, size: size)
        #if os(macOS)
        diagram.image?.size = size
        #endif
    }
  }

  /// Lays out `string` in one container which is as wide as the text and as tall as it needs to
  /// be (text views lay out tables correctly only in one container), and draws it into a PDF
  /// document, page by page.
  private static func pdfData(from string: NSAttributedString,
                              title: String?,
                              author: String?,
                              pageSize: CGSize,
                              margins: Insets,
                              textSize: CGSize) throws -> Data {
    let storage = NSTextStorage(attributedString: string)
    let layout = NSLayoutManager()
    storage.addLayoutManager(layout)
    let container = NSTextContainer(size: CGSize(width: textSize.width,
                                                 height: CGFloat.greatestFiniteMagnitude))
    container.lineFragmentPadding = 0
    layout.addTextContainer(container)
    layout.ensureLayout(for: container)
    // The page is as wide as the text, so the first line of a list item is known now
    if ListMarkers.align(storage, layoutManager: layout) {
      layout.ensureLayout(for: container)
    }
    let pages = Self.pageRanges(of: layout,
                                in: container,
                                storage: storage,
                                pageHeight: textSize.height)
    var auxiliary: [CFString: Any] = [kCGPDFContextCreator: "MarkdownKit"]
    if let title {
      auxiliary[kCGPDFContextTitle] = title
    }
    if let author {
      auxiliary[kCGPDFContextAuthor] = author
    }
    var mediaBox = CGRect(origin: .zero, size: pageSize)
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data),
          let context = CGContext(consumer: consumer,
                                  mediaBox: &mediaBox,
                                  auxiliary as CFDictionary) else {
      throw PDFError.cannotCreateDocument
    }
    let links = Self.linkRects(in: storage, layout: layout, container: container)
    // The text system of macOS makes links of the text it draws clickable, the one of iOS
    // does not: draw text without links, and make them clickable here, so that it is the
    // same on both (the color and the underline of a link are attributes of their own)
    storage.removeAttribute(.link, range: NSRange(location: 0, length: storage.length))
    let textArea = CGRect(x: margins.left,
                          y: pageSize.height - margins.top - textSize.height,
                          width: textSize.width,
                          height: textSize.height)
    for page in pages {
      context.beginPDFPage(nil)
      context.saveGState()
      // The text system draws downwards from the upper left corner of the text
      context.translateBy(x: 0, y: pageSize.height)
      context.scaleBy(x: 1, y: -1)
      context.translateBy(x: margins.left, y: margins.top)
      context.clip(to: CGRect(origin: .zero, size: textSize))
      context.translateBy(x: 0, y: -page.minY)
      Self.draw(page, of: layout, in: container, into: context)
      context.restoreGState()
      // The links of the lines on this page, in the coordinates of the page (the origin
      // is in the lower left corner)
      for link in links where link.rect.midY >= page.minY && link.rect.midY < page.maxY {
        let rect = CGRect(x: margins.left + link.rect.minX,
                          y: pageSize.height - margins.top - (link.rect.maxY - page.minY),
                          width: link.rect.width,
                          height: link.rect.height).intersection(textArea)
        if !rect.isNull && !rect.isEmpty {
          context.setURL(link.url as CFURL, for: rect)
        }
      }
      context.endPDFPage()
    }
    context.closePDF()
    return data as Data
  }

  /// A line of text, as the paginator sees it.
  private struct PageLine {
    let top: CGFloat
    let bottom: CGFloat
    /// The table row of the outermost table cell that contains the line, if any (the lines of a
    /// list item, a code block or a row of a table).
    let row: [Int]?
    /// True if the line is in a table cell (a list, a quote, a code block or a table).
    let inCell: Bool
    /// True if the line is a paragraph of its own with bold text outside of a table cell,
    /// such as a heading, which should not be the last line of a page.
    let isHeading: Bool
  }

  /// How far above its first line the text of a cell starts: a page that starts with a table
  /// cell starts that far above the first line, so that the border and the padding of a cell
  /// are there.
  private static let cellEdge: CGFloat = 8

  /// Returns the parts of the text, from top to bottom, that fill the pages: each is at most
  /// `pageHeight` points tall and starts and ends between two lines of text, so that no line is
  /// cut by the border of a page. (The lines of the cells of a table are next to each other: a
  /// border is also not placed where any of them is.) A page does not end inside of a table row
  /// (a list item, a code block, a row of a table), unless the row is taller than a page, and a
  /// heading is not the last line of a page. Only if a line is taller than a page, it is cut.
  private static func pageRanges(of layout: NSLayoutManager,
                                 in container: NSTextContainer,
                                 storage: NSTextStorage,
                                 pageHeight: CGFloat) -> [CGRect] {
    let width = container.size.width
    let total = layout.usedRect(for: container).maxY
    let text = storage.string as NSString
    var lines: [PageLine] = []
    layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0,
                                                         length: layout.numberOfGlyphs)) {
      rect, _, _, glyphs, _ in
        let characters = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        let style = storage.attribute(.paragraphStyle, at: characters.location, effectiveRange: nil) as? NSParagraphStyle
        var row: [Int]?
        if let cell = style?.textBlocks.first as? NSTextTableBlock {
          row = [ObjectIdentifier(cell.table).hashValue, cell.startingRow]
        }
        var isHeading = false
        if style?.textBlocks.isEmpty ?? true {
          let paragraph = text.paragraphRange(for: NSRange(location: characters.location, length: 0))
          let contents = NSRange(
            location: paragraph.location,
            length: text.range(of: "\n", range: paragraph).location == NSNotFound
                      ? paragraph.length
                      : text.range(of: "\n", range: paragraph).location - paragraph.location)
          if NSMaxRange(characters) >= NSMaxRange(contents),
             characters.location <= contents.location,
             let font = storage.attribute(.font, at: characters.location, effectiveRange: nil) as? HRFont {
            #if os(macOS)
            isHeading = font.fontDescriptor.symbolicTraits.contains(.bold)
            #else
            isHeading = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            #endif
          }
        }
        lines.append(PageLine(top: rect.minY, bottom: rect.maxY, row: row,
                              inCell: style.map { !$0.textBlocks.isEmpty } ?? false,
                              isHeading: isHeading))
    }
    // The extent of each table row
    var rows: [[Int]: (top: CGFloat, bottom: CGFloat)] = [:]
    for line in lines {
      if let row = line.row {
        let extent = rows[row] ?? (line.top, line.bottom)
        rows[row] = (min(extent.top, line.top), max(extent.bottom, line.bottom))
      }
    }
    let rowExtents = rows.values.filter { $0.bottom - $0.top <= pageHeight }
    var pages: [CGRect] = []
    var top: CGFloat = 0
    while top < total {
      var bottom = top + pageHeight
      if bottom >= total {
        pages.append(CGRect(x: 0, y: top, width: width, height: total - top))
        break
      }
      var moved = true
      while moved {
        moved = false
        // Move the border above every line, and every small row, which it would cut
        for line in lines where line.top < bottom && line.bottom > bottom && line.top > top {
          bottom = line.top
          moved = true
        }
        for row in rowExtents where row.top < bottom && row.bottom > bottom && row.top > top {
          bottom = row.top
          moved = true
        }
        // A heading belongs to the text which follows
        if let last = lines.filter({ $0.bottom <= bottom + 0.001 && $0.top > top })
                           .max(by: { $0.bottom < $1.bottom }),
           last.isHeading {
          bottom = last.top
          moved = true
        }
      }
      if bottom <= top {
        // Nothing fits, because a line is taller than a page: cut it
        bottom = top + pageHeight
      }
      // A page that starts with a cell starts a little above its text: the border of a cell
      let previous = lines.filter { $0.bottom <= bottom + 0.001 }.map { $0.bottom }.max() ?? top
      let next = lines.filter { $0.top >= bottom - 0.001 }.min(by: { $0.top < $1.top })
      if let next, next.inCell {
        bottom = max(previous, bottom - Self.cellEdge, top + 1)
      }
      pages.append(CGRect(x: 0, y: top, width: width, height: bottom - top))
      top = bottom
    }
    if pages.isEmpty {
      pages.append(CGRect(x: 0, y: 0, width: width, height: pageHeight))
    }
    return pages
  }

  /// Returns the rectangles of the lines of text with a link, in the coordinates of the text view
  /// (the origin is in the upper left corner), with the URL of the link. Links which only point
  /// to a place in the same document (`#name`) are left out: they cannot be followed.
  private static func linkRects(in storage: NSTextStorage,
                                layout: NSLayoutManager,
                                container: NSTextContainer) -> [(url: URL, rect: CGRect)] {
    var result: [(url: URL, rect: CGRect)] = []
    storage.enumerateAttribute(.link, in: NSRange(location: 0, length: storage.length)) {
      value, range, _ in
        let url: URL?
        if let value = value as? URL {
          url = value
        } else if let value = value as? String {
          url = URL(string: value)
        } else {
          url = nil
        }
        guard let url, !url.absoluteString.isEmpty, !url.absoluteString.hasPrefix("#") else {
          return
        }
        let glyphs = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        layout.enumerateEnclosingRects(forGlyphRange: glyphs,
                                       withinSelectedGlyphRange: NSRange(location: NSNotFound,
                                                                         length: 0),
                                       in: container) { rect, _ in
          if rect.width > 0 && rect.height > 0 {
            result.append((url, rect))
          }
        }
    }
    return result
  }

  /// Draws the part `page` of the text of `layout`, in the coordinate system of the
  /// text view (the origin is in the upper left corner).
  private static func draw(_ page: CGRect,
                           of layout: NSLayoutManager,
                           in container: NSTextContainer,
                           into context: CGContext) {
    let glyphs = layout.glyphRange(forBoundingRect: page, in: container)
    #if os(macOS)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    layout.drawBackground(forGlyphRange: glyphs, at: .zero)
    layout.drawGlyphs(forGlyphRange: glyphs, at: .zero)
    NSGraphicsContext.restoreGraphicsState()
    #else
    UIGraphicsPushContext(context)
    layout.drawBackground(forGlyphRange: glyphs, at: .zero)
    layout.drawGlyphs(forGlyphRange: glyphs, at: .zero)
    UIGraphicsPopContext()
    #endif
  }
}

#endif
