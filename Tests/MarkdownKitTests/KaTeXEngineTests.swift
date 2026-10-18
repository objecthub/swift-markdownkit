//
//  KaTeXEngineTests.swift
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
import MarkdownKit

#if os(macOS) || os(iOS) || os(tvOS)

/// Tests for typesetting formulas with KaTeX in JavaScriptCore.
final class KaTeXEngineTests: XCTestCase {

  private func engine() throws -> KaTeXEngine {
    return try XCTUnwrap(KaTeXEngine.shared, "KaTeX is not available")
  }

  func testTheBundledKaTeXIsLoaded() throws {
    let engine = try self.engine()
    XCTAssertEqual(engine.version, KaTeXEngine.bundledVersion)
    XCTAssertEqual(KaTeXEngine.stylesheetURL.absoluteString,
                   "https://cdn.jsdelivr.net/npm/katex@\(KaTeXEngine.bundledVersion)/dist/katex.min.css")
  }

  func testOutputModes() throws {
    let engine = try self.engine()
    let html = try engine.render("x^2", options: KaTeXOptions(output: .html))
    XCTAssertTrue(html.hasPrefix("<span class=\"katex\">"), html)
    XCTAssertTrue(html.contains("katex-html"), html)
    XCTAssertFalse(html.contains("<math"), html)
    let mathml = try engine.render("x^2", options: KaTeXOptions(output: .mathml))
    XCTAssertTrue(mathml.contains("<math"), mathml)
    XCTAssertTrue(mathml.contains("<msup>"), mathml)
    XCTAssertTrue(mathml.contains("<annotation encoding=\"application/x-tex\">x^2</annotation>"), mathml)
    XCTAssertFalse(mathml.contains("katex-html"), mathml)
    let both = try engine.render("x^2")
    XCTAssertTrue(both.contains("katex-html") && both.contains("<math"), both)
  }

  func testDisplayMode() throws {
    let engine = try self.engine()
    let inline = try engine.render("\\sum_{i=0}^n i", display: false, options: KaTeXOptions(output: .html))
    let display = try engine.render("\\sum_{i=0}^n i", display: true, options: KaTeXOptions(output: .html))
    XCTAssertFalse(inline.contains("katex-display"), inline)
    XCTAssertTrue(display.contains("katex-display"), display)
    let block = try engine.render("x", display: true, options: KaTeXOptions(output: .mathml))
    XCTAssertTrue(block.contains("display=\"block\""), block)
  }

  func testCommonFormulas() throws {
    let engine = try self.engine()
    let options = KaTeXOptions(output: .mathml)
    XCTAssertTrue(try engine.render("\\frac{a}{b}", options: options).contains("<mfrac>"))
    XCTAssertTrue(try engine.render("\\sqrt{x^2+y^2}", options: options).contains("<msqrt>"))
    XCTAssertTrue(try engine.render("\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}", display: true,
                                    options: options).contains("<mtable"))
    XCTAssertTrue(try engine.render("\\int_0^1 f(x)\\,dx", options: options).contains("∫"))
    XCTAssertTrue(try engine.render("\\alpha + \\beta", options: options).contains("α"))
    // Unicode text and an empty formula
    XCTAssertTrue(try engine.render("x ≤ y", options: options).contains("≤"))
    XCTAssertNoThrow(try engine.render("", options: options))
  }

  func testInvalidLaTeXIsReportedAsParseError() throws {
    let engine = try self.engine()
    for (tex, message) in [("\\frac{", "Unexpected end of input"),
                           ("\\badcmd", "Undefined control sequence: \\badcmd"),
                           ("x^", "Expected group after '^'"),
                           ("\\begin{pmatrix}a", "Expected & or \\\\ or \\cr or \\end")] {
      do {
        let html = try engine.render(tex)
        XCTFail("\(tex) was typeset: \(html)")
      } catch KaTeXError.parse(let found) {
        XCTAssertTrue(found.hasPrefix("KaTeX parse error"), found)
        XCTAssertTrue(found.contains(message), "\(tex): \(found)")
      } catch {
        XCTFail("\(tex): \(error)")
      }
    }
    XCTAssertEqual(KaTeXError.tooLong(5).errorDescription, "The formula is longer than 5 bytes")
    XCTAssertEqual(KaTeXError.parse("m").errorDescription, "m")
  }

  func testKaTeXNeverCreatesLinksOrImages() throws {
    let engine = try self.engine()
    for tex in ["\\href{javascript:alert(1)}{click}", "\\href{http://example.com}{click}",
                "\\url{http://example.com}", "\\includegraphics{x.png}",
                "\\htmlClass{x}{y}", "\\htmlStyle{color:red}{y}"] {
      for output in [KaTeXOptions.Output.html, .mathml, .htmlAndMathml] {
        let markup = try engine.render(tex, options: KaTeXOptions(output: output))
        for forbidden in ["<a ", "<a>", "href=", "<img", "<script", " onclick", "src="] {
          XCTAssertFalse(markup.contains(forbidden), "\(tex) (\(output)): \(forbidden) in \(markup)")
        }
        // The LaTeX is part of the MathML as text, which is harmless
        if markup.contains("javascript:") {
          XCTAssertTrue(markup.contains("<annotation"), "\(tex) (\(output)): \(markup)")
        }
      }
    }
  }

