//
//  AttributedStringAsyncTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 07/10/2026.
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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

import XCTest
import Network
#if canImport(WebKit) && (os(macOS) || os(iOS))
import WebKit
#endif
@testable import MarkdownKit

/// Tests for `RenderingOptions` and for the asynchronous generation of attributed strings.
final class AttributedStringAsyncTests: XCTestCase {

  private typealias RenderingOptions = AttributedStringGenerator.RenderingOptions
  private typealias Key = NSAttributedString.DocumentReadingOptionKey

  // MARK: Options (all platforms)

  func testDefaultOptionsGiveTheDictionaryOfTheSynchronousRendering() {
    let generator = AttributedStringGenerator()
    let options = RenderingOptions().renderingOptions(forLoadFromHTML: false)
    XCTAssertEqual(Set(options.keys), [.documentType, .characterEncoding])
    XCTAssertEqual(options[.documentType] as? NSAttributedString.DocumentType, .html)
    XCTAssertEqual(options[.characterEncoding] as? UInt, String.Encoding.utf8.rawValue)
    // The generator uses default options unless told otherwise
    XCTAssertNil(generator.renderingOptions.baseUrl)
    XCTAssertEqual(generator.renderingOptions.timeout,
                   RenderingOptions.defaultTimeout)
  }

  func testBaseURLAndTimeoutAreMappedToRenderingOptions() {
    let base = URL(fileURLWithPath: "/tmp/some-directory", isDirectory: true)
    let legacy = RenderingOptions(baseUrl: base, timeout: 7).renderingOptions(forLoadFromHTML: false)
    // The timeout is only used for the asynchronous render
    XCTAssertEqual(Set(legacy.keys), [.documentType, .characterEncoding, Key(rawValue: "BaseURL")])
    XCTAssertEqual(legacy[Key(rawValue: "BaseURL")] as? URL, base)
    let async = RenderingOptions(baseUrl: base, timeout: 7).renderingOptions(forLoadFromHTML: true)
    XCTAssertEqual(Set(async.keys), [Key(rawValue: "BaseURL"), Key(rawValue: "Timeout")])
    XCTAssertEqual(async[Key(rawValue: "BaseURL")] as? URL, base)
    XCTAssertEqual((async[Key(rawValue: "Timeout")] as? NSNumber)?.doubleValue, 7)
    // No timeout, no base URL, no keys
    for timeout in [nil, 0, -1] as [TimeInterval?] {
      let none = RenderingOptions(baseUrl: nil, timeout: timeout).renderingOptions(forLoadFromHTML: true)
      XCTAssertTrue(none.isEmpty, "\(String(describing: timeout))")
    }
  }

  func testGeneratorStoresRenderingOptions() {
    let base = URL(fileURLWithPath: "/tmp", isDirectory: true)
    let generator = AttributedStringGenerator(
                      renderingOptions: RenderingOptions(baseUrl: base, timeout: 3))
    XCTAssertEqual(generator.renderingOptions.baseUrl, base)
    XCTAssertEqual(generator.renderingOptions.timeout, 3)
  }

  func testRenderingOptionsAreEquatable() {
    let base = URL(fileURLWithPath: "/tmp/a", isDirectory: true)
    let other = URL(fileURLWithPath: "/tmp/b", isDirectory: true)
    func make() -> RenderingOptions {
      return RenderingOptions(baseUrl: base, timeout: 3, localImages: .within(base),
                              remoteImages: .none, imageExtensions: ["png"], safeMode: true,
                              textSizeMultiplier: 1.5)
    }
    XCTAssertEqual(make(), make())
    XCTAssertEqual(RenderingOptions(), RenderingOptions())
    XCTAssertNotEqual(make(), RenderingOptions())
    // Each property makes a difference
    XCTAssertNotEqual(RenderingOptions(baseUrl: base), RenderingOptions())
    XCTAssertNotEqual(RenderingOptions(baseUrl: base), RenderingOptions(baseUrl: other))
    XCTAssertNotEqual(RenderingOptions(timeout: 3), RenderingOptions(timeout: 4))
    XCTAssertNotEqual(RenderingOptions(timeout: nil), RenderingOptions())
    XCTAssertNotEqual(RenderingOptions(localImages: .none), RenderingOptions())
    XCTAssertNotEqual(RenderingOptions(localImages: .within(base)),
                      RenderingOptions(localImages: .within(other)))
    XCTAssertEqual(RenderingOptions(localImages: .within(base)),
                   RenderingOptions(localImages: .within(base)))
    XCTAssertNotEqual(RenderingOptions(remoteImages: .none), RenderingOptions())
    XCTAssertNotEqual(RenderingOptions(remoteImages: .within(base)),
                      RenderingOptions(remoteImages: .any))
    XCTAssertNotEqual(RenderingOptions(imageExtensions: ["png"]), RenderingOptions())
    XCTAssertNotEqual(RenderingOptions(safeMode: true), RenderingOptions())
    XCTAssertNotEqual(RenderingOptions(textSizeMultiplier: 2), RenderingOptions())
    XCTAssertNotEqual(RenderingOptions(textSizeMultiplier: 2), RenderingOptions(textSizeMultiplier: 3))
  }

