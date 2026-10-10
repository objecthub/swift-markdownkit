//
//  NestingTests.swift
//  MarkdownKitTests
//
//  Created on 07/10/2026.
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
@testable import MarkdownKit

/// 
/// Tests for limiting the nesting depth of blocks and inline markup. Without limits, deeply
/// nested input (e.g. many `>` characters) overflows the stack when the syntax tree gets
/// processed.
/// 
class NestingTests: XCTestCase {

  private let blockLimit = DocumentParser.defaultMaxContainerDepth
  private let inlineLimit = InlineParser.defaultMaxNestingDepth

  /// Parser with custom limits
  private final class LimitedParser: MarkdownParser, @unchecked Sendable {
    var blockLimit = DocumentParser.defaultMaxContainerDepth
    var inlineLimit = InlineParser.defaultMaxNestingDepth

    override func documentParser(blockParsers: [BlockParser.Type],
                                 input: String) -> DocumentParser {
      let parser = super.documentParser(blockParsers: blockParsers, input: input)
      parser.maxContainerDepth = self.blockLimit
      return parser
    }

    override func inlineParser(inlineTransformers: [InlineTransformer.Type],
                               input: Block) -> InlineParser {
      let parser = super.inlineParser(inlineTransformers: inlineTransformers, input: input)
      parser.maxNestingDepth = self.inlineLimit
      return parser
    }
  }

  // MARK: Helpers

  /// Maximal nesting of block quotes and list items
  private func containerDepth(_ block: Block) -> Int {
    func depth(_ blocks: Blocks) -> Int {
      return blocks.map { self.containerDepth($0) }.max() ?? 0
    }
    switch block {
      case .document(let blocks), .list(_, _, let blocks):
        return depth(blocks)
      case .blockquote(let blocks), .listItem(_, _, let blocks):
        return 1 + depth(blocks)
      default:
        return 0
    }
  }

  private func inlineDepth(_ fragment: TextFragment) -> Int {
    switch fragment {
      case .emph(let text), .strong(let text), .underline(let text), .strikethrough(let text),
           .link(let text, _, _), .image(let text, _, _):
        return 1 + self.inlineDepth(text)
      default:
        return 0
    }
  }

  private func inlineDepth(_ text: Text) -> Int {
    return text.map { self.inlineDepth($0) }.max() ?? 0
  }

  /// Maximal nesting of links, images and emphasis
  private func inlineDepth(_ block: Block) -> Int {
    switch block {
      case .document(let blocks), .blockquote(let blocks), .list(_, _, let blocks),
           .listItem(_, _, let blocks):
        return blocks.map { self.inlineDepth($0) }.max() ?? 0
      case .paragraph(let text), .heading(_, let text):
        return self.inlineDepth(text)
      default:
        return 0
    }
  }

  private func count(_ str: String, in html: String) -> Int {
    return html.components(separatedBy: str).count - 1
  }

  private func html(_ block: Block) -> String {
    return HtmlGenerator().generate(doc: block)
  }

  /// Runs `body` on a thread with the given stack size (like threads used by dispatch queues
  /// and by Swift concurrency), and waits for it to finish.
  private func runOnSmallStack(kilobytes: Int = 512, _ body: @escaping () -> Void) {
    // The caller waits for the thread to finish, so `body` is not used concurrently
    nonisolated(unsafe) let body = body
    let done = DispatchSemaphore(value: 0)
    let thread = Thread {
      body()
      done.signal()
    }
    thread.stackSize = kilobytes * 1024
    // Use the quality of service of the waiting thread to avoid a priority inversion
    thread.qualityOfService = Thread.current.qualityOfService
    thread.start()
    done.wait()
  }

  // MARK: Block nesting

