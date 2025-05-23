//
//  MarkdownBlockTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 03/05/2019.
//  Copyright © 2019 Google LLC.
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

class MarkdownBlockTests: XCTestCase, MarkdownKitFactory {
  
  private func parseBlocks(_ str: String) -> Block {
    return MarkdownParser.standard.parse(str, blockOnly: true)
  }

  func testEmptyDocuments() {
    XCTAssertEqual(parseBlocks(""), document())
    XCTAssertEqual(parseBlocks("  "), document())
    XCTAssertEqual(parseBlocks("   \n  "), document())
    XCTAssertEqual(parseBlocks("     \n \t "), document())
  }

  func testParagraphs() {
    XCTAssertEqual(parseBlocks("foo"), document(paragraph("foo")))
    XCTAssertEqual(parseBlocks("foo\nbar"), document(paragraph("foo", "bar")))
    XCTAssertEqual(parseBlocks("foo \nbar"), document(paragraph("foo", "bar")))
    XCTAssertEqual(parseBlocks("foo  \nbar"), document(paragraph("foo", nil, "bar")))
    XCTAssertEqual(parseBlocks("foo   \nbar"), document(paragraph("foo", nil, "bar")))
    XCTAssertEqual(parseBlocks("foo   \nbar   \n"), document(paragraph("foo", nil, "bar")))
    XCTAssertEqual(parseBlocks("one\\\ntwo\\\n"), document(paragraph("one", nil, "two\\")))
    XCTAssertEqual(parseBlocks("one\\\n\\\ntwo\\\n"),
                   document(paragraph("one", nil, nil, "two\\")))
    XCTAssertEqual(parseBlocks("one\\\n   \\\ntwo\\\n"),
                   document(paragraph("one", nil, nil, "two\\")))
    XCTAssertEqual(parseBlocks("*foo"), document(paragraph("*foo")))
    XCTAssertEqual(parseBlocks("**foo\ntwo"), document(paragraph("**foo", "two")))
    XCTAssertEqual(parseBlocks("**foo**"), document(paragraph("**foo**")))
  }

  func testThematicBreaks() {
    XCTAssertEqual(parseBlocks("***"), document(.thematicBreak))
    XCTAssertEqual(parseBlocks("\n***"), document(.thematicBreak))
    XCTAssertEqual(parseBlocks("\n***\n"), document(.thematicBreak))
    XCTAssertEqual(parseBlocks("***\n***"), document(.thematicBreak, .thematicBreak))
  }

  func testATXHeadings() {
    XCTAssertEqual(parseBlocks("#"), document(atxHeading(1, "")))
    XCTAssertEqual(parseBlocks("   ##"), document(atxHeading(2, "")))
    XCTAssertEqual(parseBlocks("    ###"), document(indentedCode("###")))
    XCTAssertEqual(parseBlocks("# Header   \n Word1 word2."),
                   document(atxHeading(1, "Header"), paragraph("Word1 word2.")))
    XCTAssertEqual(parseBlocks(" # First\n ## Second  \n###Third"),
                   document(atxHeading(1, "First"), atxHeading(2, "Second"), paragraph("###Third")))
  }

