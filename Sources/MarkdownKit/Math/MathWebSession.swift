//
//  MathWebSession.swift
//  MarkdownKit
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

#if canImport(WebKit) && (os(macOS) || os(iOS))

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import WebKit

/// 
/// Renders formulas with a single web page, which is created on demand and released when it has
/// not been used for a while. The page loads KaTeX with its style sheet and fonts once, and
/// renders many formulas at a time.
/// 
@MainActor
final class MathWebSession {

  /// How the images of formulas get their transparency.
  enum Transparency: Sendable {
    
    /// The PDF of the page is transparent where nothing is drawn if the system supports it (macOS 14
    /// and later, and iOS); otherwise, the matte method is used.
    case automatic
    
    /// The formulas are drawn in black on a white page. As they are black, their alpha value is
    /// one minus the brightness of the pixel. This is needed for older systems; the tests use it
    /// to try the method on all systems.
    case matte
  }
  
  /// The most formulas that are rendered into the page at a time: the page grows with them.
  private static let chunkSize = 100

  private let katexFolder: URL
  private let idleTime: TimeInterval
  private let transparency: Transparency
  private var page: MathWebPage?
  private var busy = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private var idleGeneration = 0

  nonisolated init(katexFolder: URL, idleTime: TimeInterval, transparency: Transparency) {
    self.katexFolder = katexFolder
    self.idleTime = idleTime
    self.transparency = transparency
  }

  /// Renders the formulas, which have to be at most `MathWebSession.chunkSize` many at a time
  /// (the session splits longer lists) and fit the limits of `config`. The result has an entry for
  /// each formula, in the order of the formulas.
  func render(_ formulas: [MathFormula],
              fontSize: Float,
              config: MathConfig) async -> [Result<MathImage, MathError>] {
    var results: [Result<MathImage, MathError>] = []
    results.reserveCapacity(formulas.count)
    // Formulas which are too long are not rendered at all
    let maxLength = config.katex.maxLength
    var valid: [MathFormula] = []
    for formula in formulas where formula.tex.utf8.count <= maxLength {
      valid.append(formula)
    }
    guard !valid.isEmpty else {
      return formulas.map { _ in .failure(.tooLong(maxLength)) }
    }
    await self.acquire()
    var rendered: [Result<MathImage, MathError>] = []
    var index = 0
    while index < valid.count {
      let chunk = Array(valid[index..<min(index + MathWebSession.chunkSize, valid.count)])
      if Task.isCancelled {
        rendered.append(contentsOf: chunk.map { _ in .failure(.cancelled) })
        index += chunk.count
        continue
      }
      do {
        let page = try await self.page(timeout: config.timeout)
        rendered.append(contentsOf: try await page.render(chunk, fontSize: fontSize, config: config))
      } catch {
        // The page cannot be trusted any more
        self.page = nil
        let failure = (error as? MathError) ?? MathError.renderingFailed(error.localizedDescription)
        rendered.append(contentsOf: chunk.map { _ in .failure(failure) })
      }
      index += chunk.count
    }
    self.release()
    // Put the results of the formulas which were rendered at the places of the formulas
    var next = 0
    for formula in formulas {
      if formula.tex.utf8.count <= maxLength {
        results.append(rendered[next])
        next += 1
      } else {
        results.append(.failure(.tooLong(maxLength)))
      }
    }
    return results
  }

  private func page(timeout: TimeInterval) async throws -> MathWebPage {
    if let page = self.page, page.isUsable {
      return page
    }
    self.page = nil
    let page = try await MathWebPage.make(katexFolder: self.katexFolder,
                                          timeout: timeout > 0 ? max(timeout, 30) : 30,
                                          transparency: self.transparency)
    self.page = page
    return page
  }

  /// Waits until no other formulas are being rendered. The caller has to call `release()`.
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

