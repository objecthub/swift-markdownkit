# Choosing a Parser

Pick the parser class that supports the Markdown syntax your documents use.

<!-- Adapted from the README section "Markdown extensions". -->

## Overview

MarkdownKit has four parser classes. They share the same interface and differ in the syntax they recognize. Each one extends the previous one:

| Parser | Syntax |
|---|---|
| ``MarkdownParser`` | [CommonMark](https://commonmark.org) 0.31.2: headings, paragraphs, block quotes, lists, code blocks, thematic breaks, HTML, links, images, emphasis, code spans and line breaks |
| ``ExtendedMarkdownParser`` | everything in ``MarkdownParser`` plus tables and definition lists |
| ``FullMarkdownParser`` | everything in ``ExtendedMarkdownParser`` plus underlined text, struck-through text and task lists |
| ``MathMarkdownParser`` | everything in ``FullMarkdownParser`` plus LaTeX math, see <doc:MathematicalFormulas> |

``MarkdownDialect`` names the four syntaxes (`.commonMark`, `.extendedCommonMark`, `.full` and `.fullMath`) and gives access to their standard parsers, so that code which chooses a syntax at run time, such as the initializers of ``MarkdownText``, does not have to know the classes:

```swift
let doc = MarkdownDialect.fullMath.parser.parse("The area is $\\pi r^2$.")
```

Each class has a shared instance, e.g. `FullMarkdownParser.standard`. Parsers do not have mutable state, so one instance can parse many documents. Further markup will be added to ``FullMarkdownParser``, except for markup that changes the meaning of characters which are common in text, such as the dollar sign in ``MathMarkdownParser``.

### Tables and definition lists

``ExtendedMarkdownParser`` supports tables and definition lists in addition to the block types defined by the [CommonMark specification](https://commonmark.org). [Tables](https://github.github.com/gfm/#tables-extension-) are based on the [GitHub Flavored Markdown specification](https://github.github.com/gfm/) with one extension: within a table block, it is possible to escape newline characters to enable cell text to be written on multiple lines. Here is an example:

```
| Column 1     | Column 2       |
| ------------ | -------------- |
| This text \
  is very long | More cell text |
| Last line    | Last cell      |
```

A table becomes the syntax tree case ``Block/table(_:_:_:)``. [Definition lists](https://www.markdownguide.org/extended-syntax/#definition-lists) are implemented in an ad hoc fashion. A definition consists of terms and their corresponding definitions; the syntax tree case is ``Block/definitionList(_:)``. Here is an example of two definitions:

```
Apple
: Pomaceous fruit of plants of the genus Malus in the family Rosaceae.

Orange
: The fruit of an evergreen tree of the genus Citrus.
: A large round juicy citrus fruit with a tough bright reddish-yellow rind.
```

### Underline, strikethrough and task lists

``FullMarkdownParser`` supports everything that MarkdownKit implements. It is a subclass of ``ExtendedMarkdownParser`` (so it supports tables and definition lists) and adds:

- Inline markup for underlined text (`~underlined~`, text fragment `underline`) and struck-through text (`~~struck through~~`, text fragment `strikethrough`). Tildes can also be used within words (`foo~~bar~~baz`), but runs of three or more tildes are plain text, as in GitHub Flavored Markdown. Unlike GFM, a single tilde does not produce strikethrough but underlined text.
- Task list items (`- [ ] to do` and `- [x] done`, list type ``ListType/task(_:checked:)``). A task list item is a list item whose text starts with `[ ]`, `[x]` or `[X]` and a space or tab; the type of such an item wraps the bullet or number of the item.

The HTML generator creates a checkbox for a task list item, the attributed string generator uses the characters ☐ and ☑, and the text generators write `[ ]` and `[x]` instead of the bullet.

```swift
let markdown = FullMarkdownParser.standard.parse("Some ~~old~~ and ~important~ text")
```

``MarkdownParser`` and ``ExtendedMarkdownParser`` do not know this markup and leave tildes as they are, so existing code does not change its behavior.

### Handle every case when you switch over a syntax tree

Documents parsed by ``FullMarkdownParser`` contain the cases `underline` and `strikethrough` of ``TextFragment`` and the list type ``ListType/task(_:checked:)``. A `switch` over these enumerations has to handle them. Use ``ListType/marker`` to get the bullet or number of a list item, whether or not it is a task item.

### Mathematical formulas

``MathMarkdownParser`` is a subclass of ``FullMarkdownParser`` which also recognizes LaTeX math: `$a^2$` within a line, and `$$` on its own lines or a fenced code block with the info string `math` for a formula that is a block. Dollar signs are common in text (`costs $5 and $6`), so the other parsers leave them alone. The formulas are custom syntax tree nodes (``MathFragment`` and ``MathBlock``), so a `switch` over ``Block`` or ``TextFragment`` is not affected: they are handled by the `custom` cases. See <doc:MathematicalFormulas>.

## See Also

- <doc:MathematicalFormulas>
- <doc:ConfiguringTheParser>
- <doc:ExtendingTheParser>
