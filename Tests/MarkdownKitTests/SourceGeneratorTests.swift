//
//  SourceGeneratorTests.swift
//  MarkdownKitTests
//
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
import Foundation
import CommandLineKit
@testable import MarkdownKit

/// Tests of `SourceGenerator`: the source it writes parses back into the same syntax tree
/// (`roundTrips`) for the CommonMark examples, the Markdown documents of the repository, and a
/// table of cases that covers every rule of the generator. The first test shows the cases.
class SourceGeneratorTests: XCTestCase {

  // MARK: The cases

  /// Sources which exercise one rule of the generator each (the name tells which). Every case
  /// has to round-trip in every dialect, and the source has to be a fixed point.
  static let cases: [(String, String)] = [

    // tables
    ("T1 pipes in code, links, autolinks", "| a\\|b | `c\\|d` |\n|---|---|\n| [x](u\\|v) | <http://a\\|b> |"),
    ("T2 trailing backslash in cell", "| a | b |\n|:--|--:|\n| x\\\\ | y |"),
    ("T3 empty cells", "| a | b |\n|---|---|\n|  |  |\n| c |"),
    ("T4 no outer pipes", "a | b\n--- | ---\n1 | 2"),
    ("T5 math in cell", "| $a\\|b$ | c |\n|---|---|\n| d | e |"),
    ("T6 markup in cells", "| *a* | **b** |\n|:-:|---|\n| ~~c~~ | `d` |"),
    ("T7 table in item", "- | a |\n  |---|\n  | b |\n- x"),
    ("T8 table in quote", "> | a |\n> |---|\n> | b |"),
    ("T9 table after paragraph", "para\n| a | b |\n|---|---|\n| 1 | 2 |"),
    ("T10 table then list", "| a |\n|---|\n| b |\n- x"),
    ("T11 literal pipes in text", "a | b and c \\| d\n\ne \\|---|"),
    // lists and blank lines
    ("L1 mixed density", "- a\n- b\n\n- c"),
    ("L2 ordered", "1. a\n2. b\n3. c"),
    ("L3 tight after paragraph", "foo\n- bar\n- baz"),
    ("L4 nested loose", "- a\n  - b\n\n  - c\n- d"),
    ("L5 two paragraphs in item", "- a\n\n  b\n- c"),
    ("L6 blank > lines", "> a\n>\n> - b\n>\n> - c"),
    ("L7 quote with list after paragraph", "foo\n> - a\n> - b"),
    ("L8 different bullets", "- a\n+ b\n* c"),
    ("L9 two delimiters", "1. a\n1) b"),
    ("L10 empty first line", "-\n  foo"),
    ("L11 empty item", "- \n\n- b"),
    ("L12 nested on next line", "+\n  - x"),
    ("L13 heading in item", "- # h\n  para"),
    ("L14 tight item with nested list", "- a\n  - b\n  - c\n- d"),
    ("L15 definition lists", "Term\n: d1\n: d2\n\nTerm 2\n: x"),
    ("L16 blank between term and description", "Term\n\n: d"),
    ("L17 task lists", "- [ ] a\n- [x] b\n  - [ ] c"),
    ("L18 code after list", "- a\n\n      code"),
    ("L19 indented code sibling", "- a\n\n\n    code\n"),
    ("L20 html after list", "- a\n\n   <div>x</div>"),
    ("L21 loose item with tight nested", "- a\n  - b\n\n  c\n"),
    ("L22 list after heading", "# h\n- a\n- b"),
    ("L23 quote lists", "> - a\n>   - b\n> - c"),
    ("L24 ordered start", "7. a\n8. b"),
    ("L25 thematic in items", "- ***\n* ---\n+ ___"),
    ("L26 list in quote in list", "- > - a\n  > - b"),
    // inline
    ("L27 loose item opening with a tight list", "- a\n- - b\n\n  c"),
    ("L28 list opening with a tight list after paragraph", "x\n- - b\n\n  c"),
    ("L29 code sibling after list", " -    one\n\n     two\n"),
    ("L31 ordered code sibling", "1. a\n\n  2. b\n\n    3. c\n"),
    ("L30 html sibling after list", "-   a\n\n   <!X\n"),
    ("I1 snake_case", "snake_case and *emph* and 2 * 3 and a_b_c"),
    ("I2 intraword", "a*b*c **d**e"),
    ("I3 adjacent emph", "*a*_b_"),
    ("I4 strong(emph)", "**_x_**"),
    ("I5 emph(strong)", "_**x**_ ***y***"),
    ("I6 code spans", "`` `a` `` and `` ` `` and `  a  ` and ` a`"),
    ("I7 link forms", "[a](<b c> \"t\") [a](b(c)d) [a](<b)c>) [a](\\<b) [a](<> \"t\") ![a](b \"t\")"),
    ("I8 link dest specials", "[a](http://x/a_b*c) [a](x\\)y) [a](a\\[b\\]c) [a](`x`)"),
    ("I9 autolinks", "<http://x.y/a_b> <a@b.c> <x@y.z>"),
    ("I10 inline html", "a <span class=\"x\">b</span> <br/> c <!-- d --> e"),
    ("I11 hard breaks", "a\\\nb  \nc\n`d`\\\ne\n<b>x</b>\\\ny\n*z*  \nw"),
    ("I12 entities", "&amp; &copy; \\&amp; &#35; \\&#35;"),
    ("I13 escapes", "\\* \\_ \\` \\[ \\] \\< \\> \\# \\\\ \\! \\| \\~"),
    ("I14 line starts", "\\# a\n\\> b\n\\- c\n\\+ d\n\\= e\n1\\. f\n2\\) g\n\\~~~h\n\\: i"),
    ("I15 bang before link", "\\![a](b) and !\\[a](b)"),
    ("I16 backslash cases", "a\\\\b \\\\* c\\\\\nd"),
    ("I17 nested emph in link", "[*a* **b** `c`](u) *[a](u)*"),
    ("I18 image in link", "[![a](b)](c)"),
    ("I19 titles", "[a](b 'x\"y') [a](b (x)) [a](b \"x\\\"y\")"),
    ("I20 reference links", "[a][b] [b] [c][]\n\n[b]: /u \"t\"\n[c]: <d e>"),
    ("I21 literal brackets", "[1] and [a [b] c] and \\[x] and a]b and [x"),
    ("I22 brackets with ref", "\\[foo] and [bar]\n\n[foo]: /u"),
    ("I23 underline strike", "~a~ ~~b~~ x~y~z ~~*c*~~ *~d~*"),
    ("I24 lt gt", "a < b > c <3 <b> x<y"),
    ("I25 dollars", "costs $5 and $6, $x$ and $$y$$ and $`z`$"),
    ("I26 ordered-like lines", "a\n1. b\n2) c\nd 3. e"),
    // headings and breaks
    ("H1 atx", "# a #\n## b \\#\n### \\#\n####\n##### \\## x"),
    ("H2 setext", "a\nb\n===\n\n*c\nd*\n---"),
    ("H3 empty and escapes", "#\n\n# \\\n\n# a\\\\"),
    ("H4 heading with code and link", "# `a` [b](c) *d*"),
    // code
    ("C1 indented", "    a\n\n    b\n  \n    c"),
    ("C2 whitespace lines", "    a\n      \n    b"),
    ("C3 fenced info", "```c++ {x}\na\n```\n\n~~~ a`b\nc\n~~~"),
    ("C4 fence longer", "````\n```\n````\n\n~~~~\n~~~\n~~~~"),
    ("C5 unclosed eof", "```\nx"),
    ("C6 indented eof", "    a"),
    ("C7 crlf", "```\r\nx\r\n```\r\n\r\n    y\r\n\r\nz\r\n"),
    ("C8 info escapes", "``` a\\&b &amp; \\\\x\nc\n```"),
    ("C9 code in item and quote", "- ```\n  x\n\n  y\n  ```\n\n> ```\n> a\n>\n> b\n> ```"),
    ("C10 tabs", "\ta\n\n- b\n\n\tc"),
    // html blocks
    ("B1 div", "<div>\nx\n</div>\n\ny"),
    ("B2 comment with blank", "<!-- a\n\nb -->\nc"),
    ("B3 pre with blank", "<pre>\n\nx\n</pre>\n\nz"),
    ("B4 html in item", "- <div>\n  x\n  </div>\n- b"),
    ("B5 comment then list", "<!-- c -->\n- a"),
    ("B6 html then paragraph", "<!-- c -->\nfoo"),
    ("B7 type 7", "<custom-tag>\nx\n\ny"),
    // reference definitions, quotes, breaks
    ("R1 defs", "[a]: <b c> 'x'\n[A]: y\n\n[z]: /u (t)"),
    ("R2 multiline title", "[a]: b \"x\ny\"\n\n[c]: d"),
    ("R3 label escapes", "[a\\]b]: c\n\n[a\\]b]"),
    ("R4 title quotes", "[a]: /u 'it\"s'\n[b]: /u \"it's\"\n[c]: /u (a\\)b)"),
    ("Q1 quotes", ">\n\n> > a\n>\n> b\n\n> a\n\n> b"),
    ("Q2 lazy", "> a\nb\n\n> c\n> d"),
    ("Z1 thematic", "***\n\n---\n\n___\n\n* * *"),
    ("Z2 hr between paragraphs", "a\n\n***\n\nb"),
    // math
    ("M1 inline", "$a$ and $$b$$ and $`c`$"),
    ("M2 latex inline", "\\(x\\) and \\[y\\] and \\\\(z\\\\)"),
    ("M3 not a block", "$$\nx\n\ny\n$$"),
    ("M4 fenced math", "```math\nx\n\ny\n```"),
    ("M5 block", "$$\n  x\n$$\n\n$$a\nb$$\n\n$$\nc\n$$"),
    ("M6 prices", "a $5 b and $6 c"),
    ("M7 digit after", "$x$5 and $x$ 5"),
    ("M8 latex block", "\\[\nx\n\\]\n\n\\[ y \\]"),
    ("M9 citation then formula", "see [1] and [2] for \\[x^2\\] and \\(y\\)"),
    ("M10 math in cell and heading", "# $a$ b\n\n| $x$ |\n|---|\n| $$y$$ |"),
    ("M11 multiline inline", "a $x\n+ y$ b"),
    ("M12 math in emph and link", "*$a$* [$b$](c) **$$d$$**"),
    ("B8 open html at end of item", "- <!--\n  x\ny"),
    ("B9 html closed by marker then list", "<!X>\n-\n"),
    ("I27 lone colon", "\\:\n\n\\: x\n\nTerm\n\\: y"),
    ("I28 inline html at start of continuation", "a\n    </div>\nb"),
    ("I29 verbatim continuation", "a <!-- x\n    - y\n    -->"),
    ("H5 setext with math", "$a\nb$ x\n==="),
    ("M14 block with trailing space", "```math\na \nb\n```"),
    ("M13 math with specials", "$a_b * c <d> | e$ and $\\{x\\}$"),

  ]

