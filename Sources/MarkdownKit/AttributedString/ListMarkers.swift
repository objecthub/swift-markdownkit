//
//  ListMarkers.swift
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
#if os(macOS)
import AppKit
#else
import UIKit
#endif

///
/// Puts the numbers and bullets of list items on the baseline of the first line of their items.
///
/// With `Version.OS26`, the system's HTML importer turns a list into a table: the first column has
/// the markers, the second one the content of the items. The cells of a table are laid out at
/// their top (the system ignores the vertical alignment `baseline`, and the CSS properties for the
/// space above a cell), so a marker is above the baseline of its item if an image, such as a
/// formula, makes the first line of the item higher than the line of the marker.
///
/// The attribute `baselineOffset` fixes this: it lowers the marker, which makes its line a little
/// higher, but the line of the item is higher anyway. It is a character attribute, so text views
/// on macOS and iOS and the RTFD format keep it. How far the marker has to move depends on the
/// first line of the item, and this line depends on the width of the text: if the image is on the
/// second line, the marker must not move. There are two ways to know:
///
/// - `aligned(_:)` assumes a width of the text. It is used for the attributed strings of the
///   generators, and for the strings which are exported as RTFD.
/// - `align(_:layoutManager:)` measures the layout of a text view, which `MarkdownText` does after
///   each layout, so that it is right for the actual width and after the view changed its size.
///
public enum ListMarkers {

  /// The width of the text of a list item in ems that `aligned(_:)` assumes. The generator does
  /// not know the width of the text view: 30 ems are 480 points for a font of size 16.
  public static let assumedTextWidth: CGFloat = 30

  /// A marker, and the first paragraph of the content of its item.
  public struct Pair {
    /// The characters of the marker, without the end of its paragraph.
    public let marker: NSRange
    /// The first paragraph of the content of the item, with the end of the paragraph.
    public let content: NSRange
  }

  /// The number (or bullet, or checkbox) of a list item.
  private static func isMarker(_ text: String) -> Bool {
    if text == "•" || text == "☐" || text == "☑" {
      return true
    }
    guard let last = text.last, last == "." || last == ")" else {
      return false
    }
    let digits = text.dropLast()
    return !digits.isEmpty && digits.allSatisfy { $0.isASCII && $0.isNumber }
  }

  /// True if the cell has no border (the cells of lists have none; other tables do).
  private static func hasNoBorder(_ cell: NSTextTableBlock) -> Bool {
    #if os(macOS)
    return [NSRectEdge.minX, .minY, .maxX, .maxY].allSatisfy { cell.width(for: .border, edge: $0) == 0 }
    #else
    return true
    #endif
  }

  /// Returns the markers of the lists in `string` together with the first paragraph of their
  /// items, in the order of the string. Items whose content starts with something that is not a
  /// paragraph (a code block, a quote, another list) are not included.
  public static func pairs(in string: NSAttributedString) -> [Pair] {
    struct Row: Hashable {
      let table: ObjectIdentifier
      let row: Int
      let depth: Int
    }
    var markers: [(row: Row, range: NSRange)] = []
    var contents: [Row: (range: NSRange, direct: Bool)] = [:]
    let text = string.string as NSString
    var location = 0
    while location < string.length {
      let range = text.paragraphRange(for: NSRange(location: location, length: 0))
      location = NSMaxRange(range)
      guard let style = string.attribute(.paragraphStyle, at: range.location, effectiveRange: nil)
                          as? NSParagraphStyle,
            !style.textBlocks.isEmpty else {
        continue
      }
      let cells = style.textBlocks.compactMap { $0 as? NSTextTableBlock }
      guard cells.count == style.textBlocks.count else {
        continue
      }
      for (depth, cell) in cells.enumerated() {
        let row = Row(table: ObjectIdentifier(cell.table), row: cell.startingRow, depth: depth)
        if cell.startingColumn == 1 && contents[row] == nil {
          contents[row] = (range, depth == cells.count - 1)
        } else if cell.startingColumn == 0 && depth == cells.count - 1 &&
                  cell.table.numberOfColumns == 2 && cell.columnSpan == 1 &&
                  hasNoBorder(cell) {
          let contentsEnd = text.range(of: "\n", range: range).location
          let characters = contentsEnd == NSNotFound ? range
                                                     : NSRange(location: range.location,
                                                               length: contentsEnd - range.location)
          if isMarker(text.substring(with: characters).trimmingCharacters(in: .whitespaces)) {
            markers.append((row, characters))
          }
        }
      }
    }
    return markers.compactMap { marker in
      guard let content = contents[marker.row], content.direct else {
        return nil
      }
      return Pair(marker: marker.range, content: content.range)
    }.sorted { $0.marker.location < $1.marker.location }
  }