  /// Releases the web page if it is not used any more after `idleTime` seconds.
  private func scheduleIdleRelease() {
    self.idleGeneration += 1
    if self.idleTime <= 0 {
      self.page = nil
      return
    }
    guard self.idleTime < 1_000_000_000 else {
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

/// A headless web view which has loaded KaTeX and its fonts.
@MainActor
private final class MathWebPage: NSObject, WKNavigationDelegate {

  /// The width of the page in points: a formula which is wider makes the page wider.
  private static let minWidth: CGFloat = 900

  /// The JavaScript that renders formulas into the page and measures them. KaTeX is not allowed
  /// to create links or images (`trust` is false), and the LaTeX is data: it never becomes part
  /// of a script. Each formula gets a probe (a box without size) on its baseline, which tells
  /// where the baseline is.
  static let glue = """
    var __boxes = [];
    function renderAll(items, fontSize, options) {
      document.body.style.fontSize = fontSize + 'px';
      var rowPad = Math.max(10, Math.round(fontSize * 0.8));
      var stack = document.getElementById('stack');
      stack.innerHTML = '';
      __boxes = [];
      var errors = [];
      for (var i = 0; i < items.length; i++) {
        var row = document.createElement('div');
        row.className = 'row';
        row.style.padding = rowPad + 'px 16px';
        var holder = document.createElement('span');
        var settings = Object.assign({}, options, {
          macros: Object.assign({}, options.macros),
          displayMode: items[i].display, throwOnError: true, output: 'html',
          strict: 'ignore', trust: false
        });
        try {
          katex.render(items[i].tex, holder, settings);
        } catch (e) {
          errors.push(String((e && e.message) || e));
          __boxes.push(null);
          continue;
        }
        errors.push(null);
        row.appendChild(holder);
        stack.appendChild(row);
        var bases = holder.querySelectorAll('.katex-base');
        var probe = document.createElement('span');
        probe.className = 'probe';
        (bases.length ? bases[bases.length - 1] : holder).appendChild(probe);
        __boxes.push({holder: holder, probe: probe});
      }
      return errors;
    }
    function measure() {
      // The extent of a formula is where KaTeX says it is: the struts have the height and depth
      // of the formula, and the bases (and what is moved out of them) its width. The box of the
      // element `.katex` is not suited: it is the area of the font, and in display mode as wide as
      // the page. (The classes of KaTeX 0.19 have the prefix `katex-`: `katex-base`, `katex-strut`
      // and `katex-tag`; earlier versions called them `base`, `strut` and `tag`.)
      var out = [];
      for (var i = 0; i < __boxes.length; i++) {
        var item = __boxes[i];
        if (!item) { out.push(null); continue; }
        var left = Infinity, right = -Infinity, top = Infinity, bottom = -Infinity;
        var bases = item.holder.querySelectorAll('.katex-base');
        for (var j = 0; j < bases.length; j++) {
          var b = bases[j].getBoundingClientRect();
          left = Math.min(left, b.left);
          right = Math.max(right, b.right);
        }
        // Parts of a formula are moved out of their box (limits of operators, negative space), so
        // the width is also that of everything in the formula which has a size
        var parts = item.holder.querySelectorAll('.katex-html *');
        for (var m = 0; m < parts.length; m++) {
          // The drawings of roots and braces are much larger than their (clipped) container
          if (parts[m].closest('.katex-tag') || parts[m].closest('svg')) { continue; }
          var q = parts[m].getBoundingClientRect();
          if (q.width > 0 && q.height > 0) {
            left = Math.min(left, q.left);
            right = Math.max(right, q.right);
          }
        }
        var struts = item.holder.querySelectorAll('.katex-strut');
        for (var k = 0; k < struts.length; k++) {
          var s = struts[k].getBoundingClientRect();
          top = Math.min(top, s.top);
          bottom = Math.max(bottom, s.bottom);
        }
        if (!(left < right && top < bottom)) {
          var r = item.holder.querySelector('.katex').getBoundingClientRect();
          left = r.left; right = r.right; top = r.top; bottom = r.bottom;
        }
        var p = item.probe.getBoundingClientRect();
        out.push([left + window.scrollX, top + window.scrollY, right - left, bottom - top,
                  p.bottom + window.scrollY]);
      }
      return {boxes: out,
              width: document.documentElement.scrollWidth,
              height: document.documentElement.scrollHeight};
    }
    async function settle() {
      // The fonts are loaded when the layout needs them: waiting for them before the layout
      // has been computed would not wait at all. A font that has just been loaded changes the
      // layout, and `fonts.ready` does not always cover that, so measure until the result is stable.
      var previous = JSON.stringify(measure());
      for (var i = 0; i < 20; i++) {
        await document.fonts.ready;
        await new Promise(function (resolve) { setTimeout(resolve, 10); });
        var current = JSON.stringify(measure());
        if (current === previous) { break; }
        previous = current;
      }
      return measure();
    }
    function loadFonts() {
      return Promise.all(Array.from(document.fonts).map(function (face) { return face.load(); }));
    }
    """

  /// The page: the style sheet of KaTeX with the fonts it needs inlined as data URLs (the page
  /// can neither load files nor anything from the network), and KaTeX.
  static func html(katexFolder: URL) throws -> String {
    guard var css = try? String(contentsOf: katexFolder.appendingPathComponent("katex.min.css"),
                                encoding: .utf8),
          let script = try? String(contentsOf: katexFolder.appendingPathComponent("katex.min.js"),
                                   encoding: .utf8) else {
      throw MathError.resourcesMissing
    }
    let pattern = try NSRegularExpression(
      pattern: #"src:url\(fonts/([^)]+)\.woff2\) format\("woff2"\),url\([^)]+\) format\("woff"\),url\([^)]+\) format\("truetype"\)"#)
    for match in pattern.matches(in: css, range: NSRange(css.startIndex..., in: css)).reversed() {
      let name = (css as NSString).substring(with: match.range(at: 1))
      guard let font = try? Data(contentsOf: katexFolder.appendingPathComponent("fonts/\(name).woff2")) else {
        throw MathError.resourcesMissing
      }
      css = (css as NSString).replacingCharacters(
              in: match.range,
              with: "src:url(data:font/woff2;base64,\(font.base64EncodedString())) format(\"woff2\")")
    }
    return """
      <!doctype html><html><head><meta charset="utf-8">\
      <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; \
      script-src 'unsafe-inline'; font-src data:">\
      <meta name="viewport" content="width=\(Int(MathWebPage.minWidth)), initial-scale=1">\
      <style>\(css)</style>\
      <style>html,body{margin:0;padding:0;background:transparent;color:#000}\
      .probe{display:inline-block;width:0;height:0;vertical-align:baseline}\
      .row{white-space:nowrap}</style></head>\
      <body><div id="stack"></div><script>\(script)</script><script>\(MathWebPage.glue)</script>\
      </body></html>
      """
  }

  private let webView: WKWebView
  private let transparency: MathWebSession.Transparency
  private var loadHandler: (@Sendable (Result<Void, Error>) -> Void)?
  private var navigationLocked = false

  /// False once something went wrong with the page, e.g. its web content process was terminated.
  private(set) var isUsable = true

  private init(webView: WKWebView, transparency: MathWebSession.Transparency) {
    self.webView = webView
    self.transparency = transparency
    super.init()
    webView.navigationDelegate = self
  }

  static func make(katexFolder: URL,
                   timeout: TimeInterval,
                   transparency: MathWebSession.Transparency) async throws -> MathWebPage {
    let html = try MathWebPage.html(katexFolder: katexFolder)
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: MathWebPage.minWidth, height: 200),
                            configuration: configuration)
    // On iOS, the web view is transparent. A web view on macOS draws a white background, which
    // the PDF does not contain on macOS 14 and later (see `pdf(of:)`).
    #if !os(macOS)
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    #endif
    let page = MathWebPage(webView: webView, transparency: transparency)
    try await awaitCallback(timeout: timeout) {
      (done: @escaping @Sendable (Result<Void, Error>) -> Void) in
      page.loadHandler = done
      webView.loadHTMLString(html, baseURL: nil)
    }
    page.navigationLocked = true
    // Load the fonts now, so that the first formulas do not wait for them (and do not change
    // their layout while they are measured)
    _ = try await page.evaluate("await loadFonts(); return '';", [:], timeout: timeout)
    return page
  }

  // MARK: Navigation

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    self.loadHandler?(.success(()))
    self.loadHandler = nil
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    self.loadHandler?(.failure(error))
    self.loadHandler = nil
  }

  func webView(_ webView: WKWebView,
               didFailProvisionalNavigation navigation: WKNavigation!,
               withError error: Error) {
    self.loadHandler?(.failure(error))
    self.loadHandler = nil
  }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    self.isUsable = false
  }

