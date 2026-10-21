# Using MarkdownKit Concurrently

Parse and generate on background threads and tasks, and know what to restate in subclasses.

<!-- Adapted from the README section "Using MarkdownKit concurrently". -->

## Overview

MarkdownKit is compiled in Swift 6 language mode and supports strict concurrency checking. Abstract syntax trees (``Block``, ``TextFragment``, ``Text``, ...), options and configuration types (such as ``AttributedStringGenerator/RenderingOptions``) are `Sendable` value types. Parsers (``MarkdownParser``, ``ExtendedMarkdownParser``), generators (``HtmlGenerator``, ``StringGenerator``, ``TerminalGenerator``, ``AttributedStringGenerator``, ``SourceGenerator``), table renderers and the ``SyntaxHighlighter`` are immutable objects and `Sendable` as well (the highlighting configurations ``HighlightingConfig`` and ``AnsiHighlightingConfig`` are value types), so a single instance can be used from several threads or tasks at the same time.

Parsing in a background task and using the resulting ``Block`` on the main actor works:

```swift
let doc = await Task.detached { ExtendedMarkdownParser.standard.parse(text) }.value
let attributedStr = try await AttributedStringGenerator.standard.generateAsync(doc: doc)
```

### Generate attributed strings off the main thread

The synchronous methods of ``AttributedStringGenerator`` (``AttributedStringGenerator/generate(doc:)`` etc.) use the system's HTML importer, which Apple documents as usable on the main thread only. From other threads, use `generateAsync`. It exists in two forms:

- `generateAsync(doc:options:)` is an `async` method that returns the attributed string or throws an ``AttributedStringGenerator/RenderingError``.
- `generateAsync(doc:options:completionHandler:)` is for code that does not use Swift concurrency. The handler is called exactly once, asynchronously, on the main thread.

Both also load Mermaid diagrams (see <doc:DrawingMermaidDiagrams>) before they generate the attributed string.

### Subclass parsers and generators

The classes are `open`, so their `Sendable` conformance is `@unchecked`. Subclasses restate it as `@unchecked Sendable` (the compiler warns otherwise) and have to make sure that state they add is immutable or synchronized.

```swift
final class MyGenerator: HtmlGenerator, @unchecked Sendable {
  override func generate(block: Block, parent: Parent, tight: Bool = false) -> String {
    return super.generate(block: block, parent: parent, tight: tight)
  }
}
```

For the same reason, custom types implementing ``CustomBlock``, ``CustomTextFragment`` or one of the table renderer protocols have to be `Sendable`.

Parser internals, such as ``DocumentParser``, ``InlineParser`` and ``BlockParser``, are created for a single parse and are not `Sendable`. They are used by the thread that parses.

## See Also

- <doc:ExtendingTheParser>
