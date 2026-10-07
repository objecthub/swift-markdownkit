//
//  HTMLImportProbeIOSTests.swift
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

#if os(iOS)

import XCTest
import UIKit
import WebKit
@testable import MarkdownKit

/// Probe for iOS: are the base URL and timeout options honored by the legacy HTML importer
/// and by `loadFromHTML`? Skipped unless `MARKDOWNKIT_PROBES=1` is set (with xcodebuild:
/// `TEST_RUNNER_MARKDOWNKIT_PROBES=1`). The tests print what they observe (`HTMLPROBE-IOS`).
final class HTMLImportProbeIOSTests: XCTestCase {

  private typealias Options = [NSAttributedString.DocumentReadingOptionKey: Any]

  override func setUpWithError() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["MARKDOWNKIT_PROBES"] == "1",
                      "probe: set MARKDOWNKIT_PROBES=1 to run it")
  }

  private let pngData = Data(base64Encoded:
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!

  private func describe(_ astr: NSAttributedString?, _ error: Error? = nil) -> String {
    guard let astr = astr else {
      return "nil \(error.map { "error=\($0.localizedDescription)" } ?? "")"
    }
    var parts: [String] = []
    astr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: astr.length)) { value, _, _ in
      if let attachment = value as? NSTextAttachment {
        parts.append("attachment(wrapperBytes=\(attachment.fileWrapper?.regularFileContents?.count ?? -1), " +
                     "contentsBytes=\(attachment.contents?.count ?? -1), " +
                     "image=\(attachment.image != nil), " +
                     "bounds=\(Int(attachment.bounds.width))x\(Int(attachment.bounds.height)))")
      }
    }
    return "length=\(astr.length) \(parts.isEmpty ? "no attachments" : parts.joined(separator: ", "))"
  }

  private func async(_ html: String, options: Options, wait: TimeInterval = 20) -> (NSAttributedString?, Error?, Double) {
    let done = expectation(description: "load")
    var result: NSAttributedString?
    var failure: Error?
    let start = Date()
    NSAttributedString.loadFromHTML(string: html, options: options) { string, _, error in
      result = string
      failure = error
      done.fulfill()
    }
    _ = XCTWaiter().wait(for: [done], timeout: wait)
    return (result, failure, Date().timeIntervalSince(start) * 1000)
  }

  func testBaseURLOnIOS() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("HTMLImportProbeIOS-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: directory)
    }
    try pngData.write(to: directory.appendingPathComponent("inside.png"))
    let base = URL(fileURLWithPath: directory.path, isDirectory: true)
    let html = "<html><body><p>Hello</p><img src=\"inside.png\"></body></html>"
    let withBaseTag = "<html><head><base href=\"\(base.absoluteString)\"/></head>" +
                      "<body><p>Hello</p><img src=\"inside.png\"></body></html>"
    let raw = NSAttributedString.DocumentReadingOptionKey(rawValue: "BaseURL")
    let version = UIDevice.current.systemVersion
    for (label, source, options) in [("no base", html, [:]),
                                     ("raw key \"BaseURL\"", html, [raw: base]),
                                     ("<base href> in the HTML", withBaseTag, [:])] as [(String, String, Options)] {
      var legacyOptions: Options = [.documentType: NSAttributedString.DocumentType.html,
                                    .characterEncoding: String.Encoding.utf8.rawValue]
      legacyOptions.merge(options) { _, new in new }
      let legacy = try? NSAttributedString(data: Data(source.utf8), options: legacyOptions,
                                           documentAttributes: nil)
      let (asyncResult, error, elapsed) = async(source, options: options)
      print("HTMLPROBE-IOS \(version) baseURL \(label.padding(toLength: 24, withPad: " ", startingAt: 0)) " +
            "legacy: \(describe(legacy)) | async: \(describe(asyncResult, error)) (\(Int(elapsed)) ms)")
    }
  }

  func testTimeoutOnIOS() {
    let version = UIDevice.current.systemVersion
    let timeoutKey = NSAttributedString.DocumentReadingOptionKey(rawValue: "Timeout")
    let (tiny, error, elapsed) = async("<p>fast</p>", options: [timeoutKey: 0.001], wait: 10)
    print("HTMLPROBE-IOS \(version) timeout=1ms with trivial HTML: \(describe(tiny, error)) " +
          "(\(Int(elapsed)) ms) domain=\((error as NSError?)?.domain ?? "-") code=\((error as NSError?)?.code ?? 0)")
    let (normal, normalError, normalElapsed) = async("<p>fast</p>", options: [timeoutKey: 30.0], wait: 10)
    print("HTMLPROBE-IOS \(version) timeout=30s with trivial HTML: \(describe(normal, normalError)) " +
          "(\(Int(normalElapsed)) ms)")
  }

  func testGenerateAsyncOnIOS() async throws {
    let version = UIDevice.current.systemVersion
    let generator = AttributedStringGenerator()
    let doc = ExtendedMarkdownParser.standard.parse("# Title\n\nSome *text* and a [link](http://example.com).\n\n- a\n- b\n")
    let sync = generator.generate(doc: doc)
    let start = Date()
    let async = try await generator.generateAsync(doc: doc)
    print("HTMLPROBE-IOS \(version) generateAsync: same string as sync: \(async.string == sync?.string), " +
          "length \(async.length), \(Int(Date().timeIntervalSince(start) * 1000)) ms")
  }
}

#endif
