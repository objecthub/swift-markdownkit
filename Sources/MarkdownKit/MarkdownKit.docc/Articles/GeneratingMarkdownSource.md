# Generating Markdown Source

Write a syntax tree back as Markdown, after you changed it or to normalize a document.

<!-- Adapted from the README section "Generating Markdown source". -->

## Overview

``SourceGenerator`` is the counterpart of the parser: for a syntax tree, it writes Markdown source which the parser reads back into the same tree. Use it to save a document after you changed its tree with code (see <doc:ProcessingMarkdown>), to normalize the formatting of Markdown files, or to create Markdown from a tree that you built yourself.

```swift
let dialect = MarkdownDialect.full
let doc = dialect.parser.parse(text)
let source = dialect.sourceGenerator.generate(doc: doc)
```

Use the dialect of the parser that read the text. A dialect determines which Markdown the generator may use and which characters it has to escape: the source of a document with a table only reads back as a table if the parser understands tables.

The generator does not reproduce the original text, it writes one form for every construct. Headings are written with `#`, emphasis with `*` and `**`, links in the inline form, tables without padding, and characters which could be taken for markup get a backslash (`2 \* 3`). Bullets and numbers of lists, their density, code blocks, reference definitions and the line breaks of paragraphs stay as they are. Generating the source of the parsed result gives the same source again.

### Check that the source reads back

The result of parsing the generated source is the tree that you started with, but ``Block`` and ``Text`` compare the fragments of text, which the parser splits at every character that may start markup, also if it is escaped: `a (b)` and `a \(b\)` are the same text but different fragments. ``Block/normalized`` (and ``Text/normalized``) merges them, so compare normalized trees:

```swift
let generator = SourceGenerator(dialect: .full)
let again = MarkdownDialect.full.parser.parse(generator.generate(doc: doc))
again.normalized == doc.normalized     // true
again == doc                           // can be false: `2 \* 3` has other fragments than `2 * 3`
```

``SourceGenerator/roundTrips(_:)`` does this for you. ``SourceGenerator/firstMismatch(of:)`` describes the first difference, which is useful for error messages:

```swift
if let problem = generator.firstMismatch(of: doc) {
  print("cannot write the document: \(problem)")
}
```

### Choose the syntax

A generator knows the syntax of a parser as a ``MarkdownDialect/Syntax``, a set of features. ``SourceGenerator/init(dialect:)`` takes the syntax of one of the standard parsers:

| Dialect | Syntax |
|---|---|
| ``MarkdownDialect/commonMark`` | CommonMark |
| ``MarkdownDialect/extendedCommonMark`` | additionally tables and definition lists |
| ``MarkdownDialect/full`` | additionally underline, strikethrough and task lists |
| ``MarkdownDialect/fullMath`` | additionally LaTeX math with dollar signs |
| ``MarkdownDialect/fullLaTeX`` | additionally LaTeX math with the delimiters of LaTeX |

The more the syntax has, the more characters have to be escaped: a generator for ``MarkdownDialect/fullMath`` writes `\$5`, one for ``MarkdownDialect/commonMark`` writes `$5`. Escapes which a syntax needs are harmless for the parsers with a smaller syntax, so the source of ``SourceGenerator/standard``, which has the syntax of ``LaTeXMarkdownParser``, reads back correctly with every standard parser. Use it if you do not know the parser, and a generator for the dialect if you want the source with the fewest escapes.

If you configured the parser yourself (see <doc:ConfiguringTheParser>) or extended it with new markup (see <doc:ExtendingTheParser>), create the generator with the features of the parser, the parser itself, and the characters which have a meaning for the parser:

```swift
let generator = SourceGenerator(syntax: .extendedCommonMark,
                                parser: MyMarkdownParser.standard,
                                specialCharacters: ["~"])
```

``SourceGenerator/roundTrips(_:)`` uses this parser for reading the source.

### Know what cannot be written back

The generator never fails; it writes the best source it can. ``SourceGenerator/roundTrips(_:)`` is `false` if the source reads back as a different tree:

- The tree has elements that the syntax lacks. A generator for ``MarkdownDialect/commonMark`` writes the content of underlined text and a table as paragraphs, because it must not invent markup the parser does not read.
- A custom block or text fragment has no source (see <doc:ExtendingTheParser>). It is written as plain text or as a code block.
- The tree has a shape that no source expresses. The syntax tree of a text that the parser produces almost never has one. Examples are a link to an empty destination that comes from a reference definition (`[foo]: <>`), emphasis next to long runs of delimiter characters (`foo******bar*********baz`), and a formula within a line that spans several lines and starts a paragraph.

A tree that you changed by hand can have more shapes that the parser never produces: for instance a list whose density does not fit its items, a heading of level 3 with a line break, or text that starts with a space. Check it with ``SourceGenerator/roundTrips(_:)``.

### Customize the output

``SourceGenerator`` is a recursive traversal of the syntax tree with one method for each level, like ``HtmlGenerator``. A subclass overrides the methods for the elements it wants to change and calls `super` for the others:

| Method | Called for |
|---|---|
| ``SourceGenerator/generate(doc:)`` | the whole document |
| ``SourceGenerator/generate(blocks:parent:)`` | a sequence of blocks, with the blank lines between them |
| ``SourceGenerator/generate(block:parent:)`` | one block, as its lines |
| ``SourceGenerator/generate(text:in:)`` | inline text |
| ``SourceGenerator/generate(textFragment:in:)`` | one inline fragment |

Blocks are generated as lines, because block quotes and list items prefix them. This generator writes thematic breaks with underscores:

```swift
final class UnderscoreBreakGenerator: SourceGenerator, @unchecked Sendable {
  override func generate(block: Block, parent: Parent) -> [String] {
    if case .thematicBreak = block {
      return ["___"]
    }
    return super.generate(block: block, parent: parent)
  }
}
```

The rules which keep the source readable by the parser (where blank lines are needed, which characters are escaped, how emphasis next to emphasis is written) are not part of these methods. Not every change is safe: a heading written in another form, for example, can join the paragraph in front of it. Check a customized generator with ``SourceGenerator/roundTrips(_:)``.

### Write the source of custom elements

A custom block or text fragment writes its source with `generateSource(via:parent:)` or `generateSource(via:in:)`. See <doc:ExtendingTheParser>.

## See Also

- <doc:GeneratingOutput>
- <doc:ProcessingMarkdown>
- <doc:ExtendingTheParser>
- <doc:Recipes>