  /// Returns a description of the problem if the source written for the tree that `dialect`
  /// parses from `source` does not parse back into it, or if writing it again changes it.
  private func problem(_ dialect: MarkdownDialect,
                       _ source: String,
                       generator: SourceGenerator? = nil) -> String? {
    let generator = generator ?? dialect.sourceGenerator
    let doc = dialect.parser.parse(source)
    if let mismatch = generator.firstMismatch(of: doc) {
      return mismatch
    }
    let output = generator.generate(doc: doc)
    if generator.generate(doc: dialect.parser.parse(output)) != output {
      return "the output is not a fixed point"
    }
    return nil
  }

  func testCases() {
    XCTAssertEqual(Self.cases.count, 117)
    for (name, source) in Self.cases {
      for dialect in MarkdownDialect.allCases {
        if let problem = self.problem(dialect, source) {
          XCTFail("\(name) (\(dialect)): \(problem); source \(source.debugDescription)")
        }
      }
    }
  }

  // MARK: CommonMark examples and documents

  private struct Example: Decodable {
    let markdown: String
    let example: Int
  }

  private func loadExamples() throws -> [Example] {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: SourceGeneratorTests.self)
    #endif
    let url = try XCTUnwrap(bundle.url(forResource: "commonmark-spec-0.31.2",
                                       withExtension: "json"))
    return try JSONDecoder().decode([Example].self, from: Data(contentsOf: url))
  }

  /// The examples which cannot be written back, with the reason. 200: a reference to a definition
  /// with an empty destination has the destination "", which no inline link has. 417: emphasis
  /// next to runs of delimiters whose length changes when they are escaped. 520: in the syntax with
  /// LaTeX, a literal bracket pair which contains a link is escaped, and `\[` starts a formula.
  private func knownFailures(_ dialect: MarkdownDialect) -> Set<Int> {
    return dialect == .fullLaTeX ? [200, 417, 520] : [200, 417]
  }

  private func failures(_ dialect: MarkdownDialect, in documents: [(Int, String)]) -> Set<Int> {
    let generator = dialect.sourceGenerator
    var res = Set<Int>()
    for (id, source) in documents where !generator.roundTrips(dialect.parser.parse(source)) {
      res.insert(id)
    }
    return res
  }

  func testCommonMarkExamples() throws {
    let examples = try self.loadExamples()
    XCTAssertEqual(examples.count, 652)
    let documents = examples.map { ($0.example, $0.markdown) }
    for dialect in MarkdownDialect.allCases {
      XCTAssertEqual(self.failures(dialect, in: documents), self.knownFailures(dialect),
                     "\(dialect)")
    }
  }

  func testLineEndingsOfCommonMarkExamples() throws {
    let documents = try self.loadExamples().map { ($0.example, $0.markdown) }
    let variants: [(String, ((String) -> String))] = [
      ("CRLF", { $0.replacingOccurrences(of: "\n", with: "\r\n") }),
      ("CR", { $0.replacingOccurrences(of: "\n", with: "\r") }),
      ("no final newline", { $0.hasSuffix("\n") ? String($0.dropLast()) : $0 })
    ]
    for (name, variant) in variants {
      for dialect in MarkdownDialect.allCases {
        XCTAssertEqual(self.failures(dialect, in: documents.map { ($0.0, variant($0.1)) }),
                       self.knownFailures(dialect), "\(name), \(dialect)")
      }
    }
  }

  /// The Markdown documents of the repository, if the tests run in a checkout.
  private func repositoryDocuments() -> [(String, String)] {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<3 {
      root.deleteLastPathComponent()
    }
    var paths = ["README.md", "CHANGELOG.md", "CONTRIBUTING.md", "Examples/Demo.md"]
    if let files = FileManager.default.enumerator(atPath: root.path + "/Sources") {
      for case let file as String in files where file.hasSuffix(".md") {
        paths.append("Sources/" + file)
      }
    }
    return paths.compactMap { path in
      (try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)).map { (path, $0) }
    }
  }

  func testDocumentsOfTheRepository() throws {
    let documents = self.repositoryDocuments()
    try XCTSkipIf(documents.count < 10, "The Markdown documents of the repository are missing")
    for (path, source) in documents {
      for dialect in MarkdownDialect.allCases {
        XCTAssertNil(self.problem(dialect, source), "\(path), \(dialect)")
        XCTAssertNil(self.problem(dialect, source.replacingOccurrences(of: "\n", with: "\r\n")),
                     "\(path) with CRLF, \(dialect)")
      }
    }
  }

  // MARK: Normalization

  func testNormalizedTextMergesFragments() {
    let doc = MarkdownParser.standard.parse("a (b) c and \\(b\\) c")
    guard case .document(let blocks) = doc, case .paragraph(let text) = blocks[0] else {
      return XCTFail("not a paragraph")
    }
    XCTAssertGreaterThan(text.count, 1)
    XCTAssertEqual(text.normalized.count, 1)
    XCTAssertEqual(text.normalized.rawDescription, "a (b) c and (b) c")
    XCTAssertEqual(MarkdownParser.standard.parse("a (b) c").normalized,
                   MarkdownParser.standard.parse("a \\(b\\) c").normalized)
    XCTAssertNotEqual(MarkdownParser.standard.parse("a (b) c"),
                      MarkdownParser.standard.parse("a \\(b\\) c"))
  }

  func testNormalizedBlocksUseLineFeeds() {
    let doc = MarkdownParser.standard.parse("```\r\nx\r\n```\r\n\r\n    y\r\n\r\n<!--\r\nz -->\r\n")
    XCTAssertNotEqual(doc, doc.normalized)
    XCTAssertEqual(doc.normalized,
                   MarkdownParser.standard.parse("```\nx\n```\n\n    y\n\n<!--\nz -->\n").normalized)
    XCTAssertEqual(doc.normalized, .document([.fencedCode(nil, ["x\n"]),
                                              .indentedCode(["y\n"]),
                                              .htmlBlock(["<!--\n", "z -->\n"])]))
  }

  // MARK: Syntax and dialects

  func testSyntaxOfDialects() {
    XCTAssertEqual(MarkdownDialect.commonMark.syntax, [])
    XCTAssertEqual(MarkdownDialect.extendedCommonMark.syntax, [.tables, .definitionLists])
    XCTAssertTrue(MarkdownDialect.full.syntax.isSuperset(of: MarkdownDialect.extendedCommonMark.syntax))
    XCTAssertEqual(MarkdownDialect.full.syntax.union(.math), MarkdownDialect.fullMath.syntax)
    XCTAssertEqual(MarkdownDialect.fullMath.syntax.union(.latexMath), MarkdownDialect.fullLaTeX.syntax)
    XCTAssertEqual(SourceGenerator.standard.syntax, .fullLaTeX)
    XCTAssertEqual(MarkdownDialect.full.sourceGenerator.syntax, MarkdownDialect.full.syntax)
    XCTAssertTrue(SourceGenerator(dialect: .full).parser === FullMarkdownParser.standard)
  }

  // MARK: Unusual documents

  func testEmptyAndSingleBlocks() {
    let generator = SourceGenerator.standard
    XCTAssertEqual(generator.generate(doc: .document([])), "")
    XCTAssertEqual(generator.generate(doc: .paragraph(Text("a *b*"))), "a \\*b\\*\n")
    XCTAssertEqual(generator.generate(doc: .thematicBreak), "***\n")
    XCTAssertEqual(generator.generate(doc: .document([.paragraph(Text("a")), .thematicBreak])),
                   "a\n\n***\n")
    XCTAssertTrue(generator.roundTrips(.document([])))
  }

  func testSourceWithoutFinalNewline() {
    // The last line of the parser has no terminator, which the tree keeps
    for (source, expected) in [("```\nx", "```\nx"),
                               ("    a", "    a"),
                               ("<!-- a", "<!-- a"),
                               ("> ```\n> x", "> ```\n> x"),
                               ("- ```\n  x", "- ```\n  x"),
                               ("```\nx\n", "```\nx\n```\n")] {
      for dialect in MarkdownDialect.allCases {
        let doc = dialect.parser.parse(source)
        XCTAssertEqual(dialect.sourceGenerator.generate(doc: doc), expected, source.debugDescription)
        XCTAssertTrue(dialect.sourceGenerator.roundTrips(doc), source.debugDescription)
      }
    }
  }

  func testTreesThatCannotBeWritten() {
    let tree = { (dialect: MarkdownDialect, source: String) in dialect.parser.parse(source) }
    // The destination "" only exists for a reference to a definition with an empty destination
    XCTAssertFalse(SourceGenerator.standard.roundTrips(tree(.full, "[foo]: <>\n\n[foo]")))
    XCTAssertNotNil(SourceGenerator.standard.firstMismatch(of: tree(.full, "[foo]: <>\n\n[foo]")))
    // Odd emphasis
    XCTAssertFalse(SourceGenerator.standard.roundTrips(tree(.full, "foo******bar*********baz")))
    // A fenced code block with the info string `math` is a formula for the parser of formulas
    let code = Block.document([.fencedCode("math", ["x\n"])])
    XCTAssertTrue(MarkdownDialect.full.sourceGenerator.roundTrips(code))
    XCTAssertFalse(MarkdownDialect.fullMath.sourceGenerator.roundTrips(code))
    // A formula in a syntax without formulas
    let math = tree(.fullMath, "$x$ and\n\n$$\ny\n$$")
    XCTAssertTrue(MarkdownDialect.fullMath.sourceGenerator.roundTrips(math))
    XCTAssertFalse(MarkdownDialect.full.sourceGenerator.roundTrips(math))
  }

  func testSyntaxThatIsMissingIsWrittenAsNearestConstruct() {
    let source = "~a~ and ~~b~~\n\n- [x] done\n\n| a | b |\n|---|---|\n| c | d |\n\nTerm\n: Definition\n"
    let doc = MarkdownDialect.full.parser.parse(source)
    XCTAssertTrue(MarkdownDialect.full.sourceGenerator.roundTrips(doc))
    let commonMark = SourceGenerator(dialect: .commonMark)
    XCTAssertFalse(commonMark.roundTrips(doc))
    let result = commonMark.generate(doc: doc)
    XCTAssertEqual(result, "a and b\n\n- \\[x] done\n\n" +
                           "a | b\n\nc | d\n\nTerm\n\nDefinition\n")
    // The result is valid CommonMark: it parses without losing the text
    XCTAssertEqual(MarkdownDialect.commonMark.parser.parse(result).string.contains("done"), true)
  }

  // MARK: Readable output

  func testOutputOfProseIsReadable() {
    let source = "Costs $5 and $6 (or less), it's snake_case with 2 * 3 = 6 and a < b > c. " +
                 "See [1] and [the docs](http://x.y/a_b) for C:\\\\path & more! 50% of #tags."
    let expected = "Costs $5 and $6 (or less), it's snake_case with 2 \\* 3 = 6 and a \\< b > c. " +
                   "See [1] and [the docs](http://x.y/a_b) for C:\\\\path & more! 50% of #tags.\n"
    XCTAssertEqual(SourceGenerator(dialect: .commonMark)
                     .generate(doc: MarkdownDialect.commonMark.parser.parse(source)), expected)
    // Dollar signs are escaped if the syntax has formulas
    let latex = SourceGenerator.standard.generate(doc: MarkdownDialect.fullLaTeX.parser.parse(source))
    XCTAssertEqual(latex, expected.replacingOccurrences(of: "$", with: "\\$"))
  }

  func testDifferentSyntaxChangesTheEscapes() {
    let doc = MarkdownDialect.commonMark.parser.parse("a ~ b | c $d$ ~~~ e")
    XCTAssertEqual(SourceGenerator(dialect: .commonMark).generate(doc: doc), "a ~ b | c $d$ ~~~ e\n")
    XCTAssertEqual(SourceGenerator(dialect: .extendedCommonMark).generate(doc: doc),
                   "a ~ b \\| c $d$ ~~~ e\n")
    XCTAssertEqual(SourceGenerator(dialect: .full).generate(doc: doc),
                   "a \\~ b \\| c $d$ \\~\\~\\~ e\n")
    XCTAssertEqual(SourceGenerator(dialect: .fullMath).generate(doc: doc),
                   "a \\~ b \\| c \\$d\\$ \\~\\~\\~ e\n")
    // A line that starts with `~~~` is a fence in every syntax
    XCTAssertEqual(SourceGenerator(dialect: .commonMark).generate(
                     doc: .paragraph(Text("~~~ x"))), "\\~~~ x\n")
  }

  func testInfoStringsOfFencedCodeBlocks() {
    for source in ["``` &#32;a\nx\n```", "```a&#9;\nx\n```", "``` a\\&amp; b\\\\ \nx\n```",
                   "~~~ a`b\nx\n~~~", "```` x\n```\n````"] {
      for dialect in MarkdownDialect.allCases {
        XCTAssertNil(self.problem(dialect, source), "\(dialect): \(source.debugDescription)")
      }
    }
    let doc = MarkdownDialect.full.parser.parse("``` &#32;a\nx\n```")
    XCTAssertEqual(doc, .document([.fencedCode(" a", ["x\n"])]))
    XCTAssertEqual(SourceGenerator.standard.generate(doc: doc), "```&#32;a\nx\n```\n")
  }

  // MARK: Overriding

  private class StarsGenerator: SourceGenerator, @unchecked Sendable {
    override func generate(block: Block, parent: Parent) -> [String] {
      if case .thematicBreak = block {
        return ["___"]
      }
      return super.generate(block: block, parent: parent)
    }
    override func generate(textFragment fragment: TextFragment, in context: InlineContext) -> String {
      if case .code(let code) = fragment {
        return "``" + code + "``"
      }
      return super.generate(textFragment: fragment, in: context)
    }
  }

  func testGeneratorCanBeSubclassed() {
    let generator = StarsGenerator(dialect: .full)
    let doc = MarkdownDialect.full.parser.parse("a `b` c\n\n***\n\n- `d`\n\n  ---\n")
    XCTAssertEqual(generator.generate(doc: doc), "a ``b`` c\n\n___\n\n- ``d``\n\n  ___\n")
    XCTAssertTrue(generator.roundTrips(doc))
  }

  func testGeneratorCanBeUsedFromSeveralThreads() {
    let doc = MarkdownDialect.fullLaTeX.parser.parse(Self.cases.map { $0.1 }.joined(separator: "\n\n"))
    let expected = SourceGenerator.standard.generate(doc: doc)
    let results = ResultsBox()
    DispatchQueue.concurrentPerform(iterations: 8) { _ in
      results.add(SourceGenerator.standard.generate(doc: doc))
    }
    XCTAssertEqual(results.values.count, 8)
    XCTAssertTrue(results.values.allSatisfy { $0 == expected })
  }

  private final class ResultsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var strings: [String] = []
    func add(_ str: String) {
      self.lock.lock()
      self.strings.append(str)
      self.lock.unlock()
    }
    var values: [String] {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self.strings
    }
  }
}
