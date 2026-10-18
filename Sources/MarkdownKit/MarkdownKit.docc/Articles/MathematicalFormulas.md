# Mathematical Formulas

Parse LaTeX formulas in Markdown text and show them in HTML, as plain text and as images in attributed strings.

<!-- Adapted from the README section "Markdown extensions". -->

## Overview

``MathMarkdownParser`` recognizes LaTeX math. The other parsers do not: dollar signs are common in text (`costs $5 and $6`), so they leave them alone, and existing code does not change its behavior. A formula is a ``MathFragment`` within text or a ``MathBlock`` which is a block of its own. ``LaTeXMarkdownParser`` recognizes the delimiters of LaTeX in addition. Both are custom syntax tree nodes (the `custom` cases of ``TextFragment`` and ``Block``), so a `switch` over these enumerations does not have to change.

```swift
let doc = MathMarkdownParser.standard.parse("The area is $\\pi r^2$.")
print(HtmlGenerator.standard.generate(doc: doc))
// <p>The area is <span class="math inline">\(\pi r^2\)</span>.</p>
```

### Write formulas

- `$a^2 + b^2 = c^2$` is a formula within a line of text.
- `$$a^2$$` within a line of text is a display formula.
- A formula which is a block of its own is enclosed by two lines with `$$`. The LaTeX can also be on these lines, and a block can consist of a single line (`$$ a^2 $$`).
- A fenced code block with the info string `math` is a formula, too.

```
$$
\int_0^1 x^2 \, dx = \frac{1}{3}
$$
```

The rules for single dollar signs are those of Pandoc. The opening `$` is followed by a character which is not white space, and the closing `$` is not preceded by white space and not followed by a digit. So `costs $5 and $6` and `$5,$6` are text. The first `$` after the opening one decides: if it cannot close a formula, the opening `$` is an ordinary character. A backslash in front of `$` makes it an ordinary character, so `\$5` is text and `$a\$b$` is one formula.

Markdown within a formula is left alone, and a formula does not interfere with the Markdown around it. `$a_b + c_d$` and `$f^*(x) + g^*(y)$` are formulas and not emphasis, a link in a formula stays text, `**$x$**` is strong emphasis, and a formula within a code span is code. Like in GitHub Markdown, a code span between dollar signs is a formula as well; it is the way to write LaTeX which would be ambiguous otherwise.

A few restrictions follow from how Markdown is parsed:

- The block structure of a document is parsed before its formulas. A line of a formula within a paragraph that starts a list, a block quote, a heading or a table ends the paragraph, so use a `$$` block for such formulas.
- A `$$` block cannot contain a blank line. A block which is not closed before the end of its container or a blank line is parsed as a paragraph, as are lines with more `$$` than the opening and closing ones (`$$a$$ and $$b$$` is text with two formulas).
- Tables are split into cells before the formulas are parsed. Write `\vert` instead of `|` in a formula within a table cell.
- A fenced code block with the info string `math` is only turned into a formula if the inline markup is parsed, which is not the case if the parser only runs the block parsers.

### Use the delimiters of LaTeX

Language models and many LaTeX users write formulas between `\(` and `\)` (within a line) and between `\[` and `\]` (display math). ``LaTeXMarkdownParser`` recognizes these forms in addition to everything that ``MathMarkdownParser`` does:

- `\(a^2\)` is a formula within a line of text, and `\[a^2\]` a display formula within a line.
- A formula which is a block of its own is enclosed by two lines with `\[` and `\]`; the LaTeX can also be on these lines, and a block can consist of a single line (`\[ a^2 \]`).

```swift
let doc = LaTeXMarkdownParser.standard.parse("The area is \\(\\pi r^2\\).")
```

```
\[
\int_0^1 x^2 \, dx = \frac{1}{3}
\]
```

