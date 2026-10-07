//
//  ImageLoadingProbeTests.swift
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
import Network
@testable import MarkdownKit

final class ProbeRecordingServer {
  private let listener: NWListener
  private let queue = DispatchQueue(label: "ImageLoadingProbeTests.server")
  private let lock = NSLock()
  private var recorded: [String] = []
  private(set) var port: UInt16 = 0
  private let png: Data
  /// Requests for paths containing this string are never answered (to probe timeouts)
  var hangMarker: String? = nil
  private var hung: [NWConnection] = []

  init(png: Data) throws {
    let parameters = NWParameters.tcp
    parameters.requiredInterfaceType = .loopback
    self.listener = try NWListener(using: parameters, on: .any)
    self.png = png
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
      throw NSError(domain: "ImageLoadingProbeTests", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "server did not start"])
    }
    self.port = port
  }

  func stop() {
    self.listener.cancel()
  }

  private func handle(_ connection: NWConnection) {
    connection.start(queue: self.queue)
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, _, _ in
      guard let self = self else {
        connection.cancel()
        return
      }
      let request = String(decoding: data ?? Data(), as: UTF8.self)
      let line = request.components(separatedBy: "\r\n").first ?? ""
      self.lock.lock()
      self.recorded.append(line)
      self.lock.unlock()
      let path = line.split(separator: " ").dropFirst().first.map(String.init) ?? ""
      if let marker = self.hangMarker, path.contains(marker) {
        self.lock.lock()
        self.hung.append(connection)
        self.lock.unlock()
        return
      }
      let (type, body): (String, Data) = path.hasSuffix(".css")
        ? ("text/css", Data("body { color: red }".utf8))
        : ("image/png", self.png)
      let header = "HTTP/1.1 200 OK\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n" +
                   "Connection: close\r\n\r\n"
      connection.send(content: Data(header.utf8) + body,
                      completion: .contentProcessed { _ in connection.cancel() })
    }
  }
}

func makeProbePNG() -> Data {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  for x in 0..<8 {
    for y in 0..<8 {
      rep.setColor(.red, atX: x, y: y)
    }
  }
  return rep.representation(using: .png, properties: [:])!
}

///
/// Probe: what does the system's HTML importer load while `AttributedStringGenerator` turns
/// Markdown into an `NSAttributedString`? The tests print what they observe (lines starting
/// with `PROBE`); they do not assert a policy. A throwaway HTTP server on the loopback
/// interface records every request.
///
final class ImageLoadingProbeTests: XCTestCase {

  // MARK: Helpers


  /// What an attributed string contains with respect to images
  private struct Observation {
    var attachments = 0
    var attachmentBytes: [Int] = []
    var length = 0
    var string = ""
  }

