//
//  MarkdownInlineTests.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 09/06/2019.
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

class MarkdownInlineTests: XCTestCase, MarkdownKitFactory {

  private func parse(_ str: String) -> Block {
    return MarkdownParser.standard.parse(str)
  }

  func testDelimiters() {
    XCTAssertEqual(parse("foo`bar"),
                   document(paragraph(.text("foo"),
                                      .delimiter("`", 1, []),
                                      .text("bar"))))
    XCTAssertEqual(parse("*foo bar"),
                   document(paragraph(.delimiter("*", 1, .leftFlanking),
                                      .text("foo bar"))))
    XCTAssertEqual(parse("**foo bar"),
                   document(paragraph(.delimiter("*", 2, .leftFlanking),
                                      .text("foo bar"))))
    XCTAssertEqual(parse("**foo* bar"),
                   document(paragraph(.delimiter("*", 1, .leftFlanking),
                                      emph(.text("foo")),
                                      .text(" bar"))))
    XCTAssertEqual(parse("**foo\\* bar"),
                   document(paragraph(.delimiter("*", 2, .leftFlanking),
                                      .text("foo* bar"))))
    XCTAssertEqual(parse("**foo** bar"),
                   document(paragraph(strong(.text("foo")), .text(" bar"))))
    XCTAssertEqual(parse("```foo` bar`` goo"),
                   document(paragraph(.delimiter("`", 3, []),
                                      .text("foo"),
                                      .delimiter("`", 1, []),
                                      .text(" bar"),
                                      .delimiter("`", 2, []),
                                      .text(" goo"))))
  }

  func testCodeSpans() {
    XCTAssertEqual(parse("foo `bar` goo"),
                   document(paragraph(.text("foo "), .code("bar"), .text(" goo"))))
    XCTAssertEqual(parse("`foo\\`bar`"),
                   document(paragraph(.code("foo\\"), .text("bar"), .delimiter("`", 1, []))))
    XCTAssertEqual(parse("foo `n ```one`` two``` goo"),
                   document(paragraph(.text("foo "),
                                      .delimiter("`", 1, []),
                                      .text("n "),
                                      .code("one`` two"),
                                      .text(" goo"))))
    XCTAssertEqual(parse("foo `n ```one` two``` goo"),
                   document(paragraph(.text("foo "),
                                      .code("n ```one"),
                                      .text(" two"),
                                      .delimiter("`", 3, []),
                                      .text(" goo"))))
    XCTAssertEqual(parse("foo ``n ```one` ` two`\nthree```\n`goo` `bar`"),
                   document(paragraph(.text("foo "),
                                      .delimiter("`", 2, []),
                                      .text("n "),
                                      .code("one` ` two` three"),
                                      .softLineBreak,
                                      .code("goo"),
                                      .text(" "),
                                      .code("bar"))))
  }

  func testAutolinks() {
    XCTAssertEqual(parse("foo <http://lisppad.objecthub.net> bar"),
                   document(paragraph(.text("foo "),
                                      .autolink(.uri, "http://lisppad.objecthub.net"),
                                      .text(" bar"))))
    XCTAssertEqual(parse("foo <ab:>"),
                   document(paragraph(.text("foo "), .autolink(.uri, "ab:"))))
    XCTAssertEqual(parse("foo <ab:\nc>"),
                   document(paragraph(.text("foo "),
                                      .delimiter("<", 1, []),
                                      .text("ab:"),
                                      .softLineBreak,
                                      .text("c"),
                                      .delimiter(">", 1,[]))))
    XCTAssertEqual(parse("foo <test@example.org> bar"),
                   document(paragraph(.text("foo "),
                                      .autolink(.email, "test@example.org"),
                                      .text(" bar"))))
    XCTAssertEqual(parse("<foo+special@Bar.baz-bar0.com>"),
                   document(paragraph(.autolink(.email, "foo+special@Bar.baz-bar0.com"))))
    XCTAssertEqual(parse("foo <www.objecthub.net> bar"),
                   document(paragraph(.text("foo "),
                                      .delimiter("<", 1, []),
                                      .text("www.objecthub.net"),
                                      .delimiter(">", 1,[]),
                                      .text(" bar"))))
  }

