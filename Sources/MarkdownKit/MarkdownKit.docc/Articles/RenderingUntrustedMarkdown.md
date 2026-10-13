# Rendering Untrusted Markdown

Restrict what raw HTML, links and images in a document may do when the Markdown does not come from you.

<!-- Adapted from the README section "Loading images securely". -->

## Overview

Markdown can contain raw HTML, links with arbitrary URL schemes, and images that point to local files or to web servers. If the text comes from other users, from a language model, or from a downloaded file, you have to decide what the output may do. MarkdownKit offers restrictions at three levels, from the generators that create HTML to the system component that renders it.

### Choose safe mode for HTML

``HtmlGenerator`` always escapes `href`, `src`, `title`, `alt` and autolink text, so a crafted link or image cannot break out of an attribute. With `HtmlGenerator(safeMode: true)`, it also omits raw HTML and empties URLs with schemes other than `http`, `https` and `mailto`. Relative URLs stay as they are:

```swift
let generator = HtmlGenerator(safeMode: true)
let html = generator.generate(doc: MarkdownParser.standard.parse("[x](javascript:alert(1))"))
```

``StringGenerator`` and ``TerminalGenerator`` replace control and bidirectional formatting characters with U+FFFD, so the text of a document cannot inject escape sequences into a terminal.

### Choose rendering options for attributed strings

By default, images referred to by Markdown may be loaded from any location: the system's HTML renderer loads any file that an image URL points to (also files outside of `imageBaseUrl`, reached via `../` or absolute paths), and `generateAsync` additionally fetches `http(s)` images and style sheets. Only the path extension of an image is checked by default (see below).

For untrusted Markdown, use the preset ``AttributedStringGenerator/RenderingOptions/untrusted`` (safe mode, and no local and no remote images):

```swift
let generator = AttributedStringGenerator(renderingOptions: .untrusted)
```

Its counterpart ``AttributedStringGenerator/RenderingOptions/trusted`` restricts nothing; it is the same as the default options, `RenderingOptions()`. To allow some images, restrict image loading with the options `localImages` and `remoteImages` instead. Each is an ``AttributedStringGenerator/ImageAccess``:

| Value | Meaning |
|---|---|
| `.none` | never load |
| `.any` | no restriction in terms of URL path |
| `.within(url)` | local images: only image files inside this directory, symbolic links resolved; remote images: only URLs with the same scheme, host and port as `url` and a path below the path of `url` |

```swift
let imageDirectory = URL(fileURLWithPath: "/path/to/images", isDirectory: true)
let options = AttributedStringGenerator.RenderingOptions(
                baseUrl: imageDirectory,
                localImages: .within(imageDirectory),
                remoteImages: .within(URL(string: "https://example.com/images/")!),
                textSizeMultiplier: 1.2)
let generator = AttributedStringGenerator(renderingOptions: options)
```

Independently of the location checks, every image that is checked must also have one of the path extensions in `imageExtensions` (default: ``AttributedStringGenerator/RenderingOptions/defaultImageExtensions``: png, jpg, jpeg, gif, tif, tiff, bmp, ico, heic, heif, webp), whether its location was permitted by `.any` or `.within`; this keeps non-image files from being loaded via an image URL. A custom set replaces the default, and `""` stands for URLs without extension. This check always applies to the images of the Markdown text, also if `localImages` and `remoteImages` are both `.any`.

### Know what the restrictions do not cover

- Images in raw HTML are not checked, and the restrictions apply to the images of the Markdown text only: raw HTML in the Markdown can still refer to images, style sheets and other resources. Set `safeMode: true` in the options to also omit raw HTML and to limit links to the schemes `http`, `https` and `mailto`; it is independent of the image options and `false` by default.
- Images that are not allowed are replaced by their alternative text. Relative image paths are resolved against `imageBaseUrl` or, if that is not set, against `baseUrl`; the access options never influence this resolution, they only check the resolved URL (relative paths are rejected if there is no base).
- With `remoteImages: .none` and Markdown without raw HTML, `generateAsync` does not access the network. Remote images are never loaded by the synchronous methods.
- The restrictions are enforced while generating the HTML; they do not cover resources the application itself refers to (e.g. via `customStyle`), redirects of web servers, or files that change between the check and loading.

> Important: Without restrictions, do not use `generateAsync` with untrusted Markdown, as it then loads remote resources (images, style sheets) that the HTML refers to.

### Draw diagrams safely

Mermaid diagrams are drawn in a web view that cannot access the network or local files and has no connection to the rest of the application, and Mermaid runs with `securityLevel: 'strict'`. See <doc:DrawingMermaidDiagrams>.

### Limit nesting

Deeply nested input does not overflow the stack: the nesting depth is limited to 24 (``DocumentParser/maxContainerDepth`` and ``InlineParser/maxNestingDepth``); deeper markup stays text.

### View untrusted Markdown in SwiftUI

``MarkdownText`` uses `RenderingOptions.trusted` by default. Pass `renderingOptions: .untrusted` to its initializers if the document does not come from a trusted source:

```swift
MarkdownText(string: text, renderingOptions: .untrusted)
```