This is a parser of its own because a backslash in front of a parenthesis or a bracket escapes it in Markdown: `\(a\)` is the text `(a)` for all other parsers, so existing documents could change their meaning. The rules are simpler than those for dollar signs, since the delimiters are unambiguous. A formula ends at the first closing delimiter whose backslash is not escaped (`\(\{x\}\)` is one formula, and so is `\(a \\) b\)`, in which `\\)` is a line break and a parenthesis). It can have white space and a line break at its ends, but it has to contain LaTeX, and `\(\)` is text. A code span cannot be part of a formula, and a formula which is not closed before the end of the paragraph is text. A backslash which is itself escaped does not start a formula: in `\\(a\\)`, the parentheses are ordinary text. As with the dollar signs, the restrictions for formulas in tables and the other blocks apply, and the lines of a `\[` block are not parsed as Markdown. The forms with dollar signs and the fenced `math` code blocks work as before, and the formula that starts first wins: in `$a \(b$ c\)`, the first formula ends at the second dollar sign.

### Show formulas

How a formula is shown depends on the generator:

- ``HtmlGenerator`` creates `<span class="math inline">\(…\)</span>` for a formula within a line, `<span class="math display">\[…\]</span>` for a display formula and `<div class="math display">\[…\]</div>` for a block. The LaTeX is escaped. Libraries such as [KaTeX](https://katex.org) and [MathJax](https://www.mathjax.org) typeset these elements in a web page.
- ``MathHtmlGenerator`` can typeset the formulas itself, see below.
- ``StringGenerator`` and ``TerminalGenerator`` show the LaTeX as it was written, with its dollar signs. Control characters in the LaTeX are replaced.
- ``AttributedStringGenerator`` shows the LaTeX as code (a code block for a block). The system's HTML importer cannot typeset formulas. ``MathAttributedStringGenerator`` shows images of the typeset formulas, see below.

### Typeset formulas in HTML

``MathHtmlGenerator`` is an ``HtmlGenerator`` that runs [KaTeX](https://katex.org) and puts the markup of the typeset formulas into the HTML. KaTeX is part of MarkdownKit and runs in JavaScriptCore (see ``KaTeXEngine``), so it works without a web view, on every platform but watchOS. The parameter `math:` is a ``MathHtmlGenerator/Output``:

| Output | Result |
|---|---|
| ``MathHtmlGenerator/Output/delimiters`` | the LaTeX between delimiters, for a script in the page (the default, and the output of every other generator) |
| ``MathHtmlGenerator/Output/html`` | HTML for a visual rendering; the page needs the style sheet and fonts of KaTeX |
| ``MathHtmlGenerator/Output/mathml`` | MathML only; browsers display it without further resources |
| ``MathHtmlGenerator/Output/htmlAndMathml`` | HTML for the display and MathML for accessibility, the default of KaTeX; the page needs the style sheet and fonts of KaTeX |
| ``MathHtmlGenerator/Output/katex(_:)`` | one of the above with the ``KaTeXOptions`` you give: macros, limits for expansions and sizes |

```swift
let generator = MathHtmlGenerator(math: .mathml)
let html = generator.generate(doc: MathMarkdownParser.standard.parse("The area is $\\pi r^2$."))
```

A formula within a line is wrapped in `<span class="math inline">`, a display formula in a line in `<span class="math display">`, and a block in `<div class="math display">`. The style sheet that belongs to the HTML of KaTeX is at ``KaTeXEngine/stylesheetURL``; it loads the fonts from the same place.

The output of untrusted Markdown is safe. KaTeX is not allowed to create links, images or arbitrary HTML (the commands `\href`, `\url`, `\includegraphics` and `\htmlClass` are shown as text), it stops macros that do not terminate, and formulas of more than 10,000 bytes (``KaTeXOptions/maxLength``) are rejected before KaTeX sees them. A formula that KaTeX does not understand is not dropped: the HTML contains its source in an element with the class `katex-error`, and the message of KaTeX as its title.

To typeset formulas in another way, adopt ``MathHtmlRendering`` in your own subclass of ``HtmlGenerator``. Its method receives the LaTeX and returns the HTML (or `nil` for the delimiters). You can call ``KaTeXEngine`` directly as well:

```swift
let markup = try KaTeXEngine.shared?.render("x^2", options: KaTeXOptions(output: .mathml))
```

### Draw formulas in attributed strings

``MathAttributedStringGenerator`` is an ``AttributedStringGenerator`` that shows formulas as images, on macOS and iOS. On the other platforms the LaTeX stays code. It is a subclass that uses the extension points of its superclass, so the formulas are the only difference to the attributed strings of the superclass. All parameters of the initializer of the superclass are available; the additional parameters `math:` (a ``MathConfig``) and `mathRenderer:` configure the formulas.

```swift
let generator = MathAttributedStringGenerator(fontSize: 16)
let doc = MathMarkdownParser.standard.parse("The area is $\\pi r^2$.")
let text = try await generator.generateAsync(doc: doc)
```

The system's HTML importer cannot typeset formulas, and it ignores the size of an image, so the HTML that the generator creates contains a placeholder for each formula. Once the importer has created the attributed string, the placeholders are replaced with `NSTextAttachment`s. This is what the generator does for Mermaid diagrams as well (see <doc:DrawingMermaidDiagrams>), and it works the same way: ``MathRenderer`` draws the formulas, which takes some time, so the asynchronous methods (`generateAsync`) render them first. The synchronous method `generate(doc:)` cannot wait: it shows the formulas which have been rendered before, which ``MathAttributedStringGenerator/prepareMath(in:)-(Block)`` does ahead of time, and shows the others as code.

The images look like the text around them:

- A formula within a line of text sits on the baseline of the text, so that the fraction bar is between the lines of the text, and a subscript hangs below it.
- A formula has the colour of the text around it. This includes the colour of a link, and the colour of the light and dark variant of a generator. The renderer draws the formulas in black; the generator applies the colour of the text when it creates the attachment (macOS does not tint images by itself). The LaTeX command `\color` is not reflected.
- A formula is as large as the text, scaled with the font size of the text around it: formulas in headings are larger, and the rendering option `textSizeMultiplier` applies to them as well. Formulas are drawn for the font size of the generator, and the cache of the renderer depends on it.
- A formula that is a block is a centered paragraph with at least ``MathConfig/spacing`` points above and below it. A formula that is wider than its line is scaled down to the width of the line, whenever the text is laid out, and ``MathConfig/maxWidth`` limits the width.
- A formula that KaTeX does not understand is shown as code, a block with a note that has the message of KaTeX. The same holds for a formula that was not rendered in time (``MathConfig/timeout``).

The attachment of a formula has the attribute ``Foundation/NSAttributedString/Key/mathSource``, which holds the formula as it was written, for example to copy it as text, and an accessibility label with the LaTeX. The data of the attachment is a PNG image, so the formula survives copy and paste. RTFD export keeps the images but loses the baseline offset of formulas within a line, and RTF cannot contain images.

``MathRenderer`` renders formulas with [KaTeX](https://katex.org) in a headless web view that is created when the first formula is rendered and released a minute after the last use (`idleTime`). The web view cannot load anything from the network or from files: the style sheet and the fonts of KaTeX are part of its page. It draws up to a hundred formulas at a time, so a document with many formulas takes a fraction of a second; for each formula, it determines its size and the distance of its baseline from the lower edge. The images are PNG images at three pixels per point (``MathConfig/scale``), which are black on a transparent background, and about 10 KB each. The renderer caches them: by default 2,000 formulas and 32 MB. A renderer of your own (`MathRenderer(katexFolder:idleTime:maxCachedFormulas:maxCacheBytes:)`) lets you choose the limits; ``MathRenderer/shared`` is used if the generator is not given one. You can also call the renderer yourself if you need the images of formulas:

```swift
let formula = MathFormula(tex: "\\sum_{i=1}^n i = \\frac{n(n+1)}{2}", display: true)
let results = await MathRenderer.shared?.render([formula], fontSize: 14)
if case .success(let image)? = results?[formula] {
  // image.pngData is a PNG image of image.size points
}
```

Formulas in untrusted Markdown are as safe in the web view as in HTML: the options of KaTeX do not allow links and images, macros are limited, and formulas of more than 10,000 bytes are rejected (``KaTeXOptions/maxLength``); the page has a content security policy without network access. Use the limit ``MathConfig/timeout`` for the time a rendering may take.

The SwiftUI view ``MarkdownText`` shows formulas if it is given a ``MathConfig`` (`MarkdownText(string: text, math: MathConfig())`), see <doc:DisplayingMarkdownWithSwiftUI>.

### Render formulas before generating the text

Drawing formulas takes time, so it is asynchronous, as it is for diagrams:

- `generateAsync` renders all formulas of the document before it generates the attributed string.
- `generate(doc:)` cannot wait for a web view; it shows the formulas that have been rendered before, and code for the others. Call `await generator.prepareMath(in: doc)` first to render them (it returns `true` if it rendered anything, i.e. if `generate(doc:)` now gives a different result). Code that does not use Swift concurrency calls `generator.prepareMath(in: doc) { rendered in … }` instead; the handler is called exactly once, asynchronously, on the main thread. There is no blocking variant: the web view that draws the formulas needs the main thread, so waiting for it there would mean running the run loop inside the call.
- ``MarkdownText`` `(_:math:)` and `(string:math:)` show the code first and replace it with the formulas once they are available. A string is parsed with ``MathMarkdownParser`` then, unless `dialect:` selects another parser.

### Understand the cache and configure the formulas

Rendered formulas, and the errors of formulas which KaTeX rejected, are kept in memory by the ``MathRenderer`` (``MathRenderer/shared`` by default; pass `mathRenderer:` to the generator for another one). They are keyed by the formula (its LaTeX and whether it is display math), the font size of the generator and the KaTeX options and scale. The color is not part of the key: the images are black, so generators for light and dark mode share them. The cache holds at most 2,000 results and 32 MiB of images by default and drops the ones that were used least recently; `MathRenderer(katexFolder:idleTime:maxCachedFormulas:maxCacheBytes:)` sets other limits.

`generateAsync` keeps the formulas of the document it generates itself, so it shows all of them whatever the size of the cache. `generate(doc:)`, and ``MarkdownText``, which uses it, only show the formulas that are in the cache: `maxCachedFormulas` should be at least the number of formulas in the largest document that you display in this way. `MathRenderer.render(_:fontSize:config:)` has a variant `render(_:fontSize:config:completionHandler:)` for code that does not use Swift concurrency.

A ``MathConfig`` sets:

- the KaTeX options `katex:` (``KaTeXOptions``: `macros`, a limit for macro expansions, the maximal size, and the maximal length of a formula, which is 10,000 bytes by default),
- the `scale` of the images (pixels per point, default 3),
- the `spacing` between a block formula and the text above and below it (at least 8 points),
- a `maxWidth` for a formula, and
- the `timeout` for rendering a batch of formulas (15 seconds).

The web view is created when the first formula is rendered and released after 60 seconds without requests; create the ``MathRenderer`` with `idleTime:` to change that (`0` releases it as soon as no request is waiting, `.infinity` never releases it). To use another version of KaTeX, replace the folder `Sources/MarkdownKit/Math/KaTeX` (it contains `katex.min.js`, `katex.min.css` and the folder `fonts`) and update ``KaTeXEngine/bundledVersion``.

### Combine the parser with your own markup

``MathMarkdownParser`` is a ``FullMarkdownParser`` with two additions (``LaTeXMarkdownParser`` replaces them with ``LaTeXMathTransformer``, a ``MathTransformer`` that also recognizes `\(` and `\[`, and adds ``LaTeXMathBlockParser`` right after ``MathBlockParser``). ``MathTransformer`` has to come after `CodeLinkHtmlTransformer` and before `LinkTransformer` in the list of inline transformers: code, HTML and autolinks are complete at this point, while emphasis, links and escapes have not yet changed the characters of the formula. ``MathBlockParser`` has to come before `TableParser`. ``MathInlineParser`` turns fenced code blocks into formulas. To use the syntax in another configuration, build the parser from the same pieces, as in ``MathMarkdownParser/defaultInlineTransformers``.

## See Also

- <doc:ChoosingAParser>
- <doc:ExtendingTheParser>