  func testBlockquotesAreNestedUpToTheLimit() {
    for n in [1, 2, blockLimit - 1, blockLimit, blockLimit + 1, blockLimit + 10, 5 * blockLimit] {
      let doc = MarkdownParser.standard.parse(String(repeating: ">", count: n) + " x")
      let output = html(doc)
      XCTAssertEqual(containerDepth(doc), min(n, blockLimit), "n=\(n)")
      XCTAssertEqual(count("<blockquote>", in: output), min(n, blockLimit), "n=\(n)")
      // The markup beyond the limit is not lost; it is treated as text
      XCTAssertEqual(count("&gt;", in: output), max(n - blockLimit, 0), "n=\(n)")
      XCTAssertTrue(output.contains("x"), "n=\(n)")
    }
  }

  func testBlockquotesWithSpacesAreNestedUpToTheLimit() {
    let n = blockLimit + 5
    let doc = MarkdownParser.standard.parse(String(repeating: "> ", count: n) + "x")
    XCTAssertEqual(containerDepth(doc), blockLimit)
    XCTAssertEqual(count("&gt;", in: html(doc)), 5)
  }

  func testListsAreNestedUpToTheLimit() {
    for n in [1, blockLimit, blockLimit + 1, blockLimit + 10] {
      for marker in ["- ", "1. "] {
        let doc = MarkdownParser.standard.parse(String(repeating: marker, count: n) + "x")
        XCTAssertEqual(containerDepth(doc), min(n, blockLimit), "n=\(n) marker=\(marker)")
        XCTAssertTrue(html(doc).contains("x"))
      }
    }
  }

  func testListsOnSeparateLinesAreNestedUpToTheLimit() {
    let n = blockLimit + 8
    let input = (0..<n).map { String(repeating: "  ", count: $0) + "- item \($0)" }
                       .joined(separator: "\n")
    let doc = MarkdownParser.standard.parse(input)
    XCTAssertEqual(containerDepth(doc), blockLimit)
    let output = html(doc)
    for i in 0..<n {
      XCTAssertTrue(output.contains("item \(i)"), "item \(i) is missing")
    }
  }

  func testMixedContainersAreNestedUpToTheLimit() {
    let doc = MarkdownParser.standard.parse(String(repeating: "> - ", count: blockLimit) + "x")
    XCTAssertEqual(containerDepth(doc), blockLimit)
    XCTAssertTrue(html(doc).contains("x"))
  }

  func testContainersInterruptingParagraphsAreLimited() {
    // The second line of the paragraph starts deeply nested containers
    for second in [String(repeating: ">", count: 3 * blockLimit) + " b",
                   String(repeating: "- ", count: 3 * blockLimit) + "b"] {
      let input = String(repeating: ">", count: blockLimit) + " a\n" + second
      let doc = MarkdownParser.standard.parse(input)
      XCTAssertLessThanOrEqual(containerDepth(doc), blockLimit)
      let output = html(doc)
      XCTAssertTrue(output.contains("a") && output.contains("b"))
    }
    // A list item interrupting a paragraph in a container at the limit
    let doc = MarkdownParser.standard.parse(String(repeating: "> ", count: blockLimit) + "a\n" +
                                            String(repeating: "> ", count: blockLimit) + "- b")
    XCTAssertLessThanOrEqual(containerDepth(doc), blockLimit)
    XCTAssertTrue(html(doc).contains("- b") || html(doc).contains("b"))
  }

  func testBlockNestingLimitIsConfigurable() {
    let parser = LimitedParser()
    parser.blockLimit = 3
    let doc = parser.parse(">>>>> x")
    XCTAssertEqual(containerDepth(doc), 3)
    XCTAssertEqual(count("&gt;", in: html(doc)), 2)
    parser.blockLimit = 0
    let flat = parser.parse("> - x")
    XCTAssertEqual(containerDepth(flat), 0)
    XCTAssertTrue(html(flat).contains("&gt; - x"))
  }

  // MARK: Inline nesting

  private func imageChain(_ n: Int) -> String {
    return String(repeating: "![a ", count: n) + "x" + String(repeating: "](u)", count: n)
  }