  func testXmlTags() {
    XCTAssertEqual(parse("<a><bab><c2c>"),
                   document(paragraph(.html("a"), .html("bab"), .html("c2c"))))
    XCTAssertEqual(parse("<a/><b2/>"),
                   document(paragraph(.html("a/"), .html("b2/"))))
    XCTAssertEqual(parse("<a  /><b2\ndata=\"foo\" >"),
                   document(paragraph(.html("a  /"), .html("b2 data=\"foo\" "))))
    XCTAssertEqual(parse("<a foo=\"bar>\"> foo"),
                   document(paragraph(.html("a foo=\"bar>\""), .text(" foo"))))
    XCTAssertEqual(parse("<a foo=\"bar\" b = 'baz <em>\"</em>' x mk:72=m:7 />"),
                   document(paragraph(.html("a foo=\"bar\" b = 'baz <em>\"</em>' x mk:72=m:7 /"))))
    XCTAssertEqual(parse("<a foo=\"bar\" bam = 'baz <em>\"</em>'\n_b zoop:33=zoop:33 />"),
                   document(paragraph(.html("a foo=\"bar\" bam = 'baz <em>\"</em>' " +
                                            "_b zoop:33=zoop:33 /"))))
    XCTAssertEqual(parse("<33> <__>"),
                   document(paragraph(.delimiter("<", 1, []),
                                      .text("33"),
                                      .delimiter(">", 1, []),
                                      .text(" "),
                                      .delimiter("<", 1, []),
                                      .delimiter("_", 2, [.leftFlanking, .rightFlanking,
                                                          .leftPunctuation, .rightPunctuation]),
                                      .delimiter(">", 1, []))))
    XCTAssertEqual(parse("<a h*#ref=\"hi\">"),
                   document(paragraph(.delimiter("<", 1, []),
                                      .text("a h"),
                                      .delimiter("*", 1, [.rightFlanking, .rightPunctuation]),
                                      .text("#ref="),
                                      .delimiter("\"", 1, []),
                                      .text("hi"),
                                      .delimiter("\"", 1, []),
                                      .delimiter(">", 1, []))))
    XCTAssertEqual(parse("<a href=\"hi'> <a href=hi'>"),
                   document(paragraph(.delimiter("<", 1, []),
                                      .text("a href="),
                                      .delimiter("\"", 1, []),
                                      .text("hi"),
                                      .delimiter("'", 1, []),
                                      .delimiter(">", 1, []),
                                      .text(" "),
                                      .delimiter("<", 1, []),
                                      .text("a href=hi"),
                                      .delimiter("'", 1, []),
                                      .delimiter(">", 1, []))))
    XCTAssertEqual(parse("< a><\nfoo><bar/ >\n<foo bar=baz\nbim!bop />"),
                   document(paragraph(.delimiter("<", 1, []),
                                      .text(" a"),
                                      .delimiter(">", 1, []),
                                      .delimiter("<", 1, []),
                                      .softLineBreak,
                                      .text("foo"),
                                      .delimiter(">", 1, []),
                                      .delimiter("<", 1, []),
                                      .text("bar/ "),
                                      .delimiter(">", 1, []),
                                      .softLineBreak,
                                      .delimiter("<", 1, []),
                                      .text("foo bar=baz"),
                                      .softLineBreak,
                                      .text("bim!bop /"),
                                      .delimiter(">", 1, []))))
    XCTAssertEqual(parse("begin <a x=\"bar\"y='ba>z' z=foo> end"),
                   document(paragraph(.text("begin "),
                                      .delimiter("<", 1, []),
                                      .text("a x="),
                                      .delimiter("\"", 1, []),
                                      .text("bar"),
                                      .delimiter("\"", 1, []),
                                      .text("y="),
                                      .delimiter("'", 1, []),
                                      .text("ba"),
                                      .delimiter(">", 1, []),
                                      .text("z"),
                                      .delimiter("'", 1, []),
                                      .text(" z=foo"),
                                      .delimiter(">", 1, []),
                                      .text(" end"))))
    XCTAssertEqual(parse("begin <a x=\"bar\" y='ba>z' z=foo> end"),
                   document(paragraph(.text("begin "),
                                      .html("a x=\"bar\" y=\'ba>z\' z=foo"),
                                      .text(" end"))))
    XCTAssertEqual(parse("begin <a x=\"\" y  =  'f' z=f  > end"),
                   document(paragraph(.text("begin "),
                                      .html("a x=\"\" y  =  'f' z=f  "),
                                      .text(" end"))))
    XCTAssertEqual(parse("begin <a x> end"),
                   document(paragraph(.text("begin "), .html("a x"), .text(" end"))))
    XCTAssertEqual(parse("</a></foo >"),
                   document(paragraph(.html("/a"), .html("/foo "))))
    XCTAssertEqual(parse("foo <!-- this is a\ncomment - with hyphen -->"),
                   document(paragraph(.text("foo "),
                                      .html("!-- this is a comment - with hyphen --"))))
    XCTAssertEqual(parse("foo <!-- not a comment -- two hyphens -->"),
                   document(paragraph(.text("foo "),
                                      .delimiter("<", 1, []),
                                      .text("!-- not a comment -- two hyphens --"),
                                      .delimiter(">", 1, []))))
    XCTAssertEqual(parse("foo <!--> foo -->\n\nfoo <!-- foo--->"),
                   document(paragraph(.text("foo "),
                                      .delimiter("<", 1, []),
                                      .text("!--"),
                                      .delimiter(">", 1, []),
                                      .text(" foo --"),
                                      .delimiter(">", 1, [])),
                            paragraph(.text("foo "),
                                      .delimiter("<", 1, []),
                                      .text("!-- foo---"),
                                      .delimiter(">", 1, []))))
    XCTAssertEqual(parse("foo <?scheme print $x $y ?>"),
                   document(paragraph(.text("foo "), .html("?scheme print $x $y ?"))))
    XCTAssertEqual(parse("<!ABCDEF foo bar 1>0 >b"),
                   document(paragraph(.html("!ABCDEF foo bar 1"),
                                      .text("0 "),
                                      .delimiter(">", 1, []),
                                      .text("b"))))
    XCTAssertEqual(parse("<!SCALA foo bar 1<0  >b"),
                   document(paragraph(.html("!SCALA foo bar 1<0  "), .text("b"))))
    XCTAssertEqual(parse("  b<![CDATA[>&<]]>"),
                   document(paragraph(.text("b"), .html("![CDATA[>&<]]"))))
  }

