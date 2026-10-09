//
//  ConcurrencyTests.swift
//  MarkdownKitTests
//
//  Created on 09/10/2026.
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
// Deliberately not `@testable`: the tests only use the public interface, like a client.
import MarkdownKit
import CommandLineKit

/// Tests which use the shared (`Sendable`) parsers, generators and the syntax highlighter from
/// several threads and tasks at the same time. They are most useful when they are run with the
/// thread sanitizer: `swift test --sanitize=thread --filter ConcurrencyTests`.
final class ConcurrencyTests: XCTestCase {

  /// Documents with all kinds of markup, including code blocks which get highlighted
  private static let documents: [String] = [
    "# Heading\n\nSome *emphasis*, **strong text**, `code`, and a [link](https://example.com).\n",
    "- one\n- two\n  - nested\n  - items\n\n1. first\n2. second\n\n> quote with\n> > a nested quote\n",
    "| Name | Value |\n|:-----|------:|\n| a    | 1     |\n| b    | 22    |\n",
    "```swift\nlet x: Array<Int> = [1, 2, 3]\nprint(x.map { $0 * 2 })\n```\n",
    "```c\n#include <stdio.h>\nint main(void) {\n  printf(\"hi\\n\");\n  return 0;\n}\n```\n",
    "<div class=\"a\">raw *html*</div>\n\nText with &amp; entities, hard break\\\nand more.\n",
    "Setext\n======\n\n    indented code\n\n---\n\n![image](image.png) and <http://example.com>\n"
  ]

  /// Calls `body` for the numbers `0..<iterations` on several threads at the same time and
  /// returns the numbers for which `body` returned `false`.
  private func concurrently(_ iterations: Int, _ body: @escaping @Sendable (Int) -> Bool) -> [Int] {
    let lock = NSLock()
    nonisolated(unsafe) var failures: [Int] = []
    DispatchQueue.concurrentPerform(iterations: iterations) { i in
      if !body(i) {
        lock.lock()
        failures.append(i)
        lock.unlock()
      }
    }
    return failures.sorted()
  }

  // MARK: Parsers and generators

  func testSharedParsersAndGeneratorsCanBeUsedFromManyThreads() {
    let docs = ConcurrencyTests.documents
    let parser = ExtendedMarkdownParser.standard
    let html = HtmlGenerator.standard
    let text = StringGenerator.standard
    let terminal = TerminalGenerator.standard
    let expected = docs.map { doc -> (String, String, AnsiText.Normalized) in
      let block = parser.parse(doc)
      return (html.generate(doc: block), text.generate(doc: block), terminal.generate(doc: block))
    }
    let failures = self.concurrently(600) { i in
      let n = i % docs.count
      let block = parser.parse(docs[n])
      return html.generate(doc: block) == expected[n].0 &&
             text.generate(doc: block) == expected[n].1 &&
             terminal.generate(doc: block) == expected[n].2
    }
    XCTAssertEqual(failures, [])
  }

  func testSharedParserAndSafeHtmlGeneratorCanBeUsedFromManyThreads() {
    let docs = ConcurrencyTests.documents
    let parser = MarkdownParser.standard
    let html = HtmlGenerator(safeMode: true)
    let expected = docs.map { html.generate(doc: parser.parse($0)) }
    let failures = self.concurrently(600) { i in
      let n = i % docs.count
      return html.generate(doc: parser.parse(docs[n])) == expected[n]
    }
    XCTAssertEqual(failures, [])
  }

  func testSyntaxHighlighterCanBeSharedBetweenThreads() throws {
    let highlighter = try XCTUnwrap(SyntaxHighlighter.proxy)
    let snippets: [(code: String, language: String?)] = [
      ("let x = 42\nprint(x)", "swift"),
      ("int main(void) { return 0; }", "c"),
      ("<div class=\"a\">x</div>", "html"),
      ("def f(x):\n  return x * 2", nil)
    ]
    let expected = snippets.map { highlighter.highlight(code: $0.code, as: $0.language) }
    XCTAssertFalse(expected.contains { $0 == nil })
    let failures = self.concurrently(600) { i in
      let n = i % snippets.count
      return highlighter.highlight(code: snippets[n].code, as: snippets[n].language) == expected[n]
    }
    XCTAssertEqual(failures, [])
  }

  func testHighlightingConfigsCanBeSharedBetweenThreads() throws {
    let css = ".hljs{color:#fff}.hljs-keyword{color:#f00;font-weight:bold}" +
              ".hljs-function .hljs-keyword{color:#0f0}.hljs-title.function_{font-style:italic}"
    let font = HRFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    let config = HighlightingConfig(withTheme: css, usingFont: font)
    let ansiConfig = try XCTUnwrap(AnsiHighlightingConfig(withTheme: css, fullColorSupport: true))
    let stacks: [[String]] = [["hljs"], ["hljs", "hljs-keyword"],
                              ["hljs", "hljs-function", "hljs-keyword"],
                              ["hljs", "hljs-function", "hljs-title function_"]] +
                             (0..<40).map { ["hljs", "hljs-function", "hljs-x\($0)", "hljs-keyword"] }
    let expected = stacks.map { ConcurrencyTests.summary(config.apply(to: "text", styleList: $0)) }
    let ansiExpected = stacks.map { ansiConfig.apply(to: "text", styleList: $0) }
    XCTAssertGreaterThanOrEqual(Set(expected).count, 3)   // different styles look different
    let failures = self.concurrently(1000) { i in
      let n = i % stacks.count
      return ConcurrencyTests.summary(config.apply(to: "text", styleList: stacks[n])) == expected[n] &&
             ansiConfig.apply(to: "text", styleList: stacks[n]) == ansiExpected[n]
    }
    XCTAssertEqual(failures, [])
  }