  // MARK: Measuring

  /// Returns the distance of the baseline of the line which contains the character at `index` from
  /// the top of the text container. The glyph that determines it is the first glyph of the line
  /// which is neither an image nor moved by `baselineOffset`. `nil` if there is none.
  public static func baseline(in layout: NSLayoutManager,
                              of storage: NSAttributedString,
                              at index: Int) -> CGFloat? {
    guard layout.numberOfGlyphs > 0, index < storage.length else {
      return nil
    }
    var line = NSRange()
    let first = layout.glyphIndexForCharacter(at: index)
    let rect = layout.lineFragmentRect(forGlyphAt: first, effectiveRange: &line)
    for glyph in line.location..<NSMaxRange(line) {
      let character = layout.characterIndexForGlyph(at: glyph)
      let attributes = storage.attributes(at: character, effectiveRange: nil)
      if attributes[.attachment] == nil && ((attributes[.baselineOffset] as? NSNumber)?.doubleValue ?? 0) == 0 {
        return rect.minY + layout.location(forGlyphAt: glyph).y
      }
    }
    return nil
  }

  /// Returns the distance of the baseline of the first line of the paragraph `range` of `string`
  /// from the top of the paragraph, if it is laid out in `width` points and outside of a table.
  /// The offset of the baseline which was set earlier is not taken into account, if
  /// `ignoringOffsets` is true. Images which only have bounds are measured as images of that size.
  private static func baseline(of range: NSRange,
                               in string: NSAttributedString,
                               width: CGFloat,
                               ignoringOffsets: Bool) -> CGFloat? {
    let part = NSMutableAttributedString(attributedString: string.attributedSubstring(from: range))
    let all = NSRange(location: 0, length: part.length)
    part.enumerateAttribute(.paragraphStyle, in: all) { value, range, _ in
      if let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle {
        style.textBlocks = []
        part.addAttribute(.paragraphStyle, value: style, range: range)
      }
    }
    part.enumerateAttribute(.attachment, in: all) { value, range, _ in
      // The attachments of RTFD documents have a file, but no image
      if let attachment = value as? NSTextAttachment, attachment.image == nil,
         attachment.contents == nil, attachment.bounds.width > 0 {
        let copy = NSTextAttachment()
        copy.bounds = attachment.bounds
        #if os(macOS)
        copy.image = NSImage(size: attachment.bounds.size)
        #else
        copy.image = UIGraphicsImageRenderer(size: attachment.bounds.size).image { _ in }
        #endif
        part.addAttribute(.attachment, value: copy, range: range)
      }
    }
    if ignoringOffsets {
      part.removeAttribute(.baselineOffset, range: all)
    }
    let storage = NSTextStorage(attributedString: part)
    let layout = NSLayoutManager()
    let container = NSTextContainer(size: CGSize(width: width, height: 100_000))
    container.lineFragmentPadding = 0
    layout.addTextContainer(container)
    storage.addLayoutManager(layout)
    layout.ensureLayout(for: container)
    return baseline(in: layout, of: storage, at: 0)
  }

