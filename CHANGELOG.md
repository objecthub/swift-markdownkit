# Changelog

## 2.0 (2026-10-10)

Source-incompatible changes:

- `CustomBlock`, `CustomTextFragment` and the `TableRenderer` protocols refine `Sendable`. Custom types have to be `Sendable` (an error in Swift 6 language mode).
- Subclasses of the parsers and generators get the warning "must restate inherited '@unchecked Sendable' conformance" (in any language mode). Add `@unchecked Sendable` to the subclass.
- `HighlightingConfig` and `AnsiHighlightingConfig` are structs now. A config whose properties are changed has to be a `var`, and changing a copy does not change the config of a generator.
- `SyntaxHighlighter.proxy` is a constant (`static let`; it was a `static var` before 1.5).
- `TextFragment` has the new cases `underline` and `strikethrough`, and `ListType` has the new case `task(_, checked:)`. `switch` statements over them have to handle the cases. The type of a task list item wraps the original one: use `ListType.marker` to get its bullet or number (`.bullet(…)` does not match it).
- `HtmlGenerator.init()` is now `init(safeMode:)` with a default value. A subclass with `override init()` has to declare `init()` without `override`.
- Coming from 1.4: see 1.5 below for changes of the output of the parsers and generators (e.g. `&amp;` in URLs, hard line breaks, tab stops, lists).

Other changes:

- New `FullMarkdownParser` (a subclass of `ExtendedMarkdownParser`) with all features of MarkdownKit: tables, definition lists, underlined text (`~underlined~`), struck-through text (`~~struck through~~`; `~~~` and longer runs are text) and task list items (`- [ ] to do`, `- [x] done`). New features will be added to it; `MarkdownParser` and `ExtendedMarkdownParser` behave as before. HTML uses `<u>`, `<del>` and `<input type="checkbox">`, attributed strings use ☐ and ☑, and the text generators write `[ ]` and `[x]`. `TerminalGenerator` has the new parameters `underlineProperties` and `strikethroughProperties`.
- A table without rows is rendered without an empty `<tbody>` (by all parsers), like in GFM.
- A block quote in an attributed string is a single table cell with a left border instead of three cells (`AttributedStringGenerator.quoteStyle` styles this cell). With the empty cells, text views clipped the first lines of a quote at some positions in a document.
- `CustomTextFragment` has the new requirements `generateText(via: StringGenerator)` and `generateText(via: TerminalGenerator)`. They have default implementations (the raw text), so existing fragments keep working.
- MarkdownKit is compiled in Swift 6 language mode. Syntax trees, options, configurations, parsers, generators, table renderers and `SyntaxHighlighter` are `Sendable`, so they can be shared by threads and tasks (a `Block` can be parsed in a background task and used on the main actor). The classes are `open` and conform `@unchecked`: they are immutable, and subclasses with mutable state have to synchronize it. `generateAsync` returns `sending NSAttributedString`, and its completion handlers take a `sending` result.
- Highlighting themes are parsed and applied like CSS. Custom themes can be formatted by hand (whitespace, comments, `!important`). Selectors are matched properly (`.a .b`, `.a > .b`, `.a.b`; the higher specificity wins, then the last rule), `@media` blocks are ignored, and a selector list ending with a compound selector is used completely. Before, competing rules were merged in a random order (the colors of a quarter of the bundled themes differed from run to run), and such selector lists were dropped in nine themes (e.g. the keyword color of `github-dark`). Text can be bold and italic at once (`HighlightingConfig.boldItalicCodeFont`), `font-weight: normal` and `text-decoration: none` switch styles off, changes of the fonts of a `HighlightingConfig` take effect, and `lightTheme` keeps the selectors. Styling is about 25% faster.
- The framework builds for watchOS and tvOS again (it did not compile for watchOS since 1.5; `SyntaxHighlighter` is an empty placeholder type there now).
- `SyntaxHighlighter` serializes its calls into JavaScript, so `SyntaxHighlighter.proxy` can be used from several threads. New `ConcurrencyTests` (run them with `swift test --sanitize=thread`).

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
