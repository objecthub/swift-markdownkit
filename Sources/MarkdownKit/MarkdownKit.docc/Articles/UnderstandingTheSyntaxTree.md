# Understanding the Syntax Tree

Learn how Markdown syntax maps to the cases of ``Block``, ``TextFragment`` and ``Text``.

## Overview

A parser turns a Markdown string into a tree of three types:

- ``Block`` is an enumeration of the block-level elements of a document: paragraphs, headings, lists, code blocks and so on. Some blocks contain other blocks.
- ``Text`` is a sequence of inline elements. A paragraph, a heading and a table cell contain a ``Text``.
- ``TextFragment`` is an enumeration of the inline elements: plain text, emphasis, links, images and so on. Some fragments contain a ``Text``.

The root of the tree is a ``Block/document(_:)``. A tree is a value: it can be shared freely, compared with `==` and passed between threads. Printing a tree with `debugDescription` shows its structure; the examples below use it.

### Know the two parsing phases

``MarkdownParser/parse(_:blockOnly:)`` works in two phases. First, the block parsers find the block structure of the document, without looking into the text of the blocks. Then the inline parser processes the text of each block and replaces it with the structure of its inline markup. With `blockOnly: true`, only the first phase runs, and the text of paragraphs and headings stays plain text (hard line breaks are not recognized either):

```swift
FullMarkdownParser.standard.parse("# Hi *there*")
// document(heading(1, text("Hi "), emph(text("there"))))
FullMarkdownParser.standard.parse("# Hi *there*", blockOnly: true)
// document(heading(1, text("Hi *there*")))
```

### Blocks

| Markdown | Case |
|---|---|
| `## Title` or an underlined title | ``Block/heading(_:_:)`` with the level (1 to 6) and the title text |
| a paragraph | ``Block/paragraph(_:)`` |
| `> quote` | ``Block/blockquote(_:)`` with the blocks of the quote |
| `- item` or `1. item` | ``Block/list(_:_:_:)`` with ``Block/listItem(_:_:_:)`` blocks |
| a block indented by four spaces | ``Block/indentedCode(_:)`` |
| a fenced code block | ``Block/fencedCode(_:_:)`` with the info string and the lines |
| raw HTML on its own lines | ``Block/htmlBlock(_:)`` |
| `[label]: destination "title"` | ``Block/referenceDef(_:_:_:)`` |
| `***`, `---` or `___` | ``Block/thematicBreak`` |
| a table | ``Block/table(_:_:_:)`` (``ExtendedMarkdownParser`` and ``FullMarkdownParser``) |
| a term followed by `: description` | ``Block/definitionList(_:)`` (``ExtendedMarkdownParser`` and ``FullMarkdownParser``) |
| syntax you added to the parser | ``Block/custom(_:)`` |

Headings, both the `#` kind and the underlined kind, have the same representation:

```swift
// "Title\n=====" and "# Title"
document(heading(1, text("Title")))
```

Code blocks keep their lines, including the line terminators. An indented block is stored without its indentation; a fenced block has its info string, whose first word is the language, or `nil` without an info string:

```swift
// "    let x = 1\n    let y = 2"
document(indentedCode("let x = 1\n", "let y = 2"))
// "```swift\nlet x = 1\n```"
document(fencedCode(swift, "let x = 1\n"))
```

### Lists

A list is a ``Block/list(_:_:_:)`` block, whose first parameter is the number of the first item (`nil` for a bullet list) and whose second parameter says whether the list is tight. A tight list has no blank lines between its items, and its paragraphs are shown without paragraph spacing. The items are ``Block/listItem(_:_:_:)`` blocks with the type of the item (``ListType``), the density of its content (``ListDensity``) and the blocks of the item:

```swift
// "3. three\n4. four"
document(list(3, tight,
               listItem(ordered(3, .), initial, paragraph(text("three"))),
               listItem(ordered(4, .), tight, paragraph(text("four")))))
// "- one\n\n- two"
document(list(loose,
              listItem(bullet(-), initial, paragraph(text("one"))),
              listItem(bullet(-), initial, paragraph(text("two")))))
```

