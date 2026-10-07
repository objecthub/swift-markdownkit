#if os(macOS)

import XCTest
import AppKit
import WebKit
@testable import MarkdownKit

/// Probe for the image-loading restrictions. Skipped unless `MARKDOWNKIT_PROBES=1`.
final class Step2ProbeTests: XCTestCase {
  private typealias Options = [NSAttributedString.DocumentReadingOptionKey: Any]
  private var server: ProbeRecordingServer!
  private var dir: URL!      // allowed directory
  private var other: URL!    // directory outside
  private var png: Data!

  override func setUpWithError() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["MARKDOWNKIT_PROBES"] == "1", "probe")
    png = makeProbePNG()
    server = try ProbeRecordingServer(png: png)
    try server.start()
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("S2-\(UUID().uuidString)")
    dir = tmp.appendingPathComponent("allowed", isDirectory: true)
    other = tmp.appendingPathComponent("other", isDirectory: true)
    for d in [dir!, other!] { try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true) }
    try png.write(to: dir.appendingPathComponent("in.png"))
    try png.write(to: other.appendingPathComponent("out.png"))
    try Data("secret".utf8).write(to: other.appendingPathComponent("secret.txt"))
  }

  override func tearDownWithError() throws {
    server?.stop()
    if let dir { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
  }

  private func legacy(_ html: String, _ extra: Options = [:]) -> NSAttributedString? {
    var o: Options = [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue]
    o.merge(extra) { $1 }
    return try? NSAttributedString(data: Data(html.utf8), options: o, documentAttributes: nil)
  }

  private func async(_ html: String, _ o: Options = [:]) -> NSAttributedString? {
    let done = expectation(description: "load")
    var r: NSAttributedString?
    NSAttributedString.loadFromHTML(string: html, options: o) { s, _, _ in r = s; done.fulfill() }
    _ = XCTWaiter().wait(for: [done], timeout: 20)
    return r
  }

  private func att(_ a: NSAttributedString?) -> String {
    guard let a else { return "nil" }
    var n = 0, bytes: [Int] = [], sizes = Set<Int>()
    a.enumerateAttribute(.attachment, in: NSRange(location: 0, length: a.length)) { v, _, _ in
      if let t = v as? NSTextAttachment { n += 1; bytes.append(t.fileWrapper?.regularFileContents?.count ?? -1) }
    }
    a.enumerateAttribute(.font, in: NSRange(location: 0, length: a.length)) { v, _, _ in
      if let f = v as? NSFont { sizes.insert(Int(f.pointSize)) }
    }
    return "attachments=\(n) bytes=\(bytes) sizes=\(sizes.sorted()) string=\(a.string.debugDescription)"
  }

  private func page(_ body: String, head: String = "") -> String {
    "<html><head><meta charset=\"utf-8\"/>\(head)</head><body>\(body)</body></html>"
  }

  func testProbeRawFileEscape() {
    let outside = other.appendingPathComponent("out.png").absoluteString
    let secret = other.appendingPathComponent("secret.txt").absoluteString
    let rel = "../other/out.png"
    for (name, run) in [("legacy", { (h: String) in self.legacy(h) }), ("async", { (h: String) in self.async(h) })] {
      let html = page("<p>A<img src=\"\(outside)\"/>B<img src=\"\(secret)\"/>C</p>")
      print("S2PROBE a \(name) absolute-outside+txt:", att(run(html)))
      let base: Options = [.init(rawValue: "BaseURL"): dir!]
      let h2 = page("<p>A<img src=\"\(rel)\"/>B</p>")
      let r = name == "legacy" ? legacy(h2, base) : async(h2, base)
      print("S2PROBE a \(name) dotdot-with-base:", att(r))
    }
  }

  func testProbeCSP() {
    let remote = "http://127.0.0.1:\(server.port)/remote.png"
    let local = dir.appendingPathComponent("in.png").absoluteString
    let csp = "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; img-src file: data:; style-src 'unsafe-inline'\"/>"
    for withCSP in [false, true] {
      let head = withCSP ? csp : ""
      let before = server.requests.count
      let html = page("<p>R<img src=\"\(remote)\"/>L<img src=\"\(local)\"/>E</p><style>@import url(\"http://127.0.0.1:\(server.port)/x.css\");</style>", head: head)
      let a = async(html)
      Thread.sleep(forTimeInterval: 0.5)
      print("S2PROBE b async csp=\(withCSP):", att(a), "requests=\(server.requests.count - before) \(server.requests.suffix(server.requests.count - before))")
      let l = legacy(html)
      print("S2PROBE b legacy csp=\(withCSP):", att(l))
    }
  }

  func testProbeTextSizeMultiplier() {
    let html = page("<p style=\"font-size:12px\">Text</p><ul><li>one</li><li>two</li></ul>")
    let key = Options.Key(rawValue: "TextSizeMultiplier")
    print("S2PROBE d legacy x1:", att(legacy(html)))
    print("S2PROBE d legacy x2:", att(legacy(html, [key: 2.0])))
    print("S2PROBE d async x1:", att(async(html)))
    print("S2PROBE d async x2:", att(async(html, [key: 2.0])))
    let tk1 = Options.Key(rawValue: "TextKit1ListMarkerFormat")
    print("S2PROBE e legacy list default:", att(legacy(html)))
    print("S2PROBE e legacy list tk1 raw:", att(legacy(html, [tk1: true])))
    print("S2PROBE e async list tk1 raw:", att(async(html, [tk1: true])))
  }

  func testProbeReadAccessURL() {
    let outside = other.appendingPathComponent("out.png").absoluteString
    let inside = dir.appendingPathComponent("in.png").absoluteString
    let html = page("<p>I<img src=\"\(inside)\"/>O<img src=\"\(outside)\"/>E</p>")
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("S2html-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let file = tmp.appendingPathComponent("doc.html")
    try? Data(html.utf8).write(to: file)
    for (name, access) in [("allowed-dir", dir!), ("html-dir", tmp), ("parent-of-all", dir.deletingLastPathComponent())] {
      let done = expectation(description: name)
      var res: NSAttributedString?
      var err: Error?
      NSAttributedString.loadFromHTML(fileURL: file, options: [.readAccessURL: access]) { s, _, e in
        res = s; err = e; done.fulfill()
      }
      _ = XCTWaiter().wait(for: [done], timeout: 20)
      print("S2PROBE c readAccess=\(name):", att(res), "error=\(String(describing: err))")
    }
  }
}

#endif
