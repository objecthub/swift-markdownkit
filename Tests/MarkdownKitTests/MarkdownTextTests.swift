//
//  MarkdownTextTests.swift
//  MarkdownKitTests
//
//  Created on 08/10/2026.
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
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import MarkdownKit

/// Tests of the SwiftUI view `MarkdownText`; the view is hosted in a window which is not shown.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class MarkdownTextTests: XCTestCase {

  #if os(macOS)
  private typealias PlatformView = NSView
  private typealias PlatformTextView = NSTextView
  #else
  private typealias PlatformView = UIView
  private typealias PlatformTextView = UITextView
  #endif

  /// Hosts a SwiftUI view of type `Content`
  @MainActor
  private final class Host<Content: View> {
    #if os(macOS)
    let hostingView: NSHostingView<Content>
    let window: NSWindow
    var rootView: Content {
      get { return self.hostingView.rootView }
      set { self.hostingView.rootView = newValue }
    }
    init(_ content: Content) {
      self.hostingView = NSHostingView(rootView: content)
      self.window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                             styleMask: [.titled], backing: .buffered, defer: false)
      self.window.contentView = self.hostingView
      self.hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
    }
    var view: NSView {
      self.hostingView.layoutSubtreeIfNeeded()
      return self.hostingView
    }
    #else
    let controller: UIHostingController<Content>
    let window: UIWindow
    var rootView: Content {
      get { return self.controller.rootView }
      set { self.controller.rootView = newValue }
    }
    init(_ content: Content) {
      self.controller = UIHostingController(rootView: content)
      self.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
      self.window.rootViewController = self.controller
      self.window.isHidden = false
    }
    var view: UIView {
      self.controller.view.layoutIfNeeded()
      return self.controller.view
    }
    #endif
  }

  private func textViews(in view: PlatformView) -> [PlatformTextView] {
    var result: [PlatformTextView] = []
    if let textView = view as? PlatformTextView {
      result.append(textView)
    }
    for subview in view.subviews {
      result.append(contentsOf: self.textViews(in: subview))
    }
    return result
  }

  private func displayedText<Content: View>(_ host: Host<Content>) -> String {
    let views = self.textViews(in: host.view)
    #if os(macOS)
    return views.map { $0.string }.joined(separator: "\n")
    #else
    return views.map { $0.attributedText.string }.joined(separator: "\n")
    #endif
  }

  /// Runs the main run loop until the text displayed by `host` satisfies `condition`
  private func wait<Content: View>(for host: Host<Content>,
                                   timeout: TimeInterval = 20,
                                   until condition: (String) -> Bool) -> String {
    let deadline = Date().addingTimeInterval(timeout)
    var text = self.displayedText(host)
    while !condition(text) && Date() < deadline {
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
      text = self.displayedText(host)
    }
    return text
  }

  func testViewDisplaysContent() {
    let host = Host(MarkdownText(string: "Some *first* text"))
    let text = self.wait(for: host) { $0.contains("first") }
    XCTAssertTrue(text.contains("Some first text"), text)
  }

  /// A new `MarkdownText` value for a different document replaces the content (the view keeps
  /// its state when the document changes)
  func testViewDisplaysNewContentIfDocumentChanges() {
    let host = Host(MarkdownText(string: "Some *first* text"))
    XCTAssertTrue(self.wait(for: host) { $0.contains("first") }.contains("Some first text"))
    host.rootView = MarkdownText(string: "The **second** document")
    let text = self.wait(for: host) { $0.contains("second") }
    XCTAssertTrue(text.contains("The second document"), text)
    XCTAssertFalse(text.contains("first"), text)
  }

  // MARK: Initializers and rendering options

  /// All forms of initializers resolve to the intended initializer
  func testInitializerFormsCompile() {
    let doc = ExtendedMarkdownParser.standard.parse("Some text")
    let waiting = NSAttributedString(string: "...")
    let optionalGenerator: ((Block, ColorScheme) -> NSAttributedString?)? = nil
    _ = MarkdownText(doc)
    _ = MarkdownText(doc, waitingMessage: waiting)
    _ = MarkdownText(doc, renderingOptions: .untrusted)
    _ = MarkdownText(doc, waitingMessage: waiting, renderingOptions: .untrusted)
    _ = MarkdownText(doc, generator: nil)
    _ = MarkdownText(doc, generator: optionalGenerator)
    _ = MarkdownText(doc, waitingMessage: waiting, generator: nil)
    _ = MarkdownText(doc) { _, _ in nil }
    _ = MarkdownText(doc, waitingMessage: waiting) { _, _ in nil }
    _ = MarkdownText(string: "Some text")
    _ = MarkdownText(string: "Some text", waitingMessage: waiting)
    _ = MarkdownText(string: "Some text", renderingOptions: .untrusted)
    _ = MarkdownText(string: "Some text", waitingMessage: waiting, renderingOptions: .untrusted)
    _ = MarkdownText(string: "Some text", generator: nil)
    _ = MarkdownText(string: "Some text", waitingMessage: waiting, generator: optionalGenerator)
    _ = MarkdownText(string: "Some text") { _, _ in nil }
  }

  /// Without a generator, the view displays the document like the default generator
  func testViewWithoutGeneratorUsesTheDefaultGenerator() {
    let host = Host(MarkdownText(string: "Some *first* text", generator: nil))
    XCTAssertTrue(self.wait(for: host) { $0.contains("first") }.contains("Some first text"))
  }

  func testViewUsesTheGivenGenerator() {
    let host = Host(MarkdownText(string: "Some *first* text") { _, _ in
      NSAttributedString(string: "Generated by the closure")
    })
    XCTAssertTrue(self.wait(for: host) { $0.contains("closure") }.contains("Generated by the closure"))
  }

  private let pngData = Data(base64Encoded:
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!

  /// A temporary directory with an image, and the Markdown which refers to it
  private func makeImageMarkdown() throws -> (markdown: String, cleanup: () -> Void) {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("MarkdownTextTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let image = dir.appendingPathComponent("image.png")
    try self.pngData.write(to: image)
    return ("Before ![the alt text](\(image.absoluteString)) after",
            { try? FileManager.default.removeItem(at: dir) })
  }

  /// The character that stands for a text attachment in the text of a text view
  private let attachmentCharacter = "\u{FFFC}"

  func testViewWithRenderingOptionsRestrictsImages() throws {
    let (markdown, cleanup) = try self.makeImageMarkdown()
    defer {
      cleanup()
    }
    // By default, the local image is displayed
    let plain = Host(MarkdownText(string: markdown))
    let plainText = self.wait(for: plain) { $0.contains("after") }
    XCTAssertTrue(plainText.contains(self.attachmentCharacter), plainText)
    XCTAssertFalse(plainText.contains("the alt text"), plainText)
    // With `untrusted`, only its alternative text is displayed
    let untrusted = Host(MarkdownText(string: markdown, renderingOptions: .untrusted))
    let untrustedText = self.wait(for: untrusted) { $0.contains("after") }
    XCTAssertFalse(untrustedText.contains(self.attachmentCharacter), untrustedText)
    XCTAssertTrue(untrustedText.contains("the alt text"), untrustedText)
    // The same for the initializer for a document
    let doc = ExtendedMarkdownParser.standard.parse(markdown)
    let viaBlock = Host(MarkdownText(doc, renderingOptions: .untrusted))
    let viaBlockText = self.wait(for: viaBlock) { $0.contains("after") }
    XCTAssertFalse(viaBlockText.contains(self.attachmentCharacter), viaBlockText)
  }

  /// The default generators for both color schemes use the rendering options
  func testDefaultGeneratorsForBothColorSchemesUseTheRenderingOptions() throws {
    let (markdown, cleanup) = try self.makeImageMarkdown()
    defer {
      cleanup()
    }
    let doc = ExtendedMarkdownParser.standard.parse(markdown)
    func hasAttachment(_ options: AttributedStringGenerator.RenderingOptions,
                       _ scheme: ColorScheme) -> Bool {
      let astr = MarkdownText.defaultGenerator(options)(doc, scheme)
      return astr?.string.contains(self.attachmentCharacter) ?? false
    }
    for scheme in [ColorScheme.light, ColorScheme.dark] {
      XCTAssertTrue(hasAttachment(.init(), scheme), "\(scheme)")
      XCTAssertFalse(hasAttachment(.untrusted, scheme), "\(scheme)")
      XCTAssertTrue(hasAttachment(.init(localImages: .any, safeMode: true), scheme), "\(scheme)")
      XCTAssertFalse(hasAttachment(.init(localImages: .none), scheme), "\(scheme)")
    }
  }

  func testViewIsNotRenderedAgainForTheSameDocument() {
    var count = 0
    let doc = ExtendedMarkdownParser.standard.parse("Some text")
    func view() -> MarkdownText {
      return MarkdownText(doc) { doc, _ in
        count += 1
        return AttributedStringGenerator.standard.generate(doc: doc)
      }
    }
    let host = Host(view())
    XCTAssertTrue(self.wait(for: host) { $0.contains("Some text") }.contains("Some text"))
    let rendered = count
    XCTAssertGreaterThan(rendered, 0)
    host.rootView = view()
    _ = self.wait(for: host, timeout: 1) { _ in false }
    XCTAssertEqual(count, rendered)
  }
}

#endif
