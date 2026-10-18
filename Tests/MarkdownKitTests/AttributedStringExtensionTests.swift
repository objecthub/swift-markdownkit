//
//  AttributedStringExtensionTests.swift
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
// This file deliberately does not use `@testable import`: it extends the attributed string
// generator the way a client of the framework does, which needs the extension points to be `open`.
import MarkdownKit

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

/// A thread-safe list of events.
private final class EventLog: @unchecked Sendable {
  private let lock = NSLock()
  private var events: [String] = []

  func add(_ event: String) {
    self.lock.lock()
    self.events.append(event)
    self.lock.unlock()
  }

  var all: [String] {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    return self.events
  }
}

/// The content which an extension of the generator puts into the HTML: placeholders, which
/// the finishing step replaces in the attributed string.
private final class PlaceholderContext: @unchecked Sendable {
  private let lock = NSLock()
  private var names: [String] = []

  func placeholder(for name: String) -> String {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    self.names.append(name)
    return "\u{E000}RPL\(self.names.count - 1)\u{E001}"
  }

  /// Replaces each placeholder with the name between angle brackets.
  func replacing(in string: NSAttributedString) -> NSAttributedString {
    self.lock.lock()
    let names = self.names
    self.lock.unlock()
    let result = NSMutableAttributedString(attributedString: string)
    for (i, name) in names.enumerated() {
      let range = (result.string as NSString).range(of: "\u{E000}RPL\(i)\u{E001}")
      if range.location != NSNotFound {
        result.replaceCharacters(in: range, with: "⟨\(name)⟩")
      }
    }
    return result
  }
}

private protocol PlaceholderProviding: AnyObject {
  var placeholders: PlaceholderContext { get }
}

/// The HTML generators of the extension carry its context, like the diagrams of Mermaid.
private final class PlaceholderHtmlGenerator: AttributedStringGenerator.InternalHtmlGenerator,
                                              PlaceholderProviding, @unchecked Sendable {
  let placeholders = PlaceholderContext()
}

private final class PlaceholderOS26HtmlGenerator: AttributedStringGenerator.OS26HtmlGenerator,
                                                  PlaceholderProviding, @unchecked Sendable {
  let placeholders = PlaceholderContext()
}

/// A syntax tree node which becomes a placeholder in attributed strings.
private struct MarkerFragment: CustomTextFragment {
  let name: String

  func equals(to other: CustomTextFragment) -> Bool {
    return (other as? MarkerFragment)?.name == self.name
  }

  func transform(via transformer: InlineTransformer) -> TextFragment {
    return .custom(self)
  }

  func generateHtml(via htmlGen: HtmlGenerator) -> String {
    return "[\(self.name)]"
  }

  func generateHtml(via htmlGen: HtmlGenerator, and attrGen: AttributedStringGenerator?) -> String {
    guard let provider = htmlGen as? PlaceholderProviding else {
      return self.generateHtml(via: htmlGen)
    }
    return provider.placeholders.placeholder(for: self.name)
  }

  var rawDescription: String {
    return self.name
  }

  var description: String {
    return "[\(self.name)]"
  }

  var debugDescription: String {
    return "marker(\(self.name))"
  }
}

/// A generator which extends `AttributedStringGenerator` without changing any of its code.
private final class PlaceholderGenerator: AttributedStringGenerator, @unchecked Sendable {
  let events = EventLog()
  var prepares = true

  override func htmlGenerator(options: RenderingOptions? = nil) -> InternalHtmlGenerator {
    self.events.add("html")
    let renderingOptions = options ?? self.renderingOptions
    switch self.version {
      case .preOS26:
        return PlaceholderHtmlGenerator(outer: self, renderingOptions: renderingOptions)
      case .OS26:
        return PlaceholderOS26HtmlGenerator(outer: self, renderingOptions: renderingOptions)
    }
  }

  override var needsPreparation: Bool {
    return self.prepares
  }

  override func preparedHtmlGenerator(for block: Block,
                                      options: RenderingOptions?) async -> InternalHtmlGenerator {
    self.events.add("prepare block")
    await Task.yield()
    return await super.preparedHtmlGenerator(for: block, options: options)
  }

  override func preparedHtmlGenerator(for blocks: Blocks,
                                      options: RenderingOptions?) async -> InternalHtmlGenerator {
    self.events.add("prepare blocks")
    await Task.yield()
    return await super.preparedHtmlGenerator(for: blocks, options: options)
  }

  override func finishAttributedString(_ string: NSAttributedString,
                                       from generator: InternalHtmlGenerator) -> NSAttributedString {
    self.events.add("finish")
    let result = super.finishAttributedString(string, from: generator)
    guard let provider = generator as? PlaceholderProviding else {
      return result
    }
    return provider.placeholders.replacing(in: result)
  }
}

/// Tests that a subclass can put its own content into attributed strings by using the extension
/// points of `AttributedStringGenerator`, which is how the support for math will be built.
final class AttributedStringExtensionTests: XCTestCase {

  private let versions: [AttributedStringGenerator.Version] = [.OS26, .preOS26]

