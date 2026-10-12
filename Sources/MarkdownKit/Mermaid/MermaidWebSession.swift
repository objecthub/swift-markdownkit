//
//  MermaidWebSession.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 12/10/2026.
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

#if canImport(WebKit) && (os(macOS) || os(iOS))

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import WebKit

// MARK: - Session

/// Renders diagrams one after the other with a single web page, which is created on demand and
/// released when it has not been used for a while.
@MainActor
final class MermaidWebSession {

  /// The longest idle time in seconds that is taken literally: a longer time is the same as
  /// never releasing the page (about 31 years).
  private static let maxIdleTime: TimeInterval = 1_000_000_000

  /// The time in seconds after which the web page is released if no diagram is being rendered.
  /// At most 0 means that the page is released as soon as no request is waiting for it, and
  /// `maxIdleTime` or more that it is never released. Without a page, memory is freed, but the
  /// next diagram needs a new page.
  private let idleTime: TimeInterval

  /// The location of the Mermaid library, a JavaScript file.
  private let scriptURL: URL

  /// If true, the JavaScript that is injected into every page (Mermaid and the glue code) is
  /// kept after it has been read, so that creating another page does not read the file again
  /// on the main thread. This takes about 3.6 MB of memory for as long as the session exists.
  /// If false, the file is read whenever a page is created, and nothing is kept.
  private let cachesScript: Bool

  /// The JavaScript that is injected into every page, if it is cached.
  private var script: String?

  /// True if the JavaScript has been read and is being kept.
  var hasCachedScript: Bool {
    return self.script != nil
  }

  /// The web page which renders the diagrams. It is created when the first diagram is rendered,
  /// and replaced if it cannot be used any more or if a diagram needs a page of another width.
  /// It is `nil` while no page exists, i.e. before the first diagram, after a page was released
  /// because it was not used for a while, and after a page failed.
  private var page: MermaidWebPage?

  /// True while a diagram is being rendered. Diagrams are rendered one after the other since
  /// there is only one page; see `acquire()` and `release()`.
  private var busy = false

  /// The requests which wait for the diagram that is being rendered to be finished, in the
  /// order in which they arrived. Each of them is resumed by `release()` and then owns the page.
  private var waiters: [CheckedContinuation<Void, Never>] = []

  /// Counts the times the session was used or became idle. `scheduleIdleRelease()` remembers
  /// its value and only releases the page if it is unchanged when the idle time is over, i.e.
  /// if the page has not been used in the meantime.
  private var idleGeneration = 0

  /// True if there is a web page at the moment.
  var hasPage: Bool {
    return self.page != nil
  }

  /// Creates a session which renders diagrams with the Mermaid library at `scriptURL`. If
  /// `cachesScript` is false, the library is read again every time a page is created (the first
  /// page, and after a page was released or failed) instead of being kept in memory. The web
  /// page is released if no diagram has been rendered for `idleTime` seconds; see `idleTime`.
  nonisolated init(scriptURL: URL,
                   cachesScript: Bool = true,
                   idleTime: TimeInterval = MermaidRenderer.defaultIdleTime) {
    self.scriptURL = scriptURL
    self.cachesScript = cachesScript
    self.idleTime = idleTime.isNaN ? MermaidRenderer.defaultIdleTime : max(0, idleTime)
  }

  /// Renders the diagram.
  func render(source: String, config: MermaidConfig) async throws -> MermaidImage {
    await self.acquire()
    defer {
      self.release()
    }
    if Task.isCancelled {
      throw MermaidError.cancelled
    }
    do {
      let page = try await self.page(width: config.renderKey.width, timeout: config.timeout)
      return try await page.render(source: source, config: config)
    } catch let error as MermaidError {
      // A page that failed for another reason than a diagram which Mermaid rejected may be
      // stuck; use a new one for the next diagram.
      if case .syntaxError = error {
        // The page is fine
      } else {
        self.page = nil
      }
      throw error
    } catch {
      self.page = nil
      throw MermaidError.renderingFailed(error.localizedDescription)
    }
  }

  /// Returns a page of the given width that can be used.
  private func page(width: CGFloat, timeout: TimeInterval) async throws -> MermaidWebPage {
    if let page = self.page, page.isUsable, page.width == width {
      return page
    }
    self.page = nil
    let script: String
    if let cached = self.script {
      script = cached
    } else {
      guard let mermaid = try? String(contentsOf: self.scriptURL, encoding: .utf8) else {
        throw MermaidError.resourcesMissing
      }
      script = MermaidWebPage.userScript(mermaid: mermaid)
      if self.cachesScript {
        self.script = script
      }
    }
    let page = try await MermaidWebPage.make(script: script,
                                             width: width,
                                             timeout: timeout > 0 ? max(timeout, 30) : 30)
    self.page = page
    return page
  }