  func testImagesAreNestedUpToTheLimit() {
    for n in [1, 5, inlineLimit - 1, inlineLimit, inlineLimit + 1, 3 * inlineLimit] {
      let doc = MarkdownParser.standard.parse(imageChain(n))
      XCTAssertEqual(inlineDepth(doc), min(n, inlineLimit), "n=\(n)")
      XCTAssertTrue(html(doc).contains("x"), "n=\(n)")
    }
  }

  func testNestedLinksStillWork() {
    // Links cannot contain links, but images can be nested in links
    let doc = MarkdownParser.standard.parse("[![a](i)](l) and ![[b](l)](i)")
    XCTAssertEqual(inlineDepth(doc), 2)
    XCTAssertEqual(html(doc),
                   "<p><a href=\"l\"><img src=\"i\" alt=\"a\"/></a> and " +
                   "<img src=\"i\" alt=\"b\"/></p>\n")
  }

  func testEmphasisIsNestedUpToTheLimit() {
    func nested(_ n: Int) -> String {
      return (0..<n).map { $0 % 2 == 0 ? "*a " : "_a " }.joined() + "x " +
             (0..<n).reversed().map { $0 % 2 == 0 ? "a* " : "a_ " }.joined()
    }
    for n in [1, 5, inlineLimit - 1, inlineLimit, inlineLimit + 1, 3 * inlineLimit] {
      let doc = MarkdownParser.standard.parse(nested(n))
      XCTAssertEqual(inlineDepth(doc), min(n, inlineLimit), "n=\(n)")
      XCTAssertTrue(html(doc).contains("x"), "n=\(n)")
    }
  }

  func testUnderlineAndStrikethroughAreNestedUpToTheLimit() {
    func nested(_ n: Int) -> String {
      return (0..<n).map { $0 % 2 == 0 ? "~a " : "~~a " }.joined() + "x " +
             (0..<n).reversed().map { $0 % 2 == 0 ? "a~ " : "a~~ " }.joined()
    }
    for n in [1, 5, inlineLimit - 1, inlineLimit, inlineLimit + 1, 3 * inlineLimit] {
      let doc = FullMarkdownParser.standard.parse(nested(n))
      XCTAssertEqual(inlineDepth(doc), min(n, inlineLimit), "n=\(n)")
      XCTAssertTrue(html(doc).contains("x"), "n=\(n)")
    }
  }

  func testNestingBudgetIsSharedByTildesAndOtherMarkup() {
    let n = inlineLimit
    let input = "~~" + String(repeating: "![*a ~", count: n) + "x" +
                String(repeating: "a~ a* ](u)", count: n) + "~~"
    let doc = FullMarkdownParser.standard.parse(input)
    XCTAssertLessThanOrEqual(inlineDepth(doc), inlineLimit)
    XCTAssertTrue(html(doc).contains("x"))
  }

  func testNestingBudgetIsSharedByLinksAndEmphasis() {
    // Images (as many as allowed) with emphasis inside, and emphasis around them
    let n = inlineLimit
    let input = "*" + String(repeating: "![*a ", count: n) + "x" +
                String(repeating: "a* ](u)", count: n) + "*"
    let doc = MarkdownParser.standard.parse(input)
    XCTAssertLessThanOrEqual(inlineDepth(doc), inlineLimit)
    XCTAssertTrue(html(doc).contains("x"))
  }

  func testInlineNestingLimitIsConfigurable() {
    let parser = LimitedParser()
    parser.inlineLimit = 2
    XCTAssertEqual(inlineDepth(parser.parse(imageChain(10))), 2)
    XCTAssertEqual(inlineDepth(parser.parse("*a _b *c* b_ a*")), 2)
    parser.inlineLimit = 0
    XCTAssertEqual(inlineDepth(parser.parse("*a* ![b](u)")), 0)
  }

  // MARK: Robustness on threads with a small stack