  func testSetextHeadings() {
    XCTAssertEqual(parseBlocks("Foo *bar*\n========="), document(setextHeading(1, "Foo *bar*")))
    XCTAssertEqual(parseBlocks("/\n-"), document(setextHeading(2, "/")))
    XCTAssertEqual(parseBlocks("Foo *bar\nbaz*\n===="),
                   document(setextHeading(1, "Foo *bar", "baz*")))
    XCTAssertEqual(parseBlocks("  Foo *bar\nbaz*\t\n===="),
                   document(setextHeading(1, "Foo *bar", "baz*")))
    XCTAssertEqual(parseBlocks("Foo\n   ==      "), document(setextHeading(1, "Foo")))
    XCTAssertEqual(parseBlocks("Foo\n    --"), document(paragraph("Foo", "--")))
    XCTAssertEqual(parseBlocks("Foo\\\n--      "), document(setextHeading(2, "Foo\\")))
    XCTAssertEqual(parseBlocks("> foo\nbar\n==="),
                   document(blockquote(paragraph("foo", "bar", "==="))))
    XCTAssertEqual(parseBlocks("> foo\nbar\n>==="),
                   document(blockquote(setextHeading(1, "foo", "bar"))))
    XCTAssertEqual(parseBlocks("> Foo\n---"),
                   document(blockquote(paragraph("Foo")), .thematicBreak))
    XCTAssertEqual(parseBlocks("- Foo\n---"),
                   document(list(tight: true, listItem("-", initial: true, paragraph("Foo"))), .thematicBreak))
    XCTAssertEqual(parseBlocks("---\nFoo\n---\nBar\n---\nBaz"),
                   document(.thematicBreak,
                            setextHeading(2, "Foo"),
                            setextHeading(2, "Bar"),
                            paragraph("Baz")))
    XCTAssertEqual(parseBlocks("  \n====="), document(paragraph("=====")))
    XCTAssertEqual(parseBlocks("---\n---\n"), document(.thematicBreak, .thematicBreak))
    XCTAssertEqual(parseBlocks("\\> foo\n------"), document(setextHeading(2, "\\> foo")))
    XCTAssertEqual(parseBlocks("one\\\ntwo\n=\n "), document(setextHeading(1, "one", nil, "two")))
    XCTAssertEqual(parseBlocks("one  \ntwo\n=\n "), document(setextHeading(1, "one", nil, "two")))
  }

  func testBlockquotes() {
    XCTAssertEqual(parseBlocks(">"), document(blockquote()))
    XCTAssertEqual(parseBlocks(">One"), document(blockquote(paragraph("One"))))
    XCTAssertEqual(parseBlocks("> One"), document(blockquote(paragraph("One"))))
    XCTAssertEqual(parseBlocks(">    One "), document(blockquote(paragraph("One"))))
    XCTAssertEqual(parseBlocks(">     One"), document(blockquote(indentedCode("One"))))
    XCTAssertEqual(parseBlocks("> # Hello"), document(blockquote(atxHeading(1, "Hello"))))
    XCTAssertEqual(parseBlocks(">  # Hello\n>  Next line\n And last line"),
                   document(blockquote(atxHeading(1, "Hello"),
                                       paragraph("Next line", "And last line"))))
    XCTAssertEqual(parseBlocks(">  # Hello\n>  Next line\n> And last line"),
                   document(blockquote(atxHeading(1, "Hello"),
                                       paragraph("Next line", "And last line"))))
    XCTAssertEqual(parseBlocks(">  # Hello\n>  Next line\n\n And last line"),
                   document(blockquote(atxHeading(1, "Hello"), paragraph("Next line")),
                            paragraph("And last line")))
    XCTAssertEqual(parseBlocks(">  # Hello\n>  Next line\n \n>  And last line"),
                   document(blockquote(atxHeading(1, "Hello"), paragraph("Next line")),
                            blockquote(paragraph("And last line"))))
  }

  func testIndentedCode() {
    XCTAssertEqual(parseBlocks("    a simple\n      code block"),
                   document(indentedCode("a simple\n", "  code block")))
    XCTAssertEqual(parseBlocks("    foo\nbar"),
                   document(indentedCode("foo\n"), paragraph("bar")))
    XCTAssertEqual(parseBlocks("    foo\nbar"),
                   document(indentedCode("foo\n"), paragraph("bar")))
    XCTAssertEqual(parseBlocks("    foo\n\nbar"),
                   document(indentedCode("foo\n"), paragraph("bar")))
    XCTAssertEqual(parseBlocks("one\n\n      foo\n    bar\n\ntwo"),
                   document(paragraph("one"),
                            indentedCode("  foo\n", "bar\n"),
                            paragraph("two")))
    XCTAssertEqual(parseBlocks("one\n\n     \n    \n      foo\n    bar\n     \n    \n\ntwo"),
                   document(paragraph("one"),
                            indentedCode("  foo\n", "bar\n"),
                            paragraph("two")))
    XCTAssertEqual(parseBlocks("one\n\n     \n    \n      foo\n    bar\ngoo\n    \n\n\ntwo"),
                   document(paragraph("one"),
                            indentedCode("  foo\n", "bar\n"),
                            paragraph("goo"),
                            paragraph("two")))
    XCTAssertEqual(parseBlocks("one\n\n     \n    <b>foo</b>\n    <i>bar</i>\n    \n\n\ntwo"),
                   document(paragraph("one"),
                            indentedCode("<b>foo</b>\n", "<i>bar</i>\n"),
                            paragraph("two")))
  }

