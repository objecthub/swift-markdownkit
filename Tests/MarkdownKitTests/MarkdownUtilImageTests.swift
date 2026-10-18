//
//  MarkdownUtilImageTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 18/10/2026.
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

#if canImport(WebKit) && (os(macOS) || os(iOS))

import XCTest
import CoreGraphics
import ImageIO
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import MarkdownKit

/// Tests for `MarkdownUtil`, which draws diagrams and formulas into `NSImage` or `UIImage`.
final class MarkdownUtilImageTests: XCTestCase {

  private func makeUtil() throws -> (util: MarkdownUtil, math: MathRenderer, mermaid: MermaidRenderer) {
    let katex = try XCTUnwrap(Resources.katexFolder)
    let math = try XCTUnwrap(MathRenderer(katexFolder: katex))
    let script = try XCTUnwrap(Resources.bundle?.url(forResource: "mermaid.min", withExtension: "js"))
    let mermaid = try XCTUnwrap(MermaidRenderer(mermaidJSURL: script))
    return (MarkdownUtil(mermaidRenderer: mermaid, mathRenderer: math), math, mermaid)
  }

  /// The pixels of an image (red, green, blue and alpha, not premultiplied), and its width
  /// and height in pixels.
  private func pixels(_ image: HRImage) throws -> (rgba: [UInt8], width: Int, height: Int) {
    #if os(macOS)
    let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
    #else
    let cgImage = try XCTUnwrap(image.cgImage)
    #endif
    var data = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
    try data.withUnsafeMutableBytes { buffer in
      let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: cgImage.width,
                                            height: cgImage.height, bitsPerComponent: 8,
                                            bytesPerRow: cgImage.width * 4,
                                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    }
    return (data, cgImage.width, cgImage.height)
  }

  /// The color of the pixel which is the most opaque.
  private func inkColor(_ image: HRImage) throws -> [UInt8] {
    let (data, _, _) = try self.pixels(image)
    var best = 0
    for index in stride(from: 0, to: data.count, by: 4) where data[index + 3] > data[best + 3] {
      best = index
    }
    return Array(data[best..<(best + 4)])
  }

  // MARK: Formulas

  func testAFormulaBecomesAnImageWithTheSizeOfTheFormula() async throws {
    let (util, math, _) = try self.makeUtil()
    let image = try await util.mathImage("\\frac{a}{b}", fontSize: 16)
    let metrics = try await math.render("\\frac{a}{b}", fontSize: 16)
    XCTAssertEqual(image.size, metrics.size)
    XCTAssertGreaterThan(image.size.width, 5)
    XCTAssertGreaterThan(image.size.height, 10)
    let (_, width, height) = try self.pixels(image)
    XCTAssertEqual(width, Int((metrics.size.width * metrics.scale).rounded()))
    XCTAssertEqual(height, Int((metrics.size.height * metrics.scale).rounded()))
    #if !os(macOS)
    XCTAssertEqual(image.scale, metrics.scale)
    #endif
  }

  func testTheColorOfAFormula() async throws {
    let (util, _, _) = try self.makeUtil()
    let black = try await util.mathImage("x^2")
    XCTAssertEqual(try self.inkColor(black), [0, 0, 0, 255])
    #if os(macOS)
    let red = HRColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
    #else
    let red = HRColor(red: 1, green: 0, blue: 0, alpha: 1)
    #endif
    let colored = try await util.mathImage("x^2", color: red)
    XCTAssertEqual(try self.inkColor(colored), [255, 0, 0, 255])
    // The image of the same formula, which the renderer caches, is not changed by this
    let again = try await util.mathImage("x^2")
    XCTAssertEqual(try self.inkColor(again), [0, 0, 0, 255])
  }

  func testTheImageOfAColoredFormulaHasTheSameResolution() async throws {
    let (util, math, _) = try self.makeUtil()
    let metrics = try await math.render("x^2", fontSize: 16)
    #if os(macOS)
    let red = HRColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
    #else
    let red = HRColor(red: 1, green: 0, blue: 0, alpha: 1)
    #endif
    // Recoloring keeps the resolution of the PNG, which gives it its size in points
    let tinted = try XCTUnwrap(MathContext.tintedPNG(metrics.pngData, color: red))
    for png in [metrics.pngData, tinted] {
      let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
      let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
      XCTAssertEqual((properties[kCGImagePropertyDPIWidth] as? Double) ?? 0, 72 * Double(metrics.scale),
                     accuracy: 0.5)
    }
    #if os(macOS)
    let image = try await util.mathImage("x^2", fontSize: 16, color: red)
    XCTAssertEqual(image.size, metrics.size)
    XCTAssertEqual(image.representations.first?.size, metrics.size)
    let data = try XCTUnwrap(NSImage(data: tinted))
    XCTAssertEqual(data.size, metrics.size)
    #endif
  }

  func testTheBaselineOfAFormulaIsSetUpForAlignment() async throws {
    let (util, math, _) = try self.makeUtil()
    let metrics = try await math.render("\\frac{a}{b}")
    XCTAssertGreaterThan(metrics.depth, 0)
    let image = try await util.mathImage("\\frac{a}{b}")
    #if os(macOS)
    XCTAssertEqual(image.alignmentRect.origin.y, metrics.depth, accuracy: 0.001)
    XCTAssertEqual(image.alignmentRect.height, metrics.size.height - metrics.depth, accuracy: 0.001)
    #else
    XCTAssertEqual(image.baselineOffsetFromBottom ?? 0, metrics.depth, accuracy: 0.001)
    #endif
  }

