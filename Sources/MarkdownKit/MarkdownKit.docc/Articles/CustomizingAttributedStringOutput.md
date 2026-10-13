# Customizing Attributed String Output

Style the attributed strings that ``AttributedStringGenerator`` creates, and understand what the system's HTML importer does with the styles.

## Overview

``AttributedStringGenerator`` does not build an `NSAttributedString` itself. It works in three steps:

1. An HTML generator (``AttributedStringGenerator/InternalHtmlGenerator`` or ``AttributedStringGenerator/OS26HtmlGenerator``, a subclass of ``HtmlGenerator``) converts the syntax tree into HTML. Code blocks, block quotes, thematic breaks, tables and, in the newer version, lists become tables with CSS classes, because that is how the importer lays them out best.
2. ``AttributedStringGenerator/generateHtml(_:)`` wraps the HTML into a document with a style sheet, ``AttributedStringGenerator/docStyle``, which assigns a style property of the generator to each element and class.
3. The system's HTML importer converts the document into an attributed string. ``AttributedStringGenerator/generate(doc:)`` calls it synchronously; `generateAsync` uses `NSAttributedString.loadFromHTML`.

Everything you can customize is therefore HTML and CSS: the generator's parameters, its style properties and its CSS. The importer understands only part of CSS, see "Know what the importer ignores" below.

### Choose the generator version

``AttributedStringGenerator/Version`` selects the HTML that is generated. The default `.OS26` generates lists as tables, uses system fonts, has larger table padding and highlights the syntax of code blocks. `.preOS26` is the older generator for macOS and iOS before version 26: HTML lists, serif fonts (Times New Roman, and Consolas for code), and no syntax highlighting, so that the output of existing code, which was written before highlighting was added, does not change. Use it when you need the older look:

```swift
let generator = AttributedStringGenerator(version: .preOS26)
```

### Use the initializer parameters

The initializer takes the most frequent settings:

| Parameters | Effect |
|---|---|
| `fontSize`, `fontFamily`, `fontColor` | the body text; the font family is a CSS list, e.g. `"Helvetica, sans-serif"` |
| `codeFontSize`, `codeFontFamily`, `codeFontColor` | inline code |
| `codeBlockFontSize`, `codeBlockFontColor`, `codeBlockBackground` | code blocks |
| `borderColor`, `blockquoteColor` | the border of code blocks and thematic breaks, the bar of block quotes |
| `h1Color` to `h4Color` | headings |
| `maxImageWidth`, `maxImageHeight` | CSS limits for the size of images |
| `syntaxHighlighting`, `syntaxHighlighter` | see <doc:SyntaxHighlighting> |
| `mermaid`, `mermaidRenderer` | see <doc:DrawingMermaidDiagrams> |
| `options` | ``AttributedStringGenerator/Options``: `.tightLists` shows the paragraphs of loose list items without spacing |
| `customStyle` | CSS that is added at the end of the style sheet |
| `imageBaseUrl` | the directory against which relative image paths are resolved |
| `renderingOptions` | how the HTML is rendered and what it may load, see below |

Colors are CSS colors. The defaults are ``mdDefaultColor`` and ``mdDefaultBackgroundColor``, the hex values of the system's text and background color. They are determined once, for the appearance that is active when they are first used, so use a generator with explicit colors for dark mode, as in <doc:DisplayingMarkdownWithSwiftUI>.

```swift
let generator = AttributedStringGenerator(fontSize: 15,
                                          fontFamily: "Avenir Next, sans-serif",
                                          h1Color: "#036",
                                          customStyle: "td.quote { font-style: italic; }")
```

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
- Scripts never run. The `width` and `height` attributes of images and CSS sizes are ignored. On macOS, the size of an image comes from the resolution stored in the image file; iOS ignores the resolution.
- Images in `file:` URLs only load if the `baseUrl` of the rendering options matches. Images in `data:` URLs always load.
- `<input>` elements are ignored, which is why task list items use the characters ☐ and ☑.

If a style has no effect, check the attributed string, e.g. its paragraph styles and fonts, before you investigate the CSS.

## See Also

- <doc:GeneratingOutput>
- <doc:DisplayingMarkdownWithSwiftUI>
