# Getting Started

Add MarkdownKit to a project, parse a Markdown string into a syntax tree and find out what it contains.

<!-- Adapted from the README sections "Using the framework", "Known issues" and "Requirements". -->

## Overview

MarkdownKit parses Markdown text into an abstract syntax tree, which you can inspect, transform, and convert into HTML, plain text, text for ANSI terminals, or an `NSAttributedString`. This article shows how to add the framework to a project and how to parse a document.

### Add MarkdownKit to your project

MarkdownKit is distributed as a Swift package. Add it to the dependencies of your `Package.swift` and to the target that uses it:

```swift
dependencies: [
  .package(url: "https://github.com/objecthub/swift-markdownkit.git", from: "2.3.0")
],
targets: [
  .target(name: "MyApp", dependencies: [
    .product(name: "MarkdownKit", package: "swift-markdownkit")
  ])
]
```

In Xcode, choose File > Add Package Dependencies and enter the URL of the repository. The framework is compiled in Swift 6 language mode; clients can use any language mode.

### Parse a document

``MarkdownParser`` provides a simple API for parsing Markdown in a string. The parser returns an abstract syntax tree representing the Markdown structure in the string:

```swift
import MarkdownKit

let markdown = MarkdownParser.standard.parse("""
                 # Header
                 ## Sub-header
                 And this is a **paragraph**.
                 """)
print(markdown)
```

Executing this code prints the following data structure of type ``Block``:

```swift
document(heading(1, text("Header")),
         heading(2, text("Sub-header")),
         paragraph(text("And this is a "),
                   strong(text("paragraph")),
                   text(".")))
```

``Block`` is a recursively defined enumeration of cases with associated values (also called an _algebraic datatype_). Case ``Block/document(_:)`` refers to the root of a document. It contains a sequence of blocks. In the example above, two different types of blocks appear within the document: ``Block/heading(_:_:)`` and ``Block/paragraph(_:)``. A `heading` case consists of a heading level (as its first argument) and heading text (as the second argument). A `paragraph` case simply consists of text.

Text is represented using the struct ``Text``, which is effectively a sequence of ``TextFragment`` values. ``TextFragment`` is yet another recursively defined enumeration with associated values. The example above shows two different `TextFragment` cases in action: `text` and `strong`. Case `text` represents plain strings. Case `strong` contains a ``Text`` object, i.e. it encapsulates a sequence of ``TextFragment`` values which are "marked up strongly".

### Choose what to do next

- To parse tables, definition lists, underlined or struck-through text and task lists, pick the right parser: <doc:ChoosingAParser>.
- To find things in a document or to change it, walk the syntax tree: <doc:ProcessingMarkdown>.
- To turn a document into HTML, text or attributed strings: <doc:GeneratingOutput>.
- To show a document in a SwiftUI view: <doc:DisplayingMarkdownWithSwiftUI>.
- To add your own syntax: <doc:ExtendingTheParser>.

### Know the limits

The parser passes all 652 examples of the [CommonMark 0.31.2 specification](https://spec.commonmark.org/0.31.2/). The test suite compares the generated HTML with the reference HTML of the specification, ignoring differences that do not change how browsers render the output: whitespace outside of code, `&quot;` vs. `"`, `<ol start="1">` vs. `<ol>`, and percent-encoding of URLs (MarkdownKit does not encode URLs).

There are a number of limitations:

- Extensions of GitHub Flavored Markdown other than tables, strikethrough and task lists (supported by ``FullMarkdownParser``) are not supported: extended autolinks and footnotes.
- The block parser keeps trailing spaces and backslashes at the end of the lines of a paragraph; whether a line ending is a hard line break is only decided by the inline parser (``EscapeTransformer``), because it depends on the inline markup (e.g. code spans). If you only parse the block structure (`blockOnly: true`), hard line breaks are not recognized.

### Check the platform requirements

MarkdownKit supports Apple platforms only: macOS 11, iOS 15, tvOS 15 and watchOS 8 or later. Linux and other non-Apple platforms are not supported.

- Syntax highlighting relies on JavaScriptCore and is not available on watchOS.
- Mermaid diagrams rely on WebKit and are only available on macOS and iOS.
- The SwiftUI view ``MarkdownText`` is available on macOS 14 and iOS 17 or later.
- The command-line tools are only functional on macOS.

Building the framework requires Xcode 16 or later (it is developed with Xcode 26) and a Swift 6 toolchain.
