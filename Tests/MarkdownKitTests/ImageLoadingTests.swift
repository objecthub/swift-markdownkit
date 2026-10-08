//
//  ImageLoadingTests.swift
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
@testable import MarkdownKit

/// Tests for the options `localImages`, `remoteImages` and `textSizeMultiplier` of
/// `AttributedStringGenerator.RenderingOptions`.
final class ImageLoadingTests: XCTestCase {

  private typealias Options = AttributedStringGenerator.RenderingOptions

  private var root: URL!
  private var allowed: URL!
  private var outside: URL!

  override func setUpWithError() throws {
    self.root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ImageLoadingTests-\(UUID().uuidString)", isDirectory: true)
    self.allowed = self.root.appendingPathComponent("allowed", isDirectory: true)
    self.outside = self.root.appendingPathComponent("outside", isDirectory: true)
    for dir in [self.allowed!, self.outside!, self.allowed.appendingPathComponent("sub")] {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    let png = Data(base64Encoded:
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
    for url in [self.allowed.appendingPathComponent("in.png"),
                self.allowed.appendingPathComponent("sub/deep.png"),
                self.outside.appendingPathComponent("out.png")] {
      try png.write(to: url)
    }
    try Data("secret".utf8).write(to: self.outside.appendingPathComponent("secret.txt"))
    try Data("secret".utf8).write(to: self.allowed.appendingPathComponent("notes.txt"))
    try FileManager.default.createSymbolicLink(
          at: self.allowed.appendingPathComponent("link.png"),
          withDestinationURL: self.outside.appendingPathComponent("out.png"))
  }

  override func tearDownWithError() throws {
    if let root = self.root {
      try? FileManager.default.removeItem(at: root)
    }
  }

  private func html(_ markdown: String,
                    _ options: Options,
                    imageBaseUrl: URL? = nil) -> String {
    let generator = AttributedStringGenerator(imageBaseUrl: imageBaseUrl, renderingOptions: options)
    return generator.htmlGenerator.generate(doc: ExtendedMarkdownParser.standard.parse(markdown))
  }

  /// The number of `<img` tags in the generated HTML
  private func images(_ html: String) -> Int {
    return html.components(separatedBy: "<img ").count - 1
  }

  private func fileURL(_ dir: URL, _ name: String) -> String {
    return dir.appendingPathComponent(name).absoluteString
  }

  // MARK: Defaults

  func testDefaultsDoNotRestrictAnything() {
    let options = Options()
    XCTAssertEqual(options.localImages, .any)
    XCTAssertEqual(options.remoteImages, .any)
    XCTAssertNil(options.textSizeMultiplier)
    XCTAssertTrue(self.html("![a](x.png)", options).contains("<img src=\"x.png\""))
    XCTAssertTrue(self.html("![a](http://example.com/x.png)", options)
                    .contains("<img src=\"http://example.com/x.png\""))
    XCTAssertTrue(self.html("<b>raw</b>", options).contains("<b>raw</b>"))
    XCTAssertTrue(self.html("![a](x.png)", options, imageBaseUrl: self.allowed)
                    .contains("<img src=\"\(self.fileURL(self.allowed, "x.png"))\""))
  }

  // MARK: Local images

  func testBothNoneShowsAlternativeText() {
    let options = Options(localImages: .none, remoteImages: .none)
    for uri in ["x.png", "http://example.com/x.png", self.fileURL(self.allowed, "in.png"),
                "data:image/png;base64,AAAA"] {
      let result = self.html("![alt text](\(uri))", options, imageBaseUrl: self.allowed)
      XCTAssertEqual(self.images(result), 0, uri)
      XCTAssertTrue(result.contains("alt text"), uri)
    }
  }

  func testLocalWithinAllowsFilesInsideTheDirectory() {
    let options = Options(baseUrl: self.allowed, localImages: .within(self.allowed))
    for uri in ["in.png", "sub/deep.png", "./sub/../in.png", "IN.PNG".lowercased(),
                self.fileURL(self.allowed, "sub/deep.png")] {
      XCTAssertEqual(self.images(self.html("![a](\(uri))", options)), 1, uri)
    }
  }

  func testLocalWithinRejectsEverythingElse() {
    let options = Options(localImages: .within(self.allowed), remoteImages: .none)
    let rejected = ["../outside/out.png",
                    "sub/../../outside/out.png",
                    self.fileURL(self.allowed, "") + "%2e%2e/outside/out.png",
                    self.fileURL(self.allowed, "") + "sub/%2E%2E/%2e%2e/outside/out.png",
                    self.outside.appendingPathComponent("out.png").path,
                    self.fileURL(self.outside, "out.png"),
                    self.fileURL(self.allowed, "../outside/out.png"),
                    "notes.txt",                                 // not an image
                    self.fileURL(self.outside, "secret.txt"),
                    "link.png",                                  // symlink to a file outside
                    "http://127.0.0.1/x.png",
                    "ftp://example.com/x.png",
                    "javascript:alert(1)",
                    "data:text/html;base64,AAAA",
                    "/etc/passwd",
                    ""]
    for uri in rejected {
      let result = self.html("![a](<\(uri)>)", options)
      XCTAssertEqual(self.images(result), 0, uri)
    }
  }

  func testLocalWithinChecksAgainstPrefixesOfPathComponents() throws {
    let sibling = self.root.appendingPathComponent("allowed2", isDirectory: true)
    try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
    try Data().write(to: sibling.appendingPathComponent("x.png"))
    let options = Options(baseUrl: self.allowed, localImages: .within(self.allowed))
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(sibling, "x.png")))", options)), 0)
    XCTAssertEqual(self.images(self.html("![a](../allowed2/x.png)", options)), 0)
  }

