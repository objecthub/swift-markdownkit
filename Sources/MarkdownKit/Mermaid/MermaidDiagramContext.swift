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
/// The results of rendering the diagrams of a document (via some "prepare" method), by the
/// source of the diagram: the images of the diagrams that were rendered, and the errors of
/// the diagrams which Mermaid rejected. An HTML generator that was given them (see
/// `MermaidDiagramContext.pin(_:)`) does not depend on the cache of the `MermaidRenderer`,
/// which may drop some of them in the meantime.
///
struct MermaidDiagramResults: Sendable {

  /// The images of the diagrams.
  var images: [String: MermaidImage] = [:]

  /// The errors of the diagrams which Mermaid rejected.
  var failures: [String: MermaidError] = [:]

  /// True if at least one diagram was rendered while the results were collected, i.e. if it was
  /// not in the cache of the renderer.
  var rendered = false
}

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
  private var pinnedImages: [String: MermaidImage] = [:]
  private var pinnedFailures: [String: MermaidError] = [:]

  /// Diagrams which are wider than this (in points) are scaled down to this width.
  let maxWidth: CGFloat?

  /// The least space in points between a diagram and the text above and below it.
  let spacing: CGFloat

  init(maxWidth: CGFloat?, spacing: CGFloat) {
    self.maxWidth = maxWidth
    self.spacing = spacing
  }

  /// Remembers the results of rendering the diagrams of a document. The HTML generator uses them
  /// before it looks into the cache of the renderer, whose entries may have been dropped since
  /// the diagrams were rendered if the document has many diagrams.
  func pin(_ results: MermaidDiagramResults) {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    self.pinnedImages.merge(results.images) { _, new in new }
    self.pinnedFailures.merge(results.failures) { _, new in new }
  }

  /// The pinned image of the diagram with the given source.
  func pinnedImage(for source: String) -> MermaidImage? {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    return self.pinnedImages[source]
  }

  /// The pinned error of the diagram with the given source.
  func pinnedFailure(for source: String) -> MermaidError? {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    return self.pinnedFailures[source]
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
      let replacement = NSMutableAttributedString(attachment: self.attachment(for: entry.image))
      replacement.addAttributes(attributes, range: NSRange(location: 0, length: replacement.length))
      result.replaceCharacters(in: range, with: replacement)
      self.addSpacing(to: result, aroundParagraphAt: range.location)
    }
    return result
  }

  /// Makes sure that there is at least `spacing` points between the paragraph at `location`
  /// and the paragraphs above and below it. The paragraph spacing of the neighbors counts, like
  /// the margins of paragraphs in a web page do. The system's HTML importer does not provide
  /// this: it ignores the top margin of a paragraph.
  private func addSpacing(to text: NSMutableAttributedString, aroundParagraphAt location: Int) {
    let paragraph = (text.string as NSString).paragraphRange(for: NSRange(location: location,
                                                                          length: 1))
    func style(at index: Int) -> NSParagraphStyle? {
      return text.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle
    }
    let current = style(at: paragraph.location)
    let result = (current?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
    if paragraph.location > 0 {
      let above = style(at: paragraph.location - 1)?.paragraphSpacing ?? 0
      result.paragraphSpacingBefore = max(result.paragraphSpacingBefore, self.spacing - above)
    }
    if paragraph.upperBound < text.length {
      let below = style(at: paragraph.upperBound)?.paragraphSpacingBefore ?? 0
      result.paragraphSpacing = max(result.paragraphSpacing, self.spacing - below)
    }
    text.addAttribute(.paragraphStyle, value: result, range: paragraph)
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
  /// include them. The images are kept in the cache of the generator's `MermaidRenderer`, as far
  /// as it has room for them: `generate(doc:)` only shows the diagrams that are in the cache.
  ///
  /// This does nothing if the generator was created without the `mermaid:` parameter. Diagrams
  /// which Mermaid cannot render are skipped (they are shown as code), so this never fails.
  /// The asynchronous methods `generateAsync(doc:)` etc. call this themselves. Code which does
  /// not use Swift concurrency can use `prepareDiagrams(in:completionHandler:)`.
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

  /// Renders the Mermaid diagrams in `doc` without blocking the calling thread and reports the
  /// result via a completion handler. This is the variant of `prepareDiagrams(in:)` for code
  /// which does not use Swift concurrency; see there for details. Once the handler has been
  /// called, `generate(doc:)` includes the diagrams.
  ///
  /// `completionHandler` is called exactly once, asynchronously (also if the generator was
  /// created without the `mermaid:` parameter, or if all diagrams are rendered already), and
  /// always on the main thread, so it is safe to update the user interface or state which is
  /// confined to the main thread from it.
  ///
  /// - Parameters:
  ///   - doc: The Markdown document.
  ///   - completionHandler: Called with `true` if at least one diagram was rendered by this
  ///                        call, i.e. if the result of `generate(doc:)` is different from
  ///                        before.
  public func prepareDiagrams(in doc: Block, completionHandler: @escaping (Bool) -> Void) {
    // The completion handler is not used by anybody else
    nonisolated(unsafe) let handler = completionHandler
    Task {
      let rendered = await self.prepareDiagrams(in: doc)
      DispatchQueue.main.async {
        handler(rendered)
      }
    }
  }

  /// Renders the Mermaid diagrams in `blocks` and reports the result via a completion handler.
  /// See `prepareDiagrams(in:completionHandler:)`.
  public func prepareDiagrams(in blocks: Blocks, completionHandler: @escaping (Bool) -> Void) {
    // The completion handler is not used by anybody else
    nonisolated(unsafe) let handler = completionHandler
    Task {
      let rendered = await self.prepareDiagrams(in: blocks)
      DispatchQueue.main.async {
        handler(rendered)
      }
    }
  }

  private func prepareDiagrams(sources: [String]) async -> Bool {
    return await self.diagramResults(sources: sources).rendered
  }

  /// Renders the diagrams with the given sources, which are not in the cache of the renderer
  /// yet, and returns the results for all of them. They are also kept in the cache (as far as it
  /// has room for them).
  func diagramResults(sources: [String]) async -> MermaidDiagramResults {
    var results = MermaidDiagramResults()
    guard let config = self.mermaidConfig, let renderer = self.diagramRenderer else {
      return results
    }
    for source in sources {
      if let image = renderer.cachedImage(for: source, config: config) {
        results.images[source] = image
      } else if let failure = renderer.cachedFailure(for: source, config: config) {
        results.failures[source] = failure
      } else if Task.isCancelled {
        break
      } else {
        do {
          results.images[source] = try await renderer.render(source, config: config)
          results.rendered = true
        } catch let error as MermaidError {
          // Only the errors of the diagrams are remembered; the diagram is shown as code
          if case .syntaxError = error {
            results.failures[source] = error
          }
        } catch {
          // The diagram is shown as code
        }
      }
    }
    return results
  }

  /// The results of rendering the diagrams of `doc`; empty if diagrams are not enabled.
  func diagramResults(in doc: Block) async -> MermaidDiagramResults {
    guard self.mermaidConfig != nil else {
      return MermaidDiagramResults()
    }
    return await self.diagramResults(sources: doc.mermaidSources)
  }

  /// The results of rendering the diagrams of `blocks`; empty if diagrams are not enabled.
  func diagramResults(in blocks: Blocks) async -> MermaidDiagramResults {
    guard self.mermaidConfig != nil else {
      return MermaidDiagramResults()
    }
    return await self.diagramResults(sources: blocks.mermaidSources)
  }

  /// Returns the HTML generator for `options` (see `htmlGenerator(options:)`) which shows the
  /// diagrams in `results` whether or not they are still in the cache of the renderer.
  func htmlGenerator(options: RenderingOptions?,
                     pinning results: MermaidDiagramResults) -> InternalHtmlGenerator {
    let generator = self.htmlGenerator(options: options)
    generator.diagrams.pin(results)
    return generator
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