  /// True if the paragraph has text as well as images.
  private static func hasTextAndImages(_ range: NSRange, in string: NSAttributedString) -> Bool {
    var images = false
    var text = false
    string.enumerateAttributes(in: range) { attributes, range, _ in
      if attributes[.attachment] != nil {
        images = true
      } else if !(string.string as NSString).substring(with: range)
                   .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        text = true
      }
    }
    return images && text
  }

  /// The line height multiple of the paragraph at `index`: it multiplies the height of a line,
  /// including the room that a lowered marker needs, and the extra height is added above the
  /// text, so a marker which is lowered by `d` moves down by `d` times the multiple.
  private static func lineHeightMultiple(in string: NSAttributedString, at index: Int) -> CGFloat {
    let multiple = (string.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle)?.lineHeightMultiple ?? 0
    return multiple > 0 ? multiple : 1
  }

  /// Sets how far the characters in `range` are lowered, or removes the offset if it is zero.
  private static func lower(_ range: NSRange, by distance: CGFloat, in string: NSMutableAttributedString) {
    if distance > 0.25 {
      string.addAttribute(.baselineOffset, value: -distance, range: range)
    } else {
      string.removeAttribute(.baselineOffset, range: range)
    }
  }

  // MARK: Aligning

  /// Returns `string` with the markers of lists on the baseline of the first line of their items,
  /// for text in `assumedTextWidth` ems. The items whose first paragraph has text and images are
  /// measured; the other markers stay as they are. The result is `string` if nothing changes.
  public static func aligned(_ string: NSAttributedString) -> NSAttributedString {
    var hasImage = false
    string.enumerateAttribute(.attachment, in: NSRange(location: 0, length: string.length)) { value, _, stop in
      if value != nil {
        hasImage = true
        stop.pointee = true
      }
    }
    guard hasImage else {
      return string
    }
    var result: NSMutableAttributedString?
    for pair in pairs(in: string) where hasTextAndImages(pair.content, in: string) {
      let size = (string.attribute(.font, at: pair.content.location, effectiveRange: nil) as? HRFont)?.pointSize ?? 16
      let width = assumedTextWidth * size
      // The paragraph of the marker includes the end of the paragraph
      let paragraph = (string.string as NSString).paragraphRange(for: pair.marker)
      guard let marker = baseline(of: paragraph, in: string, width: width, ignoringOffsets: true),
            let content = baseline(of: pair.content, in: string, width: width, ignoringOffsets: false) else {
        continue
      }
      let distance = (content - marker) / lineHeightMultiple(in: string, at: pair.marker.location)
      let current = -((string.attribute(.baselineOffset, at: pair.marker.location, effectiveRange: nil) as? NSNumber)?.doubleValue ?? 0)
      if abs(distance - current) > 0.25 {
        if result == nil {
          result = NSMutableAttributedString(attributedString: string)
        }
        lower(pair.marker, by: distance, in: result!)
      }
    }
    return result ?? string
  }

  /// Puts the markers of the lists in `storage` on the baseline of the first line of their items,
  /// as `layoutManager` lays them out. Returns true if a marker has moved. The layout has to be
  /// that of `storage`; call this after each layout that changed the width of the text, and
  /// lay out the text again if the result is true. `pairs` can be given if the text did not change
  /// since `pairs(in:)` returned them (attributes do not matter).
  @discardableResult
  public static func align(_ storage: NSTextStorage,
                           layoutManager: NSLayoutManager,
                           pairs knownPairs: [Pair]? = nil) -> Bool {
    let pairs = knownPairs ?? pairs(in: storage)
    guard !pairs.isEmpty else {
      return false
    }
    var changes: [(range: NSRange, distance: CGFloat)] = []
    for pair in pairs {
      let glyph = layoutManager.glyphIndexForCharacter(at: pair.marker.location)
      let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
      // Text with several containers (pages): a marker and its item may be in different ones
      let contentGlyph = layoutManager.glyphIndexForCharacter(at: pair.content.location)
      guard layoutManager.textContainer(forGlyphAt: glyph, effectiveRange: nil) ===
              layoutManager.textContainer(forGlyphAt: contentGlyph, effectiveRange: nil),
            let content = baseline(in: layoutManager, of: storage, at: pair.content.location) else {
        continue
      }
      // Where the marker is now, which includes its offset
      let marker = line.minY + layoutManager.location(forGlyphAt: glyph).y
      let current = -((storage.attribute(.baselineOffset, at: pair.marker.location, effectiveRange: nil) as? NSNumber)?.doubleValue ?? 0)
      let wanted = max(0, current + (content - marker) / lineHeightMultiple(in: storage, at: pair.marker.location))
      if abs(wanted - current) > 0.5 {
        changes.append((pair.marker, wanted))
      }
    }
    guard !changes.isEmpty else {
      return false
    }
    storage.beginEditing()
    for change in changes {
      if change.distance > 0.25 {
        storage.addAttribute(.baselineOffset, value: -change.distance, range: change.range)
      } else {
        storage.removeAttribute(.baselineOffset, range: change.range)
      }
    }
    storage.endEditing()
    return true
  }
}

#endif
