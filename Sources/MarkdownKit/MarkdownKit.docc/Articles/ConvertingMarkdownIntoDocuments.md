# Converting Markdown into Documents

Turn a Markdown document into text, HTML, RTF or RTFD with one call.

## Overview

``MarkdownUtil`` converts a parsed Markdown document into the formats that you most often need, without assembling generators yourself. Each conversion is one method:

| Method | Result | Platforms |
| --- | --- | --- |
| ``MarkdownUtil/text(_:width:)`` | plain text, formatted for lines of a given width | all |
| ``MarkdownUtil/ansi(_:width:)`` | text with ANSI escape codes for a terminal | all |
| ``MarkdownUtil/html(_:math:safeMode:)`` | HTML, with formulas typeset as MathML | all (formulas stay code on watchOS) |
| ``MarkdownUtil/rtf(_:title:author:renderingOptions:)`` | the data of an RTF file | macOS and iOS |
| ``MarkdownUtil/rtfd(_:title:author:maxImageWidth:renderingOptions:)`` | an RTFD document, with diagrams and formulas as images | macOS and iOS |

```swift
let doc = MarkdownDialect.fullLaTeX.parser.parse(markdown)
let util = MarkdownUtil.standard

let text = util.text(doc, width: 72)
let html = util.html(doc)
let rtf = try await util.rtf(doc, title: "Notes", author: "Matthias")
let document = try await util.rtfd(doc, title: "Notes", author: "Matthias")
try document.write(to: URL(fileURLWithPath: "Notes.rtfd"), options: .atomic, originalContentsURL: nil)
```

The `MarkdownKitProcess` command-line tool (see <doc:UsingTheCommandLineTools>) is a thin wrapper around these methods.

### Convert into text and HTML

``MarkdownUtil/text(_:width:)`` and ``MarkdownUtil/ansi(_:width:)`` use ``StringGenerator`` and ``TerminalGenerator`` (see <doc:GeneratingTerminalOutput>). Diagrams are shown as code and formulas as they were written. ``MarkdownUtil/html(_:math:safeMode:)`` uses a ``MathHtmlGenerator``: a formula is typeset by [KaTeX](https://katex.org) as MathML, which browsers display without a style sheet or fonts. Pass another ``MathHtmlGenerator/Output`` to get KaTeX's HTML (which needs the style sheet and fonts of KaTeX, see ``KaTeXEngine/stylesheetURL``) or the delimiters for a script in the web page. `safeMode` omits raw HTML and unsafe links, which you want for untrusted Markdown (see <doc:RenderingUntrustedMarkdown>).

### Convert into RTF

``MarkdownUtil/rtf(_:title:author:renderingOptions:)`` renders the document with an ``AttributedStringGenerator`` and exports the result. An RTF file cannot contain images, so diagrams are code and formulas are shown as they were written. The method loads the images of the Markdown text, as the asynchronous methods of the generator do: the `renderingOptions` decide which ones (see <doc:RenderingUntrustedMarkdown>).

### Convert into RTFD

An RTFD document is a file package: a directory with the text (`TXT.rtf`) and the images. ``MarkdownUtil/rtfd(_:title:author:maxImageWidth:renderingOptions:)`` draws diagrams and formulas as images (with the renderers of the utility, see <doc:DrawingMermaidDiagrams> and <doc:MathematicalFormulas>) and returns the package as a `FileWrapper`; write it into a directory with the path extension `rtfd`. The files of the images are called `Formula 1.png`, `Formula 2.png` and `Image 1.png`, in the order of the document.

Viewers do not show an RTFD document as a text view does, and the method makes up for the differences with ``Foundation/NSAttributedString/preparedForRTFD()``:

- A viewer takes the size of an image from the resolution of its file, not from the bounds of its attachment. The images have the resolution that makes them as large as they are in a text view.
- A viewer ignores the vertical offset of an attachment, which is what keeps a formula within a line aligned with the text. The offset is stored as the attribute `baselineOffset`, which the format keeps.
- A viewer does not make an image smaller if it is wider than the page, so `maxImageWidth` limits the width of diagrams and formulas. Its default, 400 points, fits into a page of the size US Letter or A4 with margins of one inch, also within lists and block quotes.

```swift
// A formula within a line, as the text view shows it, is aligned with the text
let document = try await util.rtfd(MarkdownDialect.fullLaTeX.parser.parse("The area is $\\pi r^2$."))
```

`title` and `author` become properties of the document on macOS; iOS does not write the properties of a document.

### Prepare your own attributed string

If you create the attributed string yourself, for example with a ``MathAttributedStringGenerator`` of your own configuration, call ``Foundation/NSAttributedString/preparedForRTFD()`` before you export it as RTFD. It returns a copy of the string: neither the string nor its attachments change, and attachments without image data or without a size are left as they are.

```swift
let generator = MathAttributedStringGenerator(fontSize: 14)
let string = try await generator.generateAsync(doc: doc).preparedForRTFD()
let document = try string.fileWrapper(from: NSRange(location: 0, length: string.length),
                                      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
```

### Choose the renderers

The utility draws diagrams and formulas with ``MermaidRenderer/shared`` and ``MathRenderer/shared``, which cache their results. Create a utility with renderers of your own to choose the limits of the caches and the time after which a web view is released:

```swift
let util = MarkdownUtil(mermaidRenderer: myMermaidRenderer, mathRenderer: myMathRenderer)
```