  func testUntrustedOptions() {
    let untrusted = RenderingOptions.untrusted
    XCTAssertTrue(untrusted.safeMode)
    XCTAssertEqual(untrusted.localImages, .none)
    XCTAssertEqual(untrusted.remoteImages, .none)
    // The other options have their default value
    XCTAssertNil(untrusted.baseUrl)
    XCTAssertEqual(untrusted.timeout, RenderingOptions.defaultTimeout)
    XCTAssertEqual(untrusted.imageExtensions, RenderingOptions.defaultImageExtensions)
    XCTAssertNil(untrusted.textSizeMultiplier)
    XCTAssertEqual(untrusted, RenderingOptions(localImages: .none, remoteImages: .none, safeMode: true))
    XCTAssertNotEqual(untrusted, RenderingOptions())
    XCTAssertEqual(AttributedStringGenerator(renderingOptions: .untrusted).renderingOptions, untrusted)
  }

  func testTrustedOptionsAreTheDefaultOptions() {
    XCTAssertEqual(RenderingOptions.trusted, RenderingOptions())
    XCTAssertNotEqual(RenderingOptions.trusted, RenderingOptions.untrusted)
    XCTAssertEqual(RenderingOptions.trusted.localImages, .any)
    XCTAssertEqual(RenderingOptions.trusted.remoteImages, .any)
    XCTAssertFalse(RenderingOptions.trusted.safeMode)
    XCTAssertEqual(AttributedStringGenerator().renderingOptions, RenderingOptions.trusted)
  }

  func testRenderingErrorsAreEquatable() {
    typealias RenderingError = AttributedStringGenerator.RenderingError
    let all: [RenderingError] = [.unsupportedPlatform, .cancelled, .timedOut, .emptyResult,
                                 .renderingFailed(NSError(domain: "domain", code: 1))]
    for (i, lhs) in all.enumerated() {
      for (j, rhs) in all.enumerated() {
        if i == j {
          XCTAssertEqual(lhs, rhs)
        } else {
          XCTAssertNotEqual(lhs, rhs)
        }
      }
    }
    // Errors that wrap other errors are equal if the errors have the same domain and code
    let failed = RenderingError.renderingFailed(NSError(domain: "domain", code: 1, userInfo: ["a": 1]))
    XCTAssertEqual(failed, .renderingFailed(NSError(domain: "domain", code: 1)))
    XCTAssertNotEqual(failed, .renderingFailed(NSError(domain: "domain", code: 2)))
    XCTAssertNotEqual(failed, .renderingFailed(NSError(domain: "other", code: 1)))
    // Pattern matching continues to work
    if case .renderingFailed(let error) = failed {
      XCTAssertEqual((error as NSError).code, 1)
    } else {
      XCTFail("\(failed)")
    }
  }

