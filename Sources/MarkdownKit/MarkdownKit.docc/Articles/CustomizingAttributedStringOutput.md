# Customizing Attributed String Output

Style the attributed strings that ``AttributedStringGenerator`` creates, and understand what the system's HTML importer does with the styles.

## Overview

``AttributedStringGenerator`` does not build an `NSAttributedString` itself. It works in three steps:

1. An HTML generator (``AttributedStringGenerator/InternalHtmlGenerator`` or ``AttributedStringGenerator/OS26HtmlGenerator``, a subclass of ``HtmlGenerator``) converts the syntax tree into HTML. Code blocks, block quotes, thematic breaks, tables and, in the newer version, lists become tables with CSS classes, because that is how the importer lays them out best.
2. ``AttributedStringGenerator/generateHtml(_:)`` wraps the HTML into a document with a style sheet, ``AttributedStringGenerator/docStyle``, which assigns a style property of the generator to each element and class.
3. The system's HTML importer converts the document into an attributed string. ``AttributedStringGenerator/generate(doc:)`` calls it synchronously; `generateAsync` uses `NSAttributedString.loadFromHTML`.

Everything you can customize is therefore HTML and CSS: the generator's style, its style properties and its CSS. The importer understands only part of CSS, see "Know what the importer ignores" below.

### Choose the generator version

``AttributedStringGenerator/Version`` selects the HTML that is generated. The default `.OS26` generates lists as tables, uses system fonts, has larger table padding and highlights the syntax of code blocks. `.preOS26` is the older generator for macOS and iOS before version 26: HTML lists, serif fonts (Times New Roman, and Consolas for code), and no syntax highlighting, so that the output of existing code, which was written before highlighting was added, does not change. Use it when you need the older look:

```swift
let generator = AttributedStringGenerator(version: .preOS26)
```

### Use a style

The appearance of the attributed strings is a value, an ``AttributedStringGenerator/Style``. Start with a preset, change what you need, and pass it to the generator:

```swift
var style = AttributedStringGenerator.Style.light
style.fontSize = 15
style.fontFamily = "Avenir Next, sans-serif"
style.h1Color = "#036"
style.customStyle = "td.quote { font-style: italic; }"
let generator = AttributedStringGenerator(style: style)
```

These are the properties of a style:

| Properties | Effect |
|---|---|
| `fontSize`, `fontFamily`, `fontColor`, `lineSpacing` | the body text; the font family is a CSS list, e.g. `"Helvetica, sans-serif"`, or `nil` for the default of the generator's version; the line spacing is a multiple of the line height of the font (default 1.1) |
| `codeFontSize`, `codeFontFamily`, `codeFontColor` | inline code |
| `codeBlockFontSize`, `codeBlockFontColor`, `codeBlockLineSpacing`, `codeBlockBackground` | code blocks; the line spacing of code is 1 by default |
| `syntaxHighlighting` | the theme of the syntax highlighting, or `nil` for none, see <doc:SyntaxHighlighting> |
| `borderColor`, `blockquoteColor` | the border of code blocks and thematic breaks, the bar of block quotes |
| `headerFont` | the font family of all headings, a CSS list; if it is `nil`, no font is set and headings have the base font |
| `h1Color` to `h4Color` | the color of headings |
| `h1FontSize` to `h4FontSize` | the size of the font of headings; if it is `nil`, a heading is larger than `fontSize` by 6 (`h1`), 4, 2 and 1 (`h4`) |
| `maxImageWidth`, `maxImageHeight` | CSS limits for the size of images |
| `customStyle` | CSS that is added at the end of the style sheet |

Three presets cover the usual cases. ``AttributedStringGenerator/Style/default`` has the colors of the system, ``AttributedStringGenerator/Style/light`` has the colors for a white background (black text) and ``AttributedStringGenerator/Style/dark`` the colors for a dark one (white text), whatever the appearance of the system is. The colors of the default style are ``mdDefaultColor`` and ``mdDefaultBackgroundColor``, the hex values of the system's text and background color. They are determined once, for the appearance that is active when they are first used, so use a preset or explicit colors for a specific appearance, as in <doc:DisplayingMarkdownWithSwiftUI>.

The same value styles the documents that ``MarkdownUtil`` creates (see <doc:ConvertingMarkdownIntoDocuments>) and the text of a ``MarkdownText`` view.

### Use the other parameters

A style only describes how the text looks. What the generator does is the parameter of its initializer:

| Parameters | Effect |
|---|---|
| `style` | the ``AttributedStringGenerator/Style`` described above |
| `version` | the generator version, see above |
| `options` | ``AttributedStringGenerator/Options``: `.tightLists` shows the paragraphs of loose list items without spacing |
| `syntaxHighlighter` | the highlighter that colors code blocks with the theme of the style, see <doc:SyntaxHighlighting> |
| `mermaid`, `mermaidRenderer` | see <doc:DrawingMermaidDiagrams> |
| `math`, `mathRenderer` | only the initializer of ``MathAttributedStringGenerator``, see <doc:MathematicalFormulas> |
| `imageBaseUrl` | the directory against which relative image paths are resolved |
| `alignListMarkers` | aligns the numbers and bullets of lists with the baseline of the first line of their items |
| `renderingOptions` | how the HTML is rendered and what it may load, see below |

An initializer which takes the properties of the style one by one, from `fontSize` to `customStyle`, still exists; it creates the same generator as one with the equivalent style. The generator keeps the style it was created with in ``AttributedStringGenerator/style`` and its properties, such as ``AttributedStringGenerator/fontSize``, read from it.

### Override style properties

For more control, subclass ``AttributedStringGenerator`` and override a style property. Each property returns the CSS declarations for one HTML element or class in ``AttributedStringGenerator/docStyle``. This is also the way to find the selectors for `customStyle`: block quotes, for example, are the cells of a table (`td.quote`), not `blockquote` elements.

```swift
final class LargeHeadings: AttributedStringGenerator, @unchecked Sendable {
  override var h1Style: String {
    return "font-size: 32px; color: #c00; margin: 0.5em 0 0.5em 0;"
  }
}
```

These are the properties and what they style:

| Area | Properties |
|---|---|
| Document | ``AttributedStringGenerator/bodyStyle``, ``AttributedStringGenerator/pStyle``, ``AttributedStringGenerator/imgStyle`` |
| Headings | ``AttributedStringGenerator/h1Style``, ``AttributedStringGenerator/h2Style``, ``AttributedStringGenerator/h3Style``, ``AttributedStringGenerator/h4Style``, and the spacers ``AttributedStringGenerator/h1GapStyle`` and ``AttributedStringGenerator/h2GapStyle`` |
| Lists | ``AttributedStringGenerator/ulStyle``, ``AttributedStringGenerator/olStyle``, ``AttributedStringGenerator/ulNestedStyle``, ``AttributedStringGenerator/olNestedStyle``, ``AttributedStringGenerator/liStyle``, ``AttributedStringGenerator/simpleLiStyle``, ``AttributedStringGenerator/itemStyle``, ``AttributedStringGenerator/simpleItemStyle``, ``AttributedStringGenerator/numberStyle``, ``AttributedStringGenerator/bulletStyle``, ``AttributedStringGenerator/checkboxStyle`` |
| Code | ``AttributedStringGenerator/codeStyle``, ``AttributedStringGenerator/preStyle``, ``AttributedStringGenerator/preCodeStyle``, ``AttributedStringGenerator/codeBoxStyle`` |
| Quotes and breaks | ``AttributedStringGenerator/blockquoteStyle``, ``AttributedStringGenerator/quoteStyle``, ``AttributedStringGenerator/thematicBreakStyle`` |
| Tables | ``AttributedStringGenerator/tableStyle``, ``AttributedStringGenerator/tableHeaderStyle``, ``AttributedStringGenerator/tableRowStyle``, ``AttributedStringGenerator/tableCellStyle``, and the settings ``AttributedStringGenerator/tableBorders``, ``AttributedStringGenerator/tableBorderSpec``, ``AttributedStringGenerator/tableHeaderPadding``, ``AttributedStringGenerator/tableRowPadding`` and ``AttributedStringGenerator/tableCellPadding`` |

To change the HTML itself, override ``AttributedStringGenerator/htmlGenerator(options:)`` and return a subclass of the HTML generator, as <doc:CustomizingHTMLOutput> shows for ``HtmlGenerator``.

### Extend the generator

A subclass of ``AttributedStringGenerator`` can put content into attributed strings that the system's HTML importer cannot create, such as images that another renderer draws. This is how Mermaid diagrams work, and it is the way to add your own embedded content. The pieces are all `open`:

