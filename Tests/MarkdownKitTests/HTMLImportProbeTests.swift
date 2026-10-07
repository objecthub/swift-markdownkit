//
//  HTMLImportProbeTests.swift
//  MarkdownKitTests
//
//  Copyright © 2026 Google LLC.
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

#if os(macOS)

import XCTest
import AppKit
import WebKit
@testable import MarkdownKit

///
/// Probe: how does `NSAttributedString.loadFromHTML(string:options:completionHandler:)` behave
/// compared to the legacy synchronous `NSAttributedString(data:options:documentAttributes:)`?
/// These probes are skipped unless the environment variable `MARKDOWNKIT_PROBES=1` is set.
/// The tests print what they observe (lines starting with `HTMLPROBE`); they do not assert a
/// policy.
///
final class HTMLImportProbeTests: XCTestCase {

  private typealias Options = [NSAttributedString.DocumentReadingOptionKey: Any]

  private var server: ProbeRecordingServer!
  private var directory: URL!
  private var baseURL: URL!
  private var pngData: Data!

  override func setUpWithError() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["MARKDOWNKIT_PROBES"] == "1",
                      "probe: set MARKDOWNKIT_PROBES=1 to run it")
    self.pngData = makeProbePNG()
    self.server = try ProbeRecordingServer(png: self.pngData)
    try self.server.start()
    self.directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("HTMLImportProbe-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    try self.pngData.write(to: self.directory.appendingPathComponent("inside.png"))
    self.baseURL = URL(fileURLWithPath: self.directory.path, isDirectory: true)
  }

  override func tearDownWithError() throws {
    self.server?.stop()
    if let directory = self.directory {
      try? FileManager.default.removeItem(at: directory)
    }
  }

  // MARK: Helpers

  private struct Result {
    var string: NSAttributedString?
    var error: Error?
    var completedOnMainThread: Bool?
    var elapsed: Double
    var timedOut = false
  }

  private func legacy(_ html: String, options extra: Options = [:]) -> Result {
    var options: Options = [.documentType: NSAttributedString.DocumentType.html,
                            .characterEncoding: String.Encoding.utf8.rawValue]
    options.merge(extra) { _, new in new }
    let start = DispatchTime.now().uptimeNanoseconds
    var result = Result(string: nil, error: nil, completedOnMainThread: Thread.isMainThread, elapsed: 0)
    do {
      result.string = try NSAttributedString(data: Data(html.utf8), options: options,
                                             documentAttributes: nil)
    } catch {
      result.error = error
    }
    result.elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    return result
  }

  /// Calls `loadFromHTML(string:)` and waits for the completion handler while spinning the
  /// run loop of the test (the usual situation).
  private func async(_ html: String, options: Options = [:], timeout: TimeInterval = 15) -> Result {
    let done = expectation(description: "loadFromHTML")
    var result = Result(string: nil, error: nil, completedOnMainThread: nil, elapsed: 0)
    let start = DispatchTime.now().uptimeNanoseconds
    NSAttributedString.loadFromHTML(string: html, options: options) { string, _, error in
      result.string = string
      result.error = error
      result.completedOnMainThread = Thread.isMainThread
      result.elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
      done.fulfill()
    }
    if XCTWaiter().wait(for: [done], timeout: timeout) != .completed {
      result.timedOut = true
      result.elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }
    return result
  }

  private struct Observation {
    var attachments = 0
    var bytes: [Int] = []
    var length = 0
    var textBlocks = 0
    var links = 0
    var fontSizes = Set<Int>()
    var string = ""
  }

  private func observe(_ astr: NSAttributedString?) -> Observation {
    var result = Observation()
    guard let astr = astr else {
      return result
    }
    result.length = astr.length
    result.string = astr.string
    let range = NSRange(location: 0, length: astr.length)
    astr.enumerateAttributes(in: range) { attributes, _, _ in
      if let attachment = attributes[.attachment] as? NSTextAttachment {
        result.attachments += 1
        result.bytes.append(attachment.fileWrapper?.regularFileContents?.count ??
                            attachment.contents?.count ?? 0)
      }
      if attributes[.link] != nil {
        result.links += 1
      }
      if let font = attributes[.font] as? NSFont {
        result.fontSizes.insert(Int(font.pointSize.rounded()))
      }
      if let style = attributes[.paragraphStyle] as? NSParagraphStyle, !style.textBlocks.isEmpty {
        result.textBlocks += 1
      }
    }
    return result
  }

  private func pad(_ str: String, _ width: Int) -> String {
    return str.padding(toLength: width, withPad: " ", startingAt: 0)
  }

  private func describe(_ result: Result) -> String {
    let o = observe(result.string)
    var text = "attachments=\(o.attachments) bytes=\(o.bytes) length=\(o.length)"
    if let error = result.error {
      text += " error=\(error.localizedDescription)"
    }
    if result.string == nil {
      text += " (nil)"
    }
    if result.timedOut {
      text += " TIMED OUT (completion never arrived)"
    }
    if let onMain = result.completedOnMainThread {
      text += " mainThread=\(onMain)"
    }
    return text + String(format: " %.0fms", result.elapsed)
  }

  // MARK: baseURL

  /// Does a relative image resolve with a base URL? Different ways to specify the base.
  func testBaseURL() {
    let html = "<html><body><p>Hello</p><img src=\"inside.png\"></body></html>"
    let withBaseTag = "<html><head><base href=\"\(self.baseURL.absoluteString)\"/></head>" +
                      "<body><p>Hello</p><img src=\"inside.png\"></body></html>"
    let typed: Options = [.baseURL: self.baseURL!]
    let raw: Options = [NSAttributedString.DocumentReadingOptionKey(rawValue: "BaseURL"): self.baseURL!]
    print("HTMLPROBE raw value of .baseURL: \(NSAttributedString.DocumentReadingOptionKey.baseURL.rawValue), " +
          ".timeout: \(NSAttributedString.DocumentReadingOptionKey.timeout.rawValue)")
    for (label, html, options) in [("no base", html, [:]), ("typed .baseURL", html, typed),
                                   ("raw key \"BaseURL\"", html, raw),
                                   ("<base href> in the HTML", withBaseTag, [:])] as [(String, String, Options)] {
      print("HTMLPROBE baseURL \(pad(label, 24)) legacy: \(describe(legacy(html, options: options)))")
      print("HTMLPROBE baseURL \(pad(label, 24)) async:  \(describe(async(html, options: options)))")
    }
  }

  // MARK: Threads

  /// Where may loadFromHTML be called, and where does the completion handler run?
  func testThreading() {
    let html = "<p>Hello <b>threads</b></p>"
    // 1. normal: main thread, run loop spinning while waiting
    print("HTMLPROBE threading: from the main thread, run loop spinning: \(describe(async(html)))")
    // 2. from a background queue, waiting on the main thread with a spinning run loop
    let backgroundDone = expectation(description: "background")
    var background = Result(string: nil, error: nil, completedOnMainThread: nil, elapsed: 0)
    let start = DispatchTime.now().uptimeNanoseconds
    DispatchQueue.global().async {
      NSAttributedString.loadFromHTML(string: html, options: [:]) { string, _, error in
        background.string = string
        background.error = error
        background.completedOnMainThread = Thread.isMainThread
        background.elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        backgroundDone.fulfill()
      }
    }
    if XCTWaiter().wait(for: [backgroundDone], timeout: 15) != .completed {
      background.timedOut = true
    }
    print("HTMLPROBE threading: called from a background queue: \(describe(background))")
    // 3. main thread blocked on a semaphore (no run loop): does the completion arrive?
    let semaphore = DispatchSemaphore(value: 0)
    var blockedResult = Result(string: nil, error: nil, completedOnMainThread: nil, elapsed: 0)
    let blockedStart = DispatchTime.now().uptimeNanoseconds
    NSAttributedString.loadFromHTML(string: html, options: [:]) { string, _, error in
      blockedResult.string = string
      blockedResult.error = error
      blockedResult.completedOnMainThread = Thread.isMainThread
      semaphore.signal()
    }
    if semaphore.wait(timeout: .now() + 5) == .timedOut {
      blockedResult.timedOut = true
    }
    blockedResult.elapsed = Double(DispatchTime.now().uptimeNanoseconds - blockedStart) / 1_000_000
    print("HTMLPROBE threading: main thread blocked on a semaphore (5s limit): \(describe(blockedResult))")
    // Let a late completion run
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    // 4. legacy importer from a background queue
    let legacyDone = expectation(description: "legacy background")
    var legacyResult = Result(string: nil, error: nil, completedOnMainThread: nil, elapsed: 0)
    DispatchQueue.global().async {
      legacyResult = self.legacy(html)
      legacyDone.fulfill()
    }
    if XCTWaiter().wait(for: [legacyDone], timeout: 15) != .completed {
      legacyResult.timedOut = true
    }
    print("HTMLPROBE threading: legacy importer on a background queue: \(describe(legacyResult))")
  }

  // MARK: Resources and scripts

  func testResourcesAndScripts() {
    let port = self.server.port
    let remote = "<p>remote</p><img src=\"http://127.0.0.1:\(port)/async-remote.png\">"
    let before = self.server.requests.count
    let legacyRemote = legacy(remote)
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    let legacyRequests = self.server.requests.count - before
    let middle = self.server.requests.count
    let asyncRemote = async(remote)
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    let asyncRequests = self.server.requests.count - middle
    print("HTMLPROBE remote <img>: legacy \(describe(legacyRemote)), requests=\(legacyRequests)")
    print("HTMLPROBE remote <img>: async  \(describe(asyncRemote)), requests=\(asyncRequests) " +
          "\(Array(self.server.requests.dropFirst(middle)))")
    let local = "<p>local</p><img src=\"\(self.baseURL.appendingPathComponent("inside.png").absoluteString)\">"
    print("HTMLPROBE file:// <img>: legacy \(describe(legacy(local)))")
    print("HTMLPROBE file:// <img>: async  \(describe(async(local)))")
    let script = "<p id=\"t\">before</p><script>document.getElementById('t').textContent = 'after';</script>"
    print("HTMLPROBE <script>: legacy text \(observe(legacy(script).string).string.debugDescription), " +
          "async text \(observe(async(script).string).string.debugDescription)")
    let style = "<style>@import url(http://127.0.0.1:\(port)/async-import.css);</style><p>styled</p>"
    let styleBefore = self.server.requests.count
    _ = async(style)
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    print("HTMLPROBE @import: async requests=\(self.server.requests.count - styleBefore)")
  }

  // MARK: Timeout

  func testTimeout() {
    let port = self.server.port
    self.server.hangMarker = "hang"
    let html = "<p>waiting for an image</p><img src=\"http://127.0.0.1:\(port)/hang.png\">"
    let timeoutKey = NSAttributedString.DocumentReadingOptionKey.timeout
    let before = self.server.requests.count
    let noTimeout = async(html, timeout: 8)
    let requested = self.server.requests.count - before
    print("HTMLPROBE timeout: no timeout option: \(describe(noTimeout)), requests=\(requested)")
    let withTimeout = async(html, options: [timeoutKey: 1.0], timeout: 8)
    print("HTMLPROBE timeout: timeout=1s: \(describe(withTimeout))")
    let tiny = async("<p>fast</p>", options: [timeoutKey: 0.001], timeout: 8)
    print("HTMLPROBE timeout: timeout=1ms with trivial HTML: \(describe(tiny))")
    for (label, result) in [("1s", withTimeout), ("1ms", tiny)] {
      if let error = result.error as NSError? {
        print("HTMLPROBE timeout error (\(label)): domain=\(error.domain) code=\(error.code) " +
              "userInfo=\(error.userInfo)")
      }
    }
    self.server.hangMarker = nil
  }

  // MARK: Document attributes

  /// What does the completion handler of loadFromHTML report as document attributes?
  func testDocumentAttributes() {
    let generator = AttributedStringGenerator()
    let doc = ExtendedMarkdownParser.standard.parse("# Title\n\nSome *text* with a [link](http://example.com).\n")
    let html = generator.generateHtml(generator.htmlGenerator.generate(doc: doc))
    let done = expectation(description: "load")
    NSAttributedString.loadFromHTML(string: html, options: [:]) { string, attributes, error in
      let keys = (attributes ?? [:]).map { "\($0.key.rawValue)=\($0.value)" }.sorted()
      print("HTMLPROBE document attributes: nil=\(attributes == nil), count=\(attributes?.count ?? 0): \(keys)")
      done.fulfill()
    }
    wait(for: [done], timeout: 15)
    var legacyAttributes: NSDictionary?
    var dictionary: NSDictionary? = nil
    _ = try? NSAttributedString(data: Data(html.utf8),
                                options: [.documentType: NSAttributedString.DocumentType.html,
                                          .characterEncoding: String.Encoding.utf8.rawValue],
                                documentAttributes: &dictionary)
    legacyAttributes = dictionary
    print("HTMLPROBE document attributes (legacy importer): \(String(describing: legacyAttributes))")
  }

  // MARK: Fidelity and speed

  private func markdownHtml(_ n: Int) -> String {
    var markdown = ""
    for i in 0..<n {
      markdown += "## Heading \(i)\n\nSome *emphasis*, **strong text**, `code` and " +
                  "[a link](http://example.com/\(i) \"title\").\n\n" +
                  "- item one\n- item two\n  - nested\n\n> a quote\n\n" +
                  "```swift\nlet x = \(i)\n```\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n"
    }
    let generator = AttributedStringGenerator()
    let doc = ExtendedMarkdownParser.standard.parse(markdown)
    return generator.generateHtml(generator.htmlGenerator.generate(doc: doc))
  }

  func testFidelityAndSpeed() {
    for n in [1, 10, 100] {
      let html = markdownHtml(n)
      let legacyResult = legacy(html)
      let asyncResult = async(html)
      let l = observe(legacyResult.string)
      let a = observe(asyncResult.string)
      print("HTMLPROBE fidelity n=\(n): legacy length=\(l.length) textBlocks=\(l.textBlocks) links=\(l.links) " +
            "attachments=\(l.attachments) fontSizes=\(l.fontSizes.sorted())")
      print("HTMLPROBE fidelity n=\(n): async  length=\(a.length) textBlocks=\(a.textBlocks) links=\(a.links) " +
            "attachments=\(a.attachments) fontSizes=\(a.fontSizes.sorted())")
      print("HTMLPROBE fidelity n=\(n): same string: \(l.string == a.string)" +
            (l.string == a.string ? "" : " (legacy \(l.string.count) chars, async \(a.string.count) chars)") +
            String(format: " | legacy %.0fms, async %.0fms", legacyResult.elapsed, asyncResult.elapsed))
      // Repeat for stable timings
      let legacySecond = legacy(html)
      let asyncSecond = async(html)
      print(String(format: "HTMLPROBE speed n=%d (second run): legacy %.0fms, async %.0fms", n,
                   legacySecond.elapsed, asyncSecond.elapsed))
      if n == 10, l.string != a.string {
        let la = Array(l.string), aa = Array(a.string)
        let common = zip(la, aa).prefix { $0 == $1 }.count
        print("HTMLPROBE first difference at \(common): legacy \(String(l.string.dropFirst(common).prefix(40)).debugDescription) " +
              "async \(String(a.string.dropFirst(common).prefix(40)).debugDescription)")
      }
    }
  }
}

#endif
