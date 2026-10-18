# Drawing Images of Diagrams and Formulas

Turn a Mermaid diagram or a LaTeX formula into an `NSImage` or a `UIImage`, without any Markdown.

## Overview

MarkdownKit draws [Mermaid](https://mermaid.js.org) diagrams and formulas typeset by [KaTeX](https://katex.org) in a headless web view and shows the results in attributed strings. ``MarkdownUtil`` gives you the same images outside of a Markdown document: it is one place that draws both, and its methods return an image of the platform (``HRImage``: `NSImage` on macOS and `UIImage` on iOS), which you can show in any view or save to a file.

```swift
let util = MarkdownUtil.standard
let diagram = try await util.mermaidImage("graph LR\n  A[Markdown] --> B(Parser)")
let formula = try await util.mathImage("\\int_0^1 x^2 \\, dx = \\frac{1}{3}",
                                       display: true, fontSize: 18)
```

The utility is available on macOS and iOS, where WebKit draws the images. It is a thin layer over ``MermaidRenderer`` and ``MathRenderer``, which are also available directly if you need PNG data or the metrics of an image (see <doc:DrawingMermaidDiagrams> and <doc:MathematicalFormulas>).

### Draw a diagram

``MarkdownUtil/mermaidImage(_:config:)`` takes the description of the diagram and a ``MermaidConfig``. The default configuration draws a diagram for a light background; use ``MermaidConfig/dark`` for a dark one. The image is as large in points as the diagram in an attributed string, and its resolution is the `scale` of the configuration (2 by default). The background is transparent.

```swift
let image = try await util.mermaidImage("""
  sequenceDiagram
    Alice->>Bob: Hello
    Bob-->>Alice: Hi
  """, config: .dark)
```

### Draw a formula

``MarkdownUtil/mathImage(_:display:fontSize:color:config:)`` takes the LaTeX of a formula, without dollar signs. Pass `display: true` for display math, which is centered and uses larger operators, and `false` (the default) for a formula within a line of text. The `fontSize` is the size in points of the text that the formula goes with, and `color` is the color of the formula (black by default); the background is transparent. A ``MathConfig`` sets macros for KaTeX and the resolution of the image (3 pixels per point by default).

```swift
let image = try await util.mathImage("\\vec{F} = m\\vec{a}", fontSize: 16, color: .systemBlue)
```

To place a formula next to text, the baseline matters: it is not at the lower edge of the image, as a formula such as a fraction or a subscript reaches below it. The image is therefore set up for alignment. On macOS, its `alignmentRect` starts at the baseline, and on iOS, its `baselineOffsetFromBottom` is the distance from the lower edge to the baseline, which text attachments use. ``MathRenderer/render(_:display:fontSize:config:)`` returns the `depth` of the baseline as a number, if you need it.

### Show an image in a view

The images are ordinary platform images. This SwiftUI view draws a formula when it appears:

```swift
struct FormulaView: View {
  let tex: String
  @State private var image: UIImage?     // NSImage on macOS

  var body: some View {
    ZStack {
      if let image {
        Image(uiImage: image)            // Image(nsImage:) on macOS
      }
    }
    .task {
      image = try? await MarkdownUtil.standard.mathImage(tex, display: true,
                                                              fontSize: 18, color: .label)
    }
  }
}
```

### Give images uniform insets

The images that Mermaid and KaTeX draw have a small transparent margin, which differs from image to image. For a document in which the images should have the same space around them, ``MarkdownUtil/image(_:withInsets:transparentAlpha:)`` makes the space between the content of an image and its edges an exact width, the inset, for each edge. It removes the transparent area around the content where it is wider than the inset, and adds transparent space where it is narrower:

```swift
let diagram = try await util.mermaidImage("graph LR\n  A --> B")
let insets = MarkdownUtil.Insets(top: 4, left: 8, bottom: 4, right: 8)   // in points
let padded = MarkdownUtil.image(diagram, withInsets: insets)
```

An ``MarkdownUtil/Insets`` value has a width in points for the upper, left, lower and right edge; `Insets(8)` is the same width on all edges, `Insets(horizontal: 8, vertical: 4)` has the same width on opposite edges, and `Insets.none` removes all of the space around the content. The content is the area with pixels that are not transparent. Pixels with an alpha value of at most `transparentAlpha` (0 to 255) count as transparent; the default, 4, ignores the faint edges that antialiasing creates, and 0 counts every pixel that is not completely transparent. The widths are rounded to whole pixels, and the resolution of the image does not change. The function works with any bitmap image with a transparent background, not just those of this utility. The result is a new image, so the setup of a formula for aligning it with text is not carried over, as the baseline moves with the insets. If the image has no content, because it is completely transparent, the result is `nil`.

### Handle errors

The methods throw a ``MermaidError`` for diagrams and a ``MathError`` for formulas. `.syntaxError` has the message of Mermaid or KaTeX if it does not understand the input, and the other cases tell that rendering took too long (`.timedOut`), that the task was cancelled (`.cancelled`), or that images cannot be drawn on the platform or with the resources at hand. Formulas which KaTeX rejects are remembered, so asking for the same formula again fails at once.

### Use a completion handler

Each method has a variant for code that does not use Swift concurrency. The completion handler is called exactly once, asynchronously (also if the image is cached already), and always on the main thread, with a `Result`:

```swift
util.mathImage("x^2 + y^2 = z^2") { result in
  switch result {
    case .success(let image):
      imageView.image = image
    case .failure(let error):
      print("cannot draw: \(error)")
  }
}
```

### Choose the renderers

``MarkdownUtil/standard`` draws with the shared renderers, ``MermaidRenderer/shared`` and ``MathRenderer/shared``. They cache the images (diagrams: 128 results and 64 MiB; formulas: 2,000 results and 32 MiB) and release their web views after a minute without requests. Create a utility with renderers of your own to choose other limits:

```swift
let util = MarkdownUtil(mathRenderer: MathRenderer(katexFolder: folder, maxCachedFormulas: 50))
```

## See Also

- <doc:DrawingMermaidDiagrams>
- <doc:MathematicalFormulas>
