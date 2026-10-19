# Converting Markdown into Documents

Turn a Markdown document into text, HTML, RTF, RTFD or PDF with one call.

## Overview

``MarkdownUtil`` converts a parsed Markdown document into the formats that you most often need, without assembling generators yourself. Each conversion is one method:

| Method | Result | Platforms |
| --- | --- | --- |
| ``MarkdownUtil/text(_:width:)`` | plain text, formatted for lines of a given width | all |
| ``MarkdownUtil/ansi(_:width:)`` | text with ANSI escape codes for a terminal | all |
| ``MarkdownUtil/html(_:math:safeMode:)`` | HTML, with formulas typeset as MathML | all (formulas stay code on watchOS) |
| ``MarkdownUtil/rtf(_:title:author:renderingOptions:)`` | the data of an RTF file | macOS and iOS |
| ``MarkdownUtil/rtfd(_:title:author:maxImageWidth:renderingOptions:)`` | an RTFD document, with diagrams and formulas as images | macOS and iOS |
| ``MarkdownUtil/pdf(_:title:author:pageSize:margins:renderingOptions:)`` | the data of a PDF file, with diagrams and formulas as images | macOS and iOS |

```swift
let doc = MarkdownDialect.fullLaTeX.parser.parse(markdown)
let util = MarkdownUtil.standard

let text = util.text(doc, width: 72)
let html = util.html(doc)
let rtf = try await util.rtf(doc, title: "Notes", author: "Matthias")
let document = try await util.rtfd(doc, title: "Notes", author: "Matthias")
let pdf = try await util.pdf(doc, title: "Notes", author: "Matthias")
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

### Convert into PDF

``MarkdownUtil/pdf(_:title:author:pageSize:margins:renderingOptions:)`` lays the document out as a text view does, in the width of a page, and draws it into pages: headings, paragraphs, lists, quotes, code blocks (with syntax highlighting) and tables, and diagrams and formulas as images, which are scaled down if they are wider than the text. The result is the content of a `.pdf` file; `title` and `author` become properties of the document.

```swift
let pdf = try await util.pdf(doc, title: "Notes", pageSize: MarkdownUtil.a4,
                             margins: MarkdownUtil.Insets(top: 60, left: 72, bottom: 60, right: 72))
try pdf.write(to: URL(fileURLWithPath: "Notes.pdf"))
```

The pages are ``MarkdownUtil/usLetter`` (the default) or ``MarkdownUtil/a4``, or any size in points, with margins of one inch; `margins` sets the width of each edge in points (see ``MarkdownUtil/Insets``). Page sizes and margins that come from a setting or the command line can be read from text, with units: ``MarkdownUtil/pageSize(_:)`` understands `a4`, `letter`, `595x842` and `210x297mm`, and the initializer of ``MarkdownUtil/Insets`` that takes a string understands `72`, `20mm`, `10mm 30mm` (the upper and lower edge, and the left and right edge) and `1in 0.5in 1in 2in` (the upper, right, lower and left edge, as in CSS). A page is broken between lines of text, not through them. A list item, a code block or a row of a table moves to the next page as a whole if it fits on a page, and a heading is not the last line of a page. Only a block that is taller than a page is broken. The text is about 70% as large as in the other formats (14 points become about 10 points), and so are formulas, because the text of a page is smaller than the text of a view; the rendering option `textSizeMultiplier` scales it further. All diagrams are scaled by the same factor, which makes a diagram of the width that Mermaid draws for (800 points) as wide as the text of a page (0.56 for A4): a diagram that is wider than another one on the page has the same size of text, and the text of diagrams is a little smaller than the text of the document. The importer which creates the text does not make fonts smaller than 9 points, so the text of a page is never smaller, whatever the style says.

The text is black by default, whatever the appearance of the system is (see the style below). The numbers and bullets of lists sit on the baseline of the first line of their items. Links are clickable: each line of a link is an area that opens its URL (links to a place in the same document, `#name`, are not). ``MarkdownUtil/PDFError`` says why a PDF document cannot be created, for example because the margins leave no room for text.

### Choose the style

The documents of RTF, RTFD and PDF look as the ``MarkdownUtil/style`` of the utility says: fonts, colors, line spacing, the theme of syntax highlighting, and CSS of your own. The default is ``AttributedStringGenerator/Style/light``: the colors for a white page (black text), whatever the appearance of the system is. Create a utility with another style to change that; the utility is a value that shares the renderers (and their caches) with the other ones, so it is cheap to create one for each document:

```swift
var style = AttributedStringGenerator.Style.light
style.fontFamily = "Georgia, serif"
style.fontSize = 15
style.h1Color = "#1a4a8a"
style.h2Color = "#1a4a8a"
let pdf = try await MarkdownUtil(style: style).pdf(doc, title: "Notes")
```

See <doc:CustomizingAttributedStringOutput> for the properties of a style. A page of a PDF document and the background of an RTF or RTFD document are white, so use a style with dark text; the preset ``AttributedStringGenerator/Style/dark``, whose text is white, is for text views. The utility does not take the style of `text`, `ansi` and `html`, as they do not have one. The scale of PDF documents (see above) applies on top of the style, and formulas and diagrams are drawn for the sizes of the style.

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