  func testRenderingErrorsAreLocalized() {
    typealias RenderingError = AttributedStringGenerator.RenderingError
    let failed = RenderingError.renderingFailed(
                   NSError(domain: "domain", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "Something broke"]))
    let all: [RenderingError] = [.unsupportedPlatform, .cancelled, .timedOut, .emptyResult, failed]
    var descriptions: Set<String> = []
    for error in all {
      let description = error.errorDescription
      XCTAssertNotNil(description, "\(error)")
      XCTAssertEqual(error.localizedDescription, description)
      descriptions.insert(description ?? "")
    }
    XCTAssertEqual(descriptions.count, all.count)
    XCTAssertTrue(failed.localizedDescription.contains("Something broke"))
  }

  func testAsyncMethodsExistOnAllPlatforms() async {
    // On platforms without WebKit, the asynchronous methods throw `unsupportedPlatform`.
    #if !(canImport(WebKit) && (os(macOS) || os(iOS)))
    do {
      _ = try await AttributedStringGenerator().generateAsync(doc: .document([]))
      XCTFail("should throw")
    } catch AttributedStringGenerator.RenderingError.unsupportedPlatform {
    } catch {
      XCTFail("unexpected error \(error)")
    }
    let reported = expectation(description: "completion handler")
    AttributedStringGenerator().generateAsync(doc: .document([])) { result in
      if case .failure(.unsupportedPlatform) = result, Thread.isMainThread {
        reported.fulfill()
      }
    }
    await fulfillment(of: [reported], timeout: 5)
    #endif
  }

  // MARK: Syntax highlighting of code blocks (the HTML for the attributed string)

  #if !os(watchOS)

  func testSyntaxHighlightingCanBeDisabled() throws {
    try XCTSkipIf(SyntaxHighlighter.proxy == nil, "syntax highlighter is not available")
    let doc = ExtendedMarkdownParser.standard.parse("```swift\nlet a = 1\n```\n\n```\nlet b = 2\n```\n")
    let enabled = AttributedStringGenerator().htmlGenerator().generate(doc: doc)
    XCTAssertTrue(enabled.contains("hljs-keyword"), enabled)
    // Without syntax highlighting, highlight.js is not used at all (also not for guessing the
    // language of code blocks without a language)
    let disabled = AttributedStringGenerator(syntaxHighlighting: nil).htmlGenerator().generate(doc: doc)
    XCTAssertFalse(disabled.contains("hljs"), disabled)
    XCTAssertTrue(disabled.contains("<code class=\"language-swift\">let a = 1"), disabled)
  }

  /// Only the first word of the info string of a code block is its language
  func testFirstWordOfInfoStringIsTheLanguage() throws {
    try XCTSkipIf(SyntaxHighlighter.proxy == nil, "syntax highlighter is not available")
    let generator = AttributedStringGenerator()
    func html(_ info: String) -> String {
      return generator.htmlGenerator().generate(
               doc: MarkdownParser.standard.parse("```\(info)\nlet a = 1\n```\n"))
    }
    XCTAssertTrue(html("swift").contains("hljs-keyword"))
    XCTAssertEqual(html("swift title=\"x\""), html("swift"))
  }

  #endif

  // MARK: Asynchronous render (platforms with WebKit)

  #if canImport(WebKit) && (os(macOS) || os(iOS))

  private let markdown = "# Title\n\nSome *emphasis*, **strong** and `code`.\n\n" +
                         "- one\n- two\n\n> quote\n\n```swift\nlet x = 1\n```\n\n" +
                         "[a link](http://example.com)\n"

  /// A valid 1x1 PNG image
  private let pngData = Data(base64Encoded:
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!

  private func parse(_ input: String) -> Block {
    return ExtendedMarkdownParser.standard.parse(input)
  }

  private func attachmentCount(_ astr: NSAttributedString) -> Int {
    var count = 0
    astr.enumerateAttribute(.attachment,
                            in: NSRange(location: 0, length: astr.length)) { value, _, _ in
      if value is NSTextAttachment {
        count += 1
      }
    }
    return count
  }

  @MainActor
  func testAsyncResultMatchesSynchronousResult() async throws {
    let generator = AttributedStringGenerator()
    let doc = parse(markdown)
    let sync = try XCTUnwrap(generator.generate(doc: doc))
    let async = try await generator.generateAsync(doc: doc)
    XCTAssertEqual(async.string, sync.string)
    XCTAssertEqual(async.length, sync.length)
    XCTAssertEqual(attachmentCount(async), attachmentCount(sync))
    XCTAssertTrue(async.string.contains("Title"))
  }

  @MainActor
  func testAsyncBlockAndBlocksMatchSynchronousResults() async throws {
    let generator = AttributedStringGenerator()
    guard case .document(let blocks) = parse(markdown) else {
      XCTFail("document expected")
      return
    }
    let block = try XCTUnwrap(blocks.first)
    let asyncBlock = try await generator.generateAsync(block: block)
    XCTAssertEqual(asyncBlock.string, try XCTUnwrap(generator.generate(block: block)).string)
    let asyncBlocks = try await generator.generateAsync(blocks: blocks)
    XCTAssertEqual(asyncBlocks.string, try XCTUnwrap(generator.generate(blocks: blocks)).string)
  }

  func testAsyncMethodsWorkOffTheMainActor() async throws {
    // The completion handler of loadFromHTML is called on the main thread
    let text = try await Task.detached { () -> String in
      let astr = try await AttributedStringGenerator().generateAsync(doc: .document([
        .paragraph(Text(.text("Hello from a background task")))
      ]))
      return astr.string
    }.value
    XCTAssertTrue(text.contains("Hello from a background task"))
  }

  /// A relative image is only found if there is a base URL, both for `generate(doc:)` and
  /// for `generateAsync(doc:)`.
  @MainActor
  func testBaseURLResolvesRelativeImages() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("AttributedStringAsyncTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: directory)
    }
    try pngData.write(to: directory.appendingPathComponent("image.png"))
    func imageBytes(_ astr: NSAttributedString?) -> [Int] {
      var bytes: [Int] = []
      astr?.enumerateAttribute(.attachment,
                               in: NSRange(location: 0, length: astr?.length ?? 0)) { value, _, _ in
        if let attachment = value as? NSTextAttachment {
          bytes.append(attachment.fileWrapper?.regularFileContents?.count ?? 0)
        }
      }
      return bytes
    }
    let doc = parse("![an image](image.png)")
    let withoutBase = AttributedStringGenerator()
    let withBase = AttributedStringGenerator(
                     renderingOptions: RenderingOptions(
                       baseUrl: URL(fileURLWithPath: directory.path, isDirectory: true)))
    // Without a base URL, the image cannot be found (a placeholder is used instead)
    let asyncWithoutBase = try await withoutBase.generateAsync(doc: doc)
    XCTAssertNotEqual(imageBytes(withoutBase.generate(doc: doc)), [pngData.count])
    XCTAssertNotEqual(imageBytes(asyncWithoutBase), [pngData.count])
    // With a base URL it is found, in both cases
    let asyncWithBase = try await withBase.generateAsync(doc: doc)
    XCTAssertEqual(imageBytes(withBase.generate(doc: doc)), [pngData.count])
    XCTAssertEqual(imageBytes(asyncWithBase), [pngData.count])
    // The base URL can also be given per call
    let perCall = try await withoutBase.generateAsync(
                    doc: doc,
                    options: RenderingOptions(
                      baseUrl: URL(fileURLWithPath: directory.path, isDirectory: true)))
    XCTAssertEqual(imageBytes(perCall), [pngData.count])
    // ... and with the variant that uses a completion handler
    let viaHandler: Result<NSAttributedString, AttributedStringGenerator.RenderingError> =
      await withCheckedContinuation { continuation in
        withBase.generateAsync(doc: doc) { continuation.resume(returning: $0) }
      }
    if case .success(let astr) = viaHandler {
      XCTAssertEqual(imageBytes(astr), [pngData.count])
    } else {
      XCTFail("\(viaHandler)")
    }
  }

  /// The system's own timeout (not the watchdog) is reported as `.timedOut`. The document
  /// refers to an image which is never delivered; so the load cannot finish before the
  /// system's timeout is reached (a trivial document may well be rendered faster).
  @MainActor
  func testSystemTimeoutIsReportedAsTimedOut() async throws {
    let server = try SilentServer()
    try server.start()
    defer {
      server.stop()
    }
    let generator = AttributedStringGenerator()
    let start = Date()
    do {
      _ = try await generator.generateAsync(
                      doc: parse("![never delivered](http://127.0.0.1:\(server.port)/image.png)"),
                      options: RenderingOptions(timeout: 0.5))
      XCTFail("should throw")
    } catch AttributedStringGenerator.RenderingError.timedOut {
    } catch {
      XCTFail("unexpected error \(error)")
    }
    // The watchdog would only report the timeout after the grace period of 5 seconds.
    XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    XCTAssertFalse(server.requests.isEmpty, "the image was not requested")
  }

  // MARK: RenderingState

  private typealias RenderingResult = Result<NSAttributedString, AttributedStringGenerator.RenderingError>
  private typealias RenderingState = AttributedStringGenerator.RenderingState

  private func isCancelled(_ result: RenderingResult?) -> Bool {
    if case .failure(.cancelled)? = result { return true }
    return false
  }

  func testRenderingStateDeliversExactlyOnce() {
    let state = RenderingState()
    var results: [RenderingResult] = []
    state.install { results.append($0) }
    state.finish(.success(NSAttributedString(string: "first")))
    state.finish(.success(NSAttributedString(string: "second")))
    state.finish(.failure(.timedOut))
    state.cancel()
    XCTAssertEqual(results.count, 1)
    if case .success(let astr)? = results.first {
      XCTAssertEqual(astr.string, "first")
    } else {
      XCTFail("\(results)")
    }
  }

  func testRenderingStateKeepsResultThatArrivesBeforeInstall() {
    let state = RenderingState()
    state.finish(.failure(.emptyResult))
    state.finish(.failure(.timedOut))
    var results: [RenderingResult] = []
    state.install { results.append($0) }
    XCTAssertEqual(results.count, 1)
    if case .failure(.emptyResult)? = results.first {} else {
      XCTFail("\(results)")
    }
  }

  func testRenderingStateCancelBeforeAndAfterFinish() {
    let early = RenderingState()
    early.cancel()
    early.finish(.success(NSAttributedString(string: "late")))
    var earlyResults: [RenderingResult] = []
    early.install { earlyResults.append($0) }
    XCTAssertEqual(earlyResults.count, 1)
    XCTAssertTrue(isCancelled(earlyResults.first))
    let late = RenderingState()
    var lateResults: [RenderingResult] = []
    late.install { lateResults.append($0) }
    late.finish(.success(NSAttributedString(string: "done")))
    late.cancel()
    XCTAssertEqual(lateResults.count, 1)
    if case .success? = lateResults.first {} else {
      XCTFail("\(lateResults)")
    }
  }

  // MARK: Timeout and cancellation (the system loader is skipped via `ignore`)

  func testWatchdogReportsTimeoutIfNothingArrives() async {
    let start = Date()
    do {
      _ = try await AttributedStringGenerator().renderHTML(
                      "<p>x</p>",
                      options: RenderingOptions(timeout: 0.05),
                      watchdogGrace: 0.05,
                      ignore: true)
      XCTFail("should throw")
    } catch AttributedStringGenerator.RenderingError.timedOut {
    } catch {
      XCTFail("unexpected error \(error)")
    }
    XCTAssertLessThan(Date().timeIntervalSince(start), 3)
  }

  func testCancellationIsReported() async {
    let generator = AttributedStringGenerator()
    let task = Task { () -> String in
      let astr = try await generator.renderHTML("<p>x</p>",
                                                options: RenderingOptions(timeout: nil),
                                                ignore: true)
      return astr.string
    }
    try? await Task.sleep(nanoseconds: 100_000_000)
    task.cancel()
    do {
      _ = try await task.value
      XCTFail("should throw")
    } catch AttributedStringGenerator.RenderingError.cancelled {
    } catch {
      XCTFail("unexpected error \(error)")
    }
  }

  func testAlreadyCancelledTaskThrowsAtOnce() async {
    let generator = AttributedStringGenerator()
    let task = Task { () -> String in
      while !Task.isCancelled {
        await Task.yield()
      }
      return try await generator.renderHTML("<p>x</p>", options: RenderingOptions(timeout: nil),
                                            ignore: true).string
    }
    task.cancel()
    do {
      _ = try await task.value
      XCTFail("should throw")
    } catch AttributedStringGenerator.RenderingError.cancelled {
    } catch {
      XCTFail("unexpected error \(error)")
    }
  }

  // MARK: Completion handlers

  private typealias Handler = (RenderingResult) -> Void

  /// Starts an asynchronous generation with a completion handler and waits for the result.
  /// Also determines how often, and on which thread, the handler was called.
  private func awaitCompletion(_ start: (@escaping Handler) -> Void)
                -> (result: RenderingResult?, onMainThread: Bool, calls: Int) {
    let done = expectation(description: "completion handler")
    var result: RenderingResult?
    var onMainThread = false
    var calls = 0
    start { received in
      calls += 1
      onMainThread = Thread.isMainThread
      result = received
      done.fulfill()
    }
    wait(for: [done], timeout: 30)
    // Make sure that the handler is not called again
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    return (result, onMainThread, calls)
  }

  func testCompletionHandlerResultMatchesSynchronousResult() throws {
    let generator = AttributedStringGenerator()
    let doc = parse(markdown)
    guard case .document(let blocks) = doc else {
      XCTFail("document expected")
      return
    }
    let block = try XCTUnwrap(blocks.first)
    let cases: [(String, NSAttributedString?, (@escaping Handler) -> Void)] = [
      ("doc", generator.generate(doc: doc),
       { handler in generator.generateAsync(doc: doc, completionHandler: handler) }),
      ("block", generator.generate(block: block),
       { handler in generator.generateAsync(block: block, completionHandler: handler) }),
      ("blocks", generator.generate(blocks: blocks),
       { handler in generator.generateAsync(blocks: blocks, completionHandler: handler) })
    ]
    for (label, sync, start) in cases {
      let outcome = awaitCompletion(start)
      XCTAssertEqual(outcome.calls, 1, label)
      XCTAssertTrue(outcome.onMainThread, label)
      guard case .success(let astr)? = outcome.result else {
        XCTFail("\(label): \(String(describing: outcome.result))")
        continue
      }
      XCTAssertEqual(astr.string, try XCTUnwrap(sync).string, label)
      XCTAssertEqual(astr.length, sync?.length, label)
    }
  }

  func testCompletionHandlerIsAsynchronous() {
    var called = false
    let done = expectation(description: "completion handler")
    AttributedStringGenerator().generateAsync(doc: parse("text")) { _ in
      called = true
      done.fulfill()
    }
    XCTAssertFalse(called, "the handler must not be called before the method returns")
    wait(for: [done], timeout: 30)
  }

  func testCompletionHandlerReportsTimeoutOnTheMainThread() {
    let generator = AttributedStringGenerator()
    let outcome = awaitCompletion { handler in
      generator.renderHTML("<p>x</p>",
                           options: RenderingOptions(timeout: 0.05),
                           watchdogGrace: 0.05,
                           ignore: true,
                           completion: handler)
    }
    XCTAssertEqual(outcome.calls, 1)
    XCTAssertTrue(outcome.onMainThread)
    if case .failure(.timedOut)? = outcome.result {} else {
      XCTFail("\(String(describing: outcome.result))")
    }
  }

  #endif
}