  /// Waits until no other diagram is being rendered. The caller has to call `release()`.
  private func acquire() async {
    self.idleGeneration += 1
    if !self.busy {
      self.busy = true
    } else {
      // The next call of `release()` passes the ownership on to this waiter
      await withCheckedContinuation { continuation in
        self.waiters.append(continuation)
      }
    }
  }

  private func release() {
    if self.waiters.isEmpty {
      self.busy = false
      self.scheduleIdleRelease()
    } else {
      self.waiters.removeFirst().resume()
    }
  }

  /// Releases the web page if it is not used any more after `idleTime` seconds. The caller has
  /// just released the session; no request is waiting.
  private func scheduleIdleRelease() {
    self.idleGeneration += 1
    if self.idleTime <= 0 {
      self.page = nil
      return
    }
    guard self.idleTime < MermaidWebSession.maxIdleTime else {
      return
    }
    let generation = self.idleGeneration
    let nanoseconds = UInt64(self.idleTime * 1_000_000_000)
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: nanoseconds)
      guard let self, self.idleGeneration == generation, !self.busy else {
        return
      }
      self.page = nil
    }
  }
}

// MARK: - Web page

/// A headless web view which has loaded Mermaid.
@MainActor
private final class MermaidWebPage: NSObject, WKNavigationDelegate {

  /// The JavaScript which is injected into the page together with Mermaid. It renders a diagram
  /// into the page (without ever using the diagram text as JavaScript) and reports where it is.
  /// `securityLevel` is fixed to "strict" and cannot be overridden by `config`.
  static let glue = """
    globalThis.__mkRender = async function (id, source, config) {
      const host = document.getElementById('host');
      try {
        host.textContent = '';
        mermaid.initialize(Object.assign({}, config, {
          startOnLoad: false,
          securityLevel: 'strict',
          suppressErrorRendering: true
        }));
        await mermaid.parse(source);
        const result = await mermaid.render(id, source);
        host.innerHTML = result.svg;
        const svg = host.querySelector('svg');
        if (!svg) {
          return { error: 'Mermaid did not produce a diagram' };
        }
        const r = svg.getBoundingClientRect();
        return { x: r.left + window.scrollX, y: r.top + window.scrollY,
                 width: r.width, height: r.height };
      } catch (e) {
        const leftover = document.getElementById('d' + id);
        if (leftover) {
          leftover.remove();
        }
        return { error: String((e && e.message) || e) };
      }
    };
    """

  /// A rule list which blocks all network and file loads of the page: diagrams must never be
  /// able to contact other hosts (for example, via an image or a CSS import).
  private static var blockingRules: WKContentRuleList?

  private static func networkBlockingRules() async throws -> WKContentRuleList {
    if let rules = self.blockingRules {
      return rules
    }
    // Content blockers do not support alternatives in a pattern: one rule for each scheme
    let json = "[" + ["^https?:", "^wss?:", "^ftp:", "^file:"].map {
      "{\"trigger\": {\"url-filter\": \"\($0)\"}, \"action\": {\"type\": \"block\"}}"
    }.joined(separator: ",") + "]"
    guard let rules = try await WKContentRuleListStore.default().compileContentRuleList(
                                  forIdentifier: "net.objecthub.MarkdownKit.Mermaid.BlockNetwork",
                                  encodedContentRuleList: json) else {
      throw MermaidError.renderingFailed("cannot install the restrictions of the web view")
    }
    self.blockingRules = rules
    return rules
  }

  /// The width in points of the page.
  let width: CGFloat

  /// The web view which draws the diagrams. It is never part of a window, and it is not
  /// connected to the rest of the application.
  private let webView: WKWebView

  /// Reports that loading the page has finished or failed. It is set while `load(timeout:)`
  /// waits for the page, and `nil` otherwise.
  private var loadHandler: (@Sendable (Result<Void, Error>) -> Void)?

  /// True once the web view has finished loading the page (or failed to do so). From then on,
  /// the web view refuses all navigations, so the page cannot leave the page it has loaded.
  private var loaded = false

  /// The number of diagrams which this page has been asked to render. It makes the identifiers
  /// of the diagrams in the page different.
  private var counter = 0

  /// False once the web content process of the web view has terminated. The page can not render
  /// anything any more; the session has to replace it by a new page.
  private(set) var isUsable = true

  private init(webView: WKWebView, width: CGFloat) {
    self.webView = webView
    self.width = width
    super.init()
    webView.navigationDelegate = self
  }

  /// The JavaScript to inject into a page: Mermaid together with `glue`.
  static func userScript(mermaid: String) -> String {
    return mermaid + "\n" + MermaidWebPage.glue
  }