  func testListItem() {
    XCTAssertEqual(parseBlocks("- One"), document(list(listItem("-", initial: true, paragraph("One")))))
    XCTAssertEqual(parseBlocks("- One\nTwo"),
                   document(list(listItem("-", initial: true, paragraph("One", "Two")))))
    XCTAssertEqual(parseBlocks(" - One\n\n   Two"),
                   document(list(tight: false, listItem("-", paragraph("One"), paragraph("Two")))))
    XCTAssertEqual(parseBlocks("  - > One\n    > Two\n\n      Three"),
                   document(list(tight: false, listItem("-", tight: false, blockquote(paragraph("One", "Two")),
                                                              paragraph("Three")))))
    XCTAssertEqual(parseBlocks("- foo\n\n-\n\n- bar"),
                   document(list(tight: false,
                                 listItem("-", initial: true, paragraph("foo")),
                                 listItem("-", initial: true),
                                 listItem("-", initial: true, paragraph("bar")))))
    XCTAssertEqual(parseBlocks("1.  One\nTwo"),
                   document(list(1, tight: true, listItem(1, ".", initial: true, paragraph("One", "Two")))))
    XCTAssertEqual(parseBlocks("1.  O\nT\n\n2.  Three\n\n4)  Four"),
                   document(list(1, tight: false,
                                    listItem(1, ".", initial: true, paragraph("O", "T")),
                                    listItem(2, ".", initial: true, paragraph("Three"))),
                            list(4, tight: true, listItem(4, ")", initial: true, paragraph("Four")))))
    XCTAssertEqual(parseBlocks("- foo\n  - bar\n    - baz\n      - boo"),
                   document(list(tight: true, listItem("-", initial: true, paragraph("foo"),
                              list(tight: true, listItem("-", tight: true, paragraph("bar"),
                                list(tight: true, listItem("-", tight: true, paragraph("baz"),
                                  list(listItem("-", tight: true, paragraph("boo")))))))))))
    XCTAssertEqual(parseBlocks("- foo\n - bar\n  - baz\n   - boo"),
                   document(list(listItem("-", initial: true, paragraph("foo")),
                                 listItem("-", tight: true, paragraph("bar")),
                                 listItem("-", tight: true, paragraph("baz")),
                                 listItem("-", tight: true, paragraph("boo")))))
    XCTAssertEqual(parseBlocks("- foo\n - bar\n  + baz\n   - boo"),
                   document(list(listItem("-", initial: true, paragraph("foo")),
                                 listItem("-", tight: true, paragraph("bar"))),
                            list(listItem("+", tight: true, paragraph("baz"))),
                            list(listItem("-", tight: true, paragraph("boo")))))
    XCTAssertEqual(parseBlocks("1. - 2. foo"),
                   document(list(1, listItem(1, ".", initial: true,
                                list(listItem("-", initial: true, list(2,
                                     listItem(2, ".", initial: true, paragraph("foo")))))))))
    XCTAssertEqual(parseBlocks("- foo\n  - one\n  - two\n  three"),
                   document(list(listItem("-", initial: true, paragraph("foo"),
                              list(listItem("-", tight: true, paragraph("one")),
                                   listItem("-", tight: true, paragraph("two", "three")))))))
    XCTAssertEqual(parseBlocks("- foo\n  - one\n  - two\n \n  three"),
                   document(list(tight: false,
                                 listItem("-", paragraph("foo"),
                                          list(listItem("-", tight: true, paragraph("one")),
                                               listItem("-", tight: true, paragraph("two"))),
                                          paragraph("three")))))
    XCTAssertEqual(parseBlocks("- foo\n\n  - one\n  - two\n \n  three"),
                   document(list(tight: false,
                                 listItem("-", tight: false, paragraph("foo"),
                                               list(listItem("-", initial: true, paragraph("one")),
                                                    listItem("-", tight: true, paragraph("two"))),
                                               paragraph("three")))))
    XCTAssertEqual(parseBlocks("- foo\n  * * *\n  - one\n  - two\n \n  three"),
                   document(list(tight: false,
                      listItem("-", paragraph("foo"),
                                    .thematicBreak,
                                    list(listItem("-", tight: true, paragraph("one")),
                                         listItem("-", tight: true, paragraph("two"))),
                                    paragraph("three")))))
    XCTAssertEqual(parseBlocks("- foo\n***\n  - one\n  - two\n \n  three"),
                   document(list(listItem("-", initial: true, paragraph("foo"))),
                            .thematicBreak,
                            list(listItem("-", tight: true, paragraph("one")),
                                 listItem("-", tight: true, paragraph("two"))),
                            paragraph("three")))
    XCTAssertEqual(parseBlocks("10) foo\n   - bar"),
                   document(list(10, listItem(10, ")", initial: true, paragraph("foo"))),
                            list(listItem("-", tight: true, paragraph("bar")))))
    XCTAssertEqual(parseBlocks("""
                       - One
                         
                         Two
                       - Three
                       - Four
                     """),
                   document(list(tight: false,
                                 listItem("-", tight: false, paragraph("One"), paragraph("Two")),
                                 listItem("-", tight: true, paragraph("Three")),
                                 listItem("-", tight: true, paragraph("Four")))))
    XCTAssertEqual(parseBlocks("""
        - foo
        - bar
            * one
            * two
            * three
        - goo
      """),
      document(list(listItem("-", initial: true, paragraph("foo")),
                                 listItem("-", tight: true, paragraph("bar"),
                                          list(listItem("*", tight: true, paragraph("one")),
                                               listItem("*", tight: true, paragraph("two")),
                                               listItem("*", tight: true, paragraph("three")))),
                                 listItem("-", tight: true, paragraph("goo")))))
  }
  
