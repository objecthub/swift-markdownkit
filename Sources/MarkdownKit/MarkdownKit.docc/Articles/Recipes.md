# Recipes

Solve common tasks with a few lines of MarkdownKit.

## Overview

Each recipe is self-contained. They use the shared parsers and generators, so they can be called from any thread, except where noted.

### Convert a Markdown file into an HTML page

Read the file, parse it, and generate the HTML. ``HtmlGenerator`` creates the content of the page; you add the surrounding document:

```swift
let markdown = try String(contentsOf: URL(fileURLWithPath: "README.md"), encoding: .utf8)
let body = HtmlGenerator.standard.generate(doc: FullMarkdownParser.standard.parse(markdown))
let page = "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"></head><body>\n\(body)</body></html>"
try page.write(toFile: "README.html", atomically: true, encoding: .utf8)
```

If the Markdown does not come from you, use `HtmlGenerator(safeMode: true)`, see <doc:RenderingUntrustedMarkdown>.

### Build a table of contents

Walk the blocks of the document and collect its headings. This function returns a Markdown list with one entry for each heading, indented by its level:

```swift
func tableOfContents(of doc: Block) -> String {
  func headings(in block: Block) -> [(Int, String)] {
    switch block {
      case .document(let blocks), .blockquote(let blocks):
        return blocks.flatMap(headings(in:))
      case .heading(let level, let text):
        return [(level, text.rawDescription)]
      default:
        return []
    }
  }
  return headings(in: doc)
    .map { String(repeating: "  ", count: $0.0 - 1) + "- " + $0.1 }
    .joined(separator: "\n")
}
print(tableOfContents(of: MarkdownParser.standard.parse("# One\n\n## Two\n\n# Three")))
```

This prints:

```
- One
  - Two
- Three
```

### Count the words of a document

``Block/string`` returns the text of a block without any markup, which you can split into words:

```swift
let doc = MarkdownParser.standard.parse("# Title\n\nSome **important** text.")
let words = doc.string.split(whereSeparator: \.isWhitespace).count
```

### Show Markdown in a text view

``AttributedStringGenerator`` creates the attributed string for an `NSTextView` or a `UITextView`. Generate it on the main thread, or use `generateAsync`:

```swift
let doc = FullMarkdownParser.standard.parse(markdown)
textView.textStorage?.setAttributedString(AttributedStringGenerator.standard.generate(doc: doc) ?? NSAttributedString())
```

On iOS, the text storage is not optional: `textView.textStorage.setAttributedString(…)`. In SwiftUI, use ``MarkdownText``, see <doc:DisplayingMarkdownWithSwiftUI>.

### Print Markdown to a terminal

``TerminalGenerator`` produces text with ANSI escape sequences:

```swift
let doc = FullMarkdownParser.standard.parse(markdown)
print(TerminalGenerator(numColumns: 72).generate(doc: doc).encodedString)
```

### Show a text from a user safely

Text from users should not load local files or remote resources. The `.untrusted` rendering options omit raw HTML, restrict links and load no images:

```swift
let generator = AttributedStringGenerator(renderingOptions: .untrusted)
let doc = ExtendedMarkdownParser.standard.parse(userText)
let attributedStr = try await generator.generateAsync(doc: doc)
```

See <doc:RenderingUntrustedMarkdown> for allowing images from one web site.

### Rewrite a document

Change the syntax tree and write it back as Markdown with a ``SourceGenerator``. This function makes every heading one level lower (an `h6` stays one), and the generator writes the result:

```swift
func demoteHeadings(_ block: Block) -> Block {
  switch block {
    case .document(let blocks):
      return .document(Blocks(blocks.map(demoteHeadings)))
    case .blockquote(let blocks):
      return .blockquote(Blocks(blocks.map(demoteHeadings)))
    case .heading(let level, let text):
      return .heading(min(level + 1, 6), text)
    default:
      return block
  }
}

let dialect = MarkdownDialect.full
let doc = dialect.parser.parse(markdown)
let result = dialect.sourceGenerator.generate(doc: demoteHeadings(doc))
```

Use the dialect of the parser that read the document. Without changing the tree, the same code normalizes the formatting of a Markdown file. See <doc:GeneratingMarkdownSource>.

### Parse in the background

Parsing large documents takes time. Do it in a background task and use the result in your views, see <doc:UsingMarkdownKitConcurrently>.

## See Also

- <doc:ProcessingMarkdown>
- <doc:GeneratingOutput>
