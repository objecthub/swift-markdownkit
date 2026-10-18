//
//  NSAttributedStringRTFDTests.swift
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

#if os(macOS) || os(iOS)

import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import MarkdownKit

/// Tests for `NSAttributedString.preparedForRTFD()`.
final class NSAttributedStringRTFDTests: XCTestCase {

  /// A PNG which is filled with black and has no resolution.
  private func blackPNG(width: Int, height: Int) throws -> Data {
    let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try XCTUnwrap(context.makeImage())
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
                                      data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }

  /// An attachment with a PNG of `pixels` x `pixels`, which is shown with the given bounds.
  private func attachment(pixels: Int, bounds: CGRect) throws -> NSTextAttachment {
    let attachment = NSTextAttachment(data: try self.blackPNG(width: pixels, height: pixels),
                                      ofType: UTType.png.identifier)
    attachment.bounds = bounds
    return attachment
  }

  /// The data of an attachment.
  private func data(of attachment: NSTextAttachment) throws -> Data {
    return try XCTUnwrap(attachment.fileWrapper?.regularFileContents ?? attachment.contents)
  }

  /// The resolution in dots per inch, and the width in pixels of a PNG.
  private func resolution(of png: Data) throws -> (dpi: Double, pixels: Int) {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
    let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    return (try XCTUnwrap(properties[kCGImagePropertyDPIWidth] as? Double),
            try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int))
  }

  /// A string with the given attachments, between text.
  private func string(with attachments: [(NSTextAttachment, formula: Bool)]) -> NSMutableAttributedString {
    let result = NSMutableAttributedString(string: "Start ")
    for (attachment, formula) in attachments {
      let part = NSMutableAttributedString(attachment: attachment)
      if formula {
        part.addAttribute(.mathSource, value: "x^2", range: NSRange(location: 0, length: part.length))
      }
      result.append(part)
      result.append(NSAttributedString(string: " and "))
    }
    result.append(NSAttributedString(string: "end."))
    return result
  }

  /// The attachments of a string, with their ranges.
  private func attachments(in string: NSAttributedString) -> [(range: NSRange, attachment: NSTextAttachment)] {
    var result: [(NSRange, NSTextAttachment)] = []
    string.enumerateAttribute(.attachment,
                              in: NSRange(location: 0, length: string.length)) { value, range, _ in
      if let attachment = value as? NSTextAttachment {
        result.append((range, attachment))
      }
    }
    return result
  }

  // MARK: Resolution

  func testTheResolutionOfAnImageMakesItAsLargeAsItsBounds() throws {
    // 60 pixels shown as 20 points: 216 dots per inch
    let original = try self.attachment(pixels: 60, bounds: CGRect(x: 0, y: 0, width: 20, height: 20))
    let found = self.attachments(in: self.string(with: [(original, false)]).preparedForRTFD())
    let (dpi, pixels) = try self.resolution(of: self.data(of: try XCTUnwrap(found.first).attachment))
    XCTAssertEqual(found.count, 1)
    XCTAssertEqual(dpi, 216, accuracy: 0.01)
    XCTAssertEqual(pixels, 60)
  }

  func testTheResolutionDependsOnTheWidthOfEachImage() throws {
    let small = try self.attachment(pixels: 30, bounds: CGRect(x: 0, y: 0, width: 30, height: 30))
    let large = try self.attachment(pixels: 90, bounds: CGRect(x: 0, y: 0, width: 30, height: 30))
    let found = self.attachments(in: self.string(with: [(small, false), (large, false)]).preparedForRTFD())
    XCTAssertEqual(found.count, 2)
    XCTAssertEqual(try self.resolution(of: self.data(of: found[0].attachment)).dpi, 72, accuracy: 0.01)
    XCTAssertEqual(try self.resolution(of: self.data(of: found[1].attachment)).dpi, 216, accuracy: 0.01)
  }

  // MARK: Baseline

  func testTheVerticalPositionBecomesABaselineOffset() throws {
    let original = try self.attachment(pixels: 60, bounds: CGRect(x: 0, y: -4.5, width: 20, height: 18))
    let result = self.string(with: [(original, false)]).preparedForRTFD()
    let found = try XCTUnwrap(self.attachments(in: result).first)
    XCTAssertEqual(found.attachment.bounds, CGRect(x: 0, y: 0, width: 20, height: 18))
    XCTAssertEqual(try XCTUnwrap(result.attribute(.baselineOffset, at: found.range.location,
                                                  effectiveRange: nil) as? CGFloat), -4.5)
  }

  func testThereIsNoBaselineOffsetForAnImageOnTheBaseline() throws {
    let original = try self.attachment(pixels: 60, bounds: CGRect(x: 0, y: 0, width: 20, height: 18))
    let result = self.string(with: [(original, false)]).preparedForRTFD()
    let found = try XCTUnwrap(self.attachments(in: result).first)
    XCTAssertEqual(found.attachment.bounds, CGRect(x: 0, y: 0, width: 20, height: 18))
    XCTAssertNil(result.attribute(.baselineOffset, at: found.range.location, effectiveRange: nil))
  }

  // MARK: Names

  func testTheFilesOfImagesAndFormulasHaveNames() throws {
    let bounds = CGRect(x: 0, y: -2, width: 20, height: 20)
    let string = self.string(with: [(try self.attachment(pixels: 40, bounds: bounds), true),
                                    (try self.attachment(pixels: 40, bounds: bounds), false),
                                    (try self.attachment(pixels: 40, bounds: bounds), true),
                                    (try self.attachment(pixels: 40, bounds: bounds), false)])
    let names = self.attachments(in: string.preparedForRTFD()).map {
      $0.attachment.fileWrapper?.preferredFilename
    }
    XCTAssertEqual(names, ["Formula 1.png", "Image 1.png", "Formula 2.png", "Image 2.png"])
  }

  func testTheNamesAreTheNamesOfTheFilesOfTheDocument() throws {
    let bounds = CGRect(x: 0, y: -2, width: 20, height: 20)
    let string = self.string(with: [(try self.attachment(pixels: 40, bounds: bounds), true),
                                    (try self.attachment(pixels: 41, bounds: bounds), true),
                                    (try self.attachment(pixels: 42, bounds: bounds), false)])
    let prepared = string.preparedForRTFD()
    let document = try prepared.fileWrapper(from: NSRange(location: 0, length: prepared.length),
                                            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
    let names = Set(try XCTUnwrap(document.fileWrappers).keys)
    for name in ["Formula 1.png", "Formula 2.png", "Image 1.png"] {
      XCTAssertTrue(names.contains(name), "\(name) is not in \(names.sorted())")
    }
    XCTAssertEqual(names.count, 4, "\(names.sorted())")
  }

  func testTheSameImageTwiceIsStillShownTwice() throws {
    // The same formula twice has the same image: both references have to stay in the text
    let bounds = CGRect(x: 0, y: -2, width: 20, height: 20)
    let string = self.string(with: [(try self.attachment(pixels: 40, bounds: bounds), true),
                                    (try self.attachment(pixels: 40, bounds: bounds), true)])
    let prepared = string.preparedForRTFD()
    let document = try prepared.fileWrapper(from: NSRange(location: 0, length: prepared.length),
                                            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
    let text = try XCTUnwrap(try XCTUnwrap(document.fileWrappers?["TXT.rtf"]).regularFileContents)
    let rtf = String(decoding: text, as: UTF8.self)
    XCTAssertEqual(rtf.components(separatedBy: "\\NeXTGraphic").count - 1, 2, rtf)
    let names = Set(try XCTUnwrap(document.fileWrappers).keys).subtracting(["TXT.rtf"])
    XCTAssertFalse(names.isEmpty)
    for name in names {
      XCTAssertTrue(rtf.contains(name), "\(name) is not used in \(rtf)")
    }
  }

  // MARK: What stays as it is

  func testTheOriginalIsNotChanged() throws {
    let original = try self.attachment(pixels: 60, bounds: CGRect(x: 1, y: -4, width: 20, height: 18))
    let before = try self.data(of: original)
    let string = self.string(with: [(original, true)])
    let copy = NSAttributedString(attributedString: string)
    let prepared = string.preparedForRTFD()
    XCTAssertTrue(string.isEqual(to: copy))
    XCTAssertEqual(original.bounds, CGRect(x: 1, y: -4, width: 20, height: 18))
    XCTAssertEqual(try self.data(of: original), before)
    XCTAssertNil(string.attribute(.baselineOffset, at: 6, effectiveRange: nil))
    XCTAssertFalse(try XCTUnwrap(self.attachments(in: prepared).first).attachment === original)
  }

  func testTheTextAndItsAttributesAreKept() throws {
    let original = try self.attachment(pixels: 60, bounds: CGRect(x: 0, y: -4, width: 20, height: 18))
    let string = self.string(with: [(original, true)])
    let font = HRFont.systemFont(ofSize: 17)
    string.addAttribute(.font, value: font, range: NSRange(location: 0, length: 5))
    let prepared = string.preparedForRTFD()
    XCTAssertEqual(prepared.string, string.string)
    XCTAssertEqual(prepared.length, string.length)
    XCTAssertEqual(prepared.attribute(.font, at: 0, effectiveRange: nil) as? HRFont, font)
    let found = try XCTUnwrap(self.attachments(in: prepared).first)
    XCTAssertEqual(found.range, NSRange(location: 6, length: 1))
    XCTAssertEqual(prepared.attribute(.mathSource, at: found.range.location, effectiveRange: nil) as? String, "x^2")
  }

  func testAttachmentsWithoutDataOrWithoutSizeStayAsTheyAre() throws {
    let empty = NSTextAttachment()
    empty.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)
    let noSize = try self.attachment(pixels: 40, bounds: .zero)
    let notAnImage = NSTextAttachment(data: Data("hello".utf8), ofType: UTType.plainText.identifier)
    notAnImage.bounds = CGRect(x: 0, y: -2, width: 10, height: 10)
    let string = self.string(with: [(empty, false), (noSize, false), (notAnImage, false)])
    let found = self.attachments(in: string.preparedForRTFD())
    XCTAssertEqual(found.count, 3)
    XCTAssertTrue(found[0].attachment === empty)
    XCTAssertTrue(found[1].attachment === noSize)
    XCTAssertTrue(found[2].attachment === notAnImage)
    XCTAssertEqual(notAnImage.bounds, CGRect(x: 0, y: -2, width: 10, height: 10))
  }

  func testAStringWithoutAttachmentsIsAnEqualString() {
    let string = NSAttributedString(string: "No images here.",
                                    attributes: [.baselineOffset: 2])
    XCTAssertTrue(string.preparedForRTFD().isEqual(to: string))
    XCTAssertEqual(NSAttributedString().preparedForRTFD().length, 0)
  }

  // MARK: Export

  func testTheExportedDocumentKeepsTheSizeAndThePositionOfImages() throws {
    let original = try self.attachment(pixels: 60, bounds: CGRect(x: 0, y: -4, width: 20, height: 18))
    let prepared = self.string(with: [(original, true)]).preparedForRTFD()
    let document = try prepared.fileWrapper(from: NSRange(location: 0, length: prepared.length),
                                            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
    let png = try XCTUnwrap(try XCTUnwrap(document.fileWrappers?["Formula 1.png"]).regularFileContents)
    XCTAssertEqual(try self.resolution(of: png).dpi, 216, accuracy: 0.01)
    // The text of the document has the offset (in half points) and the name of the file
    let text = try XCTUnwrap(try XCTUnwrap(document.fileWrappers?["TXT.rtf"]).regularFileContents)
    let rtf = String(decoding: text, as: UTF8.self)
    XCTAssertTrue(rtf.contains("\\dn8 "), rtf)
    XCTAssertTrue(rtf.contains("Formula 1.png"), rtf)
  }
}

#endif
