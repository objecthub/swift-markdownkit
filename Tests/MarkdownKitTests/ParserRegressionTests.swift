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
}