  func testSimpleNestedList() {
    XCTAssertEqual(parseBlocks("- Apple\n\t- Banana"),
                   document(list(tight: true,
                                 listItem("-", initial: true, paragraph("Apple"),
                                          list(tight: true,
                                               listItem("-", tight: true, paragraph("Banana")))))))
  }

  func testNestedList() {
    XCTAssertEqual(parseBlocks("- foo\n- bar\n    - one\n    - two\n    - three\n- goo"),
                   document(list(tight: true,
                                 listItem("-", initial: true, paragraph("foo")),
                                 listItem("-", tight: true,
                                          paragraph("bar"),
                                          list(listItem("-", tight: true, paragraph("one")),
                                               listItem("-", tight: true, paragraph("two")),
                                               listItem("-", tight: true, paragraph("three")))),
                                 listItem("-", tight: true, paragraph("goo")))))
  }
  
  func testBlockquoteList() {
    XCTAssertEqual(parseBlocks(">>- one\n>>\n  >  > two"),
                   document(blockquote(blockquote(list(listItem("-", initial: true, paragraph("one"))),
                                                  paragraph("two")))))
    XCTAssertEqual(parseBlocks("> 1234. > blockquote\n> continued here."),
                   document(blockquote(list(1234, listItem(1234, ".", initial: true,
                                         blockquote(paragraph("blockquote", "continued here.")))))))
    XCTAssertEqual(
      parseBlocks("  1.  A paragraph\nwith two lines.\n\n          code\n\n      > quote."),
      document(list(1, tight: false, listItem(1, ".", paragraph("A paragraph", "with two lines."),
                                                      indentedCode("code\n"),
                                                      blockquote(paragraph("quote."))))))
  }

