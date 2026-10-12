//
//  MermaidDiagramContext.swift
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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import UniformTypeIdentifiers

///
/// Keeps track of the diagrams which an HTML generator has put into the HTML. The system's HTML
/// importer cannot place images with a given size (it ignores the size attributes, and the
/// resolution of an image is interpreted differently on macOS and iOS), so the HTML contains a
/// piece of text instead of an image. Once the HTML has been turned into an attributed string,
/// `replacePlaceholders(in:)` replaces each of these pieces of text with an `NSTextAttachment`.
///
/// Each context uses a random token for its placeholders, so placeholders cannot be forged by
/// the text of a Markdown document.
///
public final class MermaidDiagramContext: @unchecked Sendable {

  private struct Entry {
    let token: String
    let image: MermaidImage
  }

  #if !os(watchOS)

  ///
  /// The attachment which shows a diagram. Its `bounds` are the size of the diagram (scaled down to
  /// `MermaidConfig.maxWidth`). In addition, the diagram is scaled down to the width that a text
  /// view offers for it whenever the text is laid out, so that it is never wider than the text
  /// (the text view can be resized later; a text view does not scale attachments by itself).
  ///
  private final class MermaidTextAttachment: NSTextAttachment {

    /// The size in points at which the diagram is shown if there is enough room.
    var diagramSize: CGSize = .zero

    /// Returns `diagramSize`, scaled down so that it is at most `width` points wide.
    func fittedSize(width: CGFloat) -> CGSize {
      guard self.diagramSize.width > 0, width > 0, self.diagramSize.width > width else {
        return self.diagramSize
      }
      return CGSize(width: width, height: self.diagramSize.height * width / self.diagramSize.width)
    }

    override func attachmentBounds(for textContainer: NSTextContainer?,
                                   proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint,
                                   characterIndex charIndex: Int) -> CGRect {
      guard self.diagramSize.width > 0 else {
        return super.attachmentBounds(for: textContainer,
                                      proposedLineFragment: lineFrag,
                                      glyphPosition: position,
                                      characterIndex: charIndex)
      }
      return CGRect(origin: .zero, size: self.fittedSize(width: lineFrag.width))
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    override func attachmentBounds(for attributes: [NSAttributedString.Key : Any],
                                   location: any NSTextLocation,
                                   textContainer: NSTextContainer?,
                                   proposedLineFragment: CGRect,
                                   position: CGPoint) -> CGRect {
      guard self.diagramSize.width > 0 else {
        return super.attachmentBounds(for: attributes,
                                      location: location,
                                      textContainer: textContainer,
                                      proposedLineFragment: proposedLineFragment,
                                      position: position)
      }
      return CGRect(origin: .zero, size: self.fittedSize(width: proposedLineFragment.width))
    }
  }

  #endif

  private let lock = NSLock()
  private let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
  private var entries: [Entry] = []

  /// Diagrams which are wider than this (in points) are scaled down to this width.
  let maxWidth: CGFloat?

  init(maxWidth: CGFloat?) {
    self.maxWidth = maxWidth
  }

  /// True if no diagram was placed into the HTML.
  var isEmpty: Bool {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    return self.entries.isEmpty
  }

  /// Returns a text which stands for `image`.
  func placeholder(for image: MermaidImage) -> String {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    // The characters are in a private use area; the token ends in a character that cannot be
    // part of the nonce or the index so that no token is a prefix of another.
    let token = "\u{E000}MKD\(self.nonce)\(self.entries.count)\u{E001}"
    self.entries.append(Entry(token: token, image: image))
    return token
  }

  /// Returns a copy of `string` in which each placeholder is replaced by an attachment with the
  /// image of its diagram. The attachment gets the attributes of the placeholder text, such as
  /// the paragraph style.
  func replacePlaceholders(in string: NSAttributedString) -> NSAttributedString {
    self.lock.lock()
    let entries = self.entries
    self.lock.unlock()
    guard !entries.isEmpty else {
      return string
    }
    let result = NSMutableAttributedString(attributedString: string)
    for entry in entries {
      let range = (result.string as NSString).range(of: entry.token)
      guard range.location != NSNotFound else {
        continue
      }
      var attributes = result.attributes(at: range.location, effectiveRange: nil)
      attributes[.attachment] = nil
      let replacement = NSMutableAttributedString(
                          attachment: self.attachment(for: entry.image))
      replacement.addAttributes(attributes, range: NSRange(location: 0, length: replacement.length))
      result.replaceCharacters(in: range, with: replacement)
    }
    return result
  }

