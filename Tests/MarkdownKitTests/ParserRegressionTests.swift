//
//  ParserRegressionTests.swift
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

import XCTest
import CommandLineKit
@testable import MarkdownKit

/// Regression tests for parser bugs. Expected results follow CommonMark and GFM.
class ParserRegressionTests: XCTestCase {

  private func html(_ str: String) -> String {
    return HtmlGenerator().generate(doc: MarkdownParser.standard.parse(str))
                          .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func extHtml(_ str: String) -> String {
    return HtmlGenerator().generate(doc: ExtendedMarkdownParser.standard.parse(str))
                          .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: Failed table lookahead must not duplicate content

  func testPipeLineAfterParagraphIsNotDuplicated() {
    XCTAssertEqual(extHtml("foo\na | b\nbar"), "<p>foo\na | b\nbar</p>")
    XCTAssertEqual(extHtml("run this\ncmd | grep x\n"), "<p>run this\ncmd | grep x</p>")
  }

  func testPipeLineAfterParagraphInContainersIsNotDuplicated() {
    XCTAssertEqual(extHtml("> foo\na | b\nbar"),
                   "<blockquote>\n<p>foo\na | b\nbar</p>\n</blockquote>")
    XCTAssertEqual(extHtml("- foo\n  a | b\n  bar"), "<ul>\n<li>foo\na | b\nbar</li>\n</ul>")
    XCTAssertEqual(extHtml("> > foo\n> a | b\nbar"),
                   "<blockquote>\n<blockquote>\n<p>foo\na | b\nbar</p>\n</blockquote>\n" +
                   "</blockquote>")
  }

  func testTableStillInterruptsParagraph() {
    XCTAssertEqual(extHtml("foo\na | b\n- | -\n1 | 2"),
                   "<p>foo</p>\n<table><thead><tr>\n<th>a</th><th>b</th>\n</tr></thead><tbody>\n" +
                   "<tr><td>1</td><td>2</td></tr>\n</tbody></table>")
  }

  // MARK: Nested links

  func testLinksCannotContainLinks() {
    XCTAssertEqual(html("[foo [bar](/uri)](/uri)"),
                   "<p>[foo <a href=\"/uri\">bar</a>](/uri)</p>")
    XCTAssertEqual(html("[foo *[bar [baz](/uri)](/uri)*](/uri)"),
                   "<p>[foo <em>[bar <a href=\"/uri\">baz</a>](/uri)</em>](/uri)</p>")
    XCTAssertEqual(html("[a](b) [c [d](e)](f) [g](h)"),
                   "<p><a href=\"b\">a</a> [c <a href=\"e\">d</a>](f) <a href=\"h\">g</a></p>")
  }

  func testDeeplyNestedLinksAreProcessedInReasonableTime() {
    // Used to take time exponential in the nesting depth (about 45s for 24 levels).
    let n = 24
    let input = String(repeating: "[", count: n) + "a" + String(repeating: "](b)", count: n)
    let expected = "<p>" + String(repeating: "[", count: n - 1) + "<a href=\"b\">a</a>" +
                   String(repeating: "](b)", count: n - 1) + "</p>"
    XCTAssertEqual(html(input), expected)
  }

  // MARK: Backslash escapes

  func testBackslashBeforeNonPunctuationIsLiteral() {
    XCTAssertEqual(html("C:\\Users\\foo"), "<p>C:\\Users\\foo</p>")
    XCTAssertEqual(html("\\\tfoo \\A\\a\\ \\3\\φ\\«"),
                   "<p>\\\tfoo \\A\\a\\ \\3\\φ\\«</p>")
    XCTAssertEqual(html("a \\b c"), "<p>a \\b c</p>")
  }

  func testBackslashAtEndOfParagraphIsLiteral() {
    XCTAssertEqual(html("foo\\"), "<p>foo\\</p>")
    XCTAssertEqual(html("# foo\\"), "<h1>foo\\</h1>")
    XCTAssertEqual(html("*foo\\\\*"), "<p><em>foo\\</em></p>")
    XCTAssertEqual(html("*foo\\*"), "<p>*foo*</p>")
  }

  func testBackslashBeforePunctuationIsRemoved() {
    XCTAssertEqual(html("\\!\\\"\\#\\$\\%\\&\\'\\(\\)\\*\\+\\,\\-\\.\\/\\:\\;\\<\\=\\>\\?\\@" +
                        "\\[\\\\\\]\\^\\_\\`\\{\\|\\}\\~"),
                   "<p>!&quot;#$%&amp;&#39;()*+,-./:;&lt;=&gt;?@[\\]^_`{|}~</p>")
    XCTAssertEqual(html("a\\\\b"), "<p>a\\b</p>")
    XCTAssertEqual(html("\\*not emphasized*"), "<p>*not emphasized*</p>")
    XCTAssertEqual(html("\\`not code\\`"), "<p>`not code`</p>")
    XCTAssertEqual(html("[a](/u \"a\\\"b\")"), "<p><a href=\"/u\" title=\"a&quot;b\">a</a></p>")
  }

  func testEscapedBackslashBeforeLineEndIsNoHardBreak() {
    XCTAssertEqual(html("foo\\\\\nbar"), "<p>foo\\\nbar</p>")
    XCTAssertEqual(html("foo\\\\\\\nbar"), "<p>foo\\<br/>bar</p>")
    XCTAssertEqual(html("foo\\\nbar"), "<p>foo<br/>bar</p>")
  }

  func testEscapedAmpersandIsNotAnEntity() {
    XCTAssertEqual(html("\\&ouml; \\&#35; \\&copy;"), "<p>&amp;ouml; &amp;#35; &amp;copy;</p>")
    XCTAssertEqual(html("a \\& b"), "<p>a &amp; b</p>")
    XCTAssertEqual(html("&ouml;"), "<p>ö</p>")
  }

  // MARK: Link reference definitions

  func testReferenceLabelsAreNormalizedWithTitle() {
    XCTAssertEqual(html("[Foo]: /url \"t\"\n\n[foo] [FOO] [Foo]"),
                   "<p><a href=\"/url\" title=\"t\">foo</a> <a href=\"/url\" title=\"t\">FOO</a> " +
                   "<a href=\"/url\" title=\"t\">Foo</a></p>")
    XCTAssertEqual(html("[Foo   Bar]: /url \"t\"\n\n[foo bar] [FOO\n  BAR]"),
                   "<p><a href=\"/url\" title=\"t\">foo bar</a> <a href=\"/url\" title=\"t\">FOO\nBAR</a></p>")
    XCTAssertEqual(html("[Foo]: /url\n\n[foo] [FOO]"),
                   "<p><a href=\"/url\">foo</a> <a href=\"/url\">FOO</a></p>")
    XCTAssertEqual(html("[Foo]: /url \"t\"\n\n[x][FOO]"),
                   "<p><a href=\"/url\" title=\"t\">x</a></p>")
  }

  func testReferenceLabelsUseUnicodeCaseFolding() {
    XCTAssertEqual(html("[ẞ]: /url\n\n[SS]"), "<p><a href=\"/url\">SS</a></p>")
    XCTAssertEqual(html("[Äpfel]: /url\n\n[äPFEL]"), "<p><a href=\"/url\">äPFEL</a></p>")
  }

  func testFirstReferenceDefinitionWins() {
    XCTAssertEqual(html("[foo]: /url1\n[foo]: /url2\n\n[foo]"),
                   "<p><a href=\"/url1\">foo</a></p>")
    XCTAssertEqual(html("[foo]: /url1 \"a\"\n[FOO]: /url2 \"b\"\n\n[foo]"),
                   "<p><a href=\"/url1\" title=\"a\">foo</a></p>")
    XCTAssertEqual(html("[foo]: /url1\n\n> [foo]: /url2\n\n[foo]"),
                   "<blockquote>\n</blockquote>\n<p><a href=\"/url1\">foo</a></p>")
  }

  func testMultiLineReferenceTitle() {
    XCTAssertEqual(html("[foo]: /url 'line1\nline2'\n\n[foo]"),
                   "<p><a href=\"/url\" title=\"line1\nline2\">foo</a></p>")
  }

  func testFailedTitleDoesNotSwallowLines() {
    XCTAssertEqual(html("[foo]: /url\n\"title\nmore text\n\np"),
                   "<p>\"title\nmore text</p>\n<p>p</p>")
    XCTAssertEqual(html("[foo]: /url\n\"title\nmore text\n\n[foo]"),
                   "<p>\"title\nmore text</p>\n<p><a href=\"/url\">foo</a></p>")
    XCTAssertEqual(html("[foo]: /url\n\"title\" ok\n\n[foo]"),
                   "<p>\"title\" ok</p>\n<p><a href=\"/url\">foo</a></p>")
    XCTAssertEqual(html("[foo]: /url \"title\" ok"),
                   "<p>[foo]: /url \"title\" ok</p>")
    XCTAssertEqual(html("[foo]: /url\nbar\n\n[foo]"),
                   "<p>bar</p>\n<p><a href=\"/url\">foo</a></p>")
  }

  func testReferenceDefinitionsInDefinitionLists() {
    XCTAssertEqual(extHtml("Term\n: [foo]: /url\n\n[foo]"),
                   "<dl>\n<dt>Term</dt>\n<dd></dd>\n</dl>\n<p><a href=\"/url\">foo</a></p>")
  }

  func testReferenceLinksAtEndOfText() {
    XCTAssertEqual(html("[foo]: /url\n\n[foo]"), "<p><a href=\"/url\">foo</a></p>")
    XCTAssertEqual(html("[foo]: /url\n\nsee [foo]"), "<p>see <a href=\"/url\">foo</a></p>")
    XCTAssertEqual(html("[foo]: /url\n\n[foo][]"), "<p><a href=\"/url\">foo</a></p>")
    XCTAssertEqual(html("[foo]: /url\n\n[bar][foo]"), "<p><a href=\"/url\">bar</a></p>")
    XCTAssertEqual(html("[foo]: /url\n\n*[foo]*"), "<p><em><a href=\"/url\">foo</a></em></p>")
    XCTAssertEqual(html("[foo]: /url\n\n![foo]"), "<p><img src=\"/url\" alt=\"foo\"/></p>")
    XCTAssertEqual(html("[bar]"), "<p>[bar]</p>")
  }

  // MARK: Code blocks

  func testIndentedCodeKeepsBlankLinesInside() {
    XCTAssertEqual(html("    a\n\n    b"), "<pre><code>a\n\nb\n</code></pre>")
    XCTAssertEqual(html("    a\n\n\n    b"), "<pre><code>a\n\n\nb\n</code></pre>")
    XCTAssertEqual(html("    a\n    \n    b"), "<pre><code>a\n\nb\n</code></pre>")
    XCTAssertEqual(html("    a\n\n"), "<pre><code>a\n</code></pre>")
    XCTAssertEqual(html("    a\n\nb"), "<pre><code>a\n</code></pre>\n<p>b</p>")
  }

  func testFencedCodeEndsWithItsContainer() {
    XCTAssertEqual(html("> ```\n> a\n\nafter"),
                   "<blockquote>\n<pre><code>a\n</code></pre>\n</blockquote>\n<p>after</p>")
    XCTAssertEqual(html("> ```\n> a\nafter"),
                   "<blockquote>\n<pre><code>a\n</code></pre>\n</blockquote>\n<p>after</p>")
    XCTAssertEqual(html("- ```\n  a\nafter"),
                   "<ul>\n<li><pre><code>a\n</code></pre>\n</li>\n</ul>\n<p>after</p>")
    XCTAssertEqual(html("- ```\n  a\n  ```\n  b"),
                   "<ul>\n<li><pre><code>a\n</code></pre>\nb\n</li>\n</ul>")
  }

  func testFenceInListItemKeepsBlankLines() {
    XCTAssertEqual(html("- ```\n  a\n\n  b\n  ```"),
                   "<ul>\n<li><pre><code>a\n\nb\n</code></pre>\n</li>\n</ul>")
  }

  func testFenceClosingInOuterContainerDoesNotCloseInnerFence() {
    XCTAssertEqual(html("> ```\n> a\n```\nafter"),
                   "<blockquote>\n<pre><code>a\n</code></pre>\n</blockquote>\n" +
                   "<pre><code>after\n</code></pre>")
  }

  func testIndentedCodeEndsWithItsContainer() {
    XCTAssertEqual(html(">     code\n    more"),
                   "<blockquote>\n<pre><code>code\n</code></pre>\n</blockquote>\n" +
                   "<pre><code>more\n</code></pre>")
    XCTAssertEqual(html("- a\n\n      code\n\n  b"),
                   "<ul>\n<li><p>a</p>\n<pre><code>code\n</code></pre>\n<p>b</p>\n</li>\n</ul>")
  }

  // MARK: Lists

  func testOnlyOrderedListsStartingWithOneInterruptParagraphs() {
    XCTAssertEqual(html("Foo\n2. bar"), "<p>Foo\n2. bar</p>")
    XCTAssertEqual(html("The number\n14) is"), "<p>The number\n14) is</p>")
    XCTAssertEqual(html("Foo\n1. bar"), "<p>Foo</p>\n<ol start=\"1\">\n<li>bar</li>\n</ol>")
    XCTAssertEqual(html("Foo\n- bar"), "<p>Foo</p>\n<ul>\n<li>bar</li>\n</ul>")
  }

  func testEmptyListItemsDoNotInterruptParagraphs() {
    XCTAssertEqual(html("foo\n*"), "<p>foo\n*</p>")
    XCTAssertEqual(html("foo\n+ "), "<p>foo\n+</p>")
    XCTAssertEqual(html("foo\n1."), "<p>foo\n1.</p>")
  }

  func testSiblingListItemsAreNotRestricted() {
    XCTAssertEqual(html("1. a\n2. b\n3. c"),
                   "<ol start=\"1\">\n<li>a</li>\n<li>b</li>\n<li>c</li>\n</ol>")
    XCTAssertEqual(html("- a\n2. b"),
                   "<ul>\n<li>a</li>\n</ul>\n<ol start=\"2\">\n<li>b</li>\n</ol>")
    XCTAssertEqual(html("- a\n-\n- c"), "<ul>\n<li>a</li>\n<li></li>\n<li>c</li>\n</ul>")
    XCTAssertEqual(html("- a\n*\n- c"),
                   "<ul>\n<li>a</li>\n</ul>\n<ul>\n<li></li>\n</ul>\n<ul>\n<li>c</li>\n</ul>")
  }

  func testFiveOrMoreSpacesAfterMarkerStartIndentedCode() {
    XCTAssertEqual(html("-     code"), "<ul>\n<li><pre><code>code\n</code></pre>\n</li>\n</ul>")
    XCTAssertEqual(html("1.     code"), "<ol start=\"1\">\n<li><pre><code>code\n</code></pre>\n</li>\n</ol>")
    XCTAssertEqual(html("-    four"), "<ul>\n<li>four</li>\n</ul>")
    XCTAssertEqual(html("-     a\n      b"),
                   "<ul>\n<li><pre><code>a\nb\n</code></pre>\n</li>\n</ul>")
  }

  func testListItemsStartingWithBlankLine() {
    XCTAssertEqual(html("-\n  foo"), "<ul>\n<li>foo</li>\n</ul>")
    XCTAssertEqual(html("-   \n  foo"), "<ul>\n<li>foo</li>\n</ul>")
    XCTAssertEqual(html("-\n foo"), "<ul>\n<li></li>\n</ul>\n<p>foo</p>")
    XCTAssertEqual(html("-\n\n  foo"), "<ul>\n<li></li>\n</ul>\n<p>foo</p>")
    XCTAssertEqual(html("1.\n   foo"), "<ol start=\"1\">\n<li>foo</li>\n</ol>")
  }

  func testOrderedListNumbersHaveUpToNineDigits() {
    XCTAssertEqual(html("123456789. ok"), "<ol start=\"123456789\">\n<li>ok</li>\n</ol>")
    XCTAssertEqual(html("1234567890. not ok"), "<p>1234567890. not ok</p>")
  }

  func testTightnessOfListAfterChangingListType() {
    XCTAssertEqual(html("- a\n* b\n  * c"),
                   "<ul>\n<li>a</li>\n</ul>\n<ul>\n<li>b\n<ul>\n<li>c</li>\n</ul>\n</li>\n</ul>")
    XCTAssertEqual(html("- a\n+ b\n\n  c\n+ d"),
                   "<ul>\n<li>a</li>\n</ul>\n<ul>\n<li><p>b</p>\n<p>c</p>\n</li>\n<li><p>d</p>\n</li>\n</ul>")
  }

  // MARK: Links

  func testShortcutReferenceMustNotBeFollowedByLinkLabel() {
    XCTAssertEqual(html("[foo]: /url\n\n[foo][bar]"), "<p>[foo][bar]</p>")
    XCTAssertEqual(html("[baz]: /url\n\n[foo][bar][baz]"),
                   "<p>[foo]<a href=\"/url\">bar</a></p>")
    XCTAssertEqual(html("[baz]: /url1\n[bar]: /url2\n\n[foo][bar][baz]"),
                   "<p><a href=\"/url2\">foo</a><a href=\"/url1\">baz</a></p>")
    XCTAssertEqual(html("[foo]: /url\n\n[foo] [bar]"), "<p><a href=\"/url\">foo</a> [bar]</p>")
    XCTAssertEqual(html("[foo]: /url\n\n[foo][ unfinished"),
                   "<p><a href=\"/url\">foo</a>[ unfinished</p>")
  }

  func testLinkDestinationsResolveEscapes() {
    XCTAssertEqual(html("[link](foo\\)\\:)"), "<p><a href=\"foo):\">link</a></p>")
    XCTAssertEqual(html("[link](<foo\\>bar>)"), "<p><a href=\"foo&gt;bar\">link</a></p>")
    XCTAssertEqual(html("[link](/f\\&ouml;&ouml;)"), "<p><a href=\"/f&amp;ouml;ö\">link</a></p>")
    XCTAssertEqual(html("![img](/a\\_b.png)"), "<p><img src=\"/a_b.png\" alt=\"img\"/></p>")
    XCTAssertEqual(html("[link](/a\\b)"), "<p><a href=\"/a\\b\">link</a></p>")
  }

  func testLinkTitleNeedsWhitespaceBeforeIt() {
    XCTAssertEqual(html("[a](/u \"t\")"), "<p><a href=\"/u\" title=\"t\">a</a></p>")
    XCTAssertEqual(html("[a](<b>\"t\")"), "<p>[a](<b>\"t\")</p>")
    XCTAssertEqual(html("[a](</u>'t')"), "<p>[a](</u>'t')</p>")
  }

  // MARK: HTML blocks

  func testCdataAndDeclarationBlocks() {
    XCTAssertEqual(html("<![CDATA[\nfoo\n]]>\nbar"), "<![CDATA[\nfoo\n]]>\n<p>bar</p>")
    XCTAssertEqual(html("<!DOCTYPE html>\nfoo"), "<!DOCTYPE html>\n<p>foo</p>")
    XCTAssertEqual(html("<!doctype html>\nfoo"), "<!doctype html>\n<p>foo</p>")
    XCTAssertEqual(html("<!ELEMENT br EMPTY>\n\nfoo"), "<!ELEMENT br EMPTY>\n<p>foo</p>")
  }

  func testTextareaBlock() {
    XCTAssertEqual(html("<textarea>\n*a*\n\nb\n</textarea>\nafter"),
                   "<textarea>\n*a*\n\nb\n</textarea>\n<p>after</p>")
  }

  func testSearchTagIsBlockLevel() {
    XCTAssertEqual(html("<search>\n*a*\n</search>\n\nb"), "<search>\n*a*\n</search>\n<p>b</p>")
  }

  func testCompleteTagOnItsOwnLineStartsHtmlBlock() {
    XCTAssertEqual(html("<a href=\"foo\">\n*bar*\n</a>"), "<a href=\"foo\">\n*bar*\n</a>")
    XCTAssertEqual(html("<custom-tag>\nfoo\n\nbar"), "<custom-tag>\nfoo\n<p>bar</p>")
    XCTAssertEqual(html("</ins>\n*bar*"), "</ins>\n*bar*")
    XCTAssertEqual(html("  <Warning>   \n*bar*"), "<Warning>   \n*bar*")
  }

  func testCompleteTagBlockDoesNotApplyToInlineContent() {
    XCTAssertEqual(html("<del>*foo*</del>"), "<p><del><em>foo</em></del></p>")
    XCTAssertEqual(html("<a href=\"foo\">bar</a>"), "<p><a href=\"foo\">bar</a></p>")
  }

  func testCompleteTagBlockCannotInterruptParagraph() {
    XCTAssertEqual(html("Foo\n<a href=\"bar\">\nbaz"), "<p>Foo\n<a href=\"bar\">\nbaz</p>")
    XCTAssertEqual(html("Foo\n<div>\nbaz"), "<p>Foo</p>\n<div>\nbaz")
  }

  func testHtmlCommentKeepsBlankLinesInsideListItem() {
    let out = html("- <!--\n\n  x -->\n- b")
    XCTAssertTrue(out.hasPrefix("<ul>\n<li><!--\n\nx -->"), out)
    XCTAssertTrue(out.contains("<li>b</li>"), out)
  }

  // MARK: Code spans and inline HTML

  func testCodeSpansStripOneSpaceOnBothSides() {
    XCTAssertEqual(html("`` `foo` ``"), "<p><code>`foo`</code></p>")
    XCTAssertEqual(html("` `` `"), "<p><code>``</code></p>")
    XCTAssertEqual(html("`  ``  `"), "<p><code> `` </code></p>")
    XCTAssertEqual(html("` a`"), "<p><code> a</code></p>")
    XCTAssertEqual(html("` b `"), "<p><code>b</code></p>")
    XCTAssertEqual(html("` `\n`  `"), "<p><code> </code>\n<code>  </code></p>")
    XCTAssertEqual(html("`\nfoo\nbar\nbaz\n`"), "<p><code>foo bar baz</code></p>")
    XCTAssertEqual(html("`foo   bar\nbaz`"), "<p><code>foo   bar baz</code></p>")
    XCTAssertEqual(html("`foo`"), "<p><code>foo</code></p>")
  }

  func testInlineHtmlCommentsFollowCommonMark030() {
    XCTAssertEqual(html("a <!--> b"), "<p>a <!--> b</p>")
    XCTAssertEqual(html("a <!---> b"), "<p>a <!---> b</p>")
    XCTAssertEqual(html("a <!----> b"), "<p>a <!----> b</p>")
    XCTAssertEqual(html("a <!-- x -- y --> b"), "<p>a <!-- x -- y --> b</p>")
    XCTAssertEqual(html("a <!-- x- --> b"), "<p>a <!-- x- --> b</p>")
    XCTAssertEqual(html("a <!-- x -> b"), "<p>a &lt;!-- x -&gt; b</p>")
  }

  func testInlineCdataAndDeclarations() {
    XCTAssertEqual(html("a <![CDATA[x]]y]]> b"), "<p>a <![CDATA[x]]y]]> b</p>")
    XCTAssertEqual(html("a <![CDATA[>&<]]> b"), "<p>a <![CDATA[>&<]]> b</p>")
    XCTAssertEqual(html("a <!doctype html> b"), "<p>a <!doctype html> b</p>")
    XCTAssertEqual(html("a <!DOCTYPE html> b"), "<p>a <!DOCTYPE html> b</p>")
    XCTAssertEqual(html("a <! x> b"), "<p>a &lt;! x&gt; b</p>")
  }

  func testUnquotedAttributeValues() {
    XCTAssertEqual(html("a <b c=d> e"), "<p>a <b c=d> e</p>")
    XCTAssertEqual(html("a <b c=> e"), "<p>a &lt;b c=&gt; e</p>")
    XCTAssertEqual(html("a <b c==d> e"), "<p>a &lt;b c==d&gt; e</p>")
    XCTAssertEqual(html("a <b c=<d> e"), "<p>a &lt;b c=<d> e</p>")
    XCTAssertEqual(html("a <b c=\"d\" e='f'> g"), "<p>a <b c=\"d\" e='f'> g</p>")
  }

  // MARK: Tables

  private func table(header: [String], rows: [[String]]) -> String {
    var res = "<table><thead><tr>\n" + header.map { "<th>\($0)</th>" }.joined() +
              "\n</tr></thead><tbody>\n"
    for row in rows {
      res += "<tr>" + row.map { "<td>\($0)</td>" }.joined() + "</tr>\n"
    }
    return res + "</tbody></table>"
  }

  func testAlignmentCellNeedsADash() {
    XCTAssertEqual(extHtml("a | b\n--- | :"), "<p>a | b\n--- | :</p>")
    XCTAssertEqual(extHtml("a | b\n:- | -:"),
                   "<table><thead><tr>\n<th align=\"left\">a</th><th align=\"right\">b</th>\n" +
                   "</tr></thead><tbody>\n</tbody></table>")
  }

  func testRowEndingWithBackslashDoesNotSwallowLines() {
    XCTAssertEqual(extHtml("a | b\n- | -\n1 | 2\\\n\nafter"),
                   table(header: ["a", "b"], rows: [["1", "2\\"]]) + "\n<p>after</p>")
    XCTAssertEqual(extHtml("a | b\n- | -\n1 | 2\\"),
                   table(header: ["a", "b"], rows: [["1", "2\\"]]))
    XCTAssertEqual(extHtml("a | b\n- | -\n1 | 2\\\n# next"),
                   table(header: ["a", "b"], rows: [["1", "2\\"]]) + "\n<h1>next</h1>")
  }

  func testTableEndsAtOtherBlocks() {
    XCTAssertEqual(extHtml("a | b\n- | -\n1 | 2\n# heading\n3 | 4"),
                   table(header: ["a", "b"], rows: [["1", "2"]]) + "\n<h1>heading</h1>\n<p>3 | 4</p>")
    XCTAssertEqual(extHtml("a | b\n- | -\n1 | 2\n> quote | x"),
                   table(header: ["a", "b"], rows: [["1", "2"]]) +
                   "\n<blockquote>\n<p>quote | x</p>\n</blockquote>")
    XCTAssertEqual(extHtml("a | b\n- | -\n1 | 2\n```\ncode | x\n```"),
                   table(header: ["a", "b"], rows: [["1", "2"]]) +
                   "\n<pre><code>code | x\n</code></pre>")
    XCTAssertEqual(extHtml("a | b\n- | -\n1 | 2\n***\n3 | 4"),
                   table(header: ["a", "b"], rows: [["1", "2"]]) + "\n<hr />\n<p>3 | 4</p>")
  }

  func testTableRowsStillContinue() {
    XCTAssertEqual(extHtml("a | b\n- | -\n1 | 2\n3 | 4\n5 |"),
                   table(header: ["a", "b"], rows: [["1", "2"], ["3", "4"], ["5", ""]]))
    XCTAssertEqual(extHtml("a | b\n- | -\n1 | 2\n3"),
                   table(header: ["a", "b"], rows: [["1", "2"]]) + "\n<p>3</p>")
  }

  func testEscapedPipesInCodeSpansOfTableCells() {
    XCTAssertEqual(extHtml("a | b\n- | -\n`x \\| y` | z \\| w"),
                   table(header: ["a", "b"], rows: [["<code>x | y</code>", "z | w"]]))
  }

  // MARK: ATX headings

  func testAtxHeadingClosingSequence() {
    XCTAssertEqual(html("### ###"), "<h3></h3>")
    XCTAssertEqual(html("# #"), "<h1></h1>")
    XCTAssertEqual(html("## ##   "), "<h2></h2>")
    XCTAssertEqual(html("## foo ##"), "<h2>foo</h2>")
    XCTAssertEqual(html("## foo ##   \t "), "<h2>foo</h2>")
    XCTAssertEqual(html("# foo#"), "<h1>foo#</h1>")
    XCTAssertEqual(html("### foo \\###"), "<h3>foo ###</h3>")
    XCTAssertEqual(html("## foo #\\##"), "<h2>foo ###</h2>")
    XCTAssertEqual(html("# foo\t##"), "<h1>foo</h1>")
    XCTAssertEqual(html("#"), "<h1></h1>")
  }

  func testAtxHeadingTabs() {
    XCTAssertEqual(html("#\tfoo"), "<h1>foo</h1>")
    XCTAssertEqual(html("#  \t foo"), "<h1>foo</h1>")
    XCTAssertEqual(html("# foo \t"), "<h1>foo</h1>")
    XCTAssertEqual(html("#hashtag"), "<p>#hashtag</p>")
  }

  // MARK: Emphasis

  func testEmphasisRuleOfThree() {
    XCTAssertEqual(html("*foo**bar*"), "<p><em>foo**bar</em></p>")
    XCTAssertEqual(html("***foo** bar*"), "<p><em><strong>foo</strong> bar</em></p>")
    XCTAssertEqual(html("*foo **bar***"), "<p><em>foo <strong>bar</strong></em></p>")
    XCTAssertEqual(html("*foo**bar***"), "<p><em>foo<strong>bar</strong></em></p>")
    XCTAssertEqual(html("foo***bar***baz"), "<p>foo<em><strong>bar</strong></em>baz</p>")
    XCTAssertEqual(html("foo******bar*********baz"),
                   "<p>foo<strong><strong><strong>bar</strong></strong></strong>***baz</p>")
    XCTAssertEqual(html("*foo **bar *baz* bim** bop*"),
                   "<p><em>foo <strong>bar <em>baz</em> bim</strong> bop</em></p>")
    XCTAssertEqual(html("**foo*bar*baz**"), "<p><strong>foo<em>bar</em>baz</strong></p>")
    XCTAssertEqual(html("_foo_bar_baz_"), "<p><em>foo_bar_baz</em></p>")
    XCTAssertEqual(html("a***b* c"), "<p>a**<em>b</em> c</p>")
  }

  // MARK: Info strings of fenced code blocks

  private func info(_ str: String) -> String? {
    guard case .document(let blocks) = MarkdownParser.standard.parse(str),
          case .fencedCode(let info, _)? = blocks.first else {
      XCTFail("not a fenced code block: \(str.debugDescription)")
      return nil
    }
    return info
  }

  /// Backslash escapes and entity references are processed in the info string (CommonMark 4.5)
  func testInfoStringEscapesAndEntitiesAreResolved() {
    XCTAssertEqual(self.info("``` f&ouml;&ouml; x\n```"), "föö x")
    XCTAssertEqual(self.info("```\\;a\\*b\n```"), ";a*b")
    XCTAssertEqual(self.info("```a\\b\n```"), "a\\b")           // backslash before a letter
    XCTAssertEqual(self.info("```&#35;&#x41;&amp;\n```"), "#A&")
    XCTAssertEqual(self.info("```\\&ouml;\n```"), "&ouml;")      // an escaped & is not an entity
    XCTAssertEqual(self.info("```&unknown; &#0;\n```"), "&unknown; \u{FFFD}")
    XCTAssertEqual(self.info("```swift\n```"), "swift")
    XCTAssertNil(self.info("```\n```"))
  }

  func testCodeBlockLanguageClassFollowsSpec() {
    XCTAssertEqual(html("``` f&ouml;&ouml;\nfoo\n```"),
                   "<pre><code class=\"language-föö\">foo\n</code></pre>")
    XCTAssertEqual(html("````;\n````"), "<pre><code class=\"language-;\"></code></pre>")
    XCTAssertEqual(html("```日本語 x\ncode\n```"),
                   "<pre><code class=\"language-日本語\">code\n</code></pre>")
    XCTAssertEqual(html("```\\&ouml;\ncode\n```"),
                   "<pre><code class=\"language-&amp;ouml;\">code\n</code></pre>")
  }

  // MARK: Tight and loose lists

  /// A list is loose if its items are separated by blank lines or if an item directly contains
  /// two blocks with a blank line between them. Blank lines within nested blocks do not count.
  func testLooseNestedBlocksMakeListLoose() {
    XCTAssertEqual(html("- a\n\n  > b"),
                   "<ul>\n<li><p>a</p>\n<blockquote>\n<p>b</p>\n</blockquote>\n</li>\n</ul>")
    XCTAssertEqual(html("- a\n\n  - b"), "<ul>\n<li><p>a</p>\n<ul>\n<li>b</li>\n</ul>\n</li>\n</ul>")
    XCTAssertEqual(html("- a\n  > b\n\n- c"),
                   "<ul>\n<li><p>a</p>\n<blockquote>\n<p>b</p>\n</blockquote>\n</li>\n" +
                   "<li><p>c</p>\n</li>\n</ul>")
  }

  func testBlankLinesInNestedBlocksDoNotMakeListLoose() {
    // Blank lines inside of a block quote
    XCTAssertEqual(html("- a\n  > b\n  >\n  > c"),
                   "<ul>\n<li>a\n<blockquote>\n<p>b</p>\n<p>c</p>\n</blockquote>\n</li>\n</ul>")
    XCTAssertEqual(html("* a\n  > b\n  >\n* c"),
                   "<ul>\n<li>a\n<blockquote>\n<p>b</p>\n</blockquote>\n</li>\n<li>c</li>\n</ul>")
    // Blank lines between the items of a nested list make the nested list loose only
    XCTAssertEqual(html("- a\n  - b\n\n  - c"),
                   "<ul>\n<li>a\n<ul>\n<li><p>b</p>\n</li>\n<li><p>c</p>\n</li>\n</ul>\n</li>\n</ul>")
    // Blank lines at the end of a fenced code block which is not closed belong to the code
    XCTAssertEqual(html("- ```\n  x\n\n- b"),
                   "<ul>\n<li><pre><code>x\n\n</code></pre>\n</li>\n<li>b</li>\n</ul>")
  }

  func testBlankLinesBetweenItemsMakeListLoose() {
    XCTAssertEqual(html("- a\n- b\n\n- c"),
                   "<ul>\n<li><p>a</p>\n</li>\n<li><p>b</p>\n</li>\n<li><p>c</p>\n</li>\n</ul>")
    // The blank line between the nested item and the next item of the outer list
    XCTAssertEqual(html("- a\n  - b\n\n- c"),
                   "<ul>\n<li><p>a</p>\n<ul>\n<li>b</li>\n</ul>\n</li>\n<li><p>c</p>\n</li>\n</ul>")
    // A blank line within a block quote does separate the items of a list in the block quote
    XCTAssertEqual(html("> - a\n>\n> - b"),
                   "<blockquote>\n<ul>\n<li><p>a</p>\n</li>\n<li><p>b</p>\n</li>\n</ul>\n</blockquote>")
  }

  func testInfoStringOfTildeFenceMayContainBackticks() {
    XCTAssertEqual(self.info("~~~ aa ``` ~~~\nfoo\n~~~"), "aa ``` ~~~")
    XCTAssertEqual(html("~~~ aa ``` ~~~\nfoo\n~~~"),
                   "<pre><code class=\"language-aa\">foo\n</code></pre>")
    // A backtick fence with a backtick in the info string is not a fence (it is a code span)
    XCTAssertEqual(html("``` aa ```\nfoo"), "<p><code>aa</code>\nfoo</p>")
    // The same holds for longer fences (the last line is the start of another fence)
    XCTAssertEqual(html("````a`b\nfoo\n````"),
                   "<p>````a`b\nfoo</p>\n<pre><code></code></pre>")
  }

  // MARK: Descriptions and raw text of blocks

  func testDescriptionOfTables() {
    XCTAssertEqual(ExtendedMarkdownParser.standard.parse("| a | b |\n|---|:-:|\n| c | d |").description,
                   "document(table(row(a | b), -C, row(c | d)))")
  }

  func testRawTextOfCodeBlocks() {
    // The lines of a code block include their line terminators, for both kinds of code blocks
    XCTAssertEqual(MarkdownParser.standard.parse("```\nx\ny\n```").string, "x\ny\n")
    XCTAssertEqual(MarkdownParser.standard.parse("    x\n    y\n").string, "x\ny\n")
  }

  // MARK: Unresolved image syntax

  /// The `!` of an image which is not completed is text like any other
  func testExclamationMarkOfUnresolvedImageIsKept() {
    XCTAssertEqual(html("Hello![World]"), "<p>Hello![World]</p>")
    XCTAssertEqual(html("x ![y] z"), "<p>x ![y] z</p>")
    XCTAssertEqual(html("a ![b"), "<p>a ![b</p>")
    XCTAssertEqual(html("![[foo]]\n\n[[foo]]: /url \"title\""),
                   "<p>![[foo]]</p>\n<p>[[foo]]: /url \"title\"</p>")
    XCTAssertEqual(html("![a][undefined]"), "<p>![a][undefined]</p>")
    // Images which are completed are not affected
    XCTAssertEqual(html("![a [b] c](d)"), "<p><img src=\"d\" alt=\"a [b] c\"/></p>")
    let doc = MarkdownParser.standard.parse("Hello![World]")
    XCTAssertEqual(doc.string, "Hello![World]")
    XCTAssertEqual(StringGenerator.standard.generate(doc: doc), "Hello![World]")
    XCTAssertEqual(TerminalGenerator.standard.generate(doc: doc).plainText, "Hello![World]")
  }

  // MARK: Line endings

  /// Backslashes and spaces at the end of a line are no line breaks in code spans and HTML
  func testLineEndingsInCodeSpansAndInlineHtml() {
    XCTAssertEqual(html("`code\\\nspan`"), "<p><code>code\\ span</code></p>")
    XCTAssertEqual(html("`code  \nspan`"), "<p><code>code   span</code></p>")
    XCTAssertEqual(html("``\nfoo\nbar  \nbaz\n``"), "<p><code>foo bar   baz</code></p>")
    XCTAssertEqual(html("``\nfoo \n``"), "<p><code>foo </code></p>")
    XCTAssertEqual(html("`foo   bar \nbaz`"), "<p><code>foo   bar  baz</code></p>")
    XCTAssertEqual(html("<a href=\"foo\\\nbar\">"), "<p><a href=\"foo\\\nbar\"></p>")
    XCTAssertEqual(html("<a  /><b2\ndata=\"foo\" >"), "<p><a  /><b2\ndata=\"foo\" ></p>")
    // A link destination in angle brackets cannot contain line endings (this is an HTML tag)
    XCTAssertEqual(html("[link](<foo\nbar>)"), "<p>[link](<foo\nbar>)</p>")
  }

  func testHardAndSoftLineBreaks() {
    XCTAssertEqual(html("foo\\\nbar"), "<p>foo<br/>bar</p>")
    XCTAssertEqual(html("foo  \nbar"), "<p>foo<br/>bar</p>")
    XCTAssertEqual(html("foo      \nbar"), "<p>foo<br/>bar</p>")
    XCTAssertEqual(html("foo \nbar"), "<p>foo\nbar</p>")
    XCTAssertEqual(html("foo\t\nbar"), "<p>foo\nbar</p>")
    XCTAssertEqual(html("foo\\ \nbar"), "<p>foo\\\nbar</p>")
    XCTAssertEqual(html("foo\\  \nbar"), "<p>foo\\<br/>bar</p>")
    XCTAssertEqual(html("*foo  \nbar*"), "<p><em>foo<br/>bar</em></p>")
    XCTAssertEqual(html("*foo\\\nbar*"), "<p><em>foo<br/>bar</em></p>")
    XCTAssertEqual(html("`a`  \nb"), "<p><code>a</code><br/>b</p>")
    XCTAssertEqual(html("[a  \nb](/u)"), "<p><a href=\"/u\">a<br/>b</a></p>")
    // No line break at the end of a paragraph or heading
    XCTAssertEqual(html("foo\\"), "<p>foo\\</p>")
    XCTAssertEqual(html("foo  "), "<p>foo</p>")
    XCTAssertEqual(html("Foo  \n---"), "<h2>Foo</h2>")
    XCTAssertEqual(html("# Foo  "), "<h1>Foo</h1>")
  }

  // MARK: Autolinks and angle brackets

  /// Backslash escapes do not work in autolinks, but an escaped `>` is a literal `>` elsewhere
  func testBackslashesInAutolinks() {
    XCTAssertEqual(html("<http://example.com/\\[\\>"),
                   "<p><a href=\"http://example.com/\\[\\\">http://example.com/\\[\\</a></p>")
    XCTAssertEqual(html("<http://example.com/a\\>b>"),
                   "<p><a href=\"http://example.com/a\\\">http://example.com/a\\</a>b&gt;</p>")
    XCTAssertEqual(html("a \\> b"), "<p>a &gt; b</p>")
    XCTAssertEqual(html("1 < 2 \\> 0"), "<p>1 &lt; 2 &gt; 0</p>")
    XCTAssertEqual(html("\\>a\\>"), "<p>&gt;a&gt;</p>")
    XCTAssertEqual(html("[a](<b\\>c>)"), "<p><a href=\"b&gt;c\">a</a></p>")
    // The same text as in the case without a preceding `<`
    XCTAssertEqual(MarkdownParser.standard.parse("a \\> b"),
                   .document([.paragraph(Text(TextFragment.text("a > b")))]))
    XCTAssertEqual(MarkdownParser.standard.parse("1 < 2 \\> 0"),
                   .document([.paragraph({
                     var text = Text()
                     text.append(fragment: .text("1 "))
                     text.append(fragment: .delimiter("<", 1, []))
                     text.append(fragment: .text(" 2 > 0"))
                     return text
                   }())]))
  }

  // MARK: Tabs

  /// Tabs behave like spaces up to the next tab stop (a multiple of 4 columns) where whitespace
  /// is significant for the block structure. They are not changed in code.
  func testTabsExpandToTabStopsForIndentation() {
    // A tab which is partially consumed by a container leaves spaces in the code block
    XCTAssertEqual(html("- foo\n\n\t\tbar"),
                   "<ul>\n<li><p>foo</p>\n<pre><code>  bar\n</code></pre>\n</li>\n</ul>")
    XCTAssertEqual(html(">\t\tfoo"), "<blockquote>\n<pre><code>  foo\n</code></pre>\n</blockquote>")
    XCTAssertEqual(html("-\t\tfoo"), "<ul>\n<li><pre><code>  foo\n</code></pre>\n</li>\n</ul>")
    // (the first tab spans two columns, one of which follows the marker)
    XCTAssertEqual(html("1.\t\tfoo"), "<ol start=\"1\">\n<li><pre><code> foo\n</code></pre>\n</li>\n</ol>")
    // A tab which starts after two columns spans two columns only
    XCTAssertEqual(html("  \tfoo"), "<pre><code>foo\n</code></pre>")
    XCTAssertEqual(html("   \tfoo\tbar"), "<pre><code>foo\tbar\n</code></pre>")
    XCTAssertEqual(html("\t\tfoo\n\t\t\tbar"), "<pre><code>\tfoo\n\t\tbar\n</code></pre>")
    // A tab after the `>` of a block quote consumes one column
    XCTAssertEqual(html(">\tfoo"), "<blockquote>\n<p>foo</p>\n</blockquote>")
    XCTAssertEqual(html("> a\n>\t b\n>\t\t c"), "<blockquote>\n<p>a\nb\nc</p>\n</blockquote>")
  }

  func testTabsDetermineNestingOfListItems() {
    XCTAssertEqual(html(" - foo\n   - bar\n\t - baz"),
                   "<ul>\n<li>foo\n<ul>\n<li>bar\n<ul>\n<li>baz</li>\n</ul>\n</li>\n</ul>\n</li>\n</ul>")
    XCTAssertEqual(html("- a\n\t- b\n\t\t- c"),
                   "<ul>\n<li>a\n<ul>\n<li>b\n<ul>\n<li>c</li>\n</ul>\n</li>\n</ul>\n</li>\n</ul>")
    XCTAssertEqual(html("1.\tfoo\n\tbar\n\n\tbaz"),
                   "<ol start=\"1\">\n<li><p>foo\nbar</p>\n<p>baz</p>\n</li>\n</ol>")
    XCTAssertEqual(html("-\tfoo\n\n\tbar"), "<ul>\n<li><p>foo</p>\n<p>bar</p>\n</li>\n</ul>")
  }

  func testTabsDoNotCountAsFourColumnsAfterOtherCharacters() {
    // A tab after two spaces and a list marker ends at the tab stop of column 4
    XCTAssertEqual(html("  -\tfoo\n\n\tbar"), "<ul>\n<li><p>foo</p>\n<p>bar</p>\n</li>\n</ul>")
    // Content of code blocks and tabs in paragraphs are preserved
    XCTAssertEqual(html("    a\ta\n    \u{1F50}\ta"), "<pre><code>a\ta\n\u{1F50}\ta\n</code></pre>")
    XCTAssertEqual(html("a\tb"), "<p>a\tb</p>")
  }
}
