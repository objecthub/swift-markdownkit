# Generating Output

Convert a parsed Markdown document into HTML, attributed strings, plain text or text for ANSI terminals.

<!-- Adapted from the README section "Generating text, HTML, and Attributed Strings". -->

## Overview

MarkdownKit provides several _generators_, i.e. Markdown processors which output, for a given Markdown document, a corresponding representation in a different format:

| Generator | Output | Use it for |
|---|---|---|
| ``HtmlGenerator`` | HTML as a `String` | web pages, and as the basis for attributed strings |
| ``AttributedStringGenerator`` | `NSAttributedString` | text views on macOS and iOS (see also <doc:DisplayingMarkdownWithSwiftUI>) |
| ``StringGenerator`` | formatted plain text | text editors, logs, plain text files |
| ``TerminalGenerator`` | text marked up with ANSI escape codes | ANSI-compliant terminals |

All generators take a document that a parser returned: ``Block/document(_:)``. They work with every parser, see <doc:ChoosingAParser>.

### Generate HTML

``HtmlGenerator`` defines a simple mapping from Markdown into HTML. Here is an example for the usage of the generator:

```swift
let html = HtmlGenerator.standard.generate(doc: markdown)
```

To omit raw HTML and unsafe links from the output, create the generator with `HtmlGenerator(safeMode: true)`, see <doc:RenderingUntrustedMarkdown>. Beyond that option, there are currently no means to customize ``HtmlGenerator`` other than subclassing; <doc:CustomizingHTMLOutput> shows how.

Fenced code blocks with the language `mermaid` are [Mermaid](https://mermaid.js.org) diagrams. ``HtmlGenerator`` passes them on in a `<pre class="mermaid">` element for web pages that load Mermaid.

### Generate attributed strings

MarkdownKit also comes with a generator for attributed strings. ``AttributedStringGenerator`` uses a customized HTML generator internally to define the translation from Markdown into `NSAttributedString`. The initializer of ``AttributedStringGenerator`` provides a number of parameters for customizing the style of the generated attributed string:

```swift
let generator = AttributedStringGenerator(fontSize: 12,
                                          fontFamily: "Helvetica, sans-serif",
                                          fontColor: "#33C",
                                          h1Color: "#000")
let attributedStr = generator.generate(doc: markdown)
```

Alternatively, it is also possible to subclass the internal HTML generator and customize the output this way. For the implementation of syntax highlighting in code blocks, ``AttributedStringGenerator`` uses [Highlight.js](https://github.com/highlightjs/highlight.js/); see <doc:SyntaxHighlighting>. <doc:CustomizingAttributedStringOutput> covers the styling options in detail.

The generated HTML is rendered into an `NSAttributedString` by the system. Use ``AttributedStringGenerator/RenderingOptions`` to configure it. `baseUrl` is the base for resolving relative URLs (e.g. relative image paths) in the generated HTML. ``AttributedStringGenerator/generate(doc:)`` renders synchronously on the calling thread; `generateAsync(doc:)` is an alternative based on `NSAttributedString.loadFromHTML` which does not block the calling thread. It throws an ``AttributedStringGenerator/RenderingError`` (e.g. `.timedOut` if the render takes longer than `timeout` seconds, or `.cancelled`). It is available on macOS and iOS; on other platforms it throws `.unsupportedPlatform`.

```swift
let options = AttributedStringGenerator.RenderingOptions(
                baseUrl: URL(fileURLWithPath: "/path/to/images", isDirectory: true),
                timeout: 10)
let generator = AttributedStringGenerator(renderingOptions: options)
let attributedStr = generator.generate(doc: markdown)               // synchronous
let asyncStr = try await generator.generateAsync(doc: markdown)     // asynchronous
```

For code that does not use Swift concurrency, there are variants with a completion handler. The handler is called exactly once, asynchronously, and always on the main thread; it receives a `Result` with either the attributed string or a `RenderingError`:

```swift
generator.generateAsync(doc: markdown) { result in
  switch result {
    case .success(let attributedStr):
      textView.textStorage.setAttributedString(attributedStr)
    case .failure(let error):
      print("cannot convert: \(error)")
  }
}
```

Do not use `generateAsync` with untrusted Markdown without restricting what it may load, because it loads remote resources that the HTML refers to. See <doc:RenderingUntrustedMarkdown>.

### Generate plain text and terminal output

There are two generators for outputting formatted text. ``StringGenerator`` formats text based on the given Markdown and returns text that can be, e.g. edited in a text editor. ``TerminalGenerator`` formats text for output in an ANSI-compliant terminal, using control sequences to mark up the text. Both wrap text to a number of columns:

```swift
print(StringGenerator(numColumns: 60).generate(doc: markdown))
print(TerminalGenerator(numColumns: 60).generate(doc: markdown).encodedString)
```

See <doc:GeneratingTerminalOutput> for tables, styles and customization.

## See Also

- <doc:ProcessingMarkdown>
- <doc:Recipes>