#if canImport(WebKit) && (os(macOS) || os(iOS))

/// Tests for `AttributedStringGenerator.lineSpacing` and `codeBlockLineSpacing`. The system's
/// HTML importer ignores `line-height`, so the generator sets the line height multiple of the
/// paragraph styles of the attributed string.
final class AttributedStringLineSpacingTests: XCTestCase {

  private let markdown = "# Title\n\nSome text with `code` in it.\n\n- item one\n- item two\n\n" +
                         "> quote\n\n```\nlet a = 1\n\nlet c = 3\n```\n\nLast paragraph.\n"

  /// A valid 1x1 PNG image
  private let image = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADU" +
                      "lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

  private func parse(_ input: String) -> Block {
    return ExtendedMarkdownParser.standard.parse(input)
  }

  /// The line height multiple of the paragraph at `location`.
  private func multiple(at location: Int, in string: NSAttributedString) -> CGFloat {
    let style = string.attribute(.paragraphStyle, at: location, effectiveRange: nil)
                  as? NSParagraphStyle
    return style?.lineHeightMultiple ?? 0
  }

  /// The line height multiple of the paragraph that contains the first occurrence of `fragment`.
  private func multiple(of fragment: String, in string: NSAttributedString) -> CGFloat {
    let range = (string.string as NSString).range(of: fragment)
    XCTAssertNotEqual(range.location, NSNotFound, fragment)
    return self.multiple(at: range.location, in: string)
  }