  private func observe(_ astr: NSAttributedString?) -> Observation {
    var result = Observation()
    guard let astr = astr else {
      return result
    }
    result.length = astr.length
    result.string = astr.string
    astr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: astr.length)) { value, _, _ in
      if let attachment = value as? NSTextAttachment {
        result.attachments += 1
        let bytes = attachment.fileWrapper?.regularFileContents?.count ??
                    attachment.contents?.count ?? 0
        result.attachmentBytes.append(bytes)
      }
    }
    return result
  }

  private var server: ProbeRecordingServer!
  private var directory: URL!
  private var pngData: Data!

  override func setUpWithError() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["MARKDOWNKIT_PROBES"] == "1",
                      "probe: set MARKDOWNKIT_PROBES=1 to run it")
    self.pngData = makeProbePNG()
    self.server = try ProbeRecordingServer(png: self.pngData)
    try self.server.start()
    self.directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ImageLoadingProbe-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: self.directory.appendingPathComponent("base"),
                                            withIntermediateDirectories: true)
    // The "secret" image is outside of the base directory
    try self.pngData.write(to: self.directory.appendingPathComponent("secret.png"))
    try self.pngData.write(to: self.directory.appendingPathComponent("base/inside.png"))
    // A file which is not an image
    try Data("TOP-SECRET-TEXT-0123456789".utf8)
      .write(to: self.directory.appendingPathComponent("secret.txt"))
  }

  override func tearDownWithError() throws {
    self.server?.stop()
    if let directory = self.directory {
      try? FileManager.default.removeItem(at: directory)
    }
  }

  /// Renders `markdown` and prints what happened.
  private func probe(_ label: String,
                     _ markdown: String,
                     imageBaseUrl: URL? = nil,
                     file: StaticString = #filePath, line: UInt = #line) {
    let generator = AttributedStringGenerator(imageBaseUrl: imageBaseUrl)
    let doc = ExtendedMarkdownParser.standard.parse(markdown)
    let before = self.server.requests.count
    let start = DispatchTime.now().uptimeNanoseconds
    let astr = generator.generate(doc: doc)
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    // The importer might load resources slightly after returning
    var waited = 0.0
    while self.server.requests.count == before && waited < 1.0 {
      Thread.sleep(forTimeInterval: 0.1)
      RunLoop.current.run(until: Date().addingTimeInterval(0.01))
      waited += 0.1
    }
    let observation = observe(astr)
    let newRequests = Array(self.server.requests.dropFirst(before))
    print("PROBE \(label.padding(toLength: 44, withPad: " ", startingAt: 0)) " +
          "attachments=\(observation.attachments) bytes=\(observation.attachmentBytes) " +
          "requests=\(newRequests.count) \(newRequests) " +
          "time=\(String(format: "%.0f", elapsed))ms")
  }

  // MARK: The probe

  func testControlServerIsReachable() throws {
    let url = URL(string: "http://127.0.0.1:\(self.server.port)/control.png")!
    let done = DispatchSemaphore(value: 0)
    var status = -1
    var size = 0
    URLSession.shared.dataTask(with: url) { data, response, _ in
      status = (response as? HTTPURLResponse)?.statusCode ?? -1
      size = data?.count ?? 0
      done.signal()
    }.resume()
    XCTAssertEqual(done.wait(timeout: .now() + 5), .success)
    print("PROBE control: URLSession request to the loopback server: status \(status), \(size) bytes; " +
          "server saw \(self.server.requests)")
    XCTAssertEqual(status, 200)
  }

  func testLocalFileImages() {
    let secret = self.directory.appendingPathComponent("secret.png")
    let inside = self.directory.appendingPathComponent("base/inside.png")
    let base = self.directory.appendingPathComponent("base", isDirectory: true)
    probe("file URL, no base", "![a](\(secret.absoluteString))")
    probe("file URL, base set", "![a](\(secret.absoluteString))", imageBaseUrl: base)
    probe("absolute path, no base", "![a](\(secret.path))")
    probe("absolute path, base set (outside base)", "![a](\(secret.path))", imageBaseUrl: base)
    probe("relative path inside base", "![a](inside.png)", imageBaseUrl: base)
    probe("relative path, base set, file exists", "![a](base/inside.png)", imageBaseUrl: self.directory)
    probe("relative path escaping the base (../)", "![a](../secret.png)", imageBaseUrl: base)
    probe("relative path, no base", "![a](inside.png)")
    probe("missing local file", "![a](file:///nonexistent/missing.png)")
    probe("percent-encoded path", "![a](\(secret.absoluteString.replacingOccurrences(of: "secret", with: "%73ecret")))")
    _ = inside
  }

  /// Can files which are not images be embedded, and does an RTFD export copy files?
  func testNonImageFilesAndExport() throws {
    let text = self.directory.appendingPathComponent("secret.txt")
    let secret = self.directory.appendingPathComponent("secret.png")
    let generator = AttributedStringGenerator()
    for (label, markdown) in [("non-image file (Markdown image)", "![a](\(text.absoluteString))"),
                              ("non-image file (raw <img>)", "<img src=\"\(text.absoluteString)\">"),
                              ("image file (Markdown image)", "![a](\(secret.absoluteString))")] {
      let astr = generator.generate(doc: ExtendedMarkdownParser.standard.parse(markdown))
      let observation = observe(astr)
      var contents = ""
      astr?.enumerateAttribute(.attachment, in: NSRange(location: 0, length: astr?.length ?? 0)) { value, _, _ in
        if let attachment = value as? NSTextAttachment,
           let data = attachment.fileWrapper?.regularFileContents {
          contents = "name \(attachment.fileWrapper?.preferredFilename ?? "?"), " +
                     "contains secret text: \(String(decoding: data, as: UTF8.self).contains("TOP-SECRET"))"
        }
      }
      print("PROBE \(label.padding(toLength: 44, withPad: " ", startingAt: 0)) " +
            "attachments=\(observation.attachments) bytes=\(observation.attachmentBytes) \(contents)")
      // RTF with attachments (RTFD), as `mdkitprocess rtfd` produces
      if let astr = astr, astr.length > 0 {
        let wrapper = astr.rtfdFileWrapper(from: NSRange(location: 0, length: astr.length),
                                           documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
        let files = (wrapper?.fileWrappers ?? [:]).map { "\($0.key)=\($0.value.regularFileContents?.count ?? -1)B" }
        print("PROBE   RTFD export of \(label): \(files.sorted())")
      }
    }
  }

  func testRemoteImages() {
    let port = self.server.port
    probe("remote image (Markdown)", "![a](http://127.0.0.1:\(port)/markdown.png)")
    probe("remote image, with title", "![a](http://127.0.0.1:\(port)/titled.png \"title\")")
    probe("remote image as link text", "[![a](http://127.0.0.1:\(port)/linked.png)](http://example.com)")
    probe("remote image, safe-looking alt", "![](http://127.0.0.1:\(port)/noalt.png)")
    probe("data: URL image", "![a](data:image/png;base64,\(self.pngData.base64EncodedString()))")
  }

  func testRawHtmlResources() {
    let port = self.server.port
    probe("raw <img> block", "<img src=\"http://127.0.0.1:\(port)/raw-block.png\">")
    probe("raw inline <img>", "text <img src=\"http://127.0.0.1:\(port)/raw-inline.png\"> text")
    probe("raw <link rel=stylesheet>",
          "<link rel=\"stylesheet\" href=\"http://127.0.0.1:\(port)/link.css\">\n\ntext")
    probe("raw <style>@import</style>",
          "<style>@import url(http://127.0.0.1:\(port)/import.css);</style>\n\ntext")
    probe("raw <div style=background:url(...)>",
          "<div style=\"background-image:url(http://127.0.0.1:\(port)/bg.png)\">text</div>")
    probe("raw <img src=file://...>", "<img src=\"\(self.directory.appendingPathComponent("secret.png").absoluteString)\">")
  }
}

#endif