  func testSimpleEmphasis() {
    XCTAssertEqual(parse("one *two* three"),
                   document(paragraph(.text("one "), emph(.text("two")), .text(" three"))))
    XCTAssertEqual(parse("one *two *three* four"),
                   document(paragraph(.text("one "),
                                      .delimiter("*", 1, .leftFlanking),
                                      .text("two "),
                                      emph(.text("three")),
                                      .text(" four"))))
    XCTAssertEqual(parse("one **two* three"),
                   document(paragraph(.text("one "),
                                      .delimiter("*", 1, .leftFlanking),
                                      emph(.text("two")),
                                      .text(" three"))))
    XCTAssertEqual(parse("one ***two* three*"),
                   document(paragraph(.text("one "),
                                      .delimiter("*", 1, .leftFlanking),
                                      emph(emph(.text("two")), .text(" three")))))
    XCTAssertEqual(parse("one *two*three*"),
                   document(paragraph(.text("one "),
                                      emph(.text("two")),
                                      .text("three"),
                                      .delimiter("*", 1, .rightFlanking))))
    XCTAssertEqual(parse("foo bar**one *two* three* four**five*six"),
                   document(paragraph(.text("foo bar"),
                                      strong(.text("one "),
                                             emph(.text("two")),
                                             .text(" three"),
                                             .delimiter("*", 1, .rightFlanking),
                                             .text(" four")),
                                      .text("five"),
                                      .delimiter("*", 1, [.leftFlanking, .rightFlanking]),
                                      .text("six"))))
  }

