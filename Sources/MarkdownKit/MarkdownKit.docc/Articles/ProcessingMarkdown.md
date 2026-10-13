# Processing Markdown

Walk the abstract syntax tree of a parsed document to extract information or to transform it.

<!-- Adapted from the README section "Processing Markdown". -->

## Overview

The usage of abstract syntax trees for representing Markdown text has the advantage that it is very easy to process such data, in particular, to transform it and to extract information from it. The syntax tree of a document consists of two recursive data types: ``Block`` for block-level structure such as headings, paragraphs and lists, and ``TextFragment`` for the inline markup inside of blocks, such as emphasis and links. A sequence of text fragments is a ``Text``.

### Extract the outline of a document

This function extracts the top-level headers of a document. It parses a document and matches on the `document` and `heading` cases of ``Block``:

```swift
let markdown = MarkdownParser.standard.parse("""
                   # First *Header*
                   ## Sub-header
                   And this is a **paragraph**.
                   # Second **Header**
                   And this is another paragraph.
                 """)

func topLevelHeaders(doc: Block) -> [String] {
  guard case .document(let topLevelBlocks) = doc else {
    preconditionFailure("markdown block does not represent a document")
  }
  var outline: [String] = []
  for block in topLevelBlocks {
    if case .heading(1, let text) = block {
      outline.append(text.rawDescription)
    }
  }
  return outline
}

let headers = topLevelHeaders(doc: markdown)
print(headers)
```

This will print an array with the following two entries:

```swift
["First Header", "Second Header"]
```

``Text/rawDescription`` returns the text of a heading without its markup: the emphasis in `First *Header*` is gone.

### Visit nested structure

Blocks contain blocks: a block quote contains blocks, a list contains list items, and a list item contains blocks. Text contains text fragments, which can contain text again. A function that looks at the whole document therefore recurses through both types. This example collects the destinations of all links in paragraphs and headings:

```swift
func links(inBlock block: Block) -> [String] {
  switch block {
    case .document(let blocks),
         .blockquote(let blocks),
         .list(_, _, let blocks),
         .listItem(_, _, let blocks):
      return blocks.flatMap(links(inBlock:))
    case .paragraph(let text),
         .heading(_, let text):
      return links(inText: text)
    default:
      return []
  }
}

func links(inText text: Text) -> [String] {
  var result: [String] = []
  for fragment in text {
    switch fragment {
      case .link(let inner, let destination, _):
        result.append(contentsOf: destination.map { [$0] } ?? [])
        result.append(contentsOf: links(inText: inner))
      case .autolink(_, let destination):
        result.append(String(destination))
      case .emph(let inner),
           .strong(let inner),
           .underline(let inner),
           .strikethrough(let inner):
        result.append(contentsOf: links(inText: inner))
      default:
        break
    }
  }
  return result
}

let doc = MarkdownParser.standard.parse("A [link](https://objecthub.com) and <https://swift.org>.")
print(links(inBlock: doc))
```

This prints `["https://objecthub.com", "https://swift.org"]`.

The example does not look into tables, definition lists and custom blocks, which only the extended parsers produce (see <doc:ChoosingAParser>), or into custom text fragments. A function that has to be complete handles those cases, too: see <doc:UnderstandingTheSyntaxTree> for the structure of each case.

### Process a document in a background task

Syntax trees are values that can be passed between threads. Parse in a background task and use the result wherever you need it. See <doc:UsingMarkdownKitConcurrently>.

## See Also

- <doc:GeneratingOutput>
