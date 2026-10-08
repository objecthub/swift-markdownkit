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
    XCTAssertNil(generator.renderingOptions.baseURL)
    XCTAssertEqual(generator.renderingOptions.timeout,
                   RenderingOptions.defaultTimeout)
  }

  func testBaseURLAndTimeoutAreMappedToRenderingOptions() {
    let base = URL(fileURLWithPath: "/tmp/some-directory", isDirectory: true)
    let legacy = RenderingOptions(baseURL: base, timeout: 7).renderingOptions(forLoadFromHTML: false)
    // The timeout is only used for the asynchronous render
    XCTAssertEqual(Set(legacy.keys), [.documentType, .characterEncoding, Key(rawValue: "BaseURL")])
    XCTAssertEqual(legacy[Key(rawValue: "BaseURL")] as? URL, base)
    let async = RenderingOptions(baseURL: base, timeout: 7).renderingOptions(forLoadFromHTML: true)
    XCTAssertEqual(Set(async.keys), [Key(rawValue: "BaseURL"), Key(rawValue: "Timeout")])
    XCTAssertEqual(async[Key(rawValue: "BaseURL")] as? URL, base)
    XCTAssertEqual((async[Key(rawValue: "Timeout")] as? NSNumber)?.doubleValue, 7)
    // No timeout, no base URL, no keys
    for timeout in [nil, 0, -1] as [TimeInterval?] {
      let none = RenderingOptions(baseURL: nil, timeout: timeout).renderingOptions(forLoadFromHTML: true)
      XCTAssertTrue(none.isEmpty, "\(String(describing: timeout))")
    }
  }

  func testGeneratorStoresRenderingOptions() {
    let base = URL(fileURLWithPath: "/tmp", isDirectory: true)
    let generator = AttributedStringGenerator(
                      renderingOptions: RenderingOptions(baseURL: base,
                                                                                    timeout: 3))
    XCTAssertEqual(generator.renderingOptions.baseURL, base)
    XCTAssertEqual(generator.renderingOptions.timeout, 3)
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
                       baseURL: URL(fileURLWithPath: directory.path, isDirectory: true)))
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
                      baseURL: URL(fileURLWithPath: directory.path, isDirectory: true)))
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

  /// The system's own timeout (not the watchdog) is reported as `.timedOut`.
  @MainActor
  func testSystemTimeoutIsReportedAsTimedOut() async {
    let generator = AttributedStringGenerator()
    do {
      _ = try await generator.generateAsync(doc: parse("fast"),
                                            options: RenderingOptions(timeout: 0.0001))
      XCTFail("should throw")
    } catch AttributedStringGenerator.RenderingError.timedOut {
    } catch {
      XCTFail("unexpected error \(error)")
    }
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
                           completionHandler: handler)
    }
    XCTAssertEqual(outcome.calls, 1)
    XCTAssertTrue(outcome.onMainThread)
    if case .failure(.timedOut)? = outcome.result {} else {
      XCTFail("\(String(describing: outcome.result))")
    }
  }

  #endif
}

#endif