  func testEmphasis() {
    XCTAssertEqual(parse("one * two three*"),
                   document(paragraph(.text("one "),
                                      .delimiter("*", 1, []),
                                      .text(" two three"),
                                      .delimiter("*", 1, .rightFlanking))))
    XCTAssertEqual(parse("a*\"foo\"*"),
                   document(paragraph(.text("a"),
                                      .delimiter("*", 1, [.rightFlanking, .rightPunctuation]),
                                      .delimiter("\"", 1, []),
                                      .text("foo"),
                                      .delimiter("\"", 1, []),
                                      .delimiter("*", 1, [.rightFlanking, .leftPunctuation]))))
    XCTAssertEqual(parse("foo*bar*"),
                   document(paragraph(.text("foo"), emph(.text("bar")))))
    XCTAssertEqual(parse("_foo bar_"),
                   document(paragraph(emph(.text("foo bar")))))
    XCTAssertEqual(parse("превосходство_продукта_"),
                   document(paragraph(.text("превосходство"),
                                      .delimiter("_", 1, [.leftFlanking, .rightFlanking]),
                                      .text("продукта"),
                                      .delimiter("_", 1, .rightFlanking))))
    XCTAssertEqual(parse("foo-_(bar)_"),
                   document(paragraph(.text("foo-"),
                                      emph(.delimiter("(", 1, []),
                                           .text("bar"),
                                           .delimiter(")", 1, [])))))
    XCTAssertEqual(parse("*(*foo)"),
                   document(paragraph(.delimiter("*", 1, .leftFlanking),
                                      .delimiter("(", 1, []),
                                      .delimiter("*", 1, [.leftFlanking, .leftPunctuation]),
                                      .text("foo"),
                                      .delimiter(")", 1, []))))
    XCTAssertEqual(parse("*(*foo*)*"),
                   document(paragraph(emph(.delimiter("(", 1, []),
                                           emph(.text("foo")),
                                           .delimiter(")", 1, [])))))
    XCTAssertEqual(parse("_foo_bar_baz_"),
                   document(paragraph(emph(.text("foo"),
                                           .delimiter("_", 1, [.leftFlanking, .rightFlanking]),
                                           .text("bar"),
                                           .delimiter("_", 1, [.leftFlanking, .rightFlanking]),
                                           .text("baz")))))
    XCTAssertEqual(parse("_(bar)_."),
                   document(paragraph(emph(.delimiter("(", 1, []),
                                           .text("bar"),
                                           .delimiter(")", 1, [])), .text("."))))
    XCTAssertEqual(parse("**one**"),
                   document(paragraph(strong(.text("one")))))
    XCTAssertEqual(parse("foo**bar**"),
                   document(paragraph(.text("foo"), strong(.text("bar")))))
    XCTAssertEqual(parse("foo**bar**"),
                   document(paragraph(.text("foo"), strong(.text("bar")))))
    XCTAssertEqual(parse("__(__foo)"),
                   document(paragraph(.delimiter("_", 2, [.leftFlanking]),
                                      .delimiter("(", 1, []),
                                      .delimiter("_", 2, [.leftFlanking, .leftPunctuation]),
                                      .text("foo"),
                                      .delimiter(")", 1, []))))
    XCTAssertEqual(parse("*foo\nbar*"),
                   document(paragraph(emph(.text("foo"), .softLineBreak, .text("bar")))))
    XCTAssertEqual(parse("_foo __bar__ baz_"),
                   document(paragraph(emph(.text("foo "), strong(.text("bar")), .text(" baz")))))
    XCTAssertEqual(parse("_foo _bar_ baz_"),
                   document(paragraph(emph(.text("foo "), emph(.text("bar")), .text(" baz")))))
    XCTAssertEqual(parse("__foo_ bar_"),
                   document(paragraph(emph(emph(.text("foo")), .text(" bar")))))
    XCTAssertEqual(parse("*foo *bar**"),
                   document(paragraph(emph(.text("foo "), emph(.text("bar"))))))
    XCTAssertEqual(parse("*foo **bar** baz*"),
                   document(paragraph(emph(.text("foo "), strong(.text("bar")), .text(" baz")))))
    XCTAssertEqual(parse("*foo**bar**baz*"),
                   document(paragraph(emph(.text("foo"), strong(.text("bar")), .text("baz")))))
    XCTAssertEqual(parse("*foo**bar*"),
                   document(paragraph(emph(.text("foo"),
                                           .delimiter("*", 2, [.leftFlanking, .rightFlanking]),
                                           .text("bar")))))
    XCTAssertEqual(parse("***foo** bar*"),
                   document(paragraph(emph(strong(.text("foo")), .text(" bar")))))
    XCTAssertEqual(parse("*foo **bar***"),
                   document(paragraph(emph(.text("foo "), strong(.text("bar"))))))
    XCTAssertEqual(parse("*foo**bar***"),
                   document(paragraph(emph(.text("foo"), strong(.text("bar"))))))
    XCTAssertEqual(parse("foo***bar***baz"),
                   document(paragraph(.text("foo"), emph(strong(.text("bar"))), .text("baz"))))
    XCTAssertEqual(parse("foo******bar*********baz"),
                   document(paragraph(.text("foo"),
                                      strong(strong(strong(.text("bar")))),
                                      .delimiter("*", 3, [.leftFlanking, .rightFlanking]),
                                      .text("baz"))))
    XCTAssertEqual(parse("*foo **bar *baz* bim** bop*"),
                   document(paragraph(emph(.text("foo "),
                                           strong(.text("bar "), emph(.text("baz")), .text(" bim")),
                                           .text(" bop")))))
    XCTAssertEqual(parse("** one two"),
                   document(paragraph(.delimiter("*", 2, []), .text(" one two"))))
    XCTAssertEqual(parse("one****two"),
                   document(paragraph(.text("one"),
                                      .delimiter("*", 4, [.leftFlanking, .rightFlanking]),
                                      .text("two"))))
    XCTAssertEqual(parse("**one\ntwo**"),
                   document(paragraph(strong(.text("one"), .softLineBreak, .text("two")))))
    XCTAssertEqual(parse("__foo __bar__ baz__"),
                   document(paragraph(strong(.text("foo "),
                                             strong(.text("bar")),
                                             .text(" baz")))))
    XCTAssertEqual(parse("____foo__ bar__"),
                   document(paragraph(strong(strong(.text("foo")), .text(" bar")))))
    XCTAssertEqual(parse("**foo **bar****"),
                   document(paragraph(strong(.text("foo "), strong(.text("bar"))))))
    XCTAssertEqual(parse("foo ***"),
                   document(paragraph(.text("foo "), .delimiter("*", 3, []))))
    XCTAssertEqual(parse("foo *\\**"),
                   document(paragraph(.text("foo "), emph(.text("*")))))
    XCTAssertEqual(parse("foo *_*"),
                   document(paragraph(
                              .text("foo "),
                              emph(.delimiter("_", 1, [.leftFlanking, .rightFlanking,
                                                       .leftPunctuation, .rightPunctuation])))))
    XCTAssertEqual(parse("***foo*"),
                   document(paragraph(.delimiter("*", 2, [.leftFlanking]),
                                      emph(.text("foo")))))
    XCTAssertEqual(parse("**foo****"),
                   document(paragraph(strong(.text("foo")), .delimiter("*", 2, [.rightFlanking]))))
    XCTAssertEqual(parse("foo ___"),
                   document(paragraph(.text("foo "), .delimiter("_", 3, []))))
    XCTAssertEqual(parse("foo _\\__"),
                   document(paragraph(.text("foo "), emph(.text("_")))))
    XCTAssertEqual(parse("foo _*_"),
                   document(paragraph(
                    .text("foo "),
                    emph(.delimiter("*", 1, [.leftFlanking, .rightFlanking,
                                             .leftPunctuation, .rightPunctuation])))))
    XCTAssertEqual(parse("___foo_"),
                   document(paragraph(.delimiter("_", 2, [.leftFlanking]), emph(.text("foo")))))
    XCTAssertEqual(parse("_foo__"),
                   document(paragraph(emph(.text("foo")), .delimiter("_", 1, .rightFlanking))))
    XCTAssertEqual(parse("*_foo_* _*bar*_"),
                   document(paragraph(emph(emph(.text("foo"))),
                                      .text(" "),
                                      emph(emph(.text("bar"))))))
    XCTAssertEqual(parse("*foo _bar* baz_"),
                   document(paragraph(emph(.text("foo "),
                                           .delimiter("_", 1, .leftFlanking),
                                           .text("bar")),
                                      .text(" baz"),
                                      .delimiter("_", 1, .rightFlanking))))
    XCTAssertEqual(parse("*foo __bar *baz bim__ bam*"),
                   document(paragraph(emph(.text("foo "),
                                           strong(.text("bar "),
                                                  .delimiter("*", 1, .leftFlanking),
                                                  .text("baz bim")),
                                           .text(" bam")))))
    XCTAssertEqual(parse("*foo * __bar *baz _ bim__ bam*"),
                   document(paragraph(emph(.text("foo "),
                                           .delimiter("*", 1, []),
                                           .text(" "),
                                           strong(.text("bar "),
                                                  .delimiter("*", 1, .leftFlanking),
                                                  .text("baz "),
                                                  .delimiter("_", 1, []),
                                                  .text(" bim")),
                                           .text(" bam")))))
    XCTAssertEqual(parse("**foo **bar baz**"),
                   document(paragraph(.delimiter("*", 2, .leftFlanking),
                                      .text("foo "),
                                      strong(.text("bar baz")))))
    XCTAssertEqual(parse("*<img src=\"foo\" title=\"*\"/>"),
                   document(paragraph(.delimiter("*", 1, .leftFlanking),
                                      .html("img src=\"foo\" title=\"*\"/"))))
    XCTAssertEqual(parse("__<a href=\"__\">"),
                   document(paragraph(.delimiter("_", 2, .leftFlanking),
                                      .html("a href=\"__\""))))
    XCTAssertEqual(parse("**a<http://foo.bar/?q=**>"),
                   document(paragraph(.delimiter("*", 2, .leftFlanking),
                                      .text("a"),
                                      .autolink(.uri, "http://foo.bar/?q=**"))))
  }

