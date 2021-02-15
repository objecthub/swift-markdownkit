//
//  ExtendedMarkdownBlockTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 17/07/2020.
//  Copyright © 2020 Google LLC.
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

class ExtendedMarkdownBlockTests: XCTestCase, MarkdownKitFactory {
  
  private func parseBlocks(_ str: String) -> Block {
    return ExtendedMarkdownParser.standard.parse(str, blockOnly: true)
  }

  func testBlockParserCounts() {
    XCTAssertEqual(MarkdownParser.standard.documentParser(input: "").blockParsers.count, 9)
    XCTAssertEqual(ExtendedMarkdownParser.standard.documentParser(input: "").blockParsers.count, 10)
  }
  
  func testMinimalTable() {
    XCTAssertEqual(parseBlocks("|column\n|-"), document(table(["column"],[.undefined])))
    XCTAssertEqual(parseBlocks("|colA|colB\n|-|-"), document(table(["colA", "colB"],
                                                                   [.undefined, .undefined])))
    XCTAssertEqual(parseBlocks("colA|colB\n|-|-"), document(table(["colA", "colB"],
                                                                  [.undefined, .undefined])))
    XCTAssertEqual(parseBlocks("colA|colB\n-|-"), document(table(["colA", "colB"],
                                                                 [.undefined, .undefined])))
    XCTAssertEqual(parseBlocks("colA|colB|\n-|-|\n"), document(table(["colA", "colB"],
                                                                     [.undefined, .undefined])))
  }
  
  func testComplexTable() {
    XCTAssertEqual(parseBlocks(" | col A | col B | col C | \n" +
                               "-| :--- |----: |   \n" +
                               "  this is|very cool   | right?  \n" +
                               "| and *now*|__with__| markup|\n" +
                               "||||\n"),
                   document(table(["col A", "col B", "col C"],
                                  [.undefined, .left, .right],
                                  ["this is", "very cool", "right?"],
                                  ["and *now*", "__with__", "markup"],
                                  ["", "", ""])))
  }
  
  func testComplexWrappedTable() {
    XCTAssertEqual(parseBlocks(" | col A | col B | col C | \n" +
                               "-| :--- |----: |   \n" +
                               "  this is \\\n" +
                               " a very long line |very \\| cool   | right?  \n" +
                               "| and *now*|__with__| markup|\n" +
                               "||||\n"),
                   document(table(["col A", "col B", "col C"],
                                  [.undefined, .left, .right],
                                  ["this is $a very long line", "very \\| cool", "right?"],
                                  ["and *now*", "__with__", "markup"],
                                  ["", "", ""])))
    XCTAssertEqual(parseBlocks(" | col A | col B | col C | \n" +
                               "-| :--- |:---: |   \n" +
                               "  this is \\\n" +
                               " a very long line |and here \\\n" +
                               "is another \\\n" +
                               "     one| right?  \n" +
                               "       | and *now*|__with__\n" +
                               "||||foo|bar|\n"),
                   document(table(["col A", "col B", "col C"],
                                  [.undefined, .left, .center],
                                  ["this is $a very long line",
                                   "and here $is another $one",
                                   "right?"],
                                  ["and *now*", "__with__", nil],
                                  ["", "", ""])))
  }
  
  func testTableTermination() {
    XCTAssertEqual(parseBlocks("This is a paragraph\n\n" +
                               " | col A | col B |\n" +
                               " | -     | -:    |\n" +
                               " | 1     | 2     |\n" +
                               " | 3\n" +
                               "And this is another paragraph\n"),
                   document(paragraph("This is a paragraph"),
                            table(["col A", "col B"],
                                  [.undefined, .right],
                                  ["1", "2"],
                                  ["3", nil]),
                            paragraph("And this is another paragraph")))
    XCTAssertEqual(parseBlocks("This is a paragraph\n\n" +
                               " | col A | col B |\n" +
                               " | -     | -:    |\n" +
                               " | 1     | 2     |\n" +
                               " | 3     | 4     | 5 |\n" +
                               "# Header   \n Word1 word2.\n"),
                   document(paragraph("This is a paragraph"),
                            table(["col A", "col B"],
                                  [.undefined, .right],
                                  ["1", "2"],
                                  ["3", "4"]),
                            atxHeading(1, "Header"),
                            paragraph("Word1 word2.")))
    XCTAssertEqual(parseBlocks("one\n\n     \n    \n      foo\n    bar\n" +
                               " | col A | col B |\n" +
                               " | -     | -:    |\n" +
                               " | 1     | 2     |\n" +
                               " | 3     | 4     | 5 |\n" +
                               "- item"),
                   document(paragraph("one"),
                            indentedCode("  foo\n", "bar\n"),
                            table(["col A", "col B"],
                                  [.undefined, .right],
                                  ["1", "2"],
                                  ["3", "4"]),
                            list(listItem("-", tight: true, paragraph("item")))))
  }
  