  /// The line height multiple of each paragraph, from the beginning to the end of the text.
  private func multiples(in string: NSAttributedString) -> [CGFloat] {
    let text = string.string as NSString
    var result: [CGFloat] = []
    var location = 0
    while location < text.length {
      let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
      result.append(self.multiple(at: paragraph.location, in: string))
      location = NSMaxRange(paragraph)
    }
    return result
  }

  func testDefaults() {
    XCTAssertEqual(AttributedStringGenerator().lineSpacing, 1.1)
    XCTAssertEqual(AttributedStringGenerator().codeBlockLineSpacing, 1.0)
    let generator = AttributedStringGenerator(lineSpacing: 1.4, codeBlockLineSpacing: 1.2)
    XCTAssertEqual(generator.lineSpacing, 1.4)
    XCTAssertEqual(generator.codeBlockLineSpacing, 1.2)
  }

  @MainActor
  func testTextGetsTheLineSpacingAndCodeBlocksKeepTheirLineHeight() throws {
    for highlighting in [true, false] {
      let generator = AttributedStringGenerator(syntaxHighlighting: highlighting ? .default : nil)
      let result = try XCTUnwrap(generator.generate(doc: self.parse(markdown)))
      for fragment in ["Title", "Some text", "item one", "item two", "quote", "Last paragraph"] {
        XCTAssertEqual(self.multiple(of: fragment, in: result), 1.1, accuracy: 0.001, fragment)
      }
      // Inline code is part of a paragraph
      XCTAssertEqual(self.multiple(of: "code", in: result), 1.1, accuracy: 0.001)
      // The default for code blocks, 1, does not change anything
      XCTAssertEqual(self.multiple(of: "let a", in: result), 0)
      XCTAssertEqual(self.multiple(of: "let c", in: result), 0)
    }
  }