  func testMacroExpansionIsLimited() throws {
    let engine = try self.engine()
    XCTAssertThrowsError(try engine.render("\\def\\a{\\a\\a}\\a")) { error in
      guard case KaTeXError.parse(let message) = error else {
        return XCTFail("\(error)")
      }
      XCTAssertTrue(message.contains("Too many expansions"), message)
    }
    XCTAssertThrowsError(try engine.render("\\def\\a{\\a\\a}\\a", options: KaTeXOptions(maxExpand: 50)))
    // Few expansions are fine
    XCTAssertNoThrow(try engine.render("\\def\\a{x}\\a\\a\\a", options: KaTeXOptions(maxExpand: 50)))
    XCTAssertThrowsError(try engine.render("\\def\\a{x}\\a\\a\\a\\a\\a", options: KaTeXOptions(maxExpand: 3)))
  }

  func testMacros() throws {
    let engine = try self.engine()
    XCTAssertThrowsError(try engine.render("\\RR"))
    let options = KaTeXOptions(output: .mathml, macros: ["\\RR": "\\mathbb{R}", "\\half": "\\frac{1}{2}"])
    XCTAssertTrue(try engine.render("x \\in \\RR", options: options).contains("mathvariant=\"double-struck\""))
    XCTAssertTrue(try engine.render("\\half", options: options).contains("<mfrac>"))
    // Macros of one call are not visible to the next one
    XCTAssertThrowsError(try engine.render("\\RR"))
  }

  func testDefinitionsDoNotLeakIntoOtherFormulas() throws {
    let engine = try self.engine()
    _ = try engine.render("\\gdef\\foo{42}\\foo")
    XCTAssertThrowsError(try engine.render("\\foo"))
  }

  func testSizeLimits() throws {
    let engine = try self.engine()
    let rule = "\\rule{100em}{1em}"
    let free = try engine.render(rule, options: KaTeXOptions(output: .html))
    XCTAssertTrue(free.contains("100em"), free)
    let limited = try engine.render(rule, options: KaTeXOptions(output: .html, maxSize: 5))
    XCTAssertFalse(limited.contains("100em"), limited)
    XCTAssertNoThrow(try engine.render("\\frac{a}{b}", options: KaTeXOptions(minRuleThickness: 0.1)))
  }

  func testLongFormulasAreRejected() throws {
    let engine = try self.engine()
    XCTAssertThrowsError(try engine.render("abcdefghijk", options: KaTeXOptions(maxLength: 10))) { error in
      XCTAssertEqual(error as? KaTeXError, .tooLong(10))
    }
    XCTAssertNoThrow(try engine.render("abcdefghij", options: KaTeXOptions(maxLength: 10)))
    // The limit counts bytes, not characters
    XCTAssertThrowsError(try engine.render(String(repeating: "é", count: 6), options: KaTeXOptions(maxLength: 10)))
    // The default limit
    XCTAssertThrowsError(try engine.render(String(repeating: "x", count: 10_001)))
    // Deeply nested braces do not crash the engine
    let nested = String(repeating: "{", count: 3000) + "x" + String(repeating: "}", count: 3000)
    _ = try? engine.render(nested)
    XCTAssertNoThrow(try engine.render("x"))
  }

  func testConcurrentUse() throws {
    let engine = try self.engine()
    let formulas = ["x^2", "\\frac{a}{b}", "\\sqrt{x^2+y^2}", "\\sum_{i=0}^n i^2", "\\int_0^1 f(x)\\,dx",
                    "\\badcmd"]
    let expected = formulas.map { try? engine.render($0, options: KaTeXOptions(output: .html)) }
    let failures = FailureCounter()
    DispatchQueue.concurrentPerform(iterations: 300) { i in
      let n = i % formulas.count
      let result = try? engine.render(formulas[n], options: KaTeXOptions(output: .html))
      if result != expected[n] {
        failures.increment()
      }
    }
    XCTAssertEqual(failures.count, 0)
    XCTAssertNil(expected[5])
  }

  func testAnEngineNeedsTheScriptOfKaTeX() throws {
    XCTAssertNil(KaTeXEngine(katexURL: URL(fileURLWithPath: "/nonexistent/katex.min.js")))
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let script = directory.appendingPathComponent("not-katex-\(UUID().uuidString).js")
    try "var x = 1;".write(to: script, atomically: true, encoding: .utf8)
    defer {
      try? FileManager.default.removeItem(at: script)
    }
    XCTAssertNil(KaTeXEngine(katexURL: script))
    // An engine can be created from the bundled script
    let test = Bundle(for: KaTeXEngineTests.self)
    let candidates: [Bundle?] = [
      Bundle(identifier: "net.objecthub.MarkdownKit"),
      Bundle(url: test.bundleURL.deletingLastPathComponent()
                      .appendingPathComponent("MarkdownKit_MarkdownKit.bundle")),
      test
    ]
    let found = candidates.compactMap {
      $0?.resourceURL?.appendingPathComponent("KaTeX/katex.min.js")
    }.first { FileManager.default.fileExists(atPath: $0.path) }
    guard let url = found else {
      throw XCTSkip("the bundle of MarkdownKit was not found")
    }
    let own = try XCTUnwrap(KaTeXEngine(katexURL: url))
    XCTAssertEqual(own.version, KaTeXEngine.bundledVersion)
    XCTAssertNoThrow(try own.render("x"))
  }
}

private final class FailureCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0

  func increment() {
    self.lock.lock()
    self.value += 1
    self.lock.unlock()
  }

  var count: Int {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    return self.value
  }
}

#endif