A list inside of an item is one of the blocks of the item. Task list items (``FullMarkdownParser``) wrap the bullet or number in the type, e.g. `task(bullet(-), checked: true)`. Use ``ListType/marker`` to get the bullet or number of an item independently of whether it is a task:

```swift
// "- a\n  - b\n- c"
document(list(tight,
              listItem(bullet(-), initial, paragraph(text("a")),
                                           list(tight, listItem(bullet(-), tight, paragraph(text("b"))))),
              listItem(bullet(-), tight, paragraph(text("c")))))
```

### Tables and definition lists

A table has a header row, the alignment of each column and the body rows. A row is a sequence of ``Text`` values, one per column, and the alignments are ``Alignment`` values: `L` for left, `R` for right, `C` for center and `-` for no alignment:

```swift
// "| A | B |\n|:--|--:|\n| 1 | 2 |"
document(table(row(A | B), LR, row(1 | 2)))
```

A definition list contains ``Definition`` values, each with a term and its descriptions. A description is a ``Block/listItem(_:_:_:)`` whose content is the text of the description.

### Links and references

Link reference definitions stay in the tree as ``Block/referenceDef(_:_:_:)`` blocks, but the links that use them are already resolved: a reference link has the destination and the title of its definition. The generators ignore the definition blocks:

```swift
// "[ref]: https://example.com \"T\"\n\n[link][ref]"
document(referenceDef(ref, https://example.com, "T"),
         paragraph(link(text("link"), "https://example.com", "T")))
```

### Inline fragments

| Markdown | Case |
|---|---|
| plain text | ``TextFragment/text(_:)`` |
| `*text*` or `_text_` | ``TextFragment/emph(_:)`` |
| `**text**` or `__text__` | ``TextFragment/strong(_:)`` |
| `~text~` | ``TextFragment/underline(_:)`` (``FullMarkdownParser``) |
| `~~text~~` | ``TextFragment/strikethrough(_:)`` (``FullMarkdownParser``) |
| code between backticks | ``TextFragment/code(_:)`` |
| `[text](destination "title")` | ``TextFragment/link(_:_:_:)`` |
| `<https://example.com>` | ``TextFragment/autolink(_:_:)`` |
| `![description](source "title")` | ``TextFragment/image(_:_:_:)`` |
| `<b>` | ``TextFragment/html(_:)`` |
| a line ending | ``TextFragment/softLineBreak`` |
| a backslash or two spaces before a line ending | ``TextFragment/hardLineBreak`` |
| syntax you added to the parser | ``TextFragment/custom(_:)`` |

Links and images contain a ``Text`` with their text, and the destination and title as optional strings. Autolinks have a type (``AutolinkType``) and the address. An inline HTML tag is stored without its angle brackets:

```swift
// "[objecthub](https://objecthub.com \"Title\")"
paragraph(link(text("objecthub"), "https://objecthub.com", "Title"))
// "<https://swift.org> and <me@example.com>"
paragraph(autolink(uri, "https://swift.org"), text(" and "), autolink(email, "me@example.com"))
// "text <b>bold</b>"
paragraph(text("text "), html("b"), text("bold"), html("/b"))
```

Line endings inside of a paragraph are fragments of their own, so that a generator can decide how to show them:

```swift
// "one\ntwo  \nthree\\\nfour"
paragraph(text("one"), softLineBreak, text("two"), hardLineBreak,
          text("three"), hardLineBreak, text("four"))
```

### Delimiters

Characters that could start or end markup, such as `*`, `_`, `[` and `<`, are first turned into ``TextFragment/delimiter(_:_:_:)`` fragments, which the inline transformers then match to create emphasis, links and other markup. A delimiter which is not matched stays in the tree and is shown as the character it stands for:

```swift
// "2 * 3 * 4"
paragraph(text("2 "), delimiter("*", 1, []), text(" 3 "), delimiter("*", 1, []), text(" 4"))
```

A delimiter has the character, the number of times it is repeated, and a ``DelimiterRunType`` which describes its surroundings. If you process a tree, treat a `delimiter` like text.

### Strings from the tree

``Text/description`` gives the Markdown for a text, ``Text/rawDescription`` the text without its markup, and `debugDescription` the structure.

## See Also

- <doc:ProcessingMarkdown>
- <doc:ExtendingTheParser>
