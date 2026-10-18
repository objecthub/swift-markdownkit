//
//  MathRendererTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 17/10/2026.
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
import ImageIO
@testable import MarkdownKit

#if canImport(WebKit) && (os(macOS) || os(iOS))

/// Tests for drawing formulas into images with KaTeX in a web view.
final class MathRendererTests: XCTestCase {

  private func renderer(transparency: MathWebSession.Transparency = .automatic,
                        idleTime: TimeInterval = MathRenderer.defaultIdleTime,
                        maxCachedFormulas: Int = MathRenderer.defaultMaxCachedFormulas) throws -> MathRenderer {
    let folder = try XCTUnwrap(Resources.katexFolder, "the resources of KaTeX are missing")
    return try XCTUnwrap(MathRenderer(katexFolder: folder, idleTime: idleTime,
                                      maxCachedFormulas: maxCachedFormulas,
                                      maxCacheBytes: MathRenderer.defaultMaxCacheBytes,
                                      transparency: transparency))
  }

  private func formula(_ tex: String, display: Bool = false) -> MathFormula {
    return MathFormula(tex: tex, display: display)
  }

  /// The pixels (RGBA, premultiplied) of a PNG, with its width and height.
  private func pixels(_ png: Data) throws -> (rgba: [UInt8], width: Int, height: Int) {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try data.withUnsafeMutableBytes { buffer in
      let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width,
                                            height: image.height, bitsPerComponent: 8,
                                            bytesPerRow: image.width * 4,
                                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return (data, image.width, image.height)
  }

  private func success(_ result: Result<MathImage, MathError>?, _ message: String = "") throws -> MathImage {
    switch try XCTUnwrap(result, message) {
      case .success(let image):
        return image
      case .failure(let error):
        XCTFail("\(message): \(error)")
        throw error
    }
  }

  func testFormulasBecomeBlackImagesOnATransparentBackground() async throws {
    let renderer = try self.renderer()
    let formulas = [self.formula("x^2"), self.formula("\\frac{a}{b}"),
                    self.formula("\\sum_{i=1}^{n} i^2", display: true)]
    let results = await renderer.render(formulas, fontSize: 14)
    XCTAssertEqual(results.count, 3)
    for formula in formulas {
      let image = try self.success(results[formula], formula.tex)
      XCTAssertEqual(image.scale, 3)
      XCTAssertGreaterThan(image.size.width, 5, formula.tex)
      XCTAssertGreaterThan(image.size.height, 8, formula.tex)
      XCTAssertGreaterThan(image.depth, 0, formula.tex)
      XCTAssertLessThan(image.depth, image.size.height, formula.tex)
      let (rgba, width, height) = try self.pixels(image.pngData)
      XCTAssertEqual(width, Int((image.size.width * 3).rounded()), formula.tex)
      XCTAssertEqual(height, Int((image.size.height * 3).rounded()), formula.tex)
      // The corners are transparent, there is ink, and the ink is black
      for (x, y) in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)] {
        XCTAssertEqual(rgba[(y * width + x) * 4 + 3], 0, "\(formula.tex): corner \(x),\(y)")
      }
      var ink = 0
      var colored = 0
      for i in stride(from: 0, to: rgba.count, by: 4) where rgba[i + 3] > 0 {
        ink += 1
        if rgba[i] > 3 || rgba[i + 1] > 3 || rgba[i + 2] > 3 {
          colored += 1
        }
      }
      XCTAssertGreaterThan(ink, 50, formula.tex)
      XCTAssertEqual(colored, 0, "\(formula.tex): ink is not black")
    }
  }

  func testMetricsFollowTheTypesetting() async throws {
    let renderer = try self.renderer()
    let x = self.formula("x"), fraction = self.formula("\\frac{a}{b}"), sum = self.formula("\\sum_{i=0}^{n}", display: true)
    let results = await renderer.render([x, fraction, sum], fontSize: 14)
    let (imageX, imageFraction, imageSum) = (try self.success(results[x]), try self.success(results[fraction]),
                                             try self.success(results[sum]))
    // A fraction is taller than a letter and reaches further below the baseline; a display sum
    // is taller and wider still
    XCTAssertGreaterThan(imageFraction.size.height, imageX.size.height + 6)
    XCTAssertGreaterThan(imageFraction.depth, imageX.depth + 3)
    XCTAssertGreaterThan(imageSum.size.height, imageFraction.size.height)
    // The size is proportional to the font size
    let bigger = await renderer.render([fraction], fontSize: 28)
    let imageBig = try self.success(bigger[fraction])
    XCTAssertEqual(imageBig.size.height / imageFraction.size.height, 2, accuracy: 0.3)
    XCTAssertEqual(imageBig.depth / imageFraction.depth, 2, accuracy: 0.4)
    XCTAssertEqual(imageBig.size.width / imageFraction.size.width, 2, accuracy: 0.3)
    // The baseline is where the letter ends: the letter x has almost nothing below it but the margin
    XCTAssertLessThan(imageX.depth, 4)
    XCTAssertLessThan(imageX.size.height, 16)
  }

  func testInvalidFormulasAreRememberedAsFailures() async throws {
    let renderer = try self.renderer()
    let bad = self.formula("\\frac{"), good = self.formula("y")
    let results = await renderer.render([bad, good])
    guard case .failure(.syntaxError(let message))? = results[bad] else {
      return XCTFail("\(String(describing: results[bad]))")
    }
    XCTAssertTrue(message.contains("KaTeX parse error"), message)
    _ = try self.success(results[good])
    XCTAssertEqual(renderer.cachedFailure(for: bad), .syntaxError(message))
    XCTAssertNil(renderer.cachedImage(for: bad))
    XCTAssertNotNil(renderer.cachedImage(for: good))
    XCTAssertEqual(renderer.cachedFormulaCount, 2)
    // Another formula is not affected by an error in the page
    let again = await renderer.render([self.formula("z^2")])
    _ = try self.success(again[self.formula("z^2")])
  }

  func testResultsAreCached() async throws {
    let renderer = try self.renderer()
    let formulas = [self.formula("a+b"), self.formula("c+d")]
    let first = await renderer.renderFormulas(formulas, fontSize: 14, config: MathConfig())
    XCTAssertTrue(first.rendered)
    XCTAssertEqual(renderer.cachedFormulaCount, 2)
    let second = await renderer.renderFormulas(formulas + [formulas[0]], fontSize: 14, config: MathConfig())
    XCTAssertFalse(second.rendered)
    XCTAssertEqual(second.results.count, 2)
    XCTAssertEqual(try self.success(second.results[formulas[0]]), try self.success(first.results[formulas[0]]))
    // A different font size or configuration has its own entries
    XCTAssertNil(renderer.cachedImage(for: formulas[0], fontSize: 20))
    XCTAssertNil(renderer.cachedImage(for: formulas[0], config: MathConfig(katex: KaTeXOptions(maxExpand: 5))))
    XCTAssertNotNil(renderer.cachedImage(for: formulas[0], config: MathConfig(spacing: 40, maxWidth: 100, timeout: 3)))
    renderer.clearCache()
    XCTAssertEqual(renderer.cachedFormulaCount, 0)
  }

  func testTheCacheIsLimited() async throws {
    let renderer = try self.renderer(maxCachedFormulas: 3)
    let formulas = (0..<6).map { self.formula("n_\($0)") }
    _ = await renderer.render(formulas)
    XCTAssertEqual(renderer.cachedFormulaCount, 3)
    // The ones which were used last stay
    XCTAssertNotNil(renderer.cachedImage(for: formulas[5]))
    XCTAssertNil(renderer.cachedImage(for: formulas[0]))
  }

  func testManyFormulasAreRenderedInSeveralChunks() async throws {
    let renderer = try self.renderer()
    let formulas = (0..<250).map { self.formula($0 % 2 == 0 ? "x_{\($0)}^2" : "\\frac{\($0)}{2}", display: $0 % 5 == 0) }
    let results = await renderer.render(formulas)
    XCTAssertEqual(results.count, 250)
    for formula in formulas {
      guard case .success(let image)? = results[formula] else {
        return XCTFail("\(formula): \(String(describing: results[formula]))")
      }
      XCTAssertGreaterThan(image.pngData.count, 100)
    }
  }

  func testWideAndTallFormulas() async throws {
    let renderer = try self.renderer()
    let wide = self.formula((1...100).map { "a_{\($0)}" }.joined(separator: " + "))
    let tall = self.formula("\\begin{pmatrix}" + (1...12).map { "\($0)" }.joined(separator: "\\\\") + "\\end{pmatrix}",
                            display: true)
    let results = await renderer.render([wide, tall])
    let imageWide = try self.success(results[wide], "wide")
    let imageTall = try self.success(results[tall], "tall")
    XCTAssertGreaterThan(imageWide.size.width, 1000)
    XCTAssertGreaterThan(imageTall.size.height, 150)
    // The wide formula was captured completely: ink is near both edges
    let (rgba, width, height) = try self.pixels(imageWide.pngData)
    func inkInColumn(_ x: Int) -> Bool {
      return (0..<height).contains { rgba[($0 * width + x) * 4 + 3] > 0 }
    }
    XCTAssertTrue((0..<30).contains { inkInColumn($0) })
    XCTAssertTrue(((width - 30)..<width).contains { inkInColumn($0) })
  }

  func testNothingIsCutOff() async throws {
    let renderer = try self.renderer()
    let tex = ["\\int_0^\\infty e^{-x^2}\\,dx", "\\sqrt{\\frac{1}{1+\\frac{1}{x}}}", "\\hat{A}\\vec{v}\\tilde{n}",
               "\\sum_{i=1}^{n}\\prod_{j}^{m} a_{ij}", "f(x)=\\begin{cases}1&x>0\\\\0&x\\le 0\\end{cases}",
               "\\mathcal{L}\\mathbb{R}\\mathfrak{g}", "\\left(\\frac{a}{b}\\right)^{\\!2}", "\\overbrace{x+y}^{n}",
               "j\\,f\\,\\gamma\\,\\Omega", "\\lim_{x\\to 0}\\frac{\\sin x}{x}"]
    for display in [false, true] {
      for fontSize in [Float(12), 14, 24] {
        let formulas = tex.map { self.formula($0, display: display) }
        let results = await renderer.render(formulas, fontSize: fontSize)
        for formula in formulas {
          let image = try self.success(results[formula], formula.tex)
          let (rgba, width, height) = try self.pixels(image.pngData)
          func inkInRow(_ y: Int) -> Bool {
            return (0..<width).contains { rgba[(y * width + $0) * 4 + 3] > 8 }
          }
          func inkInColumn(_ x: Int) -> Bool {
            return (0..<height).contains { rgba[($0 * width + x) * 4 + 3] > 8 }
          }
          let description = "\(formula.tex) display: \(display) size: \(fontSize)"
          // The drawings of roots and braces are huge elements, but they are clipped
          XCTAssertLessThan(image.size.width, CGFloat(fontSize) * 20, description)
          XCTAssertFalse(inkInRow(0), "ink in the first row of \(description)")
          XCTAssertFalse(inkInRow(height - 1), "ink in the last row of \(description)")
          XCTAssertFalse(inkInColumn(0), "ink in the first column of \(description)")
          XCTAssertFalse(inkInColumn(width - 1), "ink in the last column of \(description)")
          // The image is not larger than the formula needs: the margin is a few points
          var firstRow = 0
          while firstRow < height && !inkInRow(firstRow) {
            firstRow += 1
          }
          XCTAssertLessThan(CGFloat(firstRow) / image.scale, CGFloat(fontSize) * 0.6, description)
        }
      }
    }
  }

  func testMacrosAndLimits() async throws {
    let renderer = try self.renderer()
    let uses = self.formula("x \\in \\RR")
    let plain = await renderer.render([uses])
    guard case .failure(.syntaxError)? = plain[uses] else {
      return XCTFail("\(String(describing: plain[uses]))")
    }
    let config = MathConfig(katex: KaTeXOptions(macros: ["\\RR": "\\mathbb{R}"]))
    let withMacro = await renderer.render([uses], config: config)
    _ = try self.success(withMacro[uses])
    let long = self.formula(String(repeating: "x", count: 30))
    let limited = await renderer.render([long], config: MathConfig(katex: KaTeXOptions(maxLength: 10)))
    XCTAssertEqual(limited[long], .failure(.tooLong(10)))
  }

  func testTheMatteMethodGivesTheSameImages() async throws {
    let normal = try self.renderer()
    let matte = try self.renderer(transparency: .matte)
    let formulas = [self.formula("\\int_0^1 x^2\\,dx"), self.formula("\\sqrt{a^2+b^2}", display: true)]
    let a = await normal.render(formulas)
    let b = await matte.render(formulas)
    for formula in formulas {
      let imageA = try self.success(a[formula]), imageB = try self.success(b[formula])
      XCTAssertEqual(imageA.size, imageB.size)
      XCTAssertEqual(imageA.depth, imageB.depth)
      let (pa, w, h) = try self.pixels(imageA.pngData), (pb, wb, hb) = try self.pixels(imageB.pngData)
      XCTAssertEqual(w, wb)
      XCTAssertEqual(h, hb)
      // The alpha values are the same, apart from the antialiasing of the different paths
      var different = 0
      for i in stride(from: 3, to: pa.count, by: 4) where abs(Int(pa[i]) - Int(pb[i])) > 40 {
        different += 1
      }
      XCTAssertLessThan(Double(different) / Double(pa.count / 4), 0.01, formula.tex)
      // The matte images are black as well
      XCTAssertFalse(stride(from: 0, to: pb.count, by: 4).contains { pb[$0 + 3] > 0 && (pb[$0] > 3 || pb[$0 + 1] > 3) })
    }
  }

  func testATimeoutIsReportedAndTheRendererRecovers() async throws {
    let renderer = try self.renderer()
    // Even creating the page takes longer than this
    let formula = self.formula("t^2")
    let results = await renderer.render([formula], config: MathConfig(timeout: 0.001))
    guard case .failure(let error)? = results[formula] else {
      return XCTFail("rendering was not too slow: \(String(describing: results[formula]))")
    }
    XCTAssertEqual(error, .timedOut)
    // A timeout does not depend on the formula: it is not remembered
    XCTAssertNil(renderer.cachedFailure(for: formula, config: MathConfig(timeout: 0.001)))
    let again = await renderer.render([formula])
    _ = try self.success(again[formula])
  }

  func testConcurrentRequestsAreServedOneAfterTheOther() async throws {
    let renderer = try self.renderer()
    let first = (0..<30).map { self.formula("p_{\($0)}") }
    let second = (0..<30).map { self.formula("q_{\($0)}", display: true) }
    let third = (0..<30).map { self.formula("r_{\($0)}") }
    async let a = renderer.render(first)
    async let b = renderer.render(second)
    async let c = renderer.render(third)
    let (ra, rb, rc) = await (a, b, c)
    for results in [ra, rb, rc] {
      XCTAssertEqual(results.count, 30)
      for case .failure(let error) in results.values {
        XCTFail("\(error)")
      }
    }
  }

  func testThePageIsReleasedWhenIdle() async throws {
    let renderer = try self.renderer(idleTime: 0.2)
    _ = await renderer.render([self.formula("u")])
    try await Task.sleep(nanoseconds: 700_000_000)
    // A new page is created for the next request
    let results = await renderer.render([self.formula("v")])
    _ = try self.success(results[self.formula("v")])
  }

  func testCompletionHandlerVariant() async throws {
    let renderer = try self.renderer()
    let formula = self.formula("w^2")
    let expectation = expectation(description: "completion handler")
    nonisolated(unsafe) var onMainThread = false
    nonisolated(unsafe) var found = false
    renderer.render([formula]) { results in
      onMainThread = Thread.isMainThread
      if case .success? = results[formula] {
        found = true
      }
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 30)
    XCTAssertTrue(onMainThread)
    XCTAssertTrue(found)
  }

  func testASingleFormulaIsRenderedWithoutADictionary() async throws {
    let renderer = try self.renderer()
    let inline = try await renderer.render("\\frac{a}{b}")
    let display = try await renderer.render("\\frac{a}{b}", display: true)
    XCTAssertGreaterThan(inline.size.width, 5)
    XCTAssertGreaterThan(inline.depth, 0)
    XCTAssertEqual(inline.scale, 3)
    // Display math is typeset larger
    XCTAssertGreaterThan(display.size.height, inline.size.height)
    // The image is the one that the method for several formulas gives (it is cached)
    let formula = self.formula("\\frac{a}{b}")
    let batch = await renderer.render([formula])
    XCTAssertEqual(try self.success(batch[formula]), inline)
    XCTAssertEqual(renderer.cachedImage(for: formula), inline)
    // The font size and the configuration are parameters
    let big = try await renderer.render("\\frac{a}{b}", fontSize: 28)
    XCTAssertEqual(big.size.height / inline.size.height, 2, accuracy: 0.3)
    let macro = try await renderer.render("\\RR", config: MathConfig(katex: KaTeXOptions(macros: ["\\RR": "\\mathbb{R}"])))
    XCTAssertGreaterThan(macro.size.width, 5)
  }

  func testASingleFormulaThrowsItsError() async throws {
    let renderer = try self.renderer()
    do {
      _ = try await renderer.render("\\frac{")
      XCTFail("KaTeX accepted the formula")
    } catch let error as MathError {
      guard case .syntaxError(let message) = error else {
        return XCTFail("\(error)")
      }
      XCTAssertTrue(message.contains("KaTeX parse error"), message)
    }
    do {
      _ = try await renderer.render("xxxxxxxxxx", config: MathConfig(katex: KaTeXOptions(maxLength: 5)))
      XCTFail("the formula is too long")
    } catch let error as MathError {
      XCTAssertEqual(error, .tooLong(5))
    }
  }

  func testASingleFormulaWithACompletionHandler() async throws {
    let renderer = try self.renderer()
    let expectation = expectation(description: "completion handlers")
    expectation.expectedFulfillmentCount = 2
    nonisolated(unsafe) var image: MathImage?
    nonisolated(unsafe) var failure: MathError?
    nonisolated(unsafe) var onMainThread = true
    renderer.render("a^2", display: true) { result in
      onMainThread = onMainThread && Thread.isMainThread
      if case .success(let value) = result {
        image = value
      }
      expectation.fulfill()
    }
    renderer.render("\\frac{") { result in
      onMainThread = onMainThread && Thread.isMainThread
      if case .failure(let error) = result {
        failure = error
      }
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 30)
    XCTAssertTrue(onMainThread)
    XCTAssertGreaterThan(image?.size.width ?? 0, 5)
    guard case .syntaxError? = failure else {
      return XCTFail("\(String(describing: failure))")
    }
  }

  func testSharedRendererExists() {
    XCTAssertNotNil(MathRenderer.shared)
    XCTAssertNil(MathRenderer(katexFolder: URL(fileURLWithPath: "/nonexistent")))
  }

  func testFormulasInMarkdownAreFound() {
    let doc = MathMarkdownParser.standard.parse(
      "# Title $a$\n\nText $b$ and $$c$$ and *$a$* and [$d$](http://x.y)\n\n$$\ne\n$$\n\n" +
      "> quote $f$\n\n- item $g$\n\n| h | i |\n|---|---|\n| $j$ | $k$ |\n\n```math\nl\n```\n")
    XCTAssertEqual(doc.mathFormulas.map { $0.tex },
                   ["a", "b", "c", "d", "e", "f", "g", "j", "k", "l"])
    XCTAssertEqual(doc.mathFormulas.filter { $0.display }.map { $0.tex }, ["c", "e", "l"])
    guard case .document(let blocks) = doc else {
      return XCTFail("document expected")
    }
    XCTAssertEqual(blocks.mathFormulas, doc.mathFormulas)
  }
}

#endif
