//
//  SecurityTests.swift
//  MarkdownKitTests
//
//  Created on 06/10/2026.
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
@testable import MarkdownKit

/// Tests that untrusted Markdown cannot inject markup or control sequences into generated output.
class SecurityTests: XCTestCase {

  private func html(_ str: String, safeMode: Bool = false) -> String {
    return HtmlGenerator(safeMode: safeMode).generate(doc: MarkdownParser.standard.parse(str))
                                            .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func text(_ str: String) -> String {
    return StringGenerator.standard.generate(doc: MarkdownParser.standard.parse(str))
  }

  private func ansi(_ str: String) -> String {
    return TerminalGenerator.standard.generate(doc: MarkdownParser.standard.parse(str)).description
  }

  // MARK: Attribute escaping (always on)

  func testLinkDestinationIsEscaped() {
    XCTAssertEqual(html("[a](x\"onmouseover=\"alert(1))"),
                   "<p><a href=\"x&quot;onmouseover=&quot;alert(1)\">a</a></p>")
    XCTAssertEqual(html("[a](/u?x=1&y=2)"), "<p><a href=\"/u?x=1&amp;y=2\">a</a></p>")
  }

  func testLinkTitleIsEscaped() {
    XCTAssertEqual(html("[a](/x \"t\\\" onfocus=\\\"alert(1)\")"),
                   "<p><a href=\"/x\" title=\"t&quot; onfocus=&quot;alert(1)\">a</a></p>")
  }

  func testImageAttributesAreEscaped() {
    XCTAssertEqual(html("![x\" onerror=\"alert(1)](a.png)"),
                   "<p><img src=\"a.png\" alt=\"x&quot; onerror=&quot;alert(1)\"/></p>")
    XCTAssertEqual(html("![a](b\"onerror=\"alert(1))"),
                   "<p><img src=\"b&quot;onerror=&quot;alert(1)\" alt=\"a\"/></p>")
  }

  func testAutolinkIsEscaped() {
    XCTAssertEqual(html("<http://a\"onmouseover=\"x>"),
                   "<p><a href=\"http://a&quot;onmouseover=&quot;x\">" +
                   "http://a&quot;onmouseover=&quot;x</a></p>")
    XCTAssertEqual(html("<http://a?b=1&c=2>"),
                   "<p><a href=\"http://a?b=1&amp;c=2\">http://a?b=1&amp;c=2</a></p>")
  }

  func testCodeLanguageIsEscaped() {
    // The first word of the info string is the language, whatever characters it contains;
    // it is escaped, so it cannot break out of the attribute.
    XCTAssertEqual(html("```x\" onmouseover=\"alert(1)\ncode\n```"),
                   "<pre><code class=\"language-x&quot;\">code\n</code></pre>")
    XCTAssertEqual(html("```swift extra words\ncode\n```"),
                   "<pre><code class=\"language-swift\">code\n</code></pre>")
    XCTAssertEqual(html("```c++\ncode\n```"), "<pre><code class=\"language-c++\">code\n</code></pre>")
    XCTAssertEqual(html("```\"'<>\ncode\n```"),
                   "<pre><code class=\"language-&quot;&#39;&lt;&gt;\">code\n</code></pre>")
    XCTAssertEqual(html("```&quot;&gt;&lt;script&gt;alert(1)\ncode\n```"),
                   "<pre><code class=\"language-&quot;&gt;&lt;script&gt;alert(1)\">code\n</code></pre>")
    XCTAssertEqual(html("```a\\\"b\ncode\n```"),
                   "<pre><code class=\"language-a&quot;b\">code\n</code></pre>")
    // No language
    XCTAssertEqual(html("```\ncode\n```"), "<pre><code>code\n</code></pre>")
    XCTAssertEqual(html("```&#32;\ncode\n```"), "<pre><code>code\n</code></pre>")
  }

  func testCodeLanguageCannotInjectAttributesOrTags() {
    let attack = ["x\" onmouseover=\"alert(1)", "x'onmouseover='alert(1)", "\"><script>alert(1)</script>",
                  "&quot;&gt;&lt;img src=x onerror=alert(1)&gt;", "x\u{0301}\"onmouseover=\"1",
                  "\\\"onmouseover=\\\"1", "&#34;onmouseover=&#34;1"]
    let pattern = try! NSRegularExpression(pattern: "^<pre><code class=\"language-([^\"<>]*)\">code\n</code></pre>$")
    for info in attack {
      let output = html("```\(info)\ncode\n```")
      XCTAssertNotNil(pattern.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
                      "\(info.debugDescription): \(output)")
    }
  }

  func testEntityObfuscatedSchemeIsStillCaughtInSafeMode() {
    XCTAssertEqual(html("[a](&#106;avascript:alert(1))", safeMode: true),
                   "<p><a href=\"\">a</a></p>")
  }

  // MARK: Safe mode

  func testRawHtmlIsOmittedInSafeMode() {
    XCTAssertEqual(html("<script>alert(1)</script>", safeMode: true),
                   "<!-- raw HTML omitted -->")
    XCTAssertEqual(html("a <img src=x onerror=alert(1)> b", safeMode: true),
                   "<p>a <!-- raw HTML omitted --> b</p>")
    // Not enabled by default
    XCTAssertEqual(html("a <b>c</b>"), "<p>a <b>c</b></p>")
  }

  func testUnsafeUrlsAreBlockedInSafeMode() {
    for url in ["javascript:alert(1)", "JaVaScRiPt:alert(1)", " javascript:alert(1)",
                "java\tscript:alert(1)", "vbscript:x", "data:text/html;base64,AAAA", "file:///etc"] {
      XCTAssertEqual(html("[a](<\(url)>)", safeMode: true), "<p><a href=\"\">a</a></p>", url)
    }
    XCTAssertEqual(html("<javascript:alert(1)>", safeMode: true),
                   "<p><a href=\"\">javascript:alert(1)</a></p>")
    XCTAssertEqual(html("![a](data:text/html;base64,AAAA)", safeMode: true),
                   "<p><img src=\"\" alt=\"a\"/></p>")
  }

  func testSafeUrlsAreKeptInSafeMode() {
    XCTAssertEqual(html("[a](https://example.com/x?y=1#z)", safeMode: true),
                   "<p><a href=\"https://example.com/x?y=1#z\">a</a></p>")
    XCTAssertEqual(html("[a](../rel/path:colon)", safeMode: true),
                   "<p><a href=\"../rel/path:colon\">a</a></p>")
    XCTAssertEqual(html("[a](mailto:me@example.com)", safeMode: true),
                   "<p><a href=\"mailto:me@example.com\">a</a></p>")
    XCTAssertEqual(html("![a](data:image/png;base64,AAAA)", safeMode: true),
                   "<p><img src=\"data:image/png;base64,AAAA\" alt=\"a\"/></p>")
    for type in ["png", "gif", "jpeg", "webp", "tiff", "bmp", "x-icon", "vnd.microsoft.icon",
                 "heic", "heif"] {
      XCTAssertEqual(html("![a](data:image/\(type);base64,AAAA)", safeMode: true),
                     "<p><img src=\"data:image/\(type);base64,AAAA\" alt=\"a\"/></p>", type)
    }
    for type in ["svg+xml", "html", "x-unknown"] {
      XCTAssertEqual(html("![a](data:image/\(type);base64,AAAA)", safeMode: true),
                     "<p><img src=\"\" alt=\"a\"/></p>", type)
    }
  }

  // MARK: Combining characters

  func testEscapingHandlesSpecialCharactersFollowedByCombiningMarks() {
    // A combining mark forms a single `Character` together with the preceding character
    for ch in ["\"", "&", "'", "<", ">"] {
      let escaped = (ch + "\u{301}").encodingPredefinedXmlEntities()
      XCTAssertFalse(escaped.unicodeScalars.contains(where: { "\"&'<>".unicodeScalars.contains($0) && $0 != "&" }),
                     "\(ch) not escaped: \(escaped.debugDescription)")
      XCTAssertEqual(escaped.unicodeScalars.last, "\u{301}", escaped.debugDescription)
    }
    XCTAssertEqual("\"\u{301}<\u{301}>\u{301}&\u{301}'\u{301}".encodingPredefinedXmlEntities(),
                   "&quot;\u{301}&lt;\u{301}&gt;\u{301}&amp;\u{301}&#39;\u{301}")
  }

  func testAttributeValuesCannotBreakOutUsingCombiningMarks() {
    let out = html("[a](/x\"\u{301}onmouseover=alert(1))")
    XCTAssertFalse(out.contains("\"\u{301}"), out.debugDescription)
    XCTAssertEqual(out, "<p><a href=\"/x&quot;\u{301}onmouseover=alert(1)\">a</a></p>")
    let img = html("![x\"\u{301} onerror=alert(1)](a.png)")
    XCTAssertFalse(img.contains("\"\u{301}"), img.debugDescription)
  }

  func testSafeModeBlocksSchemesFollowedByCombiningMarks() {
    for url in ["javascript:\u{301}alert(1)", "JAVASCRIPT:\u{301}x", "data:\u{301}text/html,x",
                "vbscript:\u{301}x"] {
      XCTAssertEqual(html("[a](<\(url)>)", safeMode: true), "<p><a href=\"\">a</a></p>",
                     url.debugDescription)
    }
  }

  // MARK: Attributed string pipeline

  #if os(macOS) || os(iOS) || os(tvOS)
  private func attributedHtml(_ str: String, os26: Bool) -> String {
    let outer = AttributedStringGenerator.standard
    let doc = MarkdownParser.standard.parse(str)
    let gen: HtmlGenerator = os26 ? AttributedStringGenerator.OS26HtmlGenerator(outer: outer)
                                  : AttributedStringGenerator.InternalHtmlGenerator(outer: outer)
    return gen.generate(doc: doc)
  }

  func testCodeIsEscapedInAttributedStringHtml() {
    for os26 in [false, true] {
      let evil = "<img src=\"http://attacker/beacon.png\">"
      // unlabeled fence (ignored language), unknown language, and indented code
      for input in ["```\n\(evil)\n```", "```nosuchlanguage\n\(evil)\n```", "    \(evil)"] {
        let out = attributedHtml(input, os26: os26)
        XCTAssertFalse(out.contains("<img"), "os26=\(os26): \(input)")
        XCTAssertTrue(out.contains("&lt;"), "os26=\(os26): \(input)")
      }
      XCTAssertFalse(attributedHtml("```x\" onmouseover=\"alert(1)\ncode\n```", os26: os26)
                       .contains("onmouseover"), "os26=\(os26)")
    }
  }

  /// Markup inside code blocks has to be displayed verbatim in the final attributed string. It
  /// must neither be interpreted by the HTML importer (e.g. as an image) nor get lost.
  func testCodeIsDisplayedVerbatimInAttributedString() {
    let evil = "<img src=\"http://attacker/beacon.png\">"
    let inputs = ["```\n\(evil)\n```",                     // ignored language
                  "```nosuchlanguage\n\(evil)\n```",       // unknown language
                  "```html\n\(evil)\n```",                 // highlighted
                  "    \(evil)"]                            // indented
    for input in inputs {
      guard let astr = AttributedStringGenerator.standard
                         .generate(doc: MarkdownParser.standard.parse(input)) else {
        XCTFail("no attributed string for \(input)")
        continue
      }
      XCTAssertTrue(astr.string.contains(evil), "markup not shown verbatim: \(input)\n\(astr.string)")
      var attachments = 0
      astr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: astr.length)) { value, _, _ in
        if value != nil {
          attachments += 1
        }
      }
      XCTAssertEqual(attachments, 0, "image attachment created for \(input)")
    }
  }

  func testImageAttributesAreEscapedInAttributedStringHtml() {
    for os26 in [false, true] {
      let out = attributedHtml("![x\" onerror=\"alert(1)](a\"b.png \"t\\\" onfocus=\\\"x\")", os26: os26)
      XCTAssertFalse(out.contains("onerror=\""), "os26=\(os26): \(out)")
      XCTAssertFalse(out.contains("onfocus=\""), "os26=\(os26): \(out)")
    }
  }
  #endif

  // MARK: Control characters

  func testControlCharactersAreReplaced() {
    XCTAssertEqual("a\u{1B}[2Jb\u{7}c\u{9B}d\u{202E}e\tf\ng".sanitizingControlCharacters(),
                   "a\u{FFFD}[2Jb\u{FFFD}c\u{FFFD}d\u{FFFD}e\tf\ng")
    XCTAssertEqual("plain text ünïcode 日本語".sanitizingControlCharacters(),
                   "plain text ünïcode 日本語")
  }

  func testNumericEntitiesCannotProduceControlCharacters() {
    XCTAssertEqual(text("a &#27;]0;pwned&#7; b"), "a \u{FFFD}]0;pwned\u{FFFD} b")
    XCTAssertEqual(text("&#x1b;[2J"), "\u{FFFD}[2J")
    XCTAssertEqual(text("a &#0; b"), "a \u{FFFD} b")
  }

  func testPlainTextOutputIsSanitized() {
    XCTAssertFalse(text("hello \u{1B}[31mred").unicodeScalars.contains("\u{1B}"))
    XCTAssertFalse(text("```\ncode \u{1B}[31m\n```").unicodeScalars.contains("\u{1B}"))
    XCTAssertFalse(text("[link](http://a\u{1B}b)").unicodeScalars.contains("\u{1B}"))
  }

  func testTerminalOutputContainsNoInjectedEscapes() {
    // The generator emits its own SGR sequences (ESC [ ... m), but nothing else
    for input in ["hello \u{1B}]0;title\u{7}",
                  "&#27;]52;c;AAAA&#7;",
                  "```\n\u{1B}[2J\n```",
                  "```\u{1B}]0;x\u{7}\ncode\n```",
                  "[a](http://x\u{1B}]8;;evil\u{7})",
                  "![a\u{1B}[2J](http://x)",
                  "<http://a\u{1B}[2J>",
                  "    \u{1B}[2J"] {
      let out = ansi(input)
      XCTAssertFalse(out.contains("\u{1B}]"), input)
      XCTAssertFalse(out.contains("\u{1B}[2J"), input)
      XCTAssertFalse(out.unicodeScalars.contains("\u{7}"), input)
      XCTAssertFalse(out.unicodeScalars.contains("\u{9B}"), input)
    }
  }

  // MARK: Numeric character references

  func testNumericReferencesFollowCommonMark() {
    XCTAssertEqual(NamedCharacters.decode(entity: "&#35;"), "#")
    XCTAssertEqual(NamedCharacters.decode(entity: "&#x22;"), "\"")
    XCTAssertEqual(NamedCharacters.decode(entity: "&#0;"), "\u{FFFD}")
    XCTAssertEqual(NamedCharacters.decode(entity: "&#xD800;"), "\u{FFFD}")
    XCTAssertEqual(NamedCharacters.decode(entity: "&#1234567;"), "\u{FFFD}")
    XCTAssertNil(NamedCharacters.decode(entity: "&#+65;"))
    XCTAssertNil(NamedCharacters.decode(entity: "&#;"))
    XCTAssertNil(NamedCharacters.decode(entity: "&#x;"))
    XCTAssertNil(NamedCharacters.decode(entity: "&#12345678;"))
  }
}