1. A custom syntax tree node (see <doc:ExtendingTheParser>) creates a placeholder in ``CustomTextFragment/generateHtml(via:and:)``. The `htmlGen` it receives is the HTML generator of your subclass, so the node finds the context of the current generation there.
2. The subclass overrides ``AttributedStringGenerator/htmlGenerator(options:)`` and returns subclasses of both HTML generators, ``AttributedStringGenerator/InternalHtmlGenerator`` and ``AttributedStringGenerator/OS26HtmlGenerator``, which carry that context.
3. If the content takes time to create, the subclass overrides ``AttributedStringGenerator/needsPreparation`` (return `true`) and ``AttributedStringGenerator/preparedHtmlGenerator(for:options:)-(Block,_)`` and its variant for ``Blocks``. The asynchronous methods call them before they generate the HTML; call the method of the superclass, create the content, and hand it to the HTML generator you return.
4. The subclass overrides ``AttributedStringGenerator/finishAttributedString(_:from:)``, which all methods call with the string that the importer created and the HTML generator that created the HTML. Call the method of the superclass (it replaces the Mermaid placeholders), and replace your placeholders.

The placeholders must survive the importer as text. Use characters from the Unicode private use area with a token that cannot occur in a document, as ``MermaidDiagramContext`` does.

### Show table borders

``AttributedStringGenerator/tableBorders`` returns an ``AttributedStringGenerator/TableBorders`` option set. By default, there is only a line below the header row. A subclass can ask for more:

```swift
final class GridTables: AttributedStringGenerator, @unchecked Sendable {
  override var tableBorders: TableBorders {
    return [.header, .top, .bottom, .rows, .columns]
  }
}
```

### Configure rendering

``AttributedStringGenerator/RenderingOptions`` configure how the system turns the HTML into an attributed string and what it may load: the `baseUrl` for relative URLs, the `timeout` of the asynchronous methods, `textSizeMultiplier` to scale all fonts, and the options for images and raw HTML that <doc:RenderingUntrustedMarkdown> describes.

The synchronous `generate(doc:)` needs the main thread and never loads remote images. `generateAsync(doc:)` does not block the thread and loads everything the HTML refers to, within the timeout. It also renders Mermaid diagrams first. See <doc:GeneratingOutput> and <doc:UsingMarkdownKitConcurrently>.

### Know what the importer ignores

The HTML importer of macOS and iOS supports only a part of CSS, and the results differ between versions of the systems. These are the restrictions that MarkdownKit works around, found by measuring the attributed strings on macOS and in the iOS simulator:

- Only the `margin-bottom` of a block reaches the attributed string, as the paragraph spacing after it. `margin-top`, `padding-top` and `border-top` are ignored, so the space above a block is only the bottom margin of the previous block. Changing the top margin in ``AttributedStringGenerator/h1Style`` has no effect. This is why the generator inserts an empty paragraph with ``AttributedStringGenerator/h1GapStyle`` or ``AttributedStringGenerator/h2GapStyle`` in front of level 1 and level 2 headings that do not start their container, and why you can change the amount of space with those styles.
- The CSS property `line-height` is ignored. ``AttributedStringGenerator/lineSpacing`` and ``AttributedStringGenerator/codeBlockLineSpacing`` are therefore applied to the attributed string after the import, as the `lineHeightMultiple` of its paragraph styles. Paragraphs with images and the empty paragraphs that only create space keep their line height, because the multiple would also scale an image. The importer does not mark code blocks, so the generator recognizes them by their background color and their font: it puts an element in the style of code at the start of the HTML, reads its font (the importer decides which font the CSS list `codeFontFamily` stands for) from the imported string and removes the element again. A paragraph with a background and the same font family and size is code. This does not change the HTML that ``AttributedStringGenerator/generateHtml(_:)`` returns.
- Scripts never run. The `width` and `height` attributes of images and CSS sizes are ignored. On macOS, the size of an image comes from the resolution stored in the image file; iOS ignores the resolution.
- Images in `file:` URLs only load if the `baseUrl` of the rendering options matches. Images in `data:` URLs always load.
- `<input>` elements are ignored, which is why task list items use the characters ☐ and ☑.
- The importer does not scale a font below 9 points: with a `textSizeMultiplier` that would make text smaller, it stays at 9 points. This is why the text of PDF documents, which is scaled down, is never smaller than that.
- On iOS, `generateAsync` loads the HTML in WebKit, whose text autosizing enlarged the paragraphs and lists of larger documents (14 points became 21 or 23, tables and headings stayed). The generator adds a style that fixes the size at the `textSizeMultiplier` of the rendering options (1 by default), so the sizes are those of the style sheet. This concerns `MarkdownUtil.rtf` and `rtfd` on iOS as well.

If a style has no effect, check the attributed string, e.g. its paragraph styles and fonts, before you investigate the CSS.

## See Also

- <doc:GeneratingOutput>
- <doc:DisplayingMarkdownWithSwiftUI>
