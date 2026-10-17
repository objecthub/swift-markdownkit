# Changelog

## 2.1.1 (2026-10-17)

New features and other changes:

- `AttributedStringGenerator` has the new parameters (and properties) `lineSpacing` and `codeBlockLineSpacing`. They set the line height of text and of code blocks as a multiple of the natural line height of the font; the defaults are 1.1 and 1.0. **The default for text changes the output:** its lines are 10% higher than before; pass `lineSpacing: 1` for the old line height. The system's HTML importer ignores the CSS property `line-height`, so the generator sets `lineHeightMultiple` in the paragraph styles of the attributed string after the import (also with `generateAsync`). Paragraphs with images (including Mermaid diagrams) and the empty paragraphs which only create space keep their line height. The importer does not mark code blocks, so they are recognized by their background color and their font: the generator puts an element in the style of code at the start of the HTML it passes to the importer, compares the fonts of the paragraphs with the font of that element (family and size) and removes it again. `generateHtml(_:)` is not changed.

## 2.1 (2026-10-16)

Source-incompatible changes:

- Function `htmlGenerator(options:)` replaces property `AttributedStringGenerator.htmlGenerator`, so `generator.htmlGenerator` becomes `generator.htmlGenerator()`; `options` replaces `renderingOptions` for the new generator and is `nil` by default. The method returns an `AttributedStringGenerator.InternalHtmlGenerator`, not any `HtmlGenerator`, because the generator also holds the Mermaid diagrams for the attributed string. A subclass that overrides it has to return an `InternalHtmlGenerator` (e.g. an instance of a subclass of it), and no longer a plain `HtmlGenerator`.
- `AttributedStringGenerator.Version.makeHtmlGenerator(for:renderingOptions:)` returns an `InternalHtmlGenerator`, and `makeHtmlGenerator(for:)` is gone (pass the `renderingOptions` of the generator). The initializers `InternalHtmlGenerator(outer:renderingOptions:)` and `OS26HtmlGenerator(outer:renderingOptions:)` require the `renderingOptions`; before, they were optional and defaulted to those of `outer`.
- `TerminalGenerator.TableDescriptor` is gone. Its properties and initializer were not accessible outside of the framework, so nobody could use the table descriptors. `TerminalGenerator.TableRenderer` and the methods of `TerminalGenerator` use the top-level `TableDescriptor` now, which `StringGenerator` uses as well and which has public properties: a custom `TerminalGenerator.TableRenderer` declares `renderTable(_:using:in:)` with a `TableDescriptor`.

New features and other changes:

- `AttributedStringGenerator.tableRowStyle` has an effect now. The style sheet applied it to `td.mrow`, but the rows of a table are `tr` elements; it is `tr.mrow` now.
- MarkdownKit has API documentation in DocC format. The new catalog `Sources/MarkdownKit/MarkdownKit.docc` has a landing page, 18 articles (getting started, choosing and extending the parser, the syntax tree, the generators and how to customize them, syntax highlighting, untrusted Markdown, Mermaid diagrams, SwiftUI, concurrency, recipes and a migration guide) and curated topic groups for the large types. The doc comments of almost all public symbols were completed, in particular the cases of `Block` and `TextFragment`, the style properties of `AttributedStringGenerator`, the overridable methods of the text generators and the parser extension points. `.spi.yml` lets the Swift Package Index build and host the documentation, which is also published on GitHub Pages at https://objecthub.github.io/swift-markdownkit/ (`Scripts/generate-docs.sh` generates the site into the `gh-pages` branch). In Xcode, Product > Build Documentation shows it.
- `AttributedStringGenerator` can draw [Mermaid](https://mermaid.js.org) diagrams (fenced code blocks with language `mermaid`) if it is created with the new parameter `mermaid:` (a `MermaidConfig`; `nil` by default, which shows the diagram as code like any other code block). The diagrams are drawn by the new `MermaidRenderer`, which runs the bundled `mermaid.min.js` in a headless `WKWebView` (macOS and iOS only) and caches the PNG images; `MermaidRenderer.render(_:config:)` also returns the PNG image of a diagram on its own, without an attributed string. `generateAsync` renders the diagrams first; `generate(doc:)` shows the ones that were rendered before, which `prepareDiagrams(in:)` does ahead of time. Before, such blocks showed up as unstyled text in the attributed string (a `<pre class="mermaid">` element which nothing turned into a diagram).
- The empty space which Mermaid leaves around a diagram (over 100 points on the left of a sequence diagram that starts with an actor) is removed; `MermaidConfig.margin` sets the margin that is left instead, and `MermaidConfig.spacing` the least distance between a diagram and the text above and below it.
- Level 1 and level 2 headings which do not start the document (or a block quote or list item) get more space above them in attributed strings. The HTML importer ignores the top margin of a heading, so `AttributedStringGenerator` inserts an empty paragraph in front of the heading: 8 px for level 1 (`h1GapStyle`) and 4 px for level 2 (`h2GapStyle`).
- `MarkdownKitProcess` draws Mermaid diagrams in RTFD output. RTF files cannot contain images, so the format `rtf` still shows the code. The new file `Examples/Demo.md` is the demo document of `MarkdownViewer` (including nested diagrams) for trying the tool.
- `MarkdownKitProcess` parses with `FullMarkdownParser` (underline, strikethrough and task lists) and its command line is defined with `CommandLineKit`: the format and width are the options `--format` (default `text`) and `--width`, followed by the source and the optional target, e.g. `MarkdownKitProcess --format rtfd a.md`; before, they were positional arguments. Existing output files are only replaced with the new option `--overwrite`; without it the tool reports an error and exits with status 1, as it does for any other failure. A file can be converted into an existing directory.
- `generateAsync` shows all diagrams of a document whatever the size of the cache of the `MermaidRenderer` (it keeps the results it collects while rendering them). `generate(doc:)` and `MarkdownText` only show the diagrams that are in the cache.
- `AttributedStringGenerator.prepareDiagrams(in:completionHandler:)` (for `Block` and `Blocks`) and `MermaidRenderer.render(_:config:completionHandler:)` are the variants of the asynchronous methods for code which does not use Swift concurrency. Like the completion handlers of `generateAsync`, the handler is called exactly once, asynchronously, on the main thread.
- `MarkdownText(_:mermaid:)` and `MarkdownText(string:mermaid:)` show diagrams, rendered in the background, with the dark theme in dark mode (`MermaidConfig.darkVariant`).
- The bundle is located by the new internal `Resources`; the resources `mermaid.min.js` (Mermaid 11.17.2) and its license were added.

## 2.0 (2026-10-10)

Source-incompatible changes:

- New enum cases `TextFragment.underline`, `TextFragment.strikethrough` and `ListType.task(_, checked:)`: `switch` statements over them have to handle the cases. The type of a task item wraps the original one, so use `ListType.marker` to get its bullet or number.
- `CustomBlock`, `CustomTextFragment` and the `TableRenderer` protocols refine `Sendable`. Subclasses of parsers and generators get the warning "must restate inherited '@unchecked Sendable' conformance": add `@unchecked Sendable`.
- `HighlightingConfig` and `AnsiHighlightingConfig` are structs (a changed config has to be a `var`), and `TerminalGenerator.init` has the new parameters `underlineProperties` and `strikethroughProperties` (subclasses overriding it have to adopt them).
- Coming from 1.4: see 1.5 below for output changes of the parsers and generators. Also, `SyntaxHighlighter.proxy` is a `static let`, and `HtmlGenerator.init()` is `init(safeMode:)` (a subclass with `override init()` has to declare `init()` without `override`).

New features:

- `FullMarkdownParser` (a subclass of `ExtendedMarkdownParser`) supports all features of MarkdownKit: tables, definition lists, underline (`~x~`), strikethrough (`~~x~~`) and task lists (`- [ ] to do`, `- [x] done`). The other parsers are unchanged. HTML uses `<u>`, `<del>` and `<input type="checkbox">`, attributed strings ☐ and ☑, and the text generators `[ ]` and `[x]`. `MarkdownText(string:full:…)` uses it if `full` is `true`.
- Highlighting themes are parsed and applied like CSS (whitespace, comments, `!important`, selectors and specificity). Before, competing rules were merged in a random order and some selector lists were dropped. Text can be bold and italic at once (`HighlightingConfig.boldItalicCodeFont`), and styling is about 25% faster.
- New command-line tool `MarkdownTermViewer` prints the demo document of `MarkdownViewer` as plain text (`--format text`, the default) or with ANSI escape codes (`--format ansi`).

Other changes:

- MarkdownKit is compiled in Swift 6 language mode. Syntax trees, options, configurations, parsers, generators and `SyntaxHighlighter` are `Sendable` (e.g. a `Block` can be parsed in a background task); the classes are `open` and conform `@unchecked`. `generateAsync` returns `sending NSAttributedString`. `SyntaxHighlighter.proxy` can be used from several threads. New `ConcurrencyTests` (`swift test --sanitize=thread`).
- Attributed strings: bullets and checkboxes are right-aligned before the text, like numbers (`bulletStyle`, `checkboxStyle`), and a block quote is a single table cell (`quoteStyle`), because empty cells made text views clip its first lines.
- A table without rows has no empty `<tbody>`. `CustomTextFragment` has the new requirements `generateText(via:)` with default implementations. The framework builds for watchOS and tvOS again.

## 1.5 (2026-10-09)

- New `AttributedStringGenerator.generateAsync(doc:options:)` (also for `block:` and `blocks:`, and with completion handlers) renders the HTML via `NSAttributedString.loadFromHTML` without blocking the calling thread. It throws an `AttributedStringGenerator.RenderingError` (`Equatable`, `LocalizedError`). Available on macOS and iOS.
- New `AttributedStringGenerator.RenderingOptions` (parameter and property `renderingOptions`, and `options` of `generateAsync`; `Equatable`): `baseUrl`, `timeout` (default 30 seconds, asynchronous only), `textSizeMultiplier`, `safeMode`, and `localImages` and `remoteImages` (`ImageAccess`: `.none`, `.any`, `.within(URL)`) to restrict which images of the Markdown text are loaded. Images need one of the path extensions in `imageExtensions`, so by default images without such an extension (e.g. `.txt` files) are replaced by their alternative text. Without restrictions, the system's HTML renderers load any file an image URL points to; raw HTML is not covered by the restrictions. `RenderingOptions.untrusted` (safe mode, no images) is the preset for untrusted Markdown; `RenderingOptions.trusted` restricts nothing and equals `RenderingOptions()`.
- `MarkdownText(_:waitingMessage:renderingOptions:)` and `MarkdownText(string:waitingMessage:renderingOptions:)` are new (default `.trusted`). The `generator` parameter of the other initializers has no default value any more; calls without it behave as before. The view now displays new content for a different document, uses a dark highlighting theme in dark mode, and keeps the text selection.
- Subclassing outside of the framework works: the parsers, transformers, `InlineParser`, `GeneratorContext` and the table renderers have `open` methods (they were `public` in `open` classes), `InlineParser.init` and `GeneratorContext.init` are `public`, and `BlockParser.resetLineStart(_:partialTab:)` lets external block parsers start containers.
- Security hardening for untrusted Markdown:
  - `HtmlGenerator` always escapes `href`, `src`, `title`, `alt` and autolink text; before, a crafted link or image could break out of an attribute. Generated HTML now contains `&amp;` for each `&` in a URL. A bypass with combining characters is fixed.
  - New opt-in `HtmlGenerator(safeMode: true)` omits raw HTML and empties URLs with schemes other than `http`, `https` and `mailto`. `HtmlGenerator` gains the methods `hrefAttribute(_:decode:image:)` and `titleAttribute(_:)` for subclasses.
  - Code is escaped in the HTML of `AttributedStringGenerator` if it is not highlighted; the `class` of fenced code blocks is escaped.
  - `TerminalGenerator` and `StringGenerator` replace control and bidirectional formatting characters with U+FFFD.
  - Deeply nested input no longer overflows the stack. The nesting depth is limited to 24 (`DocumentParser.maxContainerDepth`, `InlineParser.maxNestingDepth`); deeper markup stays text.
- Crashes fixed: a table followed by a whitespace-only last line, a paragraph starting with a lone `\` (needs CommandLineKit 1.1.2), highlighted code ending in `<`, invalid `TextFragment.delimiter` counts, ragged tables, and `generate(doc:)` for a block that is not a document.
- `TerminalGenerator` no longer garbles highlighted code containing `<` and keeps its blank lines. The language of a fenced code block is the first word of the info string; `AttributedStringGenerator` highlights only if `syntaxHighlighting` is not `nil`.
- All 652 examples of CommonMark 0.31.2 pass. Fixes include list looseness, tab stops, backslash escapes, link reference definitions, HTML blocks, tables and code spans, and `Hello![World]` no longer loses its `!`. The parser resolves backslash escapes and entities in info strings (`Block.fencedCode` holds the resolved string). Hard line breaks are now determined by the inline parser: `EscapeTransformer` must be the last inline transformer, and trees from `parse(_:blockOnly: true)` contain no hard line breaks (`Text.append(line:withHardLineBreak:)` no longer interprets a trailing backslash). The AST of `foo\bar` is `text("foo\\bar")`.
- Parsing and word wrapping take linear time (they were quadratic or worse for some inputs).
- The package manifest uses `swift-tools-version:6.0` (sources still compile in Swift 5 mode). New tests include fuzzing, the CommonMark examples, security, nesting and performance tests.

## 1.4 (2026-06-01)

- SwiftUI view for Markdown based on attributed strings (for iOS and macOS). The view supports the full Markdown syntax, is fully responsive and adjusts dynamically also to changes to the color scheme.
- Generators for formatted text (i.e. for display in text editors) and for output in ANSI terminals (including ANSI-compliant markup). Full support for unicode characters.
- Support for syntax highlighting of code blocks across `HtmlGenerator`, `AttributedStringGenerator`, and `TerminalGenerator`.

## 1.3 (2025-05-04)

- Loose lists are now detected correctly based on section 5.3 of the CommonMark spec. This fixes a serious bug that was leading to too may lists being interpreted as loose.
- The signature of case `listItem` of enum `Block` changes to enable this bug fix.
- Fixed accessibility bug that prevented `EmphasisTransformer` to be extensible.

## 1.2 (2025-03-28)

- Improve the generation of nested lists for `AttributedStringGenerator`
- Introduce a new option `tightLists` for `AttributedStringGenerator` which renders lists more compactly
- The API of `AttributedStringGenerator` changes with this release

## 1.1.9 (2024-08-04)

- Support converting Markdown into a string without any markup

## 1.1.8 (2024-05-01)
- Fix `Color.hexString` on iOS to handle black correctly
- Clean up `Package.swift`
- Updated `CHANGELOG`

## 1.1.7 (2023-04-10)
- Fix handling of copyright sign when escaped as XML named character

## 1.1.6 (2023-04-10)
- Migrate framework to Xcode 14
- Fix tests related to images in attributed strings

## 1.1.5 (2022-02-27)
- Bug fixes to make `AttributedStringGenerator` work with images.

## 1.1.4 (2022-02-27)
- Allow customization of image sizes in the `AttributedStringGenerator`
- Support relative image links in the `AttributedStringGenerator`

## 1.1.3 (2022-02-07)
- Fix build breakage for Linux
- Encode predefined XML entities also for code blocks
- Migrate framework to Xcode 13

## 1.1.2 (2021-06-30)
- Allow creation of definition lists outside of MarkdownKit

## 1.1.0 (2021-05-12)
- Make abstract syntax trees extensible
- Provide a simple means to define new types of emphasis
- Document support for definition lists via `ExtendedMarkdownParser`
- Migrate framework to Xcode 12.5

## 1.0.4 (2021-02-15)
- Support Linux
- Fix handling of XML/HTML entities/named character references
- Escape angle brackets in HTML output
- Migrate project to Xcode 12.4

## 1.0.3 (2021-02-03)
- Make framework available to iOS

## 1.0.2 (2020-10-04)
- Improved extensibility of `AttributedStringGenerator` class

## 1.0.1 (2020-10-04)
- Ported to Swift 5.3
- Migrated project to Xcode 12.0

## 1.0 (2020-07-18)
- Implemented support for Markdown tables
- Made it easier to extend class `MarkdownParser`
- Included extended markdown parser `ExtendedMarkdownParser`

## 0.2.2 (2020-01-26)
- Fixed bug in AttributedStringGenerator.swift
- Migrated project to Xcode 11.3.1

## 0.2.1 (2019-12-28)
- Simplified extension/usage of NSAttributedString generator
- Migrated project to Xcode 11.3

## 0.2 (2019-10-19)
- Implemented support for backslash escaping
- Added support for using link reference definitions; not fully CommonMark-compliant yet
- Migrated project to Xcode 11.1

## 0.1 (2019-08-17)
- Initial version