  func testFormulasThatKaTeXRejectsThrow() async throws {
    let (util, _, _) = try self.makeUtil()
    do {
      _ = try await util.mathImage("\\frac{")
      XCTFail("KaTeX accepted the formula")
    } catch let error as MathError {
      guard case .syntaxError(let message) = error else {
        return XCTFail("\\(error)")
      }
      XCTAssertTrue(message.contains("KaTeX parse error"), message)
    }
  }

  func testTheRendererOfTheUtilityIsUsed() async throws {
    let (util, math, _) = try self.makeUtil()
    XCTAssertEqual(math.cachedFormulaCount, 0)
    _ = try await util.mathImage("a+b")
    XCTAssertEqual(math.cachedFormulaCount, 1)
    XCTAssertNotNil(math.cachedImage(for: MathFormula(tex: "a+b", display: false)))
    // The options of the configuration are used
    let config = MathConfig(katex: KaTeXOptions(macros: ["\\RR": "\\mathbb{R}"]))
    _ = try await util.mathImage("x \\in \\RR", config: config)
    XCTAssertEqual(math.cachedFormulaCount, 2)
  }

  func testAFormulaWithACompletionHandler() async throws {
    let (util, _, _) = try self.makeUtil()
    let expectation = expectation(description: "completion handlers")
    expectation.expectedFulfillmentCount = 2
    nonisolated(unsafe) var size = CGSize.zero
    nonisolated(unsafe) var failure: MathError?
    nonisolated(unsafe) var onMainThread = true
    util.mathImage("a^2", display: true) { result in
      onMainThread = onMainThread && Thread.isMainThread
      if case .success(let image) = result {
        size = image.size
      }
      expectation.fulfill()
    }
    util.mathImage("\\frac{") { result in
      onMainThread = onMainThread && Thread.isMainThread
      if case .failure(let error) = result {
        failure = error
      }
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 30)
    XCTAssertTrue(onMainThread)
    XCTAssertGreaterThan(size.width, 5)
    guard case .syntaxError? = failure else {
      return XCTFail("\\(String(describing: failure))")
    }
  }

  // MARK: Diagrams

  func testADiagramBecomesAnImageWithTheSizeOfTheDiagram() async throws {
    let (util, _, mermaid) = try self.makeUtil()
    let source = "graph LR\n  A[Start] --> B[End]\n"
    let image = try await util.mermaidImage(source)
    let diagram = try await mermaid.render(source, config: .default)
    XCTAssertEqual(image.size, diagram.size)
    XCTAssertGreaterThan(image.size.width, 40)
    XCTAssertGreaterThan(image.size.height, 20)
    let (_, width, height) = try self.pixels(image)
    XCTAssertEqual(width, Int((diagram.size.width * diagram.scale).rounded()))
    XCTAssertEqual(height, Int((diagram.size.height * diagram.scale).rounded()))
    // The diagram is on a transparent background
    let (data, _, _) = try self.pixels(image)
    XCTAssertEqual(data[3], 0)
  }

  func testADiagramUsesItsConfiguration() async throws {
    let (util, _, _) = try self.makeUtil()
    let source = "graph LR\n  A --> B\n"
    let small = try await util.mermaidImage(source, config: MermaidConfig(scale: 1))
    let large = try await util.mermaidImage(source, config: MermaidConfig(scale: 2))
    // The size in points hardly depends on the scale (the image is aligned to whole pixels)
    XCTAssertEqual(small.size.width, large.size.width, accuracy: 1)
    XCTAssertEqual(small.size.height, large.size.height, accuracy: 1.5)
    let (_, smallWidth, _) = try self.pixels(small)
    let (_, largeWidth, _) = try self.pixels(large)
    XCTAssertEqual(Double(largeWidth) / Double(smallWidth), 2, accuracy: 0.1)
  }

  func testDiagramsThatMermaidRejectsThrow() async throws {
    let (util, _, _) = try self.makeUtil()
    do {
      _ = try await util.mermaidImage("flowchart TD\n  A --> --> B ((\n")
      XCTFail("Mermaid accepted the diagram")
    } catch let error as MermaidError {
      guard case .syntaxError = error else {
        return XCTFail("\\(error)")
      }
    }
  }

  func testADiagramWithACompletionHandler() async throws {
    let (util, _, _) = try self.makeUtil()
    let expectation = expectation(description: "completion handler")
    nonisolated(unsafe) var size = CGSize.zero
    nonisolated(unsafe) var onMainThread = false
    util.mermaidImage("graph LR\n  A --> B\n") { result in
      onMainThread = Thread.isMainThread
      if case .success(let image) = result {
        size = image.size
      }
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 60)
    XCTAssertTrue(onMainThread)
    XCTAssertGreaterThan(size.width, 20)
  }

  // MARK: The shared utility

  func testTheStandardUtilityUsesTheSharedRenderers() {
    XCTAssertNil(MarkdownUtil.standard.mermaidRenderer)
    XCTAssertNil(MarkdownUtil.standard.mathRenderer)
    XCTAssertNotNil(MermaidRenderer.shared)
    XCTAssertNotNil(MathRenderer.shared)
  }
}

#endif
