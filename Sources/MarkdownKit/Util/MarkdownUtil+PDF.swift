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
  /// of ``pdf(_:title:author:pageSize:margins:renderingOptions:)``.
  public static let usLetter = CGSize(width: 612, height: 792)

  /// The size in points of a page of the format A4.
  public static let a4 = CGSize(width: 595, height: 842)

  /// Returns the document as a PDF document: the content of a `.pdf` file. The text, lists, tables,
  /// quotes and code blocks are laid out as they are in a text view, in the width of the pages, and
  /// are broken into pages. Diagrams (see <doc:DrawingMermaidDiagrams>) and formulas (see
  /// <doc:MathematicalFormulas>) are drawn as images; they are scaled down if they are wider than
  /// the text. The numbers and bullets of lists sit on the baseline of the first line of their items.
  ///
  /// This method is available on macOS and iOS. It draws diagrams and formulas with the renderers
  /// of the utility, which take a moment for the first image.
  ///
  /// - Parameters:
  ///   - doc: The Markdown document, or a part of it.
  ///   - title: The title of the document, which becomes one of its properties.
  ///   - author: The author of the document, which becomes one of its properties.
  ///   - pageSize: The size of a page in points: ``usLetter`` (the default) or ``a4``, for example.
  ///   - margins: The space in points between the text and the edges of a page. The default is
  ///              one inch on each edge.
  ///   - renderingOptions: The options for rendering the document, which restrict what it can load
  ///                       (see <doc:RenderingUntrustedMarkdown>). Its `textSizeMultiplier` changes
  ///                       the size of the text.
  /// - Throws: A ``PDFError`` if the pages have no room for text or the system cannot create the
  ///           document, or a ``AttributedStringGenerator/RenderingError`` if the document
  ///           cannot be rendered.
  public func pdf(_ doc: Block,
                  title: String? = nil,
                  author: String? = nil,
                  pageSize: CGSize = MarkdownUtil.usLetter,
                  margins: Insets = Insets(72),
                  renderingOptions: AttributedStringGenerator.RenderingOptions = .trusted)
                async throws -> Data {
    let textSize = CGSize(width: pageSize.width - margins.left - margins.right,
                          height: pageSize.height - margins.top - margins.bottom)
    guard textSize.width >= 36, textSize.height >= 36 else {
      throw PDFError.noRoomForText
    }
    // Diagrams and formulas are not wider than the text
    let generator = self.documentGenerator(maxImageWidth: textSize.width,
                                           renderingOptions: renderingOptions)
    let string = try await generator.generateAsync(doc: doc)
    return try Self.pdfData(from: string,
                            title: title,
                            author: author,
                            pageSize: pageSize,
                            margins: margins,
                            textSize: textSize)
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
    let pages = Self.pageRanges(of: layout, in: container, storage: storage, pageHeight: textSize.height)
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
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, auxiliary as CFDictionary) else {
      throw PDFError.cannotCreateDocument
    }
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
    /// True if the line is a paragraph of its own with bold text outside of a table cell, such as a
    /// heading, which should not be the last line of a page.
    let isHeading: Bool
  }

  /// How far above its first line the text of a cell starts: a page that starts with a table cell
  /// starts that far above the first line, so that the border and the padding of a cell are
  /// there.
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
    layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) { rect, _, _, glyphs, _ in
      let characters = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
      let style = storage.attribute(.paragraphStyle, at: characters.location, effectiveRange: nil) as? NSParagraphStyle
      var row: [Int]?
      if let cell = style?.textBlocks.first as? NSTextTableBlock {
        row = [ObjectIdentifier(cell.table).hashValue, cell.startingRow]
      }
      var isHeading = false
      if style?.textBlocks.isEmpty ?? true {
        let paragraph = text.paragraphRange(for: NSRange(location: characters.location, length: 0))
        let contents = NSRange(location: paragraph.location,
                               length: text.range(of: "\n", range: paragraph).location == NSNotFound
                                         ? paragraph.length
                                         : text.range(of: "\n", range: paragraph).location - paragraph.location)
        if NSMaxRange(characters) >= NSMaxRange(contents) && characters.location <= contents.location,
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

  /// Draws the part `page` of the text of `layout`, in the coordinate system of the text view (the
  /// origin is in the upper left corner).
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