  func testLinks() {
    XCTAssertEqual(parse("[link](/uri \"title\")"),
                   document(paragraph(link("/uri", "title", .text("link")))))
    XCTAssertEqual(parse("[link](/uri)"),
                   document(paragraph(link("/uri", nil, .text("link")))))
    XCTAssertEqual(parse("[link]()"), document(paragraph(link(nil, nil, .text("link")))))
    XCTAssertEqual(parse("[link](<>)"), document(paragraph(link(nil, nil, .text("link")))))
    XCTAssertEqual(parse("[link](/my uri)"),
                   document(paragraph(.delimiter("[", 1, []),
                                      .text("link"),
                                      .delimiter("]", 1, []),
                                      .delimiter("(", 1, []),
                                      .text("/my uri"),
                                      .delimiter(")", 1, []))))
    XCTAssertEqual(parse("[link](</my uri>)"),
                   document(paragraph(link("/my uri", nil, .text("link")))))
    XCTAssertEqual(parse("[link](foo\nbar)"),
                   document(paragraph(.delimiter("[", 1, []),
                                      .text("link"),
                                      .delimiter("]", 1, []),
                                      .delimiter("(", 1, []),
                                      .text("foo"),
                                      .softLineBreak,
                                      .text("bar"),
                                      .delimiter(")", 1, []))))
    XCTAssertEqual(parse("[a](<b)c>)"),
                   document(paragraph(link("b)c", nil, .text("a")))))
    XCTAssertEqual(parse("[link](<foo\\>)"),
                   document(paragraph(.delimiter("[", 1, []),
                                      .text("link"),
                                      .delimiter("]", 1, []),
                                      .delimiter("(", 1, []),
                                      .delimiter("<", 1, []),
                                      .text("foo>"),
                                      .delimiter(")", 1, []))))
    XCTAssertEqual(parse("[link](\\(foo\\))"),
                   document(paragraph(link("\\(foo\\)", nil, .text("link")))))
    XCTAssertEqual(parse("[link](foo(and(bar)))"),
                   document(paragraph(link("foo(and(bar))", nil, .text("link")))))
    XCTAssertEqual(parse("[link](foo\\(and\\(bar\\))"),
                   document(paragraph(link("foo\\(and\\(bar\\)", nil, .text("link")))))
    XCTAssertEqual(parse("[link](<foo(and(bar)>)"),
                   document(paragraph(link("foo(and(bar)", nil, .text("link")))))
    XCTAssertEqual(parse("[link](foo\\)\\:)"),
                   document(paragraph(link("foo\\)\\:", nil, .text("link")))))
    XCTAssertEqual(parse("[link](http://example.com?foo=3#frag)"),
                   document(paragraph(link("http://example.com?foo=3#frag", nil, .text("link")))))
    XCTAssertEqual(parse("[link](\"title\")"),
                   document(paragraph(link("\"title\"", nil, .text("link")))))
    XCTAssertEqual(parse("[link](/url 'title')"),
                   document(paragraph(link("/url", "title", .text("link")))))
    XCTAssertEqual(parse("[link](/url (title))"),
                   document(paragraph(link("/url", "title", .text("link")))))
    XCTAssertEqual(parse("[link](   /uri\n  \"title\"  )"),
                   document(paragraph(link("/uri", "title", .text("link")))))
    XCTAssertEqual(parse("[link] (/uri)"),
                   document(paragraph(.delimiter("[", 1, []),
                                      .text("link"),
                                      .delimiter("]", 1, []),
                                      .text(" "),
                                      .delimiter("(", 1, []),
                                      .text("/uri"),
                                      .delimiter(")", 1, []))))
    XCTAssertEqual(parse("[link [foo [bar]]](/uri)"),
                   document(paragraph(link("/uri", nil, .text("link "),
                                                        .delimiter("[", 1, []),
                                                        .text("foo "),
                                                        .delimiter("[", 1, []),
                                                        .text("bar"),
                                                        .delimiter("]", 1, []),
                                                        .delimiter("]", 1, [])))))
    XCTAssertEqual(parse("[link] bar](/uri)"),
                   document(paragraph(.delimiter("[", 1, []),
                                      .text("link"),
                                      .delimiter("]", 1, []),
                                      .text(" bar"),
                                      .delimiter("]", 1, []),
                                      .delimiter("(", 1, []),
                                      .text("/uri"),
                                      .delimiter(")", 1, []))))
    XCTAssertEqual(parse("[link [bar](/uri)"),
                   document(paragraph(.delimiter("[", 1, []),
                                      .text("link "),
                                      link("/uri", nil, .text("bar")))))
    XCTAssertEqual(parse("[link \\[bar](/uri)"),
                   document(paragraph(link("/uri", nil, .text("link [bar")))))
    XCTAssertEqual(parse("[link *foo **bar** `#`*](/uri)"),
                   document(paragraph(link("/uri", nil, .text("link "),
                                                        emph(.text("foo "),
                                                             strong(.text("bar")),
                                                             .text(" "),
                                                             .code("#"))))))
    XCTAssertEqual(parse("[foo [bar](/uri)](/uri)"),
                   document(paragraph(.delimiter("[", 1, []),
                                      .text("foo "),
                                      link("/uri", nil, .text("bar")),
                                      .delimiter("]", 1, []),
                                      .delimiter("(", 1, []),
                                      .text("/uri"),
                                      .delimiter(")", 1, []))))
    XCTAssertEqual(parse("*[foo*](/uri)`end`"),
                   document(paragraph(.delimiter("*", 1, .leftFlanking),
                                      link("/uri", nil,
                                           .text("foo"),
                                           .delimiter("*", 1, [.rightFlanking, .rightPunctuation])),
                                      .code("end"))))
    XCTAssertEqual(parse("one [foo *bar](baz*) two"),
                   document(paragraph(.text("one "),
                                      link("baz*", nil, .text("foo "),
                                                        .delimiter("*", 1, .leftFlanking),
                                                        .text("bar")),
                                      .text(" two"))))
    XCTAssertEqual(parse("*foo [bar* baz]"),
                   document(paragraph(emph(.text("foo "),
                                           .delimiter("[", 1, []),
                                           .text("bar")),
                                      .text(" baz"),
                                      .delimiter("]", 1, []))))
    XCTAssertEqual(parse("[foo <bar attr=\"](baz)\">"),
                   document(paragraph(.delimiter("[", 1, []),
                                      .text("foo "),
                                      .html("bar attr=\"](baz)\""))))
    XCTAssertEqual(parse("[foo`](/uri)`"),
                   document(paragraph(.delimiter("[", 1, []),
                                      .text("foo"),
                                      .code("](/uri)"))))
    XCTAssertEqual(parse("[foo<http://example.com/?search=](uri)>"),
                   document(paragraph(.delimiter("[", 1, []),
                                      .text("foo"),
                                      .autolink(.uri, "http://example.com/?search=](uri)"))))
    XCTAssertEqual(parse("[one ![my image](/foo/bar/pic.png) two](/uri \"title\")"),
                   document(paragraph(link("/uri", "title",
                                           .text("one "),
                                           image("/foo/bar/pic.png", nil, .text("my image")),
                                           .text(" two")))))
  }