  /// Creates a web view with `width` points, loads `script` (see `userScript(mermaid:)`) into it,
  /// and waits until it is ready.
  static func make(script: String, width: CGFloat, timeout: TimeInterval) async throws
                -> MermaidWebPage {
    let rules = try await MermaidWebPage.networkBlockingRules()
    let controller = WKUserContentController()
    controller.add(rules)
    controller.addUserScript(WKUserScript(source: script,
                                          injectionTime: .atDocumentStart,
                                          forMainFrameOnly: true))
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    configuration.userContentController = controller
    let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: 16),
                            configuration: configuration)
    #if os(macOS)
    // Without this, the web view draws a white background. There is no public API for this on
    // macOS; the key is only set if the web view has it.
    if webView.responds(to: NSSelectorFromString("_setDrawsBackground:")) {
      webView.setValue(false, forKey: "drawsBackground")
    }
    #else
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    #endif
    let page = MermaidWebPage(webView: webView, width: width)
    try await page.load(timeout: timeout)
    return page
  }

  private func load(timeout: TimeInterval) async throws {
    // A viewport is needed: without it, the layout width on iOS is about 980 points
    let html = """
      <!doctype html><html><head><meta charset="utf-8">\
      <meta name="viewport" content="width=\(Int(self.width)), initial-scale=1">\
      <style>html,body{margin:0;padding:0;background:transparent}</style></head>\
      <body><div id="host"></div></body></html>
      """
    try await awaitCallback(timeout: timeout) {
      (done: @escaping @Sendable (Result<Void, Error>) -> Void) in
      self.loadHandler = done
      self.webView.loadHTMLString(html, baseURL: nil)
    }
  }

  private func finishLoading(_ result: Result<Void, Error>) {
    self.loaded = true
    let handler = self.loadHandler
    self.loadHandler = nil
    handler?(result)
  }

  nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    MainActor.assumeIsolated {
      self.finishLoading(.success(()))
    }
  }

  nonisolated func webView(_ webView: WKWebView,
                           didFail navigation: WKNavigation!,
                           withError error: Error) {
    MainActor.assumeIsolated {
      self.finishLoading(.failure(error))
    }
  }

  nonisolated func webView(_ webView: WKWebView,
                           didFailProvisionalNavigation navigation: WKNavigation!,
                           withError error: Error) {
    MainActor.assumeIsolated {
      self.finishLoading(.failure(error))
    }
  }

  /// Only the load of the page itself is allowed; the page can never navigate anywhere else.
  nonisolated func webView(_ webView: WKWebView,
                           decidePolicyFor navigationAction: WKNavigationAction,
                           decisionHandler:
                             @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
    MainActor.assumeIsolated {
      decisionHandler(self.loaded ? .cancel : .allow)
    }
  }

  nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    MainActor.assumeIsolated {
      self.isUsable = false
    }
  }

  /// The outcome of the JavaScript function that renders a diagram.
  private enum Outcome: Sendable {
    case layout(x: Double, y: Double, width: Double, height: Double)
    case failure(String)
  }

  /// Draws the first page of the PDF into a bitmap with `scale` pixels per point and encodes it
  /// as PNG. Returns the image data and the size of the page in points.
  private static func png(fromPDF data: Data, scale: CGFloat) -> (data: Data, size: CGSize)? {
    guard let provider = CGDataProvider(data: data as CFData),
          let document = CGPDFDocument(provider),
          let page = document.page(at: 1) else {
      return nil
    }
    let box = page.getBoxRect(.mediaBox)
    let width = Int((box.width * scale).rounded(.up))
    let height = Int((box.height * scale).rounded(.up))
    guard width > 0, height > 0, width <= 16384, height <= 16384,
          let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
      return nil
    }
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -box.origin.x, y: -box.origin.y)
    context.drawPDFPage(page)
    guard let image = context.makeImage() else {
      return nil
    }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output,
                                                             UTType.png.identifier as CFString,
                                                             1,
                                                             nil) else {
      return nil
    }
    // The resolution makes the size of the image in points explicit
    let properties: [CFString: Any] = [kCGImagePropertyDPIWidth: 72.0 * Double(scale),
                                       kCGImagePropertyDPIHeight: 72.0 * Double(scale)]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      return nil
    }
    return (output as Data, box.size)
  }

  /// Renders `source` and returns an image of the diagram.
  func render(source: String, config: MermaidConfig) async throws -> MermaidImage {
    self.counter += 1
    let id = "mkmmd\(self.counter)"
    var jsConfig: [String: Any] = ["theme": config.theme.rawValue]
    if !config.themeVariables.isEmpty {
      jsConfig["themeVariables"] = config.themeVariables
    }
    if let fontFamily = config.fontFamily {
      jsConfig["fontFamily"] = fontFamily
    }
    let timeout = config.timeout > 0 ? config.timeout : 15
    nonisolated(unsafe) let arguments: [String: Any] = [
      "id": id,
      "source": source,
      "config": jsConfig
    ]
    // Draw the diagram
    let outcome: Outcome = try await awaitCallback(timeout: timeout) { done in
      self.webView.callAsyncJavaScript("return await __mkRender(id, source, config)",
                                       arguments: arguments,
                                       in: nil,
                                       in: .page) { result in
        switch result {
          case .failure(let error):
            done(.failure(error))
          case .success(let value):
            guard let dict = value as? [String: Any] else {
              done(.failure(MermaidError.renderingFailed("unexpected result")))
              return
            }
            if let message = dict["error"] as? String {
              done(.success(.failure(message)))
            } else if let x = (dict["x"] as? NSNumber)?.doubleValue,
                      let y = (dict["y"] as? NSNumber)?.doubleValue,
                      let w = (dict["width"] as? NSNumber)?.doubleValue,
                      let h = (dict["height"] as? NSNumber)?.doubleValue {
              done(.success(.layout(x: x, y: y, width: w, height: h)))
            } else {
              done(.failure(MermaidError.renderingFailed("unexpected result")))
            }
        }
      }
    }
    guard case .layout(let x, let y, let width, let height) = outcome else {
      if case .failure(let message) = outcome {
        throw MermaidError.syntaxError(message)
      }
      throw MermaidError.renderingFailed("unexpected result")
    }
    guard width >= 1, height >= 1, width <= 16384, height <= 16384 else {
      throw MermaidError.renderingFailed("the diagram has an unsuitable size")
    }
    // Make the web view as high as the diagram, and let the layout settle
    self.webView.frame = CGRect(x: 0, y: 0, width: self.width, height: ceil(y + height) + 2)
    let _: Bool = try await awaitCallback(timeout: timeout) { done in
      self.webView.callAsyncJavaScript("return document.body.scrollHeight",
                                       arguments: [:],
                                       in: nil,
                                       in: .page) { _ in
        done(.success(true))
      }
    }
    // Create a PDF of the diagram
    let rect = CGRect(x: x.rounded(.down),
                      y: y.rounded(.down),
                      width: ceil(width + x - x.rounded(.down)),
                      height: ceil(height + y - y.rounded(.down)))
    let pdf: Data = try await awaitCallback(timeout: timeout) { done in
      let pdfConfiguration = WKPDFConfiguration()
      pdfConfiguration.rect = rect
      self.webView.createPDF(configuration: pdfConfiguration) { result in
        done(result)
      }
    }
    guard let png = Self.png(fromPDF: pdf, scale: config.renderKey.scale) else {
      throw MermaidError.renderingFailed("cannot create an image of the diagram")
    }
    return MermaidImage(pngData: png.data, size: png.size, scale: config.renderKey.scale)
  }
}