  func testReferenceDefinition() {
    XCTAssertEqual(parseBlocks("[foo]: /url \"title\""),
                   document(referenceDef("foo", "/url", "title")))
    XCTAssertEqual(parseBlocks("[foo]:\n     /url  \n           \"title\"  "),
                   document(referenceDef("foo", "/url", "title")))
    XCTAssertEqual(parseBlocks("[Foo*bar\\]]:my_(url) 'title (with parens)'"),
                   document(referenceDef("Foo*bar\\]", "my_(url)", "title (with parens)")))
    XCTAssertEqual(parseBlocks("[ Foo  bar ]:\n      <my url>\n      'title'"),
                   document(referenceDef("Foo bar", "my url", "title")))
    XCTAssertEqual(parseBlocks("[foo   ]: /url '\ntitle\nline1\nline2\n'"),
                   document(referenceDef("foo", "/url", "", "title", "line1", "line2", "")))
    XCTAssertEqual(parseBlocks("[foo]: /url 'title\n\nwith blank line'"),
                   document(paragraph("[foo]: /url 'title"), paragraph("with blank line'")))
    XCTAssertEqual(parseBlocks("[  foo]: /url\n\none"),
                   document(referenceDef("foo", "/url"), paragraph("one")))
    XCTAssertEqual(parseBlocks("[foo]:\n\none"),
                   document(paragraph("[foo]:"), paragraph("one")))
    XCTAssertEqual(parseBlocks("[foo]: <>\n\none"),
                   document(referenceDef("foo", ""), paragraph("one")))
    XCTAssertEqual(parseBlocks("[foo]: <bar>(baz)\n\none"),
                   document(paragraph("[foo]: <bar>(baz)"), paragraph("one")))
    XCTAssertEqual(parseBlocks("[foo]: /url\\bar\\*baz \"foo\\\"bar\\baz\""),
                   document(referenceDef("foo", "/url\\bar\\*baz", "foo\\\"bar\\baz")))
    XCTAssertEqual(parseBlocks("[\nfoo\nbar\n]:\n/url\nbar"),
                   document(referenceDef("foo bar", "/url"), paragraph("bar")))
    XCTAssertEqual(parseBlocks("[foo]: /url \"title\" ok"),
                   document(paragraph("[foo]: /url \"title\" ok")))
    XCTAssertEqual(parseBlocks("[foo]: /url\n\"title\" ok"),
                   document(referenceDef("foo", "/url"), paragraph("\"title\" ok")))
    XCTAssertEqual(parseBlocks("Foo\n[bar]: /baz\nBar"),
                   document(paragraph("Foo", "[bar]: /baz", "Bar")))
    XCTAssertEqual(parseBlocks("# [Foo]\n[foo]: /url\n> bar"),
                   document(atxHeading(1, "[Foo]"),
                            referenceDef("foo", "/url"),
                            blockquote(paragraph("bar"))))
  }