  func testImages() {
    XCTAssertEqual(parse("![image description](/uri \"title\")"),
                   document(paragraph(image("/uri", "title", .text("image description")))))
    XCTAssertEqual(parse("![foo ![bar](/url)](/url2)"),
                   document(paragraph(image("/url2", nil, .text("foo "),
                                                          image("/url", nil, .text("bar"))))))
    XCTAssertEqual(parse("![foo [bar](/url)](/url2)"),
                   document(paragraph(image("/url2", nil, .text("foo "),
                                                          link("/url", nil, .text("bar"))))))
    XCTAssertEqual(parse("one ![foo](train.jpg) two"),
                   document(paragraph(.text("one "),
                                      image("train.jpg", nil, .text("foo")),
                                      .text(" two"))))
    XCTAssertEqual(parse("My ![foo bar](/path/to/train.jpg  \"title\"   )"),
                   document(paragraph(.text("My "),
                                      image("/path/to/train.jpg", "title", .text("foo bar")))))
    XCTAssertEqual(parse("![](/url)"), document(paragraph(image("/url", nil))))
  }

  func testCombinations() {
    XCTAssertEqual(parse("One\n- Two (three `four`)"),
                   document(paragraph(.text("One")),
                            list(listItem("-", tight: true, paragraph(.text("Two "),
                                                                      .delimiter("(", 1, []),
                                                                      .text("three "),
                                                                      .code("four"),
                                                                      .delimiter(")", 1, []))))))
  }