  func testResolutionAndAccessControlAreOrthogonal() throws {
    let sub = self.allowed.appendingPathComponent("sub", isDirectory: true)
    // Relative paths are resolved against `baseUrl` ...
    let viaBase = self.html("![a](in.png)", Options(baseUrl: self.allowed, localImages: .within(self.allowed)))
    XCTAssertTrue(viaBase.contains(
      self.allowed.resolvingSymlinksInPath().appendingPathComponent("in.png").absoluteString))
    // ... or against `imageBaseUrl`, which has priority
    let options = Options(baseUrl: self.outside, localImages: .within(self.allowed))
    XCTAssertEqual(self.images(self.html("![a](deep.png)", options, imageBaseUrl: sub)), 1)
    // `.within` does not provide a base: without a base, relative paths are rejected
    XCTAssertEqual(self.images(self.html("![a](in.png)", Options(localImages: .within(self.allowed)))), 0)
    XCTAssertEqual(self.images(self.html("![a](a.png)",
                                         Options(remoteImages: .within(URL(string: "https://example.com/")!)))), 0)
    // A base outside of the permitted directory leads to rejections
    XCTAssertEqual(self.images(self.html("![a](out.png)", options)), 0)
    XCTAssertEqual(self.images(self.html("![a](out.png)", Options(localImages: .within(self.allowed)),
                                         imageBaseUrl: self.outside)), 0)
    // The kind of the resolved URL decides which option applies, not the option's location
    let remote = Options(baseUrl: URL(string: "https://example.com/img/")!,
                         localImages: .within(self.allowed), remoteImages: .none)
    XCTAssertEqual(self.images(self.html("![a](a.png)", remote)), 0)
    let remoteAllowed = Options(baseUrl: URL(string: "https://example.com/img/")!,
                                localImages: .none, remoteImages: .any)
    XCTAssertTrue(self.html("![a](a.png)", remoteAllowed).contains("https://example.com/img/a.png"))
  }

