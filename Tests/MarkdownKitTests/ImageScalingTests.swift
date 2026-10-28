//
//  ImageScalingTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 28/10/2026.
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

#if os(iOS)

import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import UIKit
@testable import MarkdownKit

/// Tests for the parameter `scaleImages` of the `generateAsync` methods of
/// `AttributedStringGenerator`, and for `ImageTextAttachment`.
final class ImageScalingTests: XCTestCase {

  /// The size of the test image in pixels
  private let imageSize = CGSize(width: 800, height: 200)

  private var directory: URL!

  override func setUpWithError() throws {
    self.directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ImageScalingTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    try self.png(width: Int(self.imageSize.width), height: Int(self.imageSize.height))
         .write(to: self.directory.appendingPathComponent("wide.png"))
  }

  override func tearDownWithError() throws {
    if let directory = self.directory {
      try? FileManager.default.removeItem(at: directory)
    }
  }

  // MARK: Helpers

  private func png(width: Int, height: Int) throws -> Data {
    let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(srgbRed: 0, green: 0.5, blue: 0.5, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try XCTUnwrap(context.makeImage())
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
                                      data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }

  private func parse(_ markdown: String) -> Block {
    return MathMarkdownParser.standard.parse(markdown)
  }

  private func attachments(in string: NSAttributedString) -> [NSTextAttachment] {
    var result: [NSTextAttachment] = []
    string.enumerateAttribute(.attachment,
                              in: NSRange(location: 0, length: string.length)) { value, _, _ in
      if let attachment = value as? NSTextAttachment {
        result.append(attachment)
      }
    }
    return result
  }

  /// The height of `string` in a text container of the given width (TextKit 1).
  private func height(of string: NSAttributedString, width: CGFloat) -> CGFloat {
    let storage = NSTextStorage(attributedString: string)
    let layout = NSLayoutManager()
    let container = NSTextContainer(size: CGSize(width: width,
                                                 height: CGFloat.greatestFiniteMagnitude))
    container.lineFragmentPadding = 0
    layout.addTextContainer(container)
    storage.addLayoutManager(layout)
    layout.ensureLayout(for: container)
    return layout.usedRect(for: container).height
  }

  private let markdown = "Text before.\n\n![wide](wide.png)\n\n* item ![wide](wide.png) text\n\nAfter.\n"

  private func generator() -> AttributedStringGenerator {
    return AttributedStringGenerator(imageBaseUrl: self.directory,
                                     renderingOptions: .trusted)
  }

  // MARK: Tests

  /// Without `scaleImages`, the images are the attachments of the importer, and keep their size.
  func testImagesAreNotScaledByDefault() async throws {
    let result = try await self.generator().generateAsync(doc: self.parse(self.markdown))
    let found = self.attachments(in: result)
    XCTAssertEqual(found.count, 2)
    XCTAssertTrue(found.allSatisfy { type(of: $0) == NSTextAttachment.self })
    XCTAssertGreaterThanOrEqual(self.height(of: result, width: 100), 2 * self.imageSize.height)
  }

  /// With `scaleImages`, the images are scaled down to the width of their line, whatever the
  /// width of the text container is, and never scaled up.
  func testScaledImagesFitTheWidthOfTheText() async throws {
    let doc = self.parse(self.markdown)
    let plain = try await self.generator().generateAsync(doc: doc)
    let scaled = try await self.generator().generateAsync(doc: doc, scaleImages: true)
    XCTAssertEqual(scaled.string, plain.string)
    let found = self.attachments(in: scaled)
    XCTAssertEqual(found.count, 2)
    XCTAssertTrue(found.allSatisfy { $0 is ImageTextAttachment })
    // Each image is at most as high as a scaled image can be; the text takes some room as well
    for width in [100 as CGFloat, 200, 400] {
      let limit = 2 * self.imageSize.height * width / self.imageSize.width
      let textHeight = self.height(of: plain, width: width) - 2 * self.imageSize.height
      let actual = self.height(of: scaled, width: width)
      XCTAssertLessThan(actual, limit + textHeight + 40, "width \(width)")
      XCTAssertGreaterThan(actual, textHeight, "width \(width)")
    }
    // Narrower text makes the images smaller, wider text makes them larger, up to their size
    XCTAssertLessThan(self.height(of: scaled, width: 100), self.height(of: scaled, width: 200))
    XCTAssertLessThan(self.height(of: scaled, width: 200), self.height(of: scaled, width: 400))
    XCTAssertEqual(self.height(of: scaled, width: 3000), self.height(of: plain, width: 3000),
                   accuracy: 1)
  }

  /// The attachment itself: it takes the width of the line, keeps the aspect ratio, and does not
  /// grow.
  func testAttachmentBounds() throws {
    let attachment = ImageTextAttachment(copying: NSTextAttachment(data: try self.png(width: 800,
                                                                                         height: 200),
                                                                     ofType: UTType.png.identifier))
    func bounds(_ width: CGFloat) -> CGRect {
      return attachment.attachmentBounds(for: nil,
                                         proposedLineFragment: CGRect(x: 0, y: 0, width: width,
                                                                      height: 20),
                                         glyphPosition: .zero,
                                         characterIndex: 0)
    }
    XCTAssertEqual(bounds(400).size, CGSize(width: 400, height: 100))
    XCTAssertEqual(bounds(80).size, CGSize(width: 80, height: 20))
    XCTAssertEqual(bounds(800).width, 800, accuracy: 0.001)
    XCTAssertEqual(bounds(800).height, 200, accuracy: 0.001)
    XCTAssertEqual(bounds(5000).width, 800, accuracy: 0.001)
    // An unusable width does not turn the image into nothing
    XCTAssertGreaterThan(bounds(0).width, 0)
  }

  func testCompletionHandlerVariantScalesImages() async throws {
    let doc = self.parse(self.markdown)
    let generator = self.generator()
    let result: NSAttributedString = try await withCheckedThrowingContinuation { continuation in
      generator.generateAsync(doc: doc, scaleImages: true) { result in
        nonisolated(unsafe) let result = result
        continuation.resume(with: result.mapError { $0 as Error })
      }
    }
    let found = self.attachments(in: result)
    XCTAssertEqual(found.count, 2)
    XCTAssertTrue(found.allSatisfy { $0 is ImageTextAttachment })
  }

  func testBlockAndBlocksVariantsScaleImages() async throws {
    let generator = self.generator()
    guard case .document(let blocks) = self.parse(self.markdown) else {
      return XCTFail("document expected")
    }
    let fromBlocks = try await generator.generateAsync(blocks: blocks, scaleImages: true)
    let fromBlock = try await generator.generateAsync(block: .document(blocks), scaleImages: true)
    for result in [fromBlocks, fromBlock] {
      let found = self.attachments(in: result)
      XCTAssertEqual(found.count, 2)
      XCTAssertTrue(found.allSatisfy { $0 is ImageTextAttachment })
    }
  }

  /// The attachments of other classes are not replaced, and a string without images is not
  /// copied.
  func testOnlyPlainAttachmentsAreReplaced() throws {
    let other = ImageTextAttachment(copying: NSTextAttachment())
    let string = NSMutableAttributedString(string: "a")
    string.append(NSAttributedString(attachment: other))
    // Nothing to replace: the same string comes back
    XCTAssertTrue(ImageTextAttachment.scalingImages(in: string) === string)
    let plain = NSTextAttachment()
    string.append(NSAttributedString(attachment: plain))
    let result = ImageTextAttachment.scalingImages(in: string)
    let found = self.attachments(in: result)
    XCTAssertEqual(found.count, 2)
    XCTAssertTrue(found[0] === other)
    XCTAssertTrue(found[1] is ImageTextAttachment)
    // Scaling again changes nothing
    XCTAssertTrue(ImageTextAttachment.scalingImages(in: result) === result)
    let text = NSAttributedString(string: "no images")
    XCTAssertTrue(ImageTextAttachment.scalingImages(in: text) === text)
  }

  #if canImport(WebKit)

  /// Formulas have attachments of their own, which are not copied: they still scale themselves,
  /// including their baseline, while the images of the document are scaled by the generator.
  func testFormulasAreNotReplaced() async throws {
    let folder = try XCTUnwrap(Resources.katexFolder)
    let renderer = try XCTUnwrap(MathRenderer(katexFolder: folder))
    let generator = MathAttributedStringGenerator(mathRenderer: renderer,
                                                  imageBaseUrl: self.directory,
                                                  renderingOptions: .trusted)
    let doc = self.parse("""
      Euler: $e^{i\\pi}+1=0$ and $\\frac{a}{b}$.

      ![wide](wide.png)

      $$
      \\int_0^1 x^2\\,dx = \\frac13
      $$
      """)
    let plain = try await generator.generateAsync(doc: doc)
    let scaled = try await generator.generateAsync(doc: doc, scaleImages: true)
    let before = self.attachments(in: plain)
    let after = self.attachments(in: scaled)
    XCTAssertEqual(before.count, 4)
    XCTAssertEqual(after.count, 4)
    for (old, new) in zip(before, after) {
      if type(of: old) == NSTextAttachment.self {
        XCTAssertTrue(new is ImageTextAttachment)
      } else {
        // A formula: the same class as without scaling, not a copy
        XCTAssertTrue(type(of: new) == type(of: old))
        XCTAssertFalse(new is ImageTextAttachment)
        XCTAssertEqual(new.bounds, old.bounds)
      }
    }
    XCTAssertEqual(after.filter { $0 is ImageTextAttachment }.count, 1)
  }

  #endif
}

#endif