  func testLinkRef() {
    XCTAssertEqual(parse("[foo]: /url \"title\"\n\n[bar][foo]"),
                   document(referenceDef("foo", "/url", "title"),
                            paragraph(.link(Text("bar"), "/url", "title"))))
    XCTAssertEqual(parse("[one *two* __three__][Bar]\n\n[bar]: /url \"title\""),
                   document(paragraph(link("/url", "title", .text("one "),
                                                            emph(.text("two")),
                                                            .text(" "),
                                                            strong(.text("three")))),
                            referenceDef("bar", "/url", "title")))
    XCTAssertEqual(parse("[link [foo [bar]]][ref]\n\n[ref]: /uri"),
                   document(paragraph(link("/uri", nil, .text("link "),
                                                        .delimiter("[", 1, []),
                                                        .text("foo "),
                                                        .delimiter("[", 1, []),
                                                        .text("bar"),
                                                        .delimiter("]", 1, []),
                                                        .delimiter("]", 1, []))),
                            referenceDef("ref", "/uri")))
    XCTAssertEqual(parse("[![moon](moon.jpg)][ref]\n\n[ref]: /uri"),
                   document(paragraph(link("/uri", nil, image("moon.jpg", nil, .text("moon")))),
                            referenceDef("ref", "/uri")))
    XCTAssertEqual(parse("[foo]: /url \"title\"\n\n[foo]bar"),
                   document(referenceDef("foo", "/url", "title"),
                            paragraph(.link(Text("foo"), "/url", "title"),
                                      .text("bar"))))
    XCTAssertEqual(parse("[*foo* baz]: /url \"title\"\n\n[*foo* baz]bar"),
                   document(referenceDef("*foo* baz", "/url", "title"),
                            paragraph(link("/url", "title", emph(.text("foo")), .text(" baz")),
                                      .text("bar"))))
  }