  func testHtmlBlock() {
    XCTAssertEqual(parseBlocks("> <!--\n> *foo*\n> -->\nbar"),
                   document(blockquote(htmlBlock("<!--\n", "*foo*\n", "-->\n")), paragraph("bar")))
    XCTAssertEqual(
      parseBlocks("<table><tr><td>\n<pre>\n**Hello**\n\n_all_\n</pre>\n</td></tr></table>"),
      document(htmlBlock("<table><tr><td>\n", "<pre>\n", "**Hello**\n"),
               paragraph("_all_", "</pre>"),
               htmlBlock("</td></tr></table>")))
    XCTAssertEqual(parseBlocks(" <div>\n  *hello*\n         <foo><a>"),
                   document(htmlBlock(" <div>\n", "  *hello*\n", "         <foo><a>")))
    XCTAssertEqual(parseBlocks("</div>\n*foo*\n"),
                   document(htmlBlock("</div>\n", "*foo*\n")))
    XCTAssertEqual(parseBlocks("<DIV CLASS=\"foo\">\n\n_Markdown_\n\n</DIV>\n"),
                   document(htmlBlock("<DIV CLASS=\"foo\">\n"),
                            paragraph("_Markdown_"),
                            htmlBlock("</DIV>\n")))
    XCTAssertEqual(parseBlocks("<div id=\"foo\"\n  class=\"bar\">\n</div>"),
                   document(htmlBlock("<div id=\"foo\"\n","  class=\"bar\">\n", "</div>")))
    XCTAssertEqual(parseBlocks("<div><a href=\"bar\">*foo*</a></div>"),
                   document(htmlBlock("<div><a href=\"bar\">*foo*</a></div>")))
    XCTAssertEqual(parseBlocks("> <!--\n> *foo*\n> -->\nbar"),
                   document(blockquote(htmlBlock("<!--\n", "*foo*\n", "-->\n")), paragraph("bar")))
    XCTAssertEqual(parseBlocks("> <!--\n> *foo*\nbar"),
                   document(blockquote(htmlBlock("<!--\n", "*foo*\n")), paragraph("bar")))
    XCTAssertEqual(parseBlocks("> <DIV CLASS=\"foo\">\n> \n> _Markdown_\n>\n> </DIV>\n"),
                   document(blockquote(htmlBlock("<DIV CLASS=\"foo\">\n"),
                                       paragraph("_Markdown_"),
                                       htmlBlock("</DIV>\n"))))
    XCTAssertEqual(parseBlocks("> <DIV CLASS=\"foo\">\n> \n> _Markdown_\n\n> </DIV>\n"),
                   document(blockquote(htmlBlock("<DIV CLASS=\"foo\">\n"),
                                       paragraph("_Markdown_")),
                            blockquote(htmlBlock("</DIV>\n"))))
    XCTAssertEqual(parseBlocks("<pre language=\"haskell\"><code>\nimport Text.HTML.TagSoup\n\n" +
                         "main :: IO ()\n</code></pre>\nokay"),
                   document(htmlBlock("<pre language=\"haskell\"><code>\n",
                                      "import Text.HTML.TagSoup\n",
                                      "\n",
                                      "main :: IO ()\n",
                                      "</code></pre>\n"),
                            paragraph("okay")))
  }
  
  func testToString() {
    XCTAssertEqual(parseBlocks(" # First\n ## Second  \n### Third").string, "First\nSecond\nThird")
    XCTAssertEqual(parseBlocks(">  # Hello\n>  Next line\n And last line").string, "Hello\nNext line And last line")
    XCTAssertEqual(parseBlocks("one\n\n      foo\n    bar\n\ntwo").string, "one\n  foo\nbar\n\ntwo")
    XCTAssertEqual(parseBlocks("- foo\n - bar\n  - baz\n   - boo").string, "foo\nbar\nbaz\nboo")
    XCTAssertEqual(parseBlocks("- foo\n  - one\n  - two\n \n  three").string, "foo\none\ntwo\nthree")
  }

  func testDebug() {

  }
  
  static let allTests = [
    ("testEmptyDocuments", testEmptyDocuments),
    ("testParagraphs", testParagraphs),
    ("testThematicBreaks", testThematicBreaks),
    ("testATXHeadings", testATXHeadings),
    ("testSetextHeadings", testSetextHeadings),
    ("testBlockquotes", testBlockquotes),
    ("testIndentedCode", testIndentedCode),
    ("testListItem", testListItem),
    ("testNestedList", testNestedList),
    ("testBlockquoteList", testBlockquoteList),
    ("testReferenceDefinition", testReferenceDefinition),
    ("testHtmlBlock", testHtmlBlock),
  ]
}
