# Changelog

## Unreleased

- Fixed crashes found by fuzzing:
  - `ExtendedMarkdownParser` crashed for a table that is directly followed by a line consisting only of white space at the very end of the input (no line terminator). Tables no longer ask other block parsers to start a block on blank lines, and all block parsers now use the new `BlockParser.firstContentCharacter` instead of subscripting the line, which is out of bounds for such a line.
  - `TerminalGenerator` crashed for paragraphs or headings whose lines have no text (for example a first line that is just a `\`) because CommandLineKit's `joined(separator:)` could not join texts without segments. This is fixed in CommandLineKit 1.1.2, which MarkdownKit now requires.
  - `TerminalGenerator` crashed (uncaught `NSException`) for highlighted code blocks which end with a `<`.
  - `TextFragment.delimiter` with a count below 1, a table with more cells in a row than column alignments, and `generate(doc:)` of `HtmlGenerator`, `StringGenerator` and `TerminalGenerator` for a block that is not a document no longer trap. A block that is not a document is generated like a document consisting of this block. `MarkdownKitProcess` reports RTF conversion errors instead of crashing.
- Fixed syntax highlighting in `TerminalGenerator`: code containing `<` (like `#include <stdio.h>` or `Array<Int>`) was garbled because highlight.js's escaped output was decoded before it was converted to ANSI text, the character after a `<` was dropped, and blank lines inside of highlighted code blocks were lost. Entities are now decoded per run of text. Only the first word of the info string of a fenced code block is the language (`swift title="x"` is highlighted as Swift), and class attributes with several class names (`class="hljs-title function_"`) are styled with the styles of all their classes, also by `HighlightingConfig`.
- Fenced code blocks follow CommonMark for info strings: backslash escapes and entity references in the info string are resolved by the parser (`Block.fencedCode` contains the resolved info string, e.g. `föö` for `f&ouml;&ouml;`), and the `class` attribute of the generated code element is `language-` followed by the first word of the info string with all its characters, escaped for use in an attribute (e.g. `language-föö`, `language-;`). The restriction of the class name to the characters `A-Z a-z 0-9 _ + # . -` introduced earlier in this release is gone.
- New tests: `FuzzTests` runs random Markdown through the parsers and all generators (set `MARKDOWNKIT_FUZZ_ITERATIONS` for longer runs, `MARKDOWNKIT_FUZZ_VERBOSE` to log each input), `CommonMarkSpecTests` runs the examples of the CommonMark 0.31.2 specification (all but 11, which are listed in the test, produce equivalent HTML), and `CrashRegressionTests` covers the crashes above.
- The package manifest now uses `swift-tools-version:6.0` (the sources are still compiled in Swift 5 language mode) and the README states the supported platforms (Apple platforms only). The Xcode project now bundles the `markdownkit-dark` highlighting theme. Removed the obsolete `Tests/LinuxMain.swift`.
- New asynchronous generation of attributed strings: `AttributedStringGenerator.generateAsync(doc:options:)` (and `generateAsync(block:options:)` and `generateAsync(blocks:options:)`) render the generated HTML via `NSAttributedString.loadFromHTML` without blocking the calling thread. They are `async throws` and throw an `AttributedStringGenerator.RenderingError` (`.unsupportedPlatform`, `.cancelled`, `.timedOut`, `.renderingFailed`, `.emptyResult`). There are also variants for clients that do not use Swift concurrency: `generateAsync(doc:options:completionHandler:)` (and the `block:` and `blocks:` variants) call their completion handler exactly once, asynchronously, on the main thread, with a `Result<NSAttributedString, AttributedStringGenerator.RenderingError>`. The methods are available on macOS and iOS; on other platforms, which do not provide WebKit, they throw or report `.unsupportedPlatform`. Unlike the synchronous rendering, `loadFromHTML` also loads remote resources that the HTML refers to, so this API should only be used with untrusted Markdown if the image options described below restrict it.
- New `AttributedStringGenerator.RenderingOptions` (parameter `renderingOptions` of the initializer and property `renderingOptions`) for configuring how the generated HTML is rendered, by both the synchronous and the asynchronous methods: `baseURL` is the base URL for resolving relative URLs in the HTML, and `timeout` (default 30 seconds) limits the time of the asynchronous render. With the default options, the synchronous rendering behaves exactly as before.
- New options in `AttributedStringGenerator.RenderingOptions`: `localImages` and `remoteImages` (of the new type `ImageAccess` with the cases `.none`, `.any` and `.within(URL)`) restrict which images are loaded; `imageExtensions` (default `RenderingOptions.defaultImageExtensions`) lists the path extensions that local and remote images need to have, as a check that is independent of the location checks (`.any` or `.within`); it always applies to the images of the Markdown text, so with the default options images without such an extension (for example `.txt` files or URLs without extension) are replaced by their alternative text. A different set replaces the default. `textSizeMultiplier` scales font sizes. Without them, the system's HTML renderers load any file that an image URL points to, also non-image files and files outside of `imageBaseUrl` (`../` and absolute paths), and `generateAsync` also loads remote images and style sheets. The restrictions are enforced while generating the HTML; images that are not allowed are replaced by their alternative text. The restrictions apply to the images of the Markdown text; images and other resources referred to by raw HTML are not covered. The new, independent option `safeMode` (default `false`) generates the HTML in safe mode (`HtmlGenerator(safeMode:)`), which omits raw HTML and restricts link schemes. With the default locations (`.any`), all locations remain permitted. The per-call `options` of `generateAsync` now also apply to the generated HTML.
- Security hardening for output generated from untrusted Markdown:
  - `HtmlGenerator` now always escapes `href`, `src`, `title`, `alt` and autolink text. Previously, a crafted link or image could break out of an attribute. As a consequence, the generated HTML now contains `&amp;` for each `&` in a URL (e.g. `href="/search?a=1&amp;b=2"`). Browsers decode this back, so the link target does not change, but code that compares the generated HTML as a string may need to be updated.
  - The `class` attribute of fenced code blocks only uses the first word of the info string, and the word is escaped for use in an attribute. Before, an info string could break out of the attribute.
  - New opt-in `HtmlGenerator(safeMode: true)`. It replaces raw HTML with `<!-- raw HTML omitted -->` and renders links and images whose URLs use schemes other than `http`, `https` and `mailto` (and `data:image/…` for images) with an empty URL. Relative URLs remain allowed. `HtmlGenerator()` behaves as before for raw HTML and URL schemes.
  - `HtmlGenerator` gains the public methods `hrefAttribute(_:decode:image:)` and `titleAttribute(_:)`, which subclasses can use.
  - Code in the HTML generated by `AttributedStringGenerator` is now escaped whenever it is not syntax highlighted. Before, markup in unlabeled or unknown-language fenced code blocks (and in indented code blocks without highlighting) was interpreted by the HTML importer, e.g. as an image, instead of being displayed verbatim.
  - `TerminalGenerator` and `StringGenerator` replace control characters (C0 except tab and newline, DEL, C1) and bidirectional embedding, override and isolate characters with U+FFFD. This includes characters produced by numeric character references such as `&#27;`, and prevents injecting terminal escape sequences.
  - Fixed a bypass of the attribute escaping: `encodingPredefinedXmlEntities()` did not escape `"`, `'`, `<`, `>` and `&` when they were directly followed by a combining character (e.g. `"` followed by U+0301), because both form a single `Character`. This allowed breaking out of an HTML attribute (for example in `[a](/x"́ onmouseover=alert(1))`). The function now works on UTF-8 bytes. The URL scheme check of the safe mode had a similar problem (`javascript:` followed by a combining character was not recognized as a scheme) and now works on unicode scalars.
  - Deeply nested input no longer crashes the process with a stack overflow. Before, input such as 100,000 `>` characters, 20,000 nested list markers, or thousands of nested images or emphasis markers overflowed the stack when the syntax tree was processed (also by `HtmlGenerator`, `StringGenerator`, `TerminalGenerator`, and when the tree was released). Block quotes and list items can now be nested up to `DocumentParser.defaultMaxContainerDepth` (24) levels, and links, images and emphasis up to `InlineParser.defaultMaxNestingDepth` (24) levels. Markup beyond these limits is not recognized and stays in the text, so no content is lost. The limits can be changed via the properties `DocumentParser.maxContainerDepth` and `InlineParser.maxNestingDepth` (for example by overriding `MarkdownParser.documentParser(blockParsers:input:)` and `inlineParser(inlineTransformers:input:)`). `Container.depth` is new as well.
- Numeric character references are decoded according to CommonMark: `&#0;` and invalid code points decode to U+FFFD, and references with signs or too many digits are left as they are.
- Parser fixes for CommonMark/GFM compliance and robustness:
  - Lines with a `|` that follow a paragraph no longer duplicate the paragraph (or its enclosing block quote or list item) when they turn out not to be a table. The parser state now also restores the contents of open containers.
  - Parsing nested links, such as `[[[a](b)](c)](d)`, no longer takes time exponential in the nesting depth.
  - A backslash is only an escape in front of an ASCII punctuation character; otherwise it is literal (e.g. `C:\Users`), also at the end of a paragraph. A backslash at the end of a line is only a hard line break if it is not itself escaped. `\&ouml;` is not decoded as an entity any more. As a consequence, the AST of `foo\bar` is now `text("foo\\bar")`.
  - Backslash escapes are now also resolved in link and image destinations (`[a](foo\)\:)`).
  - Link reference labels are normalized consistently (whitespace collapsed, Unicode case folding), also for definitions with a title; the first definition of a label wins; multi-line titles keep their line breaks; reference definitions inside definition lists are found.
  - Shortcut references at the very end of a paragraph (`[foo]`) and collapsed references (`[foo][]`) now work; `[foo][bar]` with an undefined `bar` is no longer treated as `[foo]` followed by text; a link title needs whitespace before it.
  - A reference definition followed by an invalid title no longer loses the lines of that title.
  - Fenced and indented code blocks end where their enclosing block quote or list item ends; indented code keeps blank lines between its lines.
  - HTML generated for indented code blocks and HTML blocks no longer contains doubled line breaks, and code blocks always end with a newline.
  - Lists: ordered list items can only interrupt a paragraph if they start with 1, and empty list items cannot interrupt a paragraph; list markers followed by five or more spaces start an indented code block; list items can begin with at most one blank line; ordered list numbers can have nine digits; empty list items no longer make a list loose; the tightness of a list that follows a list of a different type is computed correctly.
  - HTML blocks: `<![CDATA[`, `<!DOCTYPE` and similar blocks are now recognized, `textarea` and `search` were added, a line with just a complete open or closing tag starts an HTML block (but cannot interrupt a paragraph), and an HTML comment can contain blank lines inside of a list item. Inline HTML follows CommonMark 0.30 (`<!-->`, comments containing `--`, CDATA containing `]]`, lowercase declarations, restrictions on unquoted attribute values).
  - Code spans strip one leading and one trailing space if both are present.
  - Tables: a table ends where another block starts; `\|` is unescaped in table cells (also in code spans); a lone `:` is not a valid alignment cell; a row ending in a backslash no longer swallows the next line or loses its last cell.
  - ATX headings: a closing sequence that makes up the whole text results in an empty heading, and tabs are handled like spaces.
- Faster inline parsing and entity handling, no change of results. Parsing time is now linear in the size of the input for text with many emphasis markers, brackets, `<` characters or entities (before, it was quadratic and, for some inputs with many `<` followed by many `>`, even cubic: a few kilobytes could take more than a minute). `Text.count` now takes constant time (it used to traverse all fragments), and `Text.description` and `Text.debugDescription` are linear (they were quadratic). `String.decodingNamedCharacters()` and `String.encodingPredefinedXmlEntities()` are single-pass.
- Faster word wrapping in `StringGenerator` and `TerminalGenerator` (`wordWrap(_:maxColumns:)`). It recomputed the display width of the whole current line for every word, which is quadratic in the length of a line. This is noticeable if lines are long, e.g. when `numColumns` is large to avoid wrapping (a 30 KB paragraph took 12 seconds, now 8 ms), and it also made `StringGenerator` about 5 times slower for ordinary text. The results do not change.
- Added tests for the security fixes (`SecurityTests`), parser regressions (`ParserRegressionTests`) baseline performance and scaling benchmarks (`PerformanceTests`), and differential tests which compare the inline transformers and the entity helpers with frozen copies of their original implementations on many random inputs (`DifferentialTests`), and tests for the nesting limits (`NestingTests`). `PerformanceTests` also benchmarks the generators on long text.

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