  func testEscaping() {
    XCTAssertEqual(parse("foo\\bar"),
                   document(paragraph(.text("foobar"))))
    XCTAssertEqual(parse("foo\\\\bar"),
                   document(paragraph(.text("foo\\bar"))))
    XCTAssertEqual(parse("foo\\\\\\bar"),
                   document(paragraph(.text("foo\\bar"))))
    XCTAssertEqual(parse("foo\\\\\\\\bar"),
                   document(paragraph(.text("foo\\\\bar"))))
    XCTAssertEqual(parse("foo bar\\"),
                   document(paragraph(.text("foo bar"))))
    XCTAssertEqual(parse("foo bar\\\nbaz"),
                   document(paragraph(.text("foo bar"),
                                      .hardLineBreak,
                                      .text("baz"))))
    XCTAssertEqual(parse("foo bar\\\\\nbaz"),
                   document(paragraph(.text("foo bar"),
                                      .hardLineBreak,
                                      .text("baz"))))
  }

  func testDebug() {

  }
  
  static let allTests = [
    ("testDelimiters", testDelimiters),
    ("testCodeSpans", testCodeSpans),
    ("testAutolinks", testAutolinks),
    ("testXmlTags", testXmlTags),
    ("testSimpleEmphasis", testSimpleEmphasis),
    ("testEmphasis", testEmphasis),
    ("testLinks", testLinks),
    ("testImages", testImages),
    ("testCombinations", testCombinations),
    ("testLinkRef", testLinkRef),
    ("testEscaping", testEscaping),
  ]
}