// MARK: - Helpers

/// Delivers exactly one result to a continuation, no matter whether it comes from a
/// completion handler, a timeout or the cancellation of the task.
private final class Once<T: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<T, Error>?
  private var early: Result<T, Error>?
  private var finished = false

  func install(_ continuation: CheckedContinuation<T, Error>) {
    self.lock.lock()
    if let result = self.early {
      self.early = nil
      self.lock.unlock()
      continuation.resume(with: result)
    } else {
      self.continuation = continuation
      self.lock.unlock()
    }
  }

  func finish(_ result: Result<T, Error>) {
    self.lock.lock()
    guard !self.finished else {
      self.lock.unlock()
      return
    }
    self.finished = true
    if let continuation = self.continuation {
      self.continuation = nil
      self.lock.unlock()
      continuation.resume(with: result)
    } else {
      self.early = result
      self.lock.unlock()
    }
  }
}

/// Calls `start`, which has to pass the outcome of an asynchronous operation to the callback it
/// receives, and waits for it. Fails with `MermaidError.timedOut` if that takes longer than
/// `timeout` seconds, and with `MermaidError.cancelled` if the task gets cancelled.
@MainActor
private func awaitCallback<T: Sendable>(
                timeout: TimeInterval,
                _ start: (@escaping @Sendable (Result<T, Error>) -> Void) -> Void) async throws
             -> T {
  let once = Once<T>()
  return try await withTaskCancellationHandler(operation: {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
      once.install(continuation)
      start { result in
        once.finish(result)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
        once.finish(.failure(MermaidError.timedOut))
      }
    }
  }, onCancel: {
    once.finish(.failure(MermaidError.cancelled))
  })
}

#endif