  /// Parses `input` and generates all kinds of output from the result on a small stack.
  private func process(_ input: String,
                       parser: MarkdownParser = MarkdownParser.standard,
                       file: StaticString = #filePath,
                       line: UInt = #line) {
    var finished = false
    runOnSmallStack {
      let doc = parser.parse(input)
      _ = HtmlGenerator().generate(doc: doc)
      _ = StringGenerator.standard.generate(doc: doc)
      _ = TerminalGenerator.standard.generate(doc: doc)
      _ = "\(doc)"
      _ = doc == parser.parse(input)
      finished = true
    }
    XCTAssertTrue(finished, file: file, line: line)
  }

  func testVeryDeeplyNestedBlocksDoNotOverflowTheStack() {
    process(String(repeating: ">", count: 50_000) + " x")
    process(String(repeating: "> ", count: 20_000) + "x")
    process(String(repeating: "- ", count: 20_000) + "x")
    process(String(repeating: "1. ", count: 20_000) + "x")
    process(String(repeating: "> - ", count: 10_000) + "x")
  }

  func testVeryDeeplyNestedInlineMarkupDoesNotOverflowTheStack() {
    process(imageChain(3_000))
    process(String(repeating: "[", count: 3_000) + "a" + String(repeating: "](u)", count: 3_000))
    process(String(repeating: "[a ", count: 3_000) + "x" + String(repeating: "](u)", count: 3_000))
    process((0..<5_000).map { $0 % 2 == 0 ? "**a " : "__a " }.joined() + "x " +
            (0..<5_000).reversed().map { $0 % 2 == 0 ? "a** " : "a__ " }.joined())
    process(String(repeating: "![*a ", count: 3_000) + "x" + String(repeating: "* ](u)", count: 3_000))
  }

  func testVeryDeeplyNestedTildesDoNotOverflowTheStack() {
    let parser = FullMarkdownParser.standard
    process((0..<5_000).map { $0 % 2 == 0 ? "~a " : "~~a " }.joined() + "x " +
            (0..<5_000).reversed().map { $0 % 2 == 0 ? "a~ " : "a~~ " }.joined(),
            parser: parser)
    process((0..<3_000).map { $0 % 3 == 0 ? "~~a " : ($0 % 3 == 1 ? "*a " : "[a ") }.joined() + "x " +
            (0..<3_000).reversed().map { $0 % 3 == 0 ? "a~~ " : ($0 % 3 == 1 ? "a* " : "](u) ") }.joined(),
            parser: parser)
    process(String(repeating: "![~a ", count: 3_000) + "x" + String(repeating: "~ ](u)", count: 3_000),
            parser: parser)
  }

  func testVeryDeeplyNestedTaskListsDoNotOverflowTheStack() {
    let parser = FullMarkdownParser.standard
    process(String(repeating: "- ", count: 20_000) + "[ ] x", parser: parser)
    process(String(repeating: "- [ ] ", count: 20_000) + "x", parser: parser)
    process(String(repeating: "1. ", count: 20_000) + "[x] x", parser: parser)
    process(String(repeating: "> - ", count: 10_000) + "[x] ~~x~~", parser: parser)
    // The tasks of the deepest lists which are still nested are recognized
    let doc = parser.parse(String(repeating: "- ", count: blockLimit) + "[x] x")
    XCTAssertEqual(containerDepth(doc), blockLimit)
    XCTAssertTrue(html(doc).contains("<input checked"))
  }

  func testDeeplyNestedBlocksAndInlineMarkupTogetherDoNotOverflowTheStack() {
    // Worst case for the stack: the limits are reached for blocks and inline markup
    let input = String(repeating: "> - ", count: blockLimit) +
                (0..<inlineLimit).map { _ in "![*a _a " }.joined() + "x " +
                (0..<inlineLimit).map { _ in "a_ a* ](u) " }.joined()
    process(input)
  }
}