  @MainActor
  func testCustomLineSpacing() throws {
    for highlighting in [true, false] {
      let generator = AttributedStringGenerator(lineSpacing: 1.5,
                                                codeBlockLineSpacing: 1.25,
                                                syntaxHighlighting: highlighting ? .default : nil)
      let result = try XCTUnwrap(generator.generate(doc: self.parse(markdown)))
      for fragment in ["Title", "Some text", "item one", "item two", "quote", "Last paragraph"] {
        XCTAssertEqual(self.multiple(of: fragment, in: result), 1.5, accuracy: 0.001, fragment)
      }
      XCTAssertEqual(self.multiple(of: "let a", in: result), 1.25, accuracy: 0.001)
      XCTAssertEqual(self.multiple(of: "let c", in: result), 1.25, accuracy: 0.001)
      // The empty line in the middle of the code block
      let code = (result.string as NSString).range(of: "let a = 1\n")
      XCTAssertEqual(self.multiple(at: NSMaxRange(code), in: result), 1.25, accuracy: 0.001)
      XCTAssertEqual((result.string as NSString).substring(with: NSRange(location: NSMaxRange(code),
                                                                         length: 1)), "\n")
    }
  }

  /// The empty paragraphs which are only there for vertical space keep their height.
  @MainActor
  func testEmptyParagraphsKeepTheirLineHeight() throws {
    let generator = AttributedStringGenerator(lineSpacing: 2, codeBlockLineSpacing: 2)
    let result = try XCTUnwrap(generator.generate(doc: self.parse(markdown)))
    let text = result.string as NSString
    var spacers = 0
    var location = 0
    while location < text.length {
      var start = 0, end = 0, contentsEnd = 0
      text.getParagraphStart(&start, end: &end, contentsEnd: &contentsEnd,
                             for: NSRange(location: location, length: 0))
      location = end
      if start == contentsEnd,
         result.attribute(.backgroundColor, at: start, effectiveRange: nil) == nil {
        XCTAssertEqual(self.multiple(at: start, in: result), 0, "paragraph at \(start)")
        spacers += 1
      }
    }
    XCTAssertGreaterThan(spacers, 0)
  }

  @MainActor
  func testSpacingWhichChangesNothingLeavesTheTextAlone() throws {
    let doc = self.parse(markdown)
    for (text, code) in [(1, 1), (0, 0), (-1, 1)] as [(Float, Float)] {
      let generator = AttributedStringGenerator(lineSpacing: text, codeBlockLineSpacing: code)
      let result = try XCTUnwrap(generator.generate(doc: doc))
      XCTAssertEqual(Set(self.multiples(in: result)), [0], "\(text) \(code)")
      // Nothing is copied
      XCTAssertTrue(generator.finishingImport(of: result, probed: false,
                                              textSizeMultiplier: nil) === result)
    }
    // Only one of the two changes the code blocks
    let onlyCode = AttributedStringGenerator(lineSpacing: 1, codeBlockLineSpacing: 1.3)
    let result = try XCTUnwrap(onlyCode.generate(doc: doc))
    XCTAssertEqual(self.multiple(of: "let a", in: result), 1.3, accuracy: 0.001)
    XCTAssertEqual(self.multiple(of: "Some text", in: result), 0)
  }

  /// A multiple would also scale the height of an image.
  @MainActor
  func testParagraphsWithImagesKeepTheirLineHeight() throws {
    let result = try XCTUnwrap(AttributedStringGenerator().generate(
                                 doc: self.parse("Before\n\nText ![alt](\(image)) text\n\nAfter\n")))
    var images = 0
    result.enumerateAttribute(.attachment,
                              in: NSRange(location: 0, length: result.length)) { value, range, _ in
      if value is NSTextAttachment {
        images += 1
        XCTAssertEqual(self.multiple(at: range.location, in: result), 0)
        XCTAssertEqual(self.multiple(of: "Text", in: result), 0)
      }
    }
    XCTAssertEqual(images, 1)
    XCTAssertEqual(self.multiple(of: "Before", in: result), 1.1, accuracy: 0.001)
    XCTAssertEqual(self.multiple(of: "After", in: result), 1.1, accuracy: 0.001)
  }

  /// The importer scales all font sizes with the text size multiplier (iOS even does it twice
  /// in the synchronous rendering), which has to be taken into account when code blocks are
  /// recognized by their font size.
  @MainActor
  func testCodeBlocksAreRecognizedWithATextSizeMultiplier() async throws {
    let options = AttributedStringGenerator.RenderingOptions(textSizeMultiplier: 1.5)
    let generator = AttributedStringGenerator(codeBlockLineSpacing: 1.25, renderingOptions: options)
    let doc = self.parse(markdown)
    let sync = try XCTUnwrap(generator.generate(doc: doc))
    let async = try await generator.generateAsync(doc: doc)
    for result in [sync, async] {
      XCTAssertEqual(self.multiple(of: "let a", in: result), 1.25, accuracy: 0.001)
      XCTAssertEqual(self.multiple(of: "let c", in: result), 1.25, accuracy: 0.001)
      XCTAssertEqual(self.multiple(of: "Some text", in: result), 1.1, accuracy: 0.001)
    }
  }

