# Migrating to Newer Versions

Find out what to change in your code when you update MarkdownKit.

<!-- Adapted from the "Source-incompatible changes" blocks of CHANGELOG.md. The CHANGELOG lists all changes. -->

## Overview

This article lists the changes that can break the source code of a client when it updates to a newer version, and how to adapt. For all changes, including new features and fixes, see the [CHANGELOG](https://github.com/objecthub/swift-markdownkit/blob/master/CHANGELOG.md).

### Moving to 2.1

- ``AttributedStringGenerator/htmlGenerator(options:)`` is a method instead of a property, so `generator.htmlGenerator` becomes `generator.htmlGenerator()`. The `options` replace ``AttributedStringGenerator/renderingOptions`` for the new generator and are `nil` by default.
- The method returns an ``AttributedStringGenerator/InternalHtmlGenerator``, not any ``HtmlGenerator``, because the generator also holds the Mermaid diagrams for the attributed string. A subclass that overrides the method has to return an `InternalHtmlGenerator` (e.g. an instance of a subclass of it), and no longer a plain ``HtmlGenerator``.
- ``AttributedStringGenerator/Version/makeHtmlGenerator(for:renderingOptions:)`` returns an `InternalHtmlGenerator`, and `makeHtmlGenerator(for:)` is gone: pass the `renderingOptions` of the generator.
- The initializers of ``AttributedStringGenerator/InternalHtmlGenerator`` and ``AttributedStringGenerator/OS26HtmlGenerator`` require `renderingOptions`; before, the parameter was optional and defaulted to the options of `outer`.
- The type `TerminalGenerator.TableDescriptor` is gone. Its properties and initializer were not accessible outside of the framework. ``TerminalGenerator`` and its `TableRenderer` protocol use the top-level ``TableDescriptor`` now, which ``StringGenerator`` uses as well and which has public properties. A custom table renderer for the terminal generator declares `renderTable(_:using:in:)` with a ``TableDescriptor``.

### Moving to 2.0

- New enum cases ``TextFragment/underline(_:)``, ``TextFragment/strikethrough(_:)`` and ``ListType/task(_:checked:)``: `switch` statements over them have to handle the cases. The type of a task item wraps the original one, so use ``ListType/marker`` to get its bullet or number.
- ``CustomBlock``, ``CustomTextFragment`` and the table renderer protocols refine `Sendable`. Subclasses of parsers and generators get the warning "must restate inherited '@unchecked Sendable' conformance": add `@unchecked Sendable`. See <doc:UsingMarkdownKitConcurrently>.
- ``HighlightingConfig`` and ``AnsiHighlightingConfig`` are structs: a config that you change has to be a `var`. ``TerminalGenerator`` has the new initializer parameters `underlineProperties` and `strikethroughProperties`; subclasses overriding the initializer have to adopt them.
- ``CustomTextFragment`` has the new requirements `generateText(via:)` with default implementations, so existing conforming types still compile.

### Coming from 1.4 or earlier

- Version 1.5 changed the output of the parsers and generators: all 652 examples of CommonMark 0.31.2 pass now, which fixed list looseness, tab stops, backslash escapes, link reference definitions, HTML blocks, tables and code spans. Hard line breaks are determined by the inline parser: ``EscapeTransformer`` must be the last inline transformer, and trees from `parse(_:blockOnly: true)` contain no hard line breaks. Generated HTML contains `&amp;` for each `&` in a URL.
- ``SyntaxHighlighter/proxy`` is a `static let`, and `HtmlGenerator.init()` is ``HtmlGenerator/init(safeMode:)``. A subclass with `override init()` has to declare `init()` without `override`.
- Version 1.3 changed the signature of case `listItem` of ``Block``, which enabled the fix of loose list detection.
