# Generating Plain Text and Terminal Output

Format Markdown documents as plain text, or as text with ANSI styling for terminals.

## Overview

MarkdownKit has two generators for formatted text. Both convert a document into lines of a fixed width, with word wrapping, headings, lists, tables and code blocks drawn with Unicode characters:

- ``StringGenerator`` returns a plain `String`. Use it for text editors, logs and plain text files.
- ``TerminalGenerator`` returns styled text (`AnsiText.Normalized` from the CommandLineKit package) with colors, bold, italic, underline and strikethrough. Its `encodedString` contains ANSI escape sequences, which an ANSI-compliant terminal shows as formatted text.

```swift
let doc = FullMarkdownParser.standard.parse(markdown)
print(StringGenerator(numColumns: 40).generate(doc: doc))
print(TerminalGenerator(numColumns: 40).generate(doc: doc).encodedString)
```

The shared instances `StringGenerator.standard` and `TerminalGenerator.standard` use 80 columns. To use the width of the terminal, ask CommandLineKit for it: `Terminal.size?.columns ?? 80`. The command-line tool `MarkdownTermViewer` is a complete example, see <doc:UsingTheCommandLineTools>.

### See what the output looks like

This Markdown document, generated with 40 columns by ``StringGenerator``:

````markdown
# Release notes

Some *emphasis*, a [link](https://objecthub.com) and `code`.

> A quote that is long enough to need wrapping when the output is only forty columns wide.

- [x] done
- [ ] open
  1. nested one
  2. nested two

| Name | Qty |
|:-----|----:|
| Apple | 3 |
| Orange | 12 |

Term
: The description of the term.

```swift
let x = 42
```
````

becomes:

```
Release notes
▔▔▔▔▔▔▔▔▔▔▔▔▔
Some *emphasis*, a link
[https://objecthub.com] and `code`.

 ┃ A quote that is long enough to need
 ┃ wrapping when the output is only
 ┃ forty columns wide.

  [x] done
  [ ] open
        1. nested one
        2. nested two

    Name   │ Qty
    ───────┼────
    Apple  │   3
    Orange │  12

 Term
  → The description of the term.

╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ swift ╌╌╌
let x = 42
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
```

- Headings of the first three levels are underlined with `▔`, `‾` and `¯`; deeper ones start with `#` characters.
- Links are followed by their destination in brackets, and images are shown as `[Image: description | destination]`. Raw HTML is left out.
- Block quotes have a bar, code blocks have a border line, and the border above a code block shows its language.
- Task list items show `[x]` and `[ ]`. These are plain ASCII because the width of symbols like ☐ and ☑ depends on the terminal and the font, which would misalign the items.
- A table that fits into the available width is drawn with the minimalistic renderer, as above. A table that is wider is drawn with the full renderer, which draws a frame with lines between the rows and wraps the text of the cells.
- ``StringGenerator`` shows emphasis with `*` and `**` as in the Markdown source. ``TerminalGenerator`` styles the text instead.

### Keep the output safe

Both generators replace control characters and bidirectional formatting characters in the text of the document with U+FFFD. A document cannot inject escape sequences into a terminal.

### Choose the width calculation

By default, the generators align text by the width the characters take on the screen, so wide characters, such as East Asian ones and emoji, do not misalign columns. Pass `alignDisplayWidth: false` to ``StringGenerator`` to count each character as one column.

### Change the styles of terminal output

The initializer of ``TerminalGenerator`` has a parameter for the style of each kind of element: `headerProperties` (an array with the styles of the heading levels), `linkProperties`, `codeProperties`, `codeBlockBorderProperties`, `codeBlockLangProperties`, `emphasisProperties`, `strongProperties`, `underlineProperties`, `strikethroughProperties`, `defTermProperties`, `defDescrProperties`, `blockquoteProperties` and `breakProperties`. They are `TextProperties` values from CommandLineKit with a text color and styles:

```swift
let generator = TerminalGenerator(
  numColumns: 80,
  headerProperties: [TextProperties(textColor: .yellow, textStyles: [.bold])],
  linkProperties: .blue)
```

Code blocks are highlighted with ANSI colors, see <doc:SyntaxHighlighting>. Pass `syntaxHighlighting: nil` to switch highlighting off.

### Customize the layout

Both classes are designed to be subclassed. The methods that determine the layout are `open`:

| Method or property | Decides |
|---|---|
| `generate(block:context:)`, `generate(text:maxColumns:)`, `generate(textFragment:)` | how blocks and inline elements are written |
| `blockquoteIndent`, `listIndent` | the strings in front of quoted and listed text |
| `listPrefix(type:context:columns:)` | the bullet, number or checkbox of list items |
| `definitionPrefix(definitions:context:)`, `definitionIndent(definitions:context:)` | the layout of definition lists |
| `headingUnderlineCharacter(level:)` | how headings are underlined |
| `wordWrap(_:maxColumns:)`, `tokenize(_:)` | how text is broken into lines |
| `newContext(doc:maxColumns:)` | the ``GeneratorContext`` that carries the layout state |

The ``GeneratorContext`` tells a method where it is: the enclosing block, the number of columns that remain, and whether the content is tight.

### Draw tables differently

A table is drawn by the first renderer in the `tableRenderers` array that returns lines for it. The generators have two renderers: ``StringGenerator/MinimalisticTableRenderer`` for tables whose rows fit into the width of the document, and ``StringGenerator/FullTableRenderer`` for any table. To change the look of tables, pass your own array of renderers, which can mix the existing renderers, configured with other delimiters, and your own types that implement ``StringGenerator/TableRenderer`` or ``TerminalGenerator/TableRenderer``:

```swift
final class BulletTableRenderer: StringGenerator.TableRenderer {
  func renderTable(_ descriptor: TableDescriptor,
                   using generate: (Text, Int) -> [String],
                   in context: GeneratorContext) -> [String]? {
    return descriptor.rows.map { row in
      zip(descriptor.header, row).map { head, cell in
        generate(head, context.maxColumns).joined() + ": " + generate(cell, context.maxColumns).joined()
      }.joined(separator: ", ")
    }
  }
}
let generator = StringGenerator(tableRenderers: [BulletTableRenderer()])
```

The renderer gets a ``TableDescriptor`` with the header, the alignments, the rows and statistics about the width of each column. A renderer is `Sendable`, so it must not hold mutable state.

### Support custom elements

A ``CustomBlock`` is shown in plain text as its `description`. A ``CustomTextFragment`` implements `generateText(via:)` for a ``StringGenerator`` and for a ``TerminalGenerator``; by default it writes its `rawDescription`. See <doc:ExtendingTheParser>.

## See Also

- <doc:GeneratingOutput>
- <doc:UsingTheCommandLineTools>