  /// Code blocks that have the font size of the text are told apart by their background.
  @MainActor
  func testCodeBlocksWithTheFontSizeOfTheText() throws {
    let generator = AttributedStringGenerator(fontSize: 12, codeBlockFontSize: 12,
                                              codeBlockLineSpacing: 1.25)
    let result = try XCTUnwrap(generator.generate(doc: self.parse(markdown)))
    XCTAssertEqual(self.multiple(of: "let a", in: result), 1.25, accuracy: 0.001)
    XCTAssertEqual(self.multiple(of: "Some text", in: result), 1.1, accuracy: 0.001)
  }

  /// Text with a background is not code if its font is not monospaced, also if it has the font
  /// size of code blocks.
  @MainActor
  func testTextWithABackgroundIsNotACodeBlock() throws {
    let generator = AttributedStringGenerator(fontSize: 12, codeBlockFontSize: 12,
                                              codeBlockLineSpacing: 1.25,
                                              customStyle: "p { background-color: #eeeeee; }")
    let result = try XCTUnwrap(generator.generate(
                                 doc: self.parse("Some text with `code`.\n\n```\nlet a = 1\n```\n")))
    let text = (result.string as NSString).range(of: "Some text")
    XCTAssertNotNil(result.attribute(.backgroundColor, at: text.location, effectiveRange: nil))
    XCTAssertEqual(self.multiple(of: "Some text", in: result), 1.1, accuracy: 0.001)
    XCTAssertEqual(self.multiple(of: "let a", in: result), 1.25, accuracy: 0.001)
  }

  /// Code blocks are found by the code font which the user chose (the importer decides which
  /// font a CSS font list stands for), also if it is not monospaced, and for lines which start
  /// with characters that the system shows in another font.
  @MainActor
  func testCodeBlocksAreRecognizedByTheCodeFont() throws {
    let doc = self.parse("```swift\n日本語\nlet a = 1 // 日本語\n\n日本語 😀 = 2\nfunc f() {}\n日本語\n```\n")
    let bold = ".hljs-keyword { font-weight: bold; }"
    let generators = [("default", AttributedStringGenerator(codeBlockLineSpacing: 1.25)),
                      ("preOS26", AttributedStringGenerator(version: .preOS26,
                                                            codeBlockLineSpacing: 1.25)),
                      ("Menlo", AttributedStringGenerator(codeFontFamily: "Menlo",
                                                          codeBlockLineSpacing: 1.25)),
                      ("list", AttributedStringGenerator(codeFontFamily: "'Fira Code', monospace",
                                                         codeBlockLineSpacing: 1.25)),
                      ("proportional", AttributedStringGenerator(codeFontFamily: "Helvetica, sans-serif",
                                                                 codeBlockLineSpacing: 1.25)),
                      ("bold keywords", AttributedStringGenerator(codeBlockLineSpacing: 1.25,
                                                                  customStyle: bold)),
                      ("no highlighting", AttributedStringGenerator(codeBlockLineSpacing: 1.25,
                                                                    syntaxHighlighting: nil))]
    for (label, generator) in generators {
      let result = try XCTUnwrap(generator.generate(doc: doc))
      let text = result.string as NSString
      var lines: [(text: String, multiple: CGFloat)] = []
      var location = 0
      while location < text.length {
        let line = text.paragraphRange(for: NSRange(location: location, length: 0))
        location = NSMaxRange(line)
        lines.append((text.substring(with: line), self.multiple(at: line.location, in: result)))
      }
      // The six lines of the code block, including the empty one, and the empty paragraph
      // after the code block, which keeps its line height
      XCTAssertEqual(lines.count, 7, label)
      for line in lines.prefix(6) {
        XCTAssertEqual(line.multiple, 1.25, accuracy: 0.001, "\(label): \(line.text)")
      }
      XCTAssertEqual(lines.last?.text, "\n", label)
      XCTAssertEqual(lines.last?.multiple, 0, label)
    }
  }

  /// The font probe is not part of the result, and it does not change the rest.
  @MainActor
  func testFontProbeIsRemoved() async throws {
    let markdown = "# Title\n\nSome `code` here.\n\n- one\n- two\n\n> quote\n\n```\nlet a = 1\n```\n\nEnd.\n"
    let doc = self.parse(markdown)
    for version in [AttributedStringGenerator.Version.OS26, .preOS26] {
      // Without line spacing, there is no probe
      let plain = try XCTUnwrap(AttributedStringGenerator(version: version, lineSpacing: 1)
                                  .generate(doc: doc))
      let spaced = try XCTUnwrap(AttributedStringGenerator(version: version).generate(doc: doc))
      XCTAssertFalse(spaced.string.contains("MKFontProbe"))
      XCTAssertEqual(spaced.string, plain.string)
      for index in 0..<plain.length {
        XCTAssertEqual(spaced.attribute(.font, at: index, effectiveRange: nil) as? NSObject,
                       plain.attribute(.font, at: index, effectiveRange: nil) as? NSObject,
                       "\(version) at \(index)")
      }
    }
    // The asynchronous methods remove it as well
    let generator = AttributedStringGenerator(codeBlockLineSpacing: 1.25)
    let sync = try XCTUnwrap(generator.generate(doc: doc))
    let async = try await generator.generateAsync(doc: doc)
    XCTAssertEqual(async.string, sync.string)
    XCTAssertFalse(async.string.contains("MKFontProbe"))
  }