  private func document() -> Block {
    var text = Text(.text("Before "))
    text.append(fragment: .custom(MarkerFragment(name: "one")))
    text.append(fragment: .text(" and "))
    text.append(fragment: .custom(MarkerFragment(name: "two")))
    text.append(fragment: .text(" after"))
    return .document([.paragraph(text)])
  }

  private func blocks() -> Blocks {
    guard case .document(let blocks) = self.document() else {
      fatalError("document expected")
    }
    return blocks
  }

  private let expected = "Before ⟨one⟩ and ⟨two⟩ after"

  func testTheDefaultsAreUnchanged() {
    XCTAssertFalse(AttributedStringGenerator().needsPreparation)
    XCTAssertTrue(AttributedStringGenerator(mermaid: MermaidConfig()).needsPreparation)
  }

  // MARK: Synchronous generation

  @MainActor
  func testSynchronousMethodsFinishTheStringWithTheGeneratorOfTheHtml() throws {
    for version in self.versions {
      let generator = PlaceholderGenerator(version: version)
      let doc = try XCTUnwrap(generator.generate(doc: self.document()))
      XCTAssertTrue(doc.string.contains(self.expected), "\(version): \(doc.string)")
      XCTAssertFalse(doc.string.contains("\u{E000}"), "\(version): \(doc.string)")
      XCTAssertEqual(generator.events.all, ["html", "finish"], "\(version)")
      guard case .document(let blocks) = self.document(), let block = blocks.first else {
        XCTFail("document expected")
        return
      }
      XCTAssertTrue(try XCTUnwrap(generator.generate(block: block)).string.contains(self.expected))
      XCTAssertTrue(try XCTUnwrap(generator.generate(blocks: blocks)).string.contains(self.expected))
      XCTAssertEqual(generator.events.all, ["html", "finish", "html", "finish", "html", "finish"],
                     "\(version)")
    }
  }

  @MainActor
  func testWithoutTheExtensionTheMarkersStayPlaceholdersOfTheHtml() throws {
    let result = try XCTUnwrap(AttributedStringGenerator().generate(doc: self.document()))
    XCTAssertTrue(result.string.contains("Before [one] and [two] after"), result.string)
  }

  #if canImport(WebKit) && (os(macOS) || os(iOS))

  // MARK: Asynchronous generation

  @MainActor
  func testAsynchronousMethodsPrepareAndFinish() async throws {
    for version in self.versions {
      let generator = PlaceholderGenerator(version: version)
      let doc = try await generator.generateAsync(doc: self.document())
      XCTAssertTrue(doc.string.contains(self.expected), "\(version): \(doc.string)")
      // The generator is prepared before the HTML is generated, and the string is finished once
      XCTAssertEqual(generator.events.all, ["prepare block", "html", "finish"], "\(version)")
      guard case .document(let blocks) = self.document(), let block = blocks.first else {
        XCTFail("document expected")
        return
      }
      let single = try await generator.generateAsync(block: block)
      XCTAssertTrue(single.string.contains(self.expected))
      let several = try await generator.generateAsync(blocks: blocks)
      XCTAssertTrue(several.string.contains(self.expected))
      XCTAssertEqual(generator.events.all,
                     ["prepare block", "html", "finish", "prepare block", "html", "finish",
                      "prepare blocks", "html", "finish"], "\(version)")
    }
  }

  @MainActor
  func testAsynchronousMethodsDoNotPrepareIfNotNeeded() async throws {
    let generator = PlaceholderGenerator()
    generator.prepares = false
    let result = try await generator.generateAsync(doc: self.document())
    XCTAssertTrue(result.string.contains(self.expected), result.string)
    XCTAssertEqual(generator.events.all, ["html", "finish"])
  }

  private func awaitCompletion(
      _ generator: PlaceholderGenerator,
      _ start: (@escaping (sending Result<NSAttributedString,
                                          AttributedStringGenerator.RenderingError>) -> Void) -> Void)
      -> (string: String?, onMainThread: Bool, calls: Int) {
    let done = expectation(description: "completion handler")
    nonisolated(unsafe) var string: String?
    nonisolated(unsafe) var onMainThread = false
    nonisolated(unsafe) var calls = 0
    start { result in
      calls += 1
      onMainThread = Thread.isMainThread
      string = try? result.get().string
      done.fulfill()
    }
    wait(for: [done], timeout: 30)
    // Make sure that the handler is not called again
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    return (string, onMainThread, calls)
  }

  func testCompletionHandlerMethodsPrepareAndFinish() {
    for prepares in [true, false] {
      let generator = PlaceholderGenerator()
      generator.prepares = prepares
      let doc = self.document()
      let outcome = self.awaitCompletion(generator) { handler in
        generator.generateAsync(doc: doc, completionHandler: handler)
      }
      XCTAssertEqual(outcome.calls, 1, "prepares: \(prepares)")
      XCTAssertTrue(outcome.onMainThread, "prepares: \(prepares)")
      XCTAssertTrue(outcome.string?.contains(self.expected) ?? false,
                    "prepares: \(prepares): \(outcome.string ?? "nil")")
      XCTAssertEqual(generator.events.all,
                     prepares ? ["prepare block", "html", "finish"] : ["html", "finish"],
                     "prepares: \(prepares)")
    }
  }

  #endif
}

#endif