  func webView(_ webView: WKWebView,
               decidePolicyFor navigationAction: WKNavigationAction,
               decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
    // The page is loaded once and never navigates anywhere
    decisionHandler(self.navigationLocked ? .cancel : .allow)
  }

  // MARK: Rendering

  /// Renders the formulas into the page, waits for the fonts, and captures each formula as an
  /// image.
  func render(_ formulas: [MathFormula],
              fontSize: Float,
              config: MathConfig) async throws -> [Result<MathImage, MathError>] {
    let timeout = config.timeout > 0 ? config.timeout : 1_000_000
    let items: [[String : Any]] = formulas.map { ["tex": $0.tex, "display": $0.display] }
    var options: [String : Any] = ["macros": config.katex.macros,
                                   "maxExpand": config.katex.maxExpand]
    if let maxSize = config.katex.maxSize {
      options["maxSize"] = maxSize
    }
    if let minRuleThickness = config.katex.minRuleThickness {
      options["minRuleThickness"] = minRuleThickness
    }
    // Render, lay out, wait for the fonts, measure
    let json = try await self.evaluate(
      "var errors = renderAll(items, fontSize, options); var m = await settle(); " +
      "return JSON.stringify({errors: errors, boxes: m.boxes, width: m.width, height: m.height});",
      ["items": items, "fontSize": Double(fontSize), "options": options],
      timeout: timeout)
    guard let data = json.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String : Any],
          let errors = root["errors"] as? [Any],
          let boxes = root["boxes"] as? [Any],
          errors.count == formulas.count, boxes.count == formulas.count,
          let width = (root["width"] as? NSNumber)?.doubleValue,
          let height = (root["height"] as? NSNumber)?.doubleValue else {
      throw MathError.renderingFailed("unexpected result of the page")
    }
    // The page has to be as large as the formulas, otherwise they cannot be captured
    self.webView.frame.size = CGSize(width: max(MathWebPage.minWidth, ceil(width)),
                                     height: max(1, ceil(height)))
    _ = try await self.evaluate("return '';", [:], timeout: timeout)
    let scale = max(config.scale, 1)
    let margin = CGFloat(fontSize)
    let vertical = (0.1 * margin).rounded(.up), horizontal = max(2, (0.12 * margin).rounded(.up))
    var results: [Result<MathImage, MathError>] = []
    for i in 0..<formulas.count {
      if let message = errors[i] as? String {
        results.append(.failure(.syntaxError(message)))
        continue
      }
      guard let box = boxes[i] as? [Double], box.count == 5 else {
        results.append(.failure(.renderingFailed("a formula was not measured")))
        continue
      }
      // The area of the formula plus a margin for the ink that is outside of its box (italic
      // overhang, large operators), aligned to whole points so that the image is sharp
      let left = (box[0] - Double(horizontal)).rounded(.down)
      let top = (box[1] - Double(vertical)).rounded(.down)
      let right = (box[0] + box[2] + Double(horizontal)).rounded(.up)
      let bottom = (box[1] + box[3] + Double(vertical)).rounded(.up)
      let rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
      let pdf = try await self.pdf(of: rect, timeout: timeout)
      guard let png = MathWebPage.maskPNG(fromPDF: pdf, size: rect.size, scale: scale,
                                          matte: self.usesMatte) else {
        results.append(.failure(.renderingFailed("the image of a formula could not be created")))
        continue
      }
      results.append(.success(MathImage(pngData: png,
                                        size: rect.size,
                                        depth: CGFloat(bottom - box[4]),
                                        scale: scale)))
    }
    return results
  }

  /// True if the images get their transparency from the brightness of the pixels.
  private var usesMatte: Bool {
    if self.transparency == .matte {
      return true
    }
    #if os(macOS)
    if #available(macOS 14.0, *) {
      return false
    }
    return true
    #else
    return false
    #endif
  }

  private func evaluate(_ body: String, _ arguments: [String : Any], timeout: TimeInterval) async throws
                -> String {
    return try await awaitCallback(timeout: timeout) { (done: @escaping @Sendable (Result<String, Error>) -> Void) in
      self.webView.callAsyncJavaScript(body, arguments: arguments, in: nil, in: .page) { result in
        switch result {
          case .success(let value):
            done(.success(value as? String ?? ""))
          case .failure(let error):
            done(.failure(MathError.renderingFailed(error.localizedDescription)))
        }
      }
    }
  }

  /// Creates a PDF of the area `rect` of the page.
  private func pdf(of rect: CGRect, timeout: TimeInterval) async throws -> Data {
    return try await awaitCallback(timeout: timeout) { (done: @escaping @Sendable (Result<Data, Error>) -> Void) in
      let configuration = WKPDFConfiguration()
      configuration.rect = rect
      #if os(macOS)
      // The web view of macOS draws a white background, which the PDF does not contain if it is
      // allowed to be transparent.
      if !self.usesMatte, #available(macOS 14.0, *) {
        configuration.allowTransparentBackground = true
      }
      #endif
      self.webView.createPDF(configuration: configuration) { result in
        done(result)
      }
    }
  }

  /// Draws the first page of the PDF into a bitmap with `scale` pixels per point and encodes it
  /// as PNG: the formula in black on a transparent background. With `matte`, the PDF has a
  /// white background, and the alpha value of a pixel is one minus its brightness.
  nonisolated static func maskPNG(fromPDF data: Data, size: CGSize, scale: CGFloat, matte: Bool) -> Data? {
    guard let provider = CGDataProvider(data: data as CFData),
          let document = CGPDFDocument(provider),
          let page = document.page(at: 1) else {
      return nil
    }
    let box = page.getBoxRect(.mediaBox)
    let width = max(1, Int((size.width * scale).rounded())), height = max(1, Int((size.height * scale).rounded()))
    guard box.width > 0, box.height > 0,
          let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
      return nil
    }
    if matte {
      context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
    context.scaleBy(x: CGFloat(width) / box.width, y: CGFloat(height) / box.height)
    context.translateBy(x: -box.minX, y: -box.minY)
    context.drawPDFPage(page)
    if matte, let pixels = context.data?.bindMemory(to: UInt8.self,
                                                    capacity: context.bytesPerRow * height) {
      for y in 0..<height {
        var i = y * context.bytesPerRow
        for _ in 0..<width {
          let brightness = (Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])) / 3
          pixels[i] = 0
          pixels[i + 1] = 0
          pixels[i + 2] = 0
          pixels[i + 3] = UInt8(255 - brightness)
          i += 4
        }
      }
    }
    guard let image = context.makeImage() else {
      return nil
    }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
      return nil
    }
    // The resolution makes the size of the image in points explicit
    let properties: [CFString : Any] = [kCGImagePropertyDPIWidth: 72.0 * Double(scale),
                                        kCGImagePropertyDPIHeight: 72.0 * Double(scale)]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      return nil
    }
    return output as Data
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
/// receives, and waits for it. Fails with `MathError.timedOut` if that takes longer than
/// `timeout` seconds, and with `MathError.cancelled` if the task gets cancelled.
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
        once.finish(.failure(MathError.timedOut))
      }
    }
  }, onCancel: {
    once.finish(.failure(MathError.cancelled))
  })
}

#endif
