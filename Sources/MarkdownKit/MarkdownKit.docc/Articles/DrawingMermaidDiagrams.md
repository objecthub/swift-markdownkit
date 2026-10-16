# Drawing Mermaid Diagrams

Show fenced code blocks with the language `mermaid` as diagrams in attributed strings.

<!-- Adapted from the README section "Drawing Mermaid diagrams". -->

## Overview

Fenced code blocks with the language `mermaid` are [Mermaid](https://mermaid.js.org) diagrams. ``HtmlGenerator`` passes them on in a `<pre class="mermaid">` element for web pages that load Mermaid. ``AttributedStringGenerator`` can draw them if it is created with the parameter `mermaid:`, which takes a ``MermaidConfig`` (the default is `nil`, in which case the diagram is shown as code):

```swift
let generator = AttributedStringGenerator(mermaid: .default)   // or .dark for a dark background
let attributedStr = try await generator.generateAsync(doc: markdown)
```

Mermaid is a JavaScript library which needs the layout engine of a web browser to measure text. In contrast to syntax highlighting, which runs Highlight.js in JavaScriptCore, the diagrams are therefore drawn by ``MermaidRenderer``, which loads the `mermaid.min.js` that ships with MarkdownKit into a headless `WKWebView` and turns each diagram into a PNG image with transparent background (before macOS 14, the transparency is calculated from renderings on a white and on a black page, which takes about twice as long). Diagrams are only supported on macOS and iOS; on other platforms, and for diagrams which Mermaid rejects (the generator then adds the error message above the code), the code is shown.

### Render diagrams before generating the text

Rendering takes time, so it is asynchronous:

- `generateAsync` renders all diagrams of the document before it generates the attributed string.
- `generate(doc:)` cannot wait for a web view; it shows the diagrams that have been rendered before, and code for the others. Call `await generator.prepareDiagrams(in: doc)` first to render them (it returns `true` if it rendered anything, i.e. if `generate(doc:)` now gives a different result). Code that does not use Swift concurrency calls `generator.prepareDiagrams(in: doc) { rendered in … }` instead; like the completion handlers of `generateAsync`, the handler is called exactly once, asynchronously, on the main thread. There is no blocking variant: the web view that draws the diagrams needs the main thread, so waiting for it there would mean running the run loop inside the call.
- ``MarkdownText`` `(_:mermaid:)` shows the code first and replaces it with the diagram once it is available. In dark mode it uses ``MermaidConfig/darkVariant``.

For a custom text view, prepare the diagrams, then generate the string synchronously:

```swift
let generator = AttributedStringGenerator(mermaid: .default)
generator.prepareDiagrams(in: markdown) { _ in
  textView.textStorage.setAttributedString(generator.generate(doc: markdown) ?? NSAttributedString())
}
```

### Configure the diagrams

A ``MermaidConfig`` selects:

- the Mermaid `theme` (``MermaidConfig/Theme``: `default`, `neutral`, `dark`, `forest` or `base`) and `themeVariables`,
- the `fontFamily`,
- the `scale` (pixels per point, default 2) and the layout `width` (default 800 points),
- the `margin` around the diagram (default 8 points; Mermaid's own, diagram-specific empty space around a diagram is removed, `nil` keeps it),
- a `maxWidth` for the diagram in the attributed string,
- the `spacing` between the diagram and the text above and below it (at least 16 points, like the margin between paragraphs), and
- the `timeout` per diagram.

A diagram that is wider than the text view is scaled down to fit when the text is laid out. Diagrams are drawn on a transparent background, so use `.dark` (or `darkVariant`) for text views with a dark background.

### Use the renderer on its own

``MermaidRenderer`` can also be used without a generator to get the PNG of a diagram:

```swift
if let renderer = MermaidRenderer.shared {
  let image = try await renderer.render("graph LR\n  A --> B")
  try image.pngData.write(to: URL(fileURLWithPath: "/tmp/diagram.png"))
}
```

`render(_:config:)` throws a ``MermaidError`` if Mermaid rejects the diagram (`.syntaxError`), if rendering takes longer than the `timeout` (`.timedOut`), or if the platform has no WebKit (`.unsupportedPlatform`). `render(_:config:completionHandler:)` is the variant for code that does not use Swift concurrency.

### Understand the cache

Rendered diagrams, and the errors of diagrams which Mermaid rejected, are kept in memory by the ``MermaidRenderer`` (``MermaidRenderer/shared`` by default; pass `mermaidRenderer:` to the generator for another one), keyed by the diagram and the configuration (theme, theme variables, font family, scale and width). The cache holds at most 128 results and 64 MiB of images by default and drops the ones that were used least recently; `MermaidRenderer(mermaidJSURL:maxCachedDiagrams:maxCacheBytes:)` sets other limits.

`generateAsync` keeps the diagrams of the document it generates itself, so it shows all of them whatever the size of the cache. `generate(doc:)`, and ``MarkdownText``, which uses it, only show the diagrams that are in the cache: `maxCachedDiagrams` should be at least the number of diagrams in the largest document that you display in this way.

### Know how the web view is isolated

The web view cannot access the network or local files and has no connection to the rest of the application, and Mermaid runs with `securityLevel: 'strict'`. It is created when the first diagram is rendered and released after 60 seconds without requests; create the ``MermaidRenderer`` with `idleTime:` to change that (`0` releases it as soon as no request is waiting, `.infinity` never releases it).

Replace `Sources/MarkdownKit/Mermaid/mermaid.min.js` to use another version of Mermaid; it has to be a build that defines the global `mermaid`. A ``MermaidRenderer`` reads the 3.6 MB file once and keeps it in memory; create it with `cachesScript: false` (`MermaidRenderer(mermaidJSURL:cachesScript:)`) to read the file again whenever the web view is created instead.

## See Also

- <doc:RenderingUntrustedMarkdown>
- <doc:DisplayingMarkdownWithSwiftUI>