  /// Creates the attachment for a diagram.
  private func attachment(for diagram: MermaidImage) -> NSTextAttachment {
    var size = diagram.size
    if let maxWidth = self.maxWidth, maxWidth > 0, size.width > maxWidth {
      size = CGSize(width: maxWidth, height: size.height * maxWidth / size.width)
    }
    // The data makes the attachment survive copy and paste and archiving
    #if os(watchOS)
    // There is no text layout on watchOS which could scale the diagram
    let attachment = NSTextAttachment(data: diagram.pngData, ofType: UTType.png.identifier)
    #else
    let attachment = MermaidTextAttachment(data: diagram.pngData, ofType: UTType.png.identifier)
    attachment.diagramSize = size
    #endif
    #if os(macOS)
    if let image = NSImage(data: diagram.pngData) {
      image.size = size
      attachment.image = image
    }
    #else
    attachment.image = UIImage(data: diagram.pngData, scale: diagram.scale)
    #endif
    attachment.bounds = CGRect(origin: .zero, size: size)
    return attachment
  }
}

extension AttributedStringGenerator {

  /// The renderer used for diagrams; `nil` if diagrams are not enabled.
  public var diagramRenderer: MermaidRenderer? {
    return self.mermaidConfig == nil ? nil : (self.mermaidRenderer ?? MermaidRenderer.shared)
  }

  /// Renders the Mermaid diagrams in `doc` (the content of the fenced code blocks with language
  /// `mermaid`) so that `generate(doc:)`, which cannot wait for a diagram to be drawn, can
  /// include them. The images are kept in the cache of the generator's `MermaidRenderer`.
  ///
  /// This does nothing if the generator was created without the `mermaid:` parameter. Diagrams
  /// which Mermaid cannot render are skipped (they are shown as code), so this never fails.
  /// The asynchronous methods `generateAsync(doc:)` etc. call this themselves.
  ///
  /// - Returns: `true` if at least one diagram was rendered by this call, i.e. if the result of
  ///            `generate(doc:)` is different from before.
  @discardableResult
  public func prepareDiagrams(in doc: Block) async -> Bool {
    guard self.mermaidConfig != nil else {
      return false
    }
    return await self.prepareDiagrams(sources: doc.mermaidSources)
  }

  /// Renders the Mermaid diagrams in `blocks`. See `prepareDiagrams(in:)`.
  @discardableResult
  public func prepareDiagrams(in blocks: Blocks) async -> Bool {
    guard self.mermaidConfig != nil else {
      return false
    }
    return await self.prepareDiagrams(sources: blocks.mermaidSources)
  }

  private func prepareDiagrams(sources: [String]) async -> Bool {
    guard let config = self.mermaidConfig, let renderer = self.diagramRenderer else {
      return false
    }
    var rendered = false
    for source in sources {
      if renderer.cachedImage(for: source, config: config) != nil ||
         renderer.cachedFailure(for: source, config: config) != nil {
        continue
      }
      if Task.isCancelled {
        break
      }
      if (try? await renderer.render(source, config: config)) != nil {
        rendered = true
      }
    }
    return rendered
  }

  /// Replaces the diagram placeholders of the HTML which `generator` created in `string`.
  public func insertingDiagrams(into string: NSAttributedString?,
                                from generator: HtmlGenerator) -> NSAttributedString? {
    guard let string,
          let diagrams = (generator as? InternalHtmlGenerator)?.diagrams,
          !diagrams.isEmpty else {
      return string
    }
    return diagrams.replacePlaceholders(in: string)
  }

  /// Replaces the diagram placeholders of the HTML which `generator` created in `string`. This
  /// is the variant for the asynchronous methods, which hand the result to their caller.
  public func addingDiagrams(to string: sending NSAttributedString,
                             from generator: HtmlGenerator) -> sending NSAttributedString {
    guard let diagrams = (generator as? InternalHtmlGenerator)?.diagrams,
          !diagrams.isEmpty else {
      return string
    }
    return diagrams.replacePlaceholders(in: string)
  }
}

#endif