  /// The text, color and font of an attributed string with a single style
  private static func summary(_ string: NSAttributedString) -> String {
    let attributes = string.attributes(at: 0, effectiveRange: nil)
    let color = attributes[.foregroundColor].map { "\($0)" } ?? "-"
    let font = (attributes[.font] as? HRFont)?.fontName ?? "-"
    return "\(string.string)|\(color)|\(font)"
  }

  /// Parsing in a background task and using the result on the main actor requires `Block` to
  /// be `Sendable`.
  @MainActor
  func testParsedDocumentCanBeReturnedFromABackgroundTask() async {
    let text = ConcurrencyTests.documents[1]
    let block = await Task.detached {
      ExtendedMarkdownParser.standard.parse(text)
    }.value
    XCTAssertEqual(block, ExtendedMarkdownParser.standard.parse(text))
    XCTAssertEqual(HtmlGenerator.standard.generate(doc: block),
                   HtmlGenerator.standard.generate(doc: ExtendedMarkdownParser.standard.parse(text)))
  }

  // MARK: Attributed strings

  #if canImport(WebKit)

  func testGenerateAsyncCanBeCalledFromSeveralTasks() async throws {
    let generator = AttributedStringGenerator()
    let doc = ExtendedMarkdownParser.standard.parse(ConcurrencyTests.documents[0])
    let strings = try await withThrowingTaskGroup(of: String.self) { group in
      for _ in 0..<6 {
        group.addTask {
          try await generator.generateAsync(doc: doc).string
        }
      }
      var result: [String] = []
      for try await string in group {
        result.append(string)
      }
      return result
    }
    XCTAssertEqual(strings.count, 6)
    XCTAssertEqual(Set(strings).count, 1)
    XCTAssertTrue(strings[0].contains("Heading"))
  }

  /// A document and a generator which belong to the main actor can be used by `generateAsync`,
  /// and the result can be used on the main actor again.
  @MainActor
  func testGenerateAsyncCanBeCalledFromTheMainActor() async throws {
    let generator = AttributedStringGenerator()
    let doc = ExtendedMarkdownParser.standard.parse(ConcurrencyTests.documents[0])
    let first = try await generator.generateAsync(doc: doc)
    let second = try await generator.generateAsync(doc: doc, options: .untrusted)
    XCTAssertEqual(first.string, second.string)
    XCTAssertTrue(first.string.contains("Heading"))
  }

  /// The completion handler can be a function value (not just a closure)
  @MainActor
  func testCompletionHandlerCanBeAFunctionValue() {
    let generator = AttributedStringGenerator()
    let doc = ExtendedMarkdownParser.standard.parse(ConcurrencyTests.documents[0])
    let done = expectation(description: "handler called")
    var received: String? = nil
    func handler(_ result: Result<NSAttributedString, AttributedStringGenerator.RenderingError>) {
      if case .success(let astr) = result {
        received = astr.string
      }
      done.fulfill()
    }
    generator.generateAsync(doc: doc, completionHandler: handler)
    wait(for: [done], timeout: 30)
    XCTAssertTrue(received?.contains("Heading") ?? false)
  }

  #endif

  // MARK: Conformances

  /// Fails to compile if one of the types is not `Sendable`
  func testPublicTypesAreSendable() {
    func requireSendable<T: Sendable>(_ type: T.Type) {}
    // Abstract syntax trees
    requireSendable(Block.self)
    requireSendable(TextFragment.self)
    requireSendable(Text.self)
    requireSendable(Definition.self)
    requireSendable(ListType.self)
    requireSendable(ListDensity.self)
    requireSendable(Alignment.self)
    requireSendable(AutolinkType.self)
    requireSendable(DelimiterRunType.self)
    requireSendable((any CustomBlock).self)
    requireSendable((any CustomTextFragment).self)
    // Parsers and generators
    requireSendable(MarkdownParser.self)
    requireSendable(ExtendedMarkdownParser.self)
    requireSendable(HtmlGenerator.self)
    requireSendable(StringGenerator.self)
    requireSendable(TerminalGenerator.self)
    requireSendable(AttributedStringGenerator.self)
    requireSendable((any StringGenerator.TableRenderer).self)
    requireSendable((any TerminalGenerator.TableRenderer).self)
    requireSendable(StringGenerator.MinimalisticTableRenderer.self)
    requireSendable(StringGenerator.FullTableRenderer.self)
    requireSendable(TerminalGenerator.MinimalisticTableRenderer.self)
    requireSendable(TerminalGenerator.FullTableRenderer.self)
    // Highlighting
    requireSendable(SyntaxHighlighter.self)
    requireSendable(HighlightingConfig.self)
    requireSendable(AnsiHighlightingConfig.self)
    requireSendable(AttributedStringGenerator.SyntaxHighlightingConfig.self)
    requireSendable(TerminalGenerator.SyntaxHighlightingConfig.self)
    // Options and errors
    requireSendable(AttributedStringGenerator.RenderingOptions.self)
    requireSendable(AttributedStringGenerator.ImageAccess.self)
    requireSendable(AttributedStringGenerator.RenderingError.self)
    requireSendable(AttributedStringGenerator.Options.self)
    requireSendable(AttributedStringGenerator.TableBorders.self)
    requireSendable(AttributedStringGenerator.Version.self)
  }
}

#endif
