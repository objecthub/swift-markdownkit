//
//  ImageInsetsTests.swift
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

import XCTest
import CoreGraphics
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
@testable import MarkdownKit

/// Tests for giving images transparent insets of a given width (`CGImage.withInsets` and, on
/// macOS and iOS, `MarkdownImageUtil.image(_:withInsets:)`).
final class ImageInsetsTests: XCTestCase {

  /// The margins of the content of an image in pixels.
  private struct Margins: Equatable {
    var top: Int, left: Int, bottom: Int, right: Int
  }

  /// An image with a transparent background and an opaque rectangle (`content`: the position
  /// and size in pixels, with the origin in the upper left corner).
  private func makeBitmap(width: Int, height: Int, content: CGRect?, halo: CGRect? = nil) throws -> CGImage {
    let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    // A faint area around the content, like the edges that antialiasing creates: its alpha value is 3
    if let halo {
      context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 3.0 / 255.0))
      context.fill(CGRect(x: halo.minX, y: CGFloat(height) - halo.maxY, width: halo.width, height: halo.height))
    }
    if let content {
      context.setFillColor(CGColor(srgbRed: 0.8, green: 0.1, blue: 0.1, alpha: 1))
      context.fill(CGRect(x: content.minX, y: CGFloat(height) - content.maxY,
                          width: content.width, height: content.height))
    }
    return try XCTUnwrap(context.makeImage())
  }

  private func margins(of bitmap: CGImage) throws -> Margins {
    let bounds = try XCTUnwrap(bitmap.contentBounds())
    return Margins(top: Int(bounds.minY), left: Int(bounds.minX),
                   bottom: bitmap.height - Int(bounds.maxY), right: bitmap.width - Int(bounds.maxX))
  }

  // MARK: Pixels

  func testContentBoundsAreTheNonTransparentArea() throws {
    let bitmap = try self.makeBitmap(width: 100, height: 60, content: CGRect(x: 30, y: 20, width: 20, height: 10))
    XCTAssertEqual(bitmap.contentBounds(), CGRect(x: 30, y: 20, width: 20, height: 10))
    let full = try self.makeBitmap(width: 10, height: 8, content: CGRect(x: 0, y: 0, width: 10, height: 8))
    XCTAssertEqual(full.contentBounds(), CGRect(x: 0, y: 0, width: 10, height: 8))
    let single = try self.makeBitmap(width: 10, height: 8, content: CGRect(x: 9, y: 7, width: 1, height: 1))
    XCTAssertEqual(single.contentBounds(), CGRect(x: 9, y: 7, width: 1, height: 1))
    // An image without content has no bounds
    XCTAssertNil(try self.makeBitmap(width: 10, height: 8, content: nil).contentBounds())
  }

  func testMissingSpaceIsAdded() throws {
    // The content touches all edges
    let bitmap = try self.makeBitmap(width: 20, height: 10, content: CGRect(x: 0, y: 0, width: 20, height: 10))
    let result = try XCTUnwrap(bitmap.withInsets(top: 1, left: 2, bottom: 3, right: 4))
    XCTAssertEqual(result.width, 26)
    XCTAssertEqual(result.height, 14)
    XCTAssertEqual(try self.margins(of: result), Margins(top: 1, left: 2, bottom: 3, right: 4))
  }

  func testExcessiveSpaceIsRemoved() throws {
    let bitmap = try self.makeBitmap(width: 100, height: 60, content: CGRect(x: 30, y: 20, width: 20, height: 10))
    let result = try XCTUnwrap(bitmap.withInsets(top: 2, left: 2, bottom: 2, right: 2))
    XCTAssertEqual(result.width, 24)
    XCTAssertEqual(result.height, 14)
    XCTAssertEqual(try self.margins(of: result), Margins(top: 2, left: 2, bottom: 2, right: 2))
    // Without insets, the image is as large as its content
    let tight = try XCTUnwrap(bitmap.withInsets(top: 0, left: 0, bottom: 0, right: 0))
    XCTAssertEqual(tight.width, 20)
    XCTAssertEqual(tight.height, 10)
  }

  func testEveryEdgeHasItsOwnInset() throws {
    // Too much space on the left and at the top, too little on the right, exactly right below
    let bitmap = try self.makeBitmap(width: 100, height: 60, content: CGRect(x: 40, y: 30, width: 59, height: 20))
    XCTAssertEqual(try self.margins(of: bitmap), Margins(top: 30, left: 40, bottom: 10, right: 1))
    let result = try XCTUnwrap(bitmap.withInsets(top: 5, left: 3, bottom: 10, right: 6))
    XCTAssertEqual(try self.margins(of: result), Margins(top: 5, left: 3, bottom: 10, right: 6))
    XCTAssertEqual(result.width, 3 + 59 + 6)
    XCTAssertEqual(result.height, 5 + 20 + 10)
  }

  func testTheContentIsNotChanged() throws {
    let bitmap = try self.makeBitmap(width: 50, height: 40, content: CGRect(x: 10, y: 8, width: 12, height: 6))
    let result = try XCTUnwrap(bitmap.withInsets(top: 3, left: 4, bottom: 5, right: 6))
    // Read the pixels of the result: the opaque area is exactly the content, in its color
    let context = try XCTUnwrap(CGContext(data: nil, width: result.width, height: result.height,
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(result, in: CGRect(x: 0, y: 0, width: result.width, height: result.height))
    let pixels = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: context.bytesPerRow * result.height)
    var opaque = 0
    for y in 0..<result.height {
      for x in 0..<result.width where pixels[y * context.bytesPerRow + x * 4 + 3] == 255 {
        opaque += 1
        XCTAssertEqual(pixels[y * context.bytesPerRow + x * 4], 204)
        XCTAssertEqual(pixels[y * context.bytesPerRow + x * 4 + 1], 26)
      }
    }
    XCTAssertEqual(opaque, 12 * 6)
  }

  func testTheThresholdForTransparencyIsConfigurable() throws {
    // A solid rectangle with a faint halo (alpha value 3) around it
    let bitmap = try self.makeBitmap(width: 60, height: 40,
                                     content: CGRect(x: 25, y: 15, width: 10, height: 10),
                                     halo: CGRect(x: 10, y: 5, width: 40, height: 30))
    // By default, the halo is transparent
    XCTAssertEqual(bitmap.contentBounds(), CGRect(x: 25, y: 15, width: 10, height: 10))
    XCTAssertEqual(bitmap.contentBounds(transparentAlpha: 4), CGRect(x: 25, y: 15, width: 10, height: 10))
    XCTAssertEqual(bitmap.contentBounds(transparentAlpha: 3), CGRect(x: 25, y: 15, width: 10, height: 10))
    // With a lower threshold, it is content
    XCTAssertEqual(bitmap.contentBounds(transparentAlpha: 2), CGRect(x: 10, y: 5, width: 40, height: 30))
    XCTAssertEqual(bitmap.contentBounds(transparentAlpha: 0), CGRect(x: 10, y: 5, width: 40, height: 30))
    // With the highest threshold, nothing is content
    XCTAssertNil(bitmap.contentBounds(transparentAlpha: 255))
    // The insets are placed around what the threshold says is content
    let tight = try XCTUnwrap(bitmap.withInsets(top: 1, left: 2, bottom: 3, right: 4))
    XCTAssertEqual(tight.width, 2 + 10 + 4)
    XCTAssertEqual(tight.height, 1 + 10 + 3)
    let wide = try XCTUnwrap(bitmap.withInsets(top: 1, left: 2, bottom: 3, right: 4, transparentAlpha: 0))
    XCTAssertEqual(wide.width, 2 + 40 + 4)
    XCTAssertEqual(wide.height, 1 + 30 + 3)
    XCTAssertNil(bitmap.withInsets(top: 1, left: 1, bottom: 1, right: 1, transparentAlpha: 255))
  }

  func testAnImageWithoutContentGivesNothing() throws {
    let bitmap = try self.makeBitmap(width: 20, height: 10, content: nil)
    XCTAssertNil(bitmap.withInsets(top: 1, left: 1, bottom: 1, right: 1))
  }

  func testNegativeWidthsCountAsZero() throws {
    let bitmap = try self.makeBitmap(width: 20, height: 10, content: CGRect(x: 5, y: 2, width: 4, height: 3))
    let result = try XCTUnwrap(bitmap.withInsets(top: -3, left: 1, bottom: 0, right: -1))
    XCTAssertEqual(try self.margins(of: result), Margins(top: 0, left: 1, bottom: 0, right: 0))
  }

  // MARK: Images of the platform

  #if os(macOS) || os(iOS)

  /// An image of the platform, with `scale` pixels per point.
  private func makeImage(width: Int, height: Int, scale: CGFloat, content: CGRect?) throws -> HRImage {
    let bitmap = try self.makeBitmap(width: width, height: height, content: content)
    #if os(macOS)
    return NSImage(cgImage: bitmap, size: NSSize(width: CGFloat(width) / scale, height: CGFloat(height) / scale))
    #else
    return UIImage(cgImage: bitmap, scale: scale, orientation: .up)
    #endif
  }

  /// The margins of the content of an image of the platform in pixels, and its resolution.
  private func measure(_ image: HRImage) throws -> (margins: Margins, width: Int, height: Int, scale: CGFloat) {
    #if os(macOS)
    var rect = CGRect(origin: .zero, size: image.size)
    let bitmap = try XCTUnwrap(image.cgImage(forProposedRect: &rect, context: nil, hints: nil))
    let scale = CGFloat(bitmap.width) / image.size.width
    #else
    let bitmap = try XCTUnwrap(image.cgImage)
    let scale = image.scale
    #endif
    return (try self.margins(of: bitmap), bitmap.width, bitmap.height, scale)
  }

  func testTheInsetsOfAnImageAreGivenInPoints() throws {
    // 3 pixels per point: the content has a margin of 12, 6, 3 and 30 pixels, which is
    // 4, 2, 1 and 10 points
    let image = try self.makeImage(width: 90, height: 60, scale: 3, content: CGRect(x: 6, y: 12, width: 54, height: 45))
    let result = try XCTUnwrap(MarkdownImageUtil.image(image, withInsets: .init(top: 2, left: 3, bottom: 4, right: 1)))
    let measured = try self.measure(result)
    XCTAssertEqual(measured.margins, Margins(top: 6, left: 9, bottom: 12, right: 3))
    XCTAssertEqual(measured.width, 9 + 54 + 3)
    XCTAssertEqual(measured.height, 6 + 45 + 12)
    // The resolution is the one of the original, so the size in points is the number of pixels
    // divided by it
    XCTAssertEqual(measured.scale, 3)
    XCTAssertEqual(result.size.width, CGFloat(9 + 54 + 3) / 3, accuracy: 0.001)
    XCTAssertEqual(result.size.height, CGFloat(6 + 45 + 12) / 3, accuracy: 0.001)
    #if os(macOS)
    XCTAssertEqual(result.representations.first?.size, result.size)
    #endif
  }

  func testInsetsAreRoundedToWholePixels() throws {
    let image = try self.makeImage(width: 40, height: 30, scale: 2, content: CGRect(x: 5, y: 5, width: 10, height: 10))
    // 1.25 points are 2.5 pixels, which become 3; 0.2 points are 0.4 pixels, which become 0
    let result = try XCTUnwrap(MarkdownImageUtil.image(image, withInsets: .init(top: 1.25, left: 0.2, bottom: 0.7, right: 2)))
    XCTAssertEqual(try self.measure(result).margins, Margins(top: 3, left: 0, bottom: 1, right: 4))
  }

  func testTheThresholdForTransparencyOfAnImageIsConfigurable() throws {
    let bitmap = try self.makeBitmap(width: 60, height: 40, content: CGRect(x: 25, y: 15, width: 10, height: 10),
                                     halo: CGRect(x: 10, y: 5, width: 40, height: 30))
    #if os(macOS)
    let image = NSImage(cgImage: bitmap, size: NSSize(width: 60, height: 40))
    #else
    let image = UIImage(cgImage: bitmap, scale: 1, orientation: .up)
    #endif
    let tight = try XCTUnwrap(MarkdownImageUtil.image(image, withInsets: .init(2)))
    XCTAssertEqual(try self.measure(tight).width, 14)
    let wide = try XCTUnwrap(MarkdownImageUtil.image(image, withInsets: .init(2), transparentAlpha: 0))
    XCTAssertEqual(try self.measure(wide).width, 44)
    XCTAssertEqual(try self.measure(wide).height, 34)
    XCTAssertNil(MarkdownImageUtil.image(image, withInsets: .init(2), transparentAlpha: 255))
  }

  func testTheInsetsHaveConvenienceInitializers() {
    XCTAssertEqual(MarkdownImageUtil.Insets(5), MarkdownImageUtil.Insets(top: 5, left: 5, bottom: 5, right: 5))
    XCTAssertEqual(MarkdownImageUtil.Insets(horizontal: 2, vertical: 7),
                   MarkdownImageUtil.Insets(top: 7, left: 2, bottom: 7, right: 2))
    XCTAssertEqual(MarkdownImageUtil.Insets.none, MarkdownImageUtil.Insets(0))
  }

  func testAnImageWithoutContentOfThePlatformGivesNothing() throws {
    let image = try self.makeImage(width: 20, height: 10, scale: 1, content: nil)
    XCTAssertNil(MarkdownImageUtil.image(image, withInsets: .init(4)))
  }

  #endif

  #if canImport(WebKit) && (os(macOS) || os(iOS))

  func testTheImagesOfTheRenderersGetUniformInsets() async throws {
    let katex = try XCTUnwrap(Resources.katexFolder)
    let math = try XCTUnwrap(MathRenderer(katexFolder: katex))
    let script = try XCTUnwrap(Resources.bundle?.url(forResource: "mermaid.min", withExtension: "js"))
    let mermaid = try XCTUnwrap(MermaidRenderer(mermaidJSURL: script))
    let util = MarkdownImageUtil(mermaidRenderer: mermaid, mathRenderer: math)
    let insets = MarkdownImageUtil.Insets(horizontal: 4, vertical: 2)
    var images: [(HRImage, CGFloat)] = []
    for tex in ["x", "\\frac{a}{b}", "\\sum_{i=1}^{n} i^2"] {
      images.append((try await util.mathImage(tex), 3))
    }
    images.append((try await util.mermaidImage("graph LR\n  A --> B\n"), 2))
    for (image, scale) in images {
      let padded = try XCTUnwrap(MarkdownImageUtil.image(image, withInsets: insets))
      let measured = try self.measure(padded)
      XCTAssertEqual(measured.scale, scale)
      XCTAssertEqual(measured.margins, Margins(top: Int(2 * scale), left: Int(4 * scale),
                                               bottom: Int(2 * scale), right: Int(4 * scale)))
      // Doing it twice changes nothing
      let again = try XCTUnwrap(MarkdownImageUtil.image(padded, withInsets: insets))
      XCTAssertEqual(try self.measure(again).margins, measured.margins)
      XCTAssertEqual(again.size, padded.size)
    }
  }

  #endif
}