  func testLocalAnyWithRemoteNoneAllowsAllFiles() {
    let options = Options(localImages: .any, remoteImages: .none)
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(self.outside, "out.png")))", options)), 1)
    XCTAssertEqual(self.images(self.html("![a](http://example.com/x.png)", options)), 0)
  }

  // MARK: Remote images

  func testRemoteWithin() throws {
    let base = try XCTUnwrap(URL(string: "https://Images.Example.com/img/"))
    let options = Options(baseUrl: base, localImages: .none, remoteImages: .within(base))
    let accepted = ["https://images.example.com/img/a.png",
                    "https://images.example.com:443/img/sub/a.png",
                    "https://images.example.com/img/./sub/../a.png",
                    "a.png", "sub/a.png"]
    for uri in accepted {
      XCTAssertEqual(self.images(self.html("![a](\(uri))", options)), 1, uri)
    }
    let rejected = ["http://images.example.com/img/a.png",           // other scheme
                    "https://other.example.com/img/a.png",           // other host
                    "https://images.example.com.evil.net/img/a.png",
                    "https://images.example.com:8443/img/a.png",     // other port
                    "https://images.example.com/imgs/a.png",         // prefix of a component
                    "https://images.example.com/img/../a.png",
                    "https://images.example.com/img/%2e%2e/a.png",
                    "https://images.example.com/img/%2E%2e/a.png",
                    "https://images.example.com/img/sub%2f..%2f..%2fa.png",
                    "https://images.example.com/img/sub%5c..%5ca.png",
                    "https://images.example.com/a.png",
                    "https://user:pw@images.example.com/img/a.png",
                    "https://images.example.com@evil.net/img/a.png",
                    "../a.png",
                    "file:///etc/passwd"]
    for uri in rejected {
      XCTAssertEqual(self.images(self.html("![a](<\(uri)>)", options)), 0, uri)
    }
  }

  func testRemoteWithinWithPortAndLocalCombination() throws {
    let base = try XCTUnwrap(URL(string: "http://127.0.0.1:8080/img"))
    let options = Options(baseUrl: self.allowed, localImages: .within(self.allowed),
                          remoteImages: .within(base))
    XCTAssertEqual(self.images(self.html("![a](http://127.0.0.1:8080/img/a.png)", options)), 1)
    XCTAssertEqual(self.images(self.html("![a](http://127.0.0.1:8081/img/a.png)", options)), 0)
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(self.allowed, "in.png")))", options)), 1)
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(self.outside, "out.png")))", options)), 0)
    // Relative paths resolve against `baseUrl`, which is local here
    XCTAssertTrue(self.html("![a](in.png)", options).contains("file:"))
  }

  func testRemoteNoneKeepsLocalAndInlineImages() {
    let options = Options(localImages: .any, remoteImages: .none)
    XCTAssertEqual(self.images(self.html("![a](data:image/png;base64,AAAA)", options)), 1)
    XCTAssertEqual(self.images(self.html("![a](http://example.com/x.png)", options)), 0)
  }

  // MARK: Image extensions

  func testExtensionsAreCheckedForLocalAndRemoteImagesWhenRestricted() {
    let local = Options(localImages: .any, remoteImages: .none)
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(self.allowed, "in.png")))", local)), 1)
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(self.allowed, "notes.txt")))", local)), 0)
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(self.allowed, "noextension")))", local)), 0)
    let remote = Options(localImages: .none, remoteImages: .any)
    XCTAssertEqual(self.images(self.html("![a](http://example.com/x.PNG)", remote)), 1)
    XCTAssertEqual(self.images(self.html("![a](http://example.com/x.png?v=1)", remote)), 1)   // query is ignored
    XCTAssertEqual(self.images(self.html("![a](http://example.com/x.txt?a=.png)", remote)), 0)
    XCTAssertEqual(self.images(self.html("![a](http://example.com/avatar)", remote)), 0)
    XCTAssertEqual(self.images(self.html("![a](http://example.com/dir/)", remote)), 0)
    let within = Options(baseUrl: URL(string: "https://example.com/img/")!, localImages: .none,
                         remoteImages: .within(URL(string: "https://example.com/img/")!))
    XCTAssertEqual(self.images(self.html("![a](a.png)", within)), 1)
    XCTAssertEqual(self.images(self.html("![a](a.txt)", within)), 0)
    XCTAssertEqual(self.images(self.html("![a](a)", within)), 0)
  }

  func testExtensionsAreAlsoCheckedIfLocationsAreNotRestricted() {
    // The extension check is independent of `localImages` and `remoteImages`
    XCTAssertEqual(self.images(self.html("![a](x.png)", Options())), 1)
    XCTAssertEqual(self.images(self.html("![a](http://example.com/x.png)", Options())), 1)
    XCTAssertEqual(self.images(self.html("![a](notes.txt)", Options())), 0)
    XCTAssertEqual(self.images(self.html("![a](http://example.com/avatar)", Options())), 0)
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(self.outside, "secret.txt")))", Options())), 0)
    XCTAssertEqual(self.images(self.html("![a](ftp://example.com/x.txt)", Options())), 0)
    XCTAssertEqual(self.images(self.html("![a](ftp://example.com/x.png)", Options())), 1)
    XCTAssertEqual(self.images(self.html("![a](data:image/png;base64,AAAA)", Options())), 1)
    let anything = Options(imageExtensions: ["", "txt"])
    XCTAssertEqual(self.images(self.html("![a](notes.txt)", anything)), 1)
    XCTAssertEqual(self.images(self.html("![a](x.png)", anything)), 0)
  }

  func testImageExtensionsCanBeConfigured() {
    XCTAssertEqual(Options().imageExtensions, Options.defaultImageExtensions)
    let svg = Options(localImages: .any, remoteImages: .none, imageExtensions: ["SVG", ".webp"])
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(self.allowed, "a.svg")))", svg)), 1)
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(self.allowed, "a.WebP")))", svg)), 1)
    // The set replaces the defaults
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(self.allowed, "in.png")))", svg)), 0)
    // The empty string allows paths without extension
    let none = Options(localImages: .none, remoteImages: .any, imageExtensions: ["", "png"])
    XCTAssertEqual(self.images(self.html("![a](http://example.com/avatar)", none)), 1)
    XCTAssertEqual(self.images(self.html("![a](http://example.com/a.gif)", none)), 0)
    // No extensions: no image
    let empty = Options(localImages: .any, remoteImages: .any, imageExtensions: [])
    XCTAssertEqual(self.images(self.html("![a](x.png)", empty)), 0)
    let emptyRestricted = Options(localImages: .any, remoteImages: .none, imageExtensions: [])
    XCTAssertEqual(self.images(self.html("![a](\(self.fileURL(self.allowed, "in.png")))", emptyRestricted)), 0)
  }

  // MARK: Raw HTML and links

  func testRawHtmlAndLinksAreNotAffectedByImageAccess() {
    // Safe mode is independent of the access control of images
    let markdown = "Text <b>bold</b> [a link](custom://x) <img src=\"x.png\">"
    for options in [Options(), Options(localImages: .none), Options(remoteImages: .none),
                    Options(localImages: .within(self.allowed), remoteImages: .none)] {
      let generator = AttributedStringGenerator(renderingOptions: options)
      XCTAssertFalse(generator.htmlGenerator.safeMode)
      let result = self.html(markdown, options)
      XCTAssertTrue(result.contains("<b>bold</b>"))
      XCTAssertTrue(result.contains("href=\"custom://x\""))
      XCTAssertTrue(result.contains("<img src=\"x.png\">"))
    }
  }

  func testSafeModeIsAnIndependentOption() {
    XCTAssertFalse(Options().safeMode)
    let markdown = "Text <b>bold</b> [a link](custom://x) ![a](in.png) <img src=\"x.png\">"
    // Safe mode with unrestricted images: raw HTML and link schemes are restricted, images
    // are decided by the image options alone
    let safe = Options(baseUrl: self.allowed, safeMode: true)
    let generator = AttributedStringGenerator(renderingOptions: safe)
    XCTAssertTrue(generator.htmlGenerator.safeMode)
    let result = self.html(markdown, safe)
    XCTAssertFalse(result.contains("<b>"))
    XCTAssertTrue(result.contains("<!-- raw HTML omitted -->"))
    XCTAssertTrue(result.contains("href=\"\""))
    XCTAssertFalse(result.contains("custom://x"))
    XCTAssertEqual(self.images(result), 1)
    // Restricting images does not turn on safe mode
    let restricted = Options(baseUrl: self.allowed, localImages: .none)
    XCTAssertFalse(AttributedStringGenerator(renderingOptions: restricted).htmlGenerator.safeMode)
    // Both together
    let both = Options(baseUrl: self.allowed, localImages: .none, safeMode: true)
    let combined = self.html(markdown, both)
    XCTAssertEqual(self.images(combined), 0)
    XCTAssertFalse(combined.contains("<b>"))
  }

  // MARK: Options mapping

  func testTextSizeMultiplierIsMappedToImportOptions() {
    let key = NSAttributedString.DocumentReadingOptionKey(rawValue: "TextSizeMultiplier")
    XCTAssertNil(Options().renderingOptions(forLoadFromHTML: false)[key])
    XCTAssertNil(Options(textSizeMultiplier: 0).renderingOptions(forLoadFromHTML: true)[key])
    for forLoad in [false, true] {
      let dictionary = Options(textSizeMultiplier: 1.5).renderingOptions(forLoadFromHTML: forLoad)
      XCTAssertEqual(dictionary[key] as? Double, 1.5)
    }
  }

  // MARK: End to end

  #if os(macOS)

  private func attachmentCount(_ astr: NSAttributedString?) -> Int {
    var count = 0
    astr?.enumerateAttribute(.attachment,
                             in: NSRange(location: 0, length: astr?.length ?? 0)) { value, _, _ in
      if value is NSTextAttachment {
        count += 1
      }
    }
    return count
  }

  func testSynchronousRenderingHonorsLocalImageRestrictions() {
    let markdown = "![a](in.png) ![b](../outside/out.png) ![c](\(self.fileURL(self.outside, "out.png")))"
    let unrestricted = AttributedStringGenerator(imageBaseUrl: self.allowed)
    XCTAssertEqual(self.attachmentCount(unrestricted.generate(doc: ExtendedMarkdownParser.standard.parse(markdown))), 3)
    let restricted = AttributedStringGenerator(
                       renderingOptions: Options(baseUrl: self.allowed,
                                                 localImages: .within(self.allowed),
                                                 remoteImages: .none))
    let result = restricted.generate(doc: ExtendedMarkdownParser.standard.parse(markdown))
    XCTAssertEqual(self.attachmentCount(result), 1)
    XCTAssertTrue(result?.string.contains("b") ?? false)
    let off = AttributedStringGenerator(imageBaseUrl: self.allowed,
                                        renderingOptions: Options(localImages: .none, remoteImages: .none))
    XCTAssertEqual(self.attachmentCount(off.generate(doc: ExtendedMarkdownParser.standard.parse(markdown))), 0)
  }

  @MainActor
  func testAsynchronousRenderingHonorsRemoteImageRestrictions() async throws {
    let server = try LoopbackImageServer(png: makeTestPNG())
    try server.start()
    defer {
      server.stop()
    }
    let base = try XCTUnwrap(URL(string: "http://127.0.0.1:\(server.port)/allowed/"))
    let markdown = "![a](http://127.0.0.1:\(server.port)/allowed/a.png) " +
                   "![b](http://127.0.0.1:\(server.port)/other/b.png)"
    let doc = ExtendedMarkdownParser.standard.parse(markdown)
    func requests(_ options: Options) async throws -> [String] {
      let before = server.requests.count
      _ = try await AttributedStringGenerator(renderingOptions: options).generateAsync(doc: doc)
      try await Task.sleep(nanoseconds: 300_000_000)
      return Array(server.requests.dropFirst(before)).map { String($0.split(separator: " ")[1]) }
    }
    // unrestricted: both images are requested
    let all = try await requests(Options())
    XCTAssertEqual(Set(all), ["/allowed/a.png", "/other/b.png"])
    // no remote images: nothing is requested
    let none = try await requests(Options(remoteImages: .none))
    XCTAssertEqual(none, [])
    // only below the base
    let within = try await requests(Options(remoteImages: .within(base)))
    XCTAssertEqual(within, ["/allowed/a.png"])
    // the per-call options replace the options of the generator, also for generating HTML
    let before = server.requests.count
    _ = try await AttributedStringGenerator().generateAsync(doc: doc, options: Options(remoteImages: .none))
    try await Task.sleep(nanoseconds: 300_000_000)
    XCTAssertEqual(server.requests.count, before)
  }

  func testTextSizeMultiplierChangesFontSizes() async throws {
    func size(_ astr: NSAttributedString?) -> CGFloat? {
      return astr?.attribute(.font, at: 0, effectiveRange: nil).flatMap { ($0 as? NSFont)?.pointSize }
    }
    let doc = ExtendedMarkdownParser.standard.parse("Text")
    let normal = AttributedStringGenerator()
    let doubled = AttributedStringGenerator(renderingOptions: Options(textSizeMultiplier: 2))
    let syncNormal = try XCTUnwrap(size(normal.generate(doc: doc)))
    XCTAssertEqual(try XCTUnwrap(size(doubled.generate(doc: doc))), syncNormal * 2, accuracy: 0.5)
    let asyncNormal = try await normal.generateAsync(doc: doc)
    let asyncDoubled = try await doubled.generateAsync(doc: doc)
    XCTAssertEqual(try XCTUnwrap(size(asyncDoubled)), try XCTUnwrap(size(asyncNormal)) * 2, accuracy: 0.5)
  }

  #endif
}

#endif