  func testNestedTable() {
    XCTAssertEqual(parseBlocks("> | col A | col B |\n" +
                               "> | -     | -:    |\n" +
                               "> | 1     | 2     |\n" +
                               "Last line"),
                   document(blockquote(table(["col A", "col B"],
                                             [.undefined, .right],
                                             ["1", "2"])),
                            paragraph("Last line")))
    XCTAssertEqual(parseBlocks("- One\n" +
                               "- Two:\n" +
                               "  | col A | col B |\n" +
                               "  | -     | -:    |\n" +
                               "  | 1     | 2     |\n" +
                               "  End table\n" +
                               "- Three"),
                   document(list(tight: false,
                                 listItem("-", paragraph("One")),
                                 listItem("-", tight: true,
                                          paragraph("Two:"),
                                          table(["col A", "col B"],
                                                [.undefined, .right],
                                                ["1", "2"]),
                                          paragraph("End table")),
                                 listItem("-", tight: true, paragraph("Three")))))
  }
  
  func testDefinitionList() {
    XCTAssertEqual(parseBlocks("Software\n: programs used by a computer"),
                   document(definitionList(("Software",
                                            [[paragraph("programs used by a computer")]]))))
    XCTAssertEqual(parseBlocks("Software\n" +
                               ": programs used by a computer\n" +
                               ": operating instructions"),
                   document(definitionList(("Software",
                             [[paragraph("programs used by a computer")],
                              [paragraph("operating instructions")]]))))
    XCTAssertEqual(parseBlocks("Software\n" +
                               ": programs used by a\n" +
                               "  computer\n" +
                               ": operating instructions\n\n" +
                               "Hardware\n" +
                               ": physical components of a computer\n"),
                   document(definitionList(
                             ("Software", [[paragraph(.text("programs used by a"),
                                                      .softLineBreak,
                                                      .text("computer"))],
                                           [paragraph("operating instructions")]]),
                             ("Hardware", [[paragraph("physical components of a computer")]]))))
    XCTAssertEqual(parseBlocks("# Header\n\n" +
                               "Software\n" +
                               " : programs used by a\n" +
                               "     - device\n" +
                               "     - computer\n\n" +
                               "   and other systems\n\n" +
                               " : operating instructions\n\n" +
                               "Hardware\n" +
                               "  :  > One\n" +
                               "     > Two\n"),
                   document(atxHeading(1, "Header"),
                            definitionList(
                             ("Software", [[paragraph("programs used by a"),
                                            list(tight: true,
                                                 listItem("-", tight: true, paragraph("device")),
                                                 listItem("-", tight: true, paragraph("computer"))),
                                            paragraph("and other systems")],
                                           [paragraph("operating instructions")]]),
                             ("Hardware", [[blockquote(paragraph(.text("One"),
                                                                 .softLineBreak,
                                                                 .text("Two")))]]))))
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
                   document(list(listItem("-", paragraph("Foo"))), .thematicBreak))
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
  }

  func testListItem() {
    XCTAssertEqual(parseBlocks("- One"), document(list(listItem("-", paragraph("One")))))
    XCTAssertEqual(parseBlocks("- One\nTwo"),
                   document(list(listItem("-", paragraph("One", "Two")))))
    XCTAssertEqual(parseBlocks(" - One\n\n   Two"),
                   document(list(tight: false, listItem("-", paragraph("One"), paragraph("Two")))))
    XCTAssertEqual(parseBlocks("  - > One\n    > Two\n\n      Three"),
                   document(list(tight: false, listItem("-", blockquote(paragraph("One", "Two")),
                                                             paragraph("Three")))))
    XCTAssertEqual(parseBlocks("- foo\n\n-\n\n- bar"),
                   document(list(tight: false,
                                 listItem("-", paragraph("foo")),
                                 listItem("-"),
                                 listItem("-", paragraph("bar")))))
    XCTAssertEqual(parseBlocks("1.  One\nTwo"),
                   document(list(1, listItem(1, ".", paragraph("One", "Two")))))
    XCTAssertEqual(parseBlocks("1.  O\nT\n\n2.  Three\n\n4)  Four"),
                   document(list(1, tight: false,
                                    listItem(1, ".", paragraph("O", "T")),
                                    listItem(2, ".", paragraph("Three"))),
                            list(4, listItem(4, ")", paragraph("Four")))))
    XCTAssertEqual(parseBlocks("- foo\n  - bar\n    - baz\n      - boo"),
                   document(list(tight: false, listItem("-", paragraph("foo"),
                              list(tight: false, listItem("-", tight: true, paragraph("bar"),
                                list(tight: false, listItem("-", tight: true, paragraph("baz"),
                                  list(listItem("-", tight: true, paragraph("boo")))))))))))
    XCTAssertEqual(parseBlocks("- foo\n - bar\n  - baz\n   - boo"),
                   document(list(listItem("-", paragraph("foo")),
                                 listItem("-", tight: true, paragraph("bar")),
                                 listItem("-", tight: true, paragraph("baz")),
                                 listItem("-", tight: true, paragraph("boo")))))
    XCTAssertEqual(parseBlocks("- foo\n - bar\n  + baz\n   - boo"),
                   document(list(listItem("-", paragraph("foo")),
                                 listItem("-", tight: true, paragraph("bar"))),
                            list(listItem("+", tight: true, paragraph("baz"))),
                            list(listItem("-", tight: true, paragraph("boo")))))
    XCTAssertEqual(parseBlocks("1. - 2. foo"),
                   document(list(1, listItem(1, ".",
                              list(listItem("-", list(2,
                                listItem(2, ".", paragraph("foo")))))))))
    XCTAssertEqual(parseBlocks("- foo\n  - one\n  - two\n  three"),
                   document(list(tight: false, listItem("-", paragraph("foo"),
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
                                 listItem("-", paragraph("foo"),
                                               list(listItem("-", paragraph("one")),
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
                   document(list(listItem("-", paragraph("foo"))),
                            .thematicBreak,
                            list(listItem("-", tight: true, paragraph("one")),
                                 listItem("-", tight: true, paragraph("two"))),
                            paragraph("three")))
    XCTAssertEqual(parseBlocks("10) foo\n   - bar"),
                   document(list(10, listItem(10, ")", paragraph("foo"))),
                            list(listItem("-", tight: true, paragraph("bar")))))
  }
  
  func testNestedList() {
    XCTAssertEqual(parseBlocks("- foo\n- bar\n    - one\n    - two\n    - three\n- goo"),
                   document(list(tight: false,
                                 listItem("-", paragraph("foo")),
                                 listItem("-", tight: true,
                                          paragraph("bar"),
                                          list(listItem("-", tight: true, paragraph("one")),
                                               listItem("-", tight: true, paragraph("two")),
                                               listItem("-", tight: true, paragraph("three")))),
                                 listItem("-", tight: true, paragraph("goo")))))
  }

  func testBlockquoteList() {
    XCTAssertEqual(parseBlocks(">>- one\n>>\n  >  > two"),
                   document(blockquote(blockquote(list(listItem("-", paragraph("one"))),
                                                  paragraph("two")))))
    XCTAssertEqual(parseBlocks("> 1234. > blockquote\n> continued here."),
                   document(blockquote(list(1234, listItem(1234, ".",
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
  
  static let allTests = [
    ("testBlockParserCounts", testBlockParserCounts),
    ("testMinimalTable", testMinimalTable),
    ("testComplexTable", testComplexTable),
    ("testComplexWrappedTable", testComplexWrappedTable),
    ("testTableTermination", testTableTermination),
    ("testNestedTable", testNestedTable),
    ("testDefinitionList", testDefinitionList),
    ("testEmptyDocuments", testEmptyDocuments),
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