  /// `generateHtml(_:)` is not changed by the font probe.
  func testGeneratedHtmlHasNoFontProbe() {
    let generator = AttributedStringGenerator(codeBlockLineSpacing: 1.25)
    XCTAssertFalse(generator.generateHtml("<p>x</p>").contains("MKFontProbe"))
    XCTAssertEqual(generator.generateHtmlForImport("<p>x</p>").html.components(
                     separatedBy: "MKFontProbe").count, 2)
    XCTAssertTrue(generator.generateHtmlForImport("<p>x</p>").probed)
    // The probe is only needed if the line spacing changes something
    let none = AttributedStringGenerator(lineSpacing: 1)
    XCTAssertFalse(none.generateHtmlForImport("<p>x</p>").probed)
    XCTAssertEqual(none.generateHtmlForImport("<p>x</p>").html, none.generateHtml("<p>x</p>"))
  }

  /// A subclass which creates a document without `<body>` gets no probe. Code blocks are then
  /// recognized by their font size.
  @MainActor
  func testDocumentsWithoutBodyTagHaveNoProbe() throws {
    final class Generator: AttributedStringGenerator, @unchecked Sendable {
      override func htmlBody(_ body: String) -> String {
        return "<body class=\"custom\">\n\(body)\n</body>"
      }
    }
    let generator = Generator(codeBlockLineSpacing: 1.25)
    XCTAssertFalse(generator.generateHtmlForImport("<p>x</p>").probed)
    let result = try XCTUnwrap(generator.generate(doc: self.parse(markdown)))
    XCTAssertFalse(result.string.contains("MKFontProbe"))
    XCTAssertEqual(self.multiple(of: "let a", in: result), 1.25, accuracy: 0.001)
    XCTAssertEqual(self.multiple(of: "Some text", in: result), 1.1, accuracy: 0.001)
  }

  @MainActor
  func testAsynchronousMethodsApplyTheLineSpacing() async throws {
    let generator = AttributedStringGenerator(lineSpacing: 1.5, codeBlockLineSpacing: 1.25)
    let doc = self.parse(markdown)
    let sync = try XCTUnwrap(generator.generate(doc: doc))
    let async = try await generator.generateAsync(doc: doc)
    XCTAssertEqual(self.multiple(of: "Some text", in: async), 1.5, accuracy: 0.001)
    XCTAssertEqual(self.multiple(of: "let a", in: async), 1.25, accuracy: 0.001)
    XCTAssertEqual(self.multiples(in: async), self.multiples(in: sync))
    guard case .document(let blocks) = doc else {
      XCTFail("document expected")
      return
    }
    let asyncBlocks = try await generator.generateAsync(blocks: blocks)
    XCTAssertEqual(self.multiples(in: asyncBlocks), self.multiples(in: sync))
    let expectation = expectation(description: "completion handler")
    nonisolated(unsafe) var viaHandler: NSAttributedString?
    generator.generateAsync(doc: doc) { result in
      viaHandler = try? result.get()
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 30)
    XCTAssertEqual(self.multiples(in: try XCTUnwrap(viaHandler)), self.multiples(in: sync))
  }
}

#endif

/// A minimal HTTP server on the loopback interface which accepts connections, records the
/// requests it receives, but never answers them. The state which is changed concurrently is
/// guarded by a lock; the port is set before the server is used.
private final class SilentServer: @unchecked Sendable {
  private let listener: NWListener
  private let queue = DispatchQueue(label: "SilentServer")
  private let lock = NSLock()
  private var connections: [NWConnection] = []
  private var recorded: [String] = []
  private(set) var port: UInt16 = 0

  init() throws {
    let parameters = NWParameters.tcp
    parameters.requiredInterfaceType = .loopback
    self.listener = try NWListener(using: parameters, on: .any)
  }

  var requests: [String] {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    return self.recorded
  }

  func start() throws {
    let ready = DispatchSemaphore(value: 0)
    self.listener.stateUpdateHandler = { state in
      if case .ready = state {
        ready.signal()
      }
    }
    self.listener.newConnectionHandler = { [weak self] connection in
      self?.handle(connection)
    }
    self.listener.start(queue: self.queue)
    guard ready.wait(timeout: .now() + 5) == .success, let port = self.listener.port?.rawValue else {
      throw NSError(domain: "SilentServer", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "server did not start"])
    }
    self.port = port
  }

  func stop() {
    self.listener.cancel()
    self.lock.lock()
    let open = self.connections
    self.connections = []
    self.lock.unlock()
    for connection in open {
      connection.cancel()
    }
  }

  private func handle(_ connection: NWConnection) {
    self.lock.lock()
    self.connections.append(connection)
    self.lock.unlock()
    connection.start(queue: self.queue)
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, _, _ in
      let request = String(decoding: data ?? Data(), as: UTF8.self)
      let line = request.components(separatedBy: "\r\n").first ?? ""
      self?.lock.lock()
      self?.recorded.append(line)
      self?.lock.unlock()
    }
  }
}

#endif
