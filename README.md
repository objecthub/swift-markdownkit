# Swift MarkdownKit

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fobjecthub%2Fswift-markdownkit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/objecthub/swift-markdownkit) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fobjecthub%2Fswift-markdownkit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/objecthub/swift-markdownkit) [![IDE: Xcode 26](https://img.shields.io/badge/IDE-Xcode%2026-orange.svg?style=flat)](https://developer.apple.com/xcode/) [![Package managers: SwiftPM, Carthage](https://img.shields.io/badge/Package%20managers-SwiftPM,%20Carthage-green.svg?style=flat)](https://github.com/Carthage/Carthage) [![Documentation](https://img.shields.io/badge/Documentation-DocC-red.svg?style=flat)](https://objecthub.github.io/swift-markdownkit/documentation/markdownkit/) [![License: Apache](http://img.shields.io/badge/License-Apache-lightgrey.svg?style=flat)](https://raw.githubusercontent.com/objecthub/swift-markdownkit/master/LICENSE)

_Swift MarkdownKit_ is a framework for parsing, processing and displaying text in [Markdown](https://daringfireball.net/projects/markdown/) format. The supported syntax is based on the [CommonMark Markdown specification](https://commonmark.org) (version 0.31.2). _Swift MarkdownKit_ also provides four extended versions of the parser: `ExtendedMarkdownParser` (tables and definition lists), `FullMarkdownParser` (additionally underline, strikethrough, and task lists), `MathMarkdownParser` (additionally LaTeX math with dollar signs) and `LaTeXMarkdownParser` (additionally the delimiters of LaTeX for math).

_Swift MarkdownKit_ defines an abstract syntax representation for Markdown, it provides a parser for parsing strings into abstract syntax trees, and comes with generators for creating output in plain text, HTML and [attributed strings](https://developer.apple.com/documentation/foundation/nsattributedstring). There is also a generator which can be used to display Markdown documents in ANSI-compliant terminals.

The API reference and a number of articles are also available as [online documentation](https://objecthub.github.io/swift-markdownkit/documentation/markdownkit/), generated with Swift-DocC.

Here is an overview of the supported Markdown features. The parser classes supporting a feature are given in parentheses (see also [Markdown extensions](#markdown-extensions)):

- **[CommonMark](https://commonmark.org) 0.31.2**: headings, paragraphs, block quotes, lists, code blocks, thematic breaks, HTML, links, images, emphasis, code spans and line breaks (`MarkdownParser`, `ExtendedMarkdownParser`, `FullMarkdownParser`, `MathMarkdownParser`, `LaTeXMarkdownParser`)
- **[Tables](https://github.github.com/gfm/#tables-extension-)** with column alignment, in the style of GitHub Flavored Markdown (`ExtendedMarkdownParser`, `FullMarkdownParser`, `MathMarkdownParser`, `LaTeXMarkdownParser`)
- **[Definition lists](https://www.markdownguide.org/extended-syntax/#definition-lists)** (`ExtendedMarkdownParser`, `FullMarkdownParser`, `MathMarkdownParser`, `LaTeXMarkdownParser`)
- **Underlined** text: `~underlined~` (`FullMarkdownParser`, `MathMarkdownParser`, `LaTeXMarkdownParser`)
- **Strikethrough** text: `~~struck through~~` (`FullMarkdownParser`, `MathMarkdownParser`, `LaTeXMarkdownParser`)
- **Task lists**: `- [ ] to do` and `- [x] done` (`FullMarkdownParser`, `MathMarkdownParser`, `LaTeXMarkdownParser`)
- **[Mermaid](https://mermaid.js.org) diagrams**: fenced code blocks with the language `mermaid`; `AttributedStringGenerator` draws them, see [Drawing Mermaid diagrams](#drawing-mermaid-diagrams) (`MarkdownParser`, `ExtendedMarkdownParser`, `FullMarkdownParser`, `MathMarkdownParser`, `LaTeXMarkdownParser`)
- **LaTeX math** with dollar signs: `$a^2$` within a line, `$$` … `$$` and fenced `math` code blocks for formulas that are blocks; `MathAttributedStringGenerator` draws the formulas, see [Drawing mathematical formulas](#drawing-mathematical-formulas) (`MathMarkdownParser`, `LaTeXMarkdownParser`); math with LaTeX delimiters is supported optionally: `\(a^2\)` within a line, `\[` … `\]` for formulas that are blocks (`LaTeXMarkdownParser`)
- **Custom syntax** defined by [extending the parser](#extending-the-parser)

&nbsp;

<table width="100%">
<tr><th colspan="2">Table of contents</th></tr>
<tr>
<td width="650px" valign="top">
1. &nbsp;<a href="#parsing-markdown">Parsing Markdown</a><br />
&nbsp;&nbsp; 1.1 &nbsp;<a href="#using-the-framework">Using the framework</a><br />
&nbsp;&nbsp; 1.2 &nbsp;<a href="#markdown-extensions">Markdown extensions</a><br />
&nbsp;&nbsp; 1.3 &nbsp;<a href="#configuring-the-parser">Configuring the parser</a><br />
&nbsp;&nbsp; 1.4 &nbsp;<a href="#extending-the-parser">Extending the parser</a><br />
&nbsp;&nbsp; 1.5 &nbsp;<a href="#using-markdownkit-concurrently">Using MarkdownKit concurrently</a><br />
2. &nbsp;<a href="#processing-markdown">Processing Markdown</a><br />
</td>
<td width="50%" valign="top">
3. &nbsp;<a href="#converting-markdown-into-other-formats">Converting Markdown into other formats</a><br />
&nbsp;&nbsp; 3.1 &nbsp;<a href="#generating-text-html-and-attributed-strings">Generating text, HTML, and Attributed Strings</a><br />
&nbsp;&nbsp; 3.2 &nbsp;<a href="#using-the-command-line-tools">Using the command-line tools</a><br />
4. &nbsp;<a href="#displaying-markdown-with-swiftui">Displaying Markdown with SwiftUI</a><br />
5. &nbsp;<a href="#known-issues">Known issues</a><br />
6. &nbsp;<a href="#requirements">Requirements</a><br />
</td>
</tr>
</table>

&nbsp;

## Parsing Markdown

### Using the framework

Class [`MarkdownParser`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Parser/MarkdownParser.swift)
provides a simple API for parsing Markdown in a string. The parser returns an abstract syntax tree
representing the Markdown structure in the string:

```swift
let markdown = MarkdownParser.standard.parse("""
                 # Header
                 ## Sub-header
                 And this is a **paragraph**.
                 """)
print(markdown)
```

Executing this code will result in the following data structure of type `Block` getting printed:

```swift
document(heading(1, text("Header")),
         heading(2, text("Sub-header")),
         paragraph(text("And this is a "),
                   strong(text("paragraph")),
                   text(".")))
```

[`Block`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Block.swift) is a recursively defined enumeration of cases with associated values (also called an _algebraic datatype_). Case `document` refers to the root of a document. It contains a sequence of blocks. In the example above, two different types of blocks appear within the document: `heading` and `paragraph`. A `heading` case consists of a heading level (as its first argument) and heading text (as the second argument). A `paragraph` case simply consists of text.

Text is represented using the struct [`Text`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Text.swift) which is effectively a sequence of `TextFragment` values. [`TextFragment`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/TextFragment.swift) is yet another recursively defined enumeration with associated values. The example above shows two different `TextFragment` cases in action: `text` and `strong`. Case `text` represents plain strings. Case `strong` contains a `Text`  object, i.e. it encapsulates a sequence of `TextFragment` values which are "marked up strongly".

### Markdown extensions

Enum `MarkdownDialect` names the syntaxes that the standard parsers support (`.commonMark`, `.extendedCommonMark`, `.full`, `.fullMath` and `.fullLaTeX`) and gives access to their parsers, e.g. `MarkdownDialect.full.parser` is `FullMarkdownParser.standard`. The extensions are described in the following paragraphs, starting with the one that `ExtendedMarkdownParser` implements.

Class `ExtendedMarkdownParser` has the same interface like `MarkdownParser` but supports tables and definition lists in addition to the block types defined by the [CommonMark specification](https://commonmark.org). [Tables](https://github.github.com/gfm/#tables-extension-) are based on the [GitHub Flavored Markdown specification](https://github.github.com/gfm/) with one extension: within a table block, it is possible to escape newline characters to enable cell text to be written on multiple lines. Here is an example:

```
| Column 1     | Column 2       |
| ------------ | -------------- |
| This text \
  is very long | More cell text |
| Last line    | Last cell      |        
```

[Definition lists](https://www.markdownguide.org/extended-syntax/#definition-lists) are implemented in an ad hoc fashion. A definition consists of terms and their corresponding definitions. Here is an example of two definitions:

```
Apple
: Pomaceous fruit of plants of the genus Malus in the family Rosaceae.

Orange
: The fruit of an evergreen tree of the genus Citrus.
: A large round juicy citrus fruit with a tough bright reddish-yellow rind.
```

Class `FullMarkdownParser` supports everything that MarkdownKit implements. It is a subclass of `ExtendedMarkdownParser` (so it supports tables and definition lists) and adds inline markup for underlined text (`~underlined~`, text fragment `underline`) and struck-through text (`~~struck through~~`, text fragment `strikethrough`), as well as task list items (`- [ ] to do` and `- [x] done`, list type `task`). Tildes can also be used within words (`foo~~bar~~baz`), but runs of three or more tildes are plain text, as in GitHub Flavored Markdown. Unlike GFM, a single tilde does not produce strikethrough but underlined text. A task list item is a list item whose text starts with `[ ]`, `[x]` or `[X]` and a space or tab; the type of such an item is `ListType.task`, which wraps the bullet or number of the item. The HTML generator creates a checkbox, the attributed string generator uses the characters ☐ and ☑, and the text generators write `[ ]` and `[x]` instead of the bullet. `MarkdownParser` and `ExtendedMarkdownParser` do not know this markup and leave tildes as they are, so existing code does not change its behavior. Further markup will be added to `FullMarkdownParser`, except for markup that changes the meaning of characters which are common in text, such as the dollar sign in `MathMarkdownParser`.

```swift
let markdown = FullMarkdownParser.standard.parse("Some ~~old~~ and ~important~ text")
```

Class `MathMarkdownParser` is a subclass of `FullMarkdownParser` which also recognizes LaTeX math. A formula within a line is written between dollar signs (`$a^2 + b^2 = c^2$`); a formula between double dollar signs (`$$a^2$$`) within a line is display math. A formula which is a block of its own is enclosed by two lines with `$$` (or written in a single line, `$$ a^2 $$`), or it is a fenced code block with the info string `math`:

```
$$
\int_0^1 x^2 \, dx = \frac{1}{3}
$$
```

The rules for single dollar signs are those of Pandoc: the opening `$` is followed by a character which is not white space, and the closing `$` is not preceded by white space and not followed by a digit, so `costs $5 and $6` is text. A backslash in front of `$` makes it an ordinary character, and code spans stay code. Markdown within a formula is left alone: `$a_b + c_d$` and `$f^*(x)$` are formulas, not emphasis. Like in GitHub Markdown, a code span between dollar signs (`` $`a_b`$ ``) is a formula as well. A block cannot contain a blank line, and the lines of a formula within a paragraph must not start a list, a quote or another block, so use `$$` blocks for such formulas. In table cells, write `\vert` instead of `|`. The other parsers do not know this syntax and leave dollar signs alone.

Class `LaTeXMarkdownParser` is a subclass of `MathMarkdownParser` which also recognizes the delimiters of LaTeX: `\(a^2\)` is a formula within a line, `\[a^2\]` a display formula within a line, and `\[` and `\]` on their own lines enclose a formula which is a block. Language models, for example, write formulas in this way. It is a class of its own because a backslash in front of a parenthesis or a bracket escapes it in Markdown, so these forms change the meaning of existing text: `\(a\)` is the text `(a)` for all other parsers. A formula ends at the first closing delimiter that is not escaped, and it may contain white space (and a line break) at its ends; without a closing delimiter the opening one is text. The formulas with dollar signs work as before, and whichever formula starts first wins.

```swift
let doc = LaTeXMarkdownParser.standard.parse("The area is \\(\\pi r^2\\).")
```

Formulas are represented by the custom syntax tree nodes `MathFragment` (in text) and `MathBlock`, so existing code that switches over `Block` and `TextFragment` is not affected. `HtmlGenerator` creates `<span class="math inline">\(…\)</span>` for a formula in a line and `<div class="math display">\[…\]</div>` for a block, with the LaTeX escaped; libraries such as KaTeX or MathJax typeset these elements in a web page. The text generators show the LaTeX with its dollar signs, and `AttributedStringGenerator` shows it as code (`MathAttributedStringGenerator` shows images of the typeset formulas, see below).

`MathHtmlGenerator`, a subclass of `HtmlGenerator`, can also typeset the formulas itself. It runs [KaTeX](https://katex.org), which is part of the framework, in JavaScriptCore (class `KaTeXEngine`; it works on all platforms but watchOS) and puts the markup that KaTeX creates into the HTML. The parameter `math:` selects the output: `.delimiters` (the default), `.html` (HTML for a visual rendering), `.mathml` (MathML only, which browsers display without further resources) or `.htmlAndMathml` (the default of KaTeX); `.katex(KaTeXOptions(...))` takes the options of KaTeX, such as macros. The HTML of KaTeX needs the style sheet and the fonts of KaTeX in the web page (`KaTeXEngine.stylesheetURL`). KaTeX is never allowed to create links or images, so formulas of untrusted Markdown cannot do any harm, and a formula that KaTeX does not understand is shown with its source in an element with the class `katex-error`. A client can typeset formulas in another way by adopting the protocol `MathHtmlRendering` in its own subclass of `HtmlGenerator`.

```swift
let generator = MathHtmlGenerator(math: .mathml)
let html = generator.generate(doc: MathMarkdownParser.standard.parse("The area is $\\pi r^2$."))
```

```swift
let doc = MathMarkdownParser.standard.parse("The area is $\\pi r^2$.")
print(HtmlGenerator.standard.generate(doc: doc))
// <p>The area is <span class="math inline">\(\pi r^2\)</span>.</p>
```

`MathAttributedStringGenerator`, a subclass of `AttributedStringGenerator`, shows formulas as images in attributed strings (macOS and iOS); see [Drawing mathematical formulas](#drawing-mathematical-formulas).

### Configuring the parser

The Markdown dialect supported by `MarkdownParser` is defined by two parameters: a sequence of _block parsers_ (each represented as a subclass of [`BlockParser`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Parser/BlockParser.swift)), and a sequence of _inline transformers_ (each represented as a subclass of [`InlineTransformer`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Parser/InlineTransformer.swift)). The initializer of class `MarkdownParser` accepts both components optionally. The default configuration (neither block parsers nor inline transformers are provided for the initializer) is able to handle Markdown based on the [CommonMark specification](https://commonmark.org).

Since `MarkdownParser` objects are stateless (beyond the configuration of block parsers and inline transformers), there is a predefined default `MarkdownParser` object accessible via the static property `MarkdownParser.standard`. This default parsing object is used in the example above.

New markdown parsers with different configurations can also be created by subclassing [`MarkdownParser`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Parser/MarkdownParser.swift) and by overriding the class properties `defaultBlockParsers` and `defaultInlineTransformers`. Here is an example of how class [`ExtendedMarkdownParser`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Parser/ExtendedMarkdownParser.swift) is derived from `MarkdownParser` by overriding `defaultBlockParsers`, by specializing `standard` in a covariant fashion, and by overriding the factory method `documentParser(blockParsers:input:)`, which is needed for supporting definition lists.

```swift
open class ExtendedMarkdownParser: MarkdownParser {
  override open class var defaultBlockParsers: [BlockParser.Type] {
    return self.blockParsers
  }
  private static let blockParsers: [BlockParser.Type] = MarkdownParser.headingParsers + [
    IndentedCodeBlockParser.self,
    FencedCodeBlockParser.self,
    HtmlBlockParser.self,
    LinkRefDefinitionParser.self,
    BlockquoteParser.self,
    ExtendedListItemParser.self,
    TableParser.self
  ]
  override open class var standard: ExtendedMarkdownParser {
    return self.singleton
  }
  private static let singleton: ExtendedMarkdownParser = ExtendedMarkdownParser()
  open override func documentParser(blockParsers: [BlockParser.Type],
                                    input: String) -> DocumentParser {
    return ExtendedDocumentParser(blockParsers: blockParsers, input: input)
  }
}
```

### Extending the parser

With version 1.1 of the MarkdownKit framework, it is now also possible to extend the abstract syntax supported by MarkdownKit. Both `Block` and `TextFragment` enumerations now include a `custom` case which refers to objects representing the extended syntax. These objects have to implement protocol [`CustomBlock`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/CustomBlock.swift) for blocks and [`CustomTextFragment`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/CustomTextFragment.swift) for text fragments.

Here is a simple example how one can add support for "underline" (e.g. `this is ~underlined~ text`) and "strikethrough" (e.g. `this is using ~~strike-through~~`) by subclassing existing inline transformers. `FullMarkdownParser` supports this markup out of the box, with the text fragments `underline` and `strikethrough`; the example implements the same markup as a custom extension in order to show how the mechanism works. Use a different delimiter if you want to try it together with `FullMarkdownParser`.

First, a new custom text fragment type has to be implemented for representing underlined and strike-through text. This is done with an enumeration which implements the `CustomTextFragment` protocol:

```swift
enum LineEmphasis: CustomTextFragment {
  case underline(Text)
  case strikethrough(Text)

  func equals(to other: CustomTextFragment) -> Bool {
    guard let that = other as? LineEmphasis else {
      return false
    }
    switch (self, that) {
      case (.underline(let lhs), .underline(let rhs)):
        return lhs == rhs
      case (.strikethrough(let lhs), .strikethrough(let rhs)):
        return lhs == rhs
      default:
        return false
    }
  }
  func transform(via transformer: InlineTransformer) -> TextFragment {
    switch self {
      case .underline(let text):
        return .custom(LineEmphasis.underline(transformer.transform(text)))
      case .strikethrough(let text):
        return .custom(LineEmphasis.strikethrough(transformer.transform(text)))
    }
  }
  func generateHtml(via htmlGen: HtmlGenerator) -> String {
    switch self {
      case .underline(let text):
        return "<u>" + htmlGen.generate(text: text) + "</u>"
      case .strikethrough(let text):
        return "<s>" + htmlGen.generate(text: text) + "</s>"
    }
  }
  func generateHtml(via htmlGen: HtmlGenerator,
                    and attrGen: AttributedStringGenerator?) -> String {
    return self.generateHtml(via: htmlGen)
  }
  var rawDescription: String {
    switch self {
      case .underline(let text):
        return text.rawDescription
      case .strikethrough(let text):
        return text.rawDescription
    }
  }
  var description: String {
    switch self {
      case .underline(let text):
        return "~\(text.description)~"
      case .strikethrough(let text):
        return "~~\(text.description)~~"
    }
  }
  var debugDescription: String {
    switch self {
      case .underline(let text):
        return "underline(\(text.debugDescription))"
      case .strikethrough(let text):
        return "strikethrough(\(text.debugDescription))"
    }
  }
}
```

Next, two inline transformers need to be extended to recognize the new emphasis delimiter `~`:

```swift
final class EmphasisTestTransformer: EmphasisTransformer {
  override public class var supportedEmphasis: [Emphasis] {
    return super.supportedEmphasis + [
             Emphasis(ch: "~", special: false, factory: { double, text in
               return .custom(double ? LineEmphasis.strikethrough(text)
                                     : LineEmphasis.underline(text))
             })]
  }
}
final class DelimiterTestTransformer: DelimiterTransformer {
  override public class var emphasisChars: [Character] {
    return super.emphasisChars + ["~"]
  }
}
```

Finally, a new extended markdown parser can be created:

```swift
final class EmphasisTestMarkdownParser: MarkdownParser, @unchecked Sendable {
  override public class var defaultInlineTransformers: [InlineTransformer.Type] {
    return [DelimiterTestTransformer.self,
            CodeLinkHtmlTransformer.self,
            LinkTransformer.self,
            EmphasisTestTransformer.self,
            EscapeTransformer.self]
  }
  override public class var standard: EmphasisTestMarkdownParser {
    return self.singleton
  }
  private static let singleton: EmphasisTestMarkdownParser = EmphasisTestMarkdownParser()
}
```

The order of the inline transformers matters. In particular, `EscapeTransformer` needs to be the last transformer of the list, and it should not be left out:

  - It resolves backslash escapes. This includes the escapes in link destinations and titles, which only exist after `LinkTransformer` has created the links.
  - It decides which line endings are hard line breaks (a backslash or at least two spaces at the end of a line) and removes the trailing spaces of the other line endings. This has to happen after `DelimiterTransformer` has classified the delimiters (a `*` followed by a backslash is treated differently from a `*` at the end of a line), after `CodeLinkHtmlTransformer` has recognized code spans and HTML tags (a backslash or spaces at the end of a line are literal text in these, and the line ending is no line break), and after `LinkTransformer` has matched link reference labels (they are compared as written, including backslashes).

A parser without `EscapeTransformer` does not recognize hard line breaks; trailing spaces and backslashes at the end of lines remain in the text. Custom transformers for new inline markup, such as the ones above, belong in front of `EscapeTransformer`.

### Using MarkdownKit concurrently

_MarkdownKit_ is compiled in Swift 6 language mode and supports strict concurrency checking. Abstract syntax trees (`Block`, `TextFragment`, `Text`, ...), options and configuration types (such as `RenderingOptions`) are `Sendable` value types. Parsers (`MarkdownParser`, `ExtendedMarkdownParser`), generators (`HtmlGenerator`, `StringGenerator`, `TerminalGenerator`, `AttributedStringGenerator`), table renderers and the `SyntaxHighlighter` are immutable objects and `Sendable` as well (the highlighting configurations `HighlightingConfig` and `AnsiHighlightingConfig` are value types), so a single instance can be used from several threads or tasks at the same time. Parsing in a background task and using the resulting `Block` on the main actor works:

```swift
let doc = await Task.detached { ExtendedMarkdownParser.standard.parse(text) }.value
let attributedStr = try await AttributedStringGenerator.standard.generateAsync(doc: doc)
```

The classes are `open`, so their `Sendable` conformance is `@unchecked`. Subclasses restate it as `@unchecked Sendable` (the compiler warns otherwise) and have to make sure that state they add is immutable or synchronized. For the same reason, custom types implementing `CustomBlock`, `CustomTextFragment` or one of the `TableRenderer` protocols have to be `Sendable`. Parser internals, such as `DocumentParser`, `InlineParser` and `BlockParser`, are created for a single parse and are not `Sendable`. The synchronous methods of `AttributedStringGenerator` (`generate(doc:)` etc.) use the system's HTML importer, which Apple documents as usable on the main thread only; from other threads, use `generateAsync`.

## Processing Markdown

The usage of abstract syntax trees for representing Markdown text has the advantage that it is very easy to process such data, in particular, to transform it and to extract information. Below is a short  _Swift_  snippet which illustrates how to process an abstract syntax tree for the purpose of extracting all top-level headers (i.e. this code prints the top-level outline of a text in Markdown format).

```swift
let markdown = MarkdownParser.standard.parse("""
                   # First *Header*
                   ## Sub-header
                   And this is a **paragraph**.
                   # Second **Header**
                   And this is another paragraph.
                 """)

func topLevelHeaders(doc: Block) -> [String] {
  guard case .document(let topLevelBlocks) = doc else {
    preconditionFailure("markdown block does not represent a document")
  }
  var outline: [String] = []
  for block in topLevelBlocks {
    if case .heading(1, let text) = block {
      outline.append(text.rawDescription)
    }
  }
  return outline
}

let headers = topLevelHeaders(doc: markdown)
print(headers)
```

This will print an array with the following two entries:

```swift
["First Header", "Second Header"]
```

## Converting Markdown into other formats

### Generating text, HTML, and Attributed Strings

_Swift MarkdownKit_ provides several _generators_, i.e. Markdown processors which
output, for a given Markdown document, a corresponding representation in a different format.

[`HtmlGenerator`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/HTML/HtmlGenerator.swift) defines a simple mapping from Markdown into **HTML**. Here is an example for the usage of the generator: 

```swift
let html = HtmlGenerator.standard.generate(doc: markdown)
```

Beyond the `safeMode` option (see the `HtmlGenerator` initializer), there are currently no means to customize `HtmlGenerator` other than subclassing. Here is an example that defines a customized HTML generator which formats `blockquote` Markdown blocks using HTML tables:

```swift
open class CustomizedHtmlGenerator: HtmlGenerator, @unchecked Sendable {
  open override func generate(block: Block, parent: Parent, tight: Bool = false) -> String {
    switch block {
      case .blockquote(let blocks):
        return "<table><tbody><tr><td style=\"background: #bbb; width: 0.2em;\"  />" +
               "<td style=\"width: 0.2em;\" /><td>\n" +
               self.generate(blocks: blocks, parent: .block(block, parent)) +
               "</td></tr></tbody></table>\n"
      default:
        return super.generate(block: block, parent: parent, tight: tight)
    }
  }
}
```

_Swift MarkdownKit_ also comes with a generator for **attributed strings**.
[`AttributedStringGenerator`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/AttributedString/AttributedStringGenerator.swift) uses a customized HTML generator internally to define the translation from Markdown into `NSAttributedString`. The initializer of `AttributedStringGenerator` provides a number of parameters for customizing the style of the generated attributed string. Alternatively, it is also possible to subclass the internal HTML generator and customize the output this way. For the implementation of syntax highlighting in code blocks, `AttributedStringGenerator` uses [Highlight.js](https://github.com/highlightjs/highlight.js/). Syntax highlighting is configured with a [`SyntaxHighlightingConfig`](https://github.com/objecthub/swift-markdownkit/blob/f6bd3102cbd1413b5205fc72564a48d4e3a78822/Sources/MarkdownKit/AttributedString/AttributedStringGenerator.swift#L81) value which gets passed to the initializer of `AttributedStringGenerator` via parameter `syntaxHighlighting:`. Setting this parameter to `nil` will disable syntax highlighting.

```swift
let generator = AttributedStringGenerator(fontSize: 12,
                                          fontFamily: "Helvetica, sans-serif",
                                          fontColor: "#33C",
                                          h1Color: "#000")
let attributedStr = generator.generate(doc: markdown)
```

The generated HTML is rendered into an `NSAttributedString` by the system. Use `RenderingOptions` to configure it. `baseUrl` is the base for resolving relative URLs (e.g. relative image paths) in the generated HTML. `AttributedStringGenerator.generate(doc:)` renders synchronously on the calling thread; `generateAsync(doc:)` is an alternative based on `NSAttributedString.loadFromHTML` which does not block the calling thread. It throws an `AttributedStringGenerator.RenderingError` (e.g. `.timedOut` if the render takes longer than `timeout` seconds, or `.cancelled`). It is available on macOS and iOS; on other platforms it throws `.unsupportedPlatform`.

```swift
let options = AttributedStringGenerator.RenderingOptions(
                baseUrl: URL(fileURLWithPath: "/path/to/images", isDirectory: true),
                timeout: 10)
let generator = AttributedStringGenerator(renderingOptions: options)
let attributedStr = generator.generate(doc: markdown)               // synchronous
let asyncStr = try await generator.generateAsync(doc: markdown)     // asynchronous
```

For code that does not use Swift concurrency, there are variants with a completion handler. The handler is called exactly once, asynchronously, and always on the main thread; it receives a `Result` with either the attributed string or a `RenderingError`:

```swift
generator.generateAsync(doc: markdown) { result in
  switch result {
    case .success(let attributedStr):
      textView.textStorage.setAttributedString(attributedStr)
    case .failure(let error):
      print("cannot convert: \(error)")
  }
}
```

There are two generators for outputting formatted text. [`StringGenerator`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/String/StringGenerator.swift) formats text based on the given Markdown and returns text that can be, e.g. edited in a text editor. [`TerminalGenerator`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/String/TerminalGenerator.swift) formats text for output in an ANSI-compliant terminal, using control sequences to mark up the text.

#### Loading images securely

By default, images referred to by Markdown may be loaded from any location: the system's HTML renderer loads any file that an image URL points to, and `generateAsync` additionally fetches `http(s)` images and style sheets. For untrusted Markdown, use the preset `RenderingOptions.untrusted` (safe mode, and no local and no remote images): `AttributedStringGenerator(renderingOptions: .untrusted)`. Its counterpart `RenderingOptions.trusted` restricts nothing, like the default `RenderingOptions()`. To allow some images, use the options `localImages` and `remoteImages`. Each is an `ImageAccess`: `.none` (never load), `.any` (no restriction in terms of URL path), or `.within(url)` (local images: only files inside this directory; remote images: only URLs below `url`).

```swift
let imageDirectory = URL(fileURLWithPath: "/path/to/images", isDirectory: true)
let options = AttributedStringGenerator.RenderingOptions(
                baseUrl: imageDirectory,
                localImages: .within(imageDirectory),
                remoteImages: .within(URL(string: "https://example.com/images/")!),
                textSizeMultiplier: 1.2)
let generator = AttributedStringGenerator(renderingOptions: options)
```

Every checked image must also have one of the path extensions in `imageExtensions` (png, jpg, gif, webp, …); images that are not allowed are replaced by their alternative text. The restrictions cover the images of the Markdown text only, so raw HTML can still refer to other resources: set `safeMode: true` to omit raw HTML and to limit links to the schemes `http`, `https` and `mailto`. With `remoteImages: .none` and no raw HTML, `generateAsync` does not access the network, and the synchronous methods never load remote images. See [Rendering Untrusted Markdown](https://objecthub.github.io/swift-markdownkit/documentation/markdownkit/renderinguntrustedmarkdown) for all details.

_Note:_ Without restrictions, do not use `generateAsync` with untrusted Markdown, as it then loads remote resources that the HTML refers to.

#### Drawing Mermaid diagrams

Fenced code blocks with the language `mermaid` are [Mermaid](https://mermaid.js.org) diagrams. `HtmlGenerator` passes them on in a `<pre class="mermaid">` element for web pages that load Mermaid. `AttributedStringGenerator` can draw them if it is created with the parameter `mermaid:`, which takes a `MermaidConfig` (the default is `nil`, in which case the diagram is shown as code):

```swift
let generator = AttributedStringGenerator(mermaid: .default)   // or .dark for a dark background
let attributedStr = try await generator.generateAsync(doc: markdown)
```

Mermaid needs the layout engine of a web browser to measure text. In contrast to syntax highlighting, which runs Highlight.js in JavaScriptCore, the diagrams are therefore drawn by `MermaidRenderer`, which loads the `mermaid.min.js` that ships with _MarkdownKit_ into a headless `WKWebView` and turns each diagram into a PNG image with transparent background (before macOS 14, the transparency is calculated from renderings on a white and on a black page, which takes about twice as long). Diagrams are only supported on macOS and iOS; on other platforms, and for diagrams which Mermaid rejects (the generator then adds the error message above the code), the code is shown.

Rendering takes time, so it is asynchronous:

  - `generateAsync` renders all diagrams of the document before it generates the attributed string.
  - `generate(doc:)` cannot wait for a web view; it shows the diagrams that have been rendered before, and code for the others. Call `await generator.prepareDiagrams(in: doc)` first to render them (it returns `true` if it rendered anything). Code that does not use Swift concurrency calls `generator.prepareDiagrams(in: doc) { rendered in … }` instead; the handler is called exactly once, asynchronously, on the main thread.
  - `MarkdownText(_:mermaid:)` shows the code first and replaces it with the diagram once it is available. In dark mode it uses `MermaidConfig.darkVariant`.

Rendered diagrams, and the errors of diagrams which Mermaid rejected, are cached by the `MermaidRenderer` (`MermaidRenderer.shared` by default; pass `mermaidRenderer:` to the generator for another one), keyed by the diagram and the configuration. The cache holds at most 128 results and 64 MiB of images by default; `MermaidRenderer(mermaidJSURL:maxCachedDiagrams:maxCacheBytes:)` sets other limits. `generateAsync` shows all diagrams of its document whatever the size of the cache, whereas `generate(doc:)` and `MarkdownText` only show the diagrams that are in the cache: `maxCachedDiagrams` should be at least the number of diagrams in the largest document that you display in this way. `MermaidRenderer.render(_:config:)` returns the PNG of a diagram without a generator. A `MermaidConfig` selects the Mermaid `theme` and `themeVariables`, the `fontFamily`, the `scale` (pixels per point, default 2), the layout `width` (default 800 points), the `margin` (default 8 points) and `spacing` (at least 16 points) around the diagram, a `maxWidth` and the `timeout` per diagram. A diagram that is wider than the text view is scaled down to fit.

The web view cannot access the network or local files, and Mermaid runs with `securityLevel: 'strict'`. It is released after 60 seconds without requests (`MermaidRenderer(…, idleTime:)`). Replace `Sources/MarkdownKit/Mermaid/mermaid.min.js` to use another version of Mermaid. See [Drawing Mermaid Diagrams](https://objecthub.github.io/swift-markdownkit/documentation/markdownkit/drawingmermaiddiagrams) for details.

#### Drawing mathematical formulas

Formulas are recognized by `MathMarkdownParser` and `LaTeXMarkdownParser` (see [Markdown extensions](#markdown-extensions)). `MathAttributedStringGenerator`, a subclass of `AttributedStringGenerator`, shows them as images. It takes all parameters of its superclass plus `math:`, a `MathConfig`, and `mathRenderer:`. Every other generator shows a formula as code (`MathHtmlGenerator` typesets formulas in HTML instead):

```swift
let generator = MathAttributedStringGenerator(fontSize: 16)
let doc = MathMarkdownParser.standard.parse("The area is $\\pi r^2$.")
let attributedStr = try await generator.generateAsync(doc: doc)
```

Like Mermaid, KaTeX needs the layout engine of a web browser, so the formulas are drawn by `MathRenderer`: it loads the KaTeX that ships with _MarkdownKit_ into a headless `WKWebView`, renders many formulas at a time, measures each one and turns it into a PNG image. The generator replaces a placeholder in the HTML with an `NSTextAttachment` for each formula. A formula within a line sits on the baseline of the text, is as large as the text and has its color, also in links; a block is a centered paragraph, and a formula that is wider than its line is scaled down. Formulas are only supported on macOS and iOS; on other platforms, and for formulas which KaTeX rejects, the LaTeX is shown as code. The attachment has the attribute `.mathSource` with the formula as it was written. The LaTeX commands `\color` and `\tag` are not supported, and RTFD export loses the baseline offset.

Rendering is asynchronous, just like drawing diagrams. `generateAsync` renders all formulas of the document first. `generate(doc:)` only shows the formulas that have been rendered before: call `await generator.prepareMath(in: doc)` first (or `prepareMath(in:completionHandler:)`). `MarkdownText(_:math:)` and `MarkdownText(string:math:)` show the code first and replace it once the formulas are available; a string is parsed with `MathMarkdownParser` then, unless `dialect:` selects another parser.

The images, and the errors of rejected formulas, are cached by the `MathRenderer` (`MathRenderer.shared` by default; pass `mathRenderer:` for another one): at most 2,000 results and 32 MiB by default. `generateAsync` shows all formulas whatever the size of the cache, whereas `generate(doc:)` and `MarkdownText` only show those in the cache. `MathRenderer.render(_:display:fontSize:config:)` returns the PNG of a formula, given its LaTeX, without a generator. A `MathConfig` sets the KaTeX options (macros and limits), the `scale` of the images, the `spacing` around blocks, a `maxWidth` and the `timeout`.

The web view cannot access the network or local files, and KaTeX runs with `trust` set to `false`, so formulas cannot create links, images or HTML. It is released after 60 seconds without requests (`idleTime:`). To use another version of KaTeX, replace the folder `Sources/MarkdownKit/Math/KaTeX` and update `KaTeXEngine.bundledVersion`. See [Mathematical Formulas](https://objecthub.github.io/swift-markdownkit/documentation/markdownkit/mathematicalformulas) for details.

#### Drawing diagrams and formulas as images

`MarkdownUtil` draws Mermaid diagrams and formulas into images without any Markdown, in one place. Its methods return an `NSImage` (macOS) or a `UIImage` (iOS), asynchronously or with a completion handler, and `MarkdownUtil.image(_:withInsets:)` gives such an image transparent space of a given width between its content and each edge:

```swift
let util = MarkdownUtil.standard
let diagram = try await util.mermaidImage("graph LR\n  A --> B")
let formula = try await util.mathImage("x^2 + y^2 = z^2", fontSize: 16, color: .systemBlue)
```

See [Drawing Images of Diagrams and Formulas](https://objecthub.github.io/swift-markdownkit/documentation/markdownkit/drawingimagesofdiagramsandformulas) for details.

#### Converting Markdown into documents

`MarkdownUtil` also converts a Markdown document into text, HTML, RTF or RTFD with one call: `text(_:width:)`, `ansi(_:width:)` and `html(_:math:safeMode:)` are available on all platforms, `rtf(_:title:author:renderingOptions:)` and `rtfd(_:title:author:maxImageWidth:renderingOptions:)` on macOS and iOS. An RTFD document contains diagrams and formulas as images, which are sized correctly, and formulas within a line are aligned with the text. Call `preparedForRTFD()` on your own `NSAttributedString` to get the same when you export it as RTFD yourself:

```swift
let doc = MarkdownDialect.fullLaTeX.parser.parse(markdown)
let html = MarkdownUtil.standard.html(doc)
let document = try await MarkdownUtil.standard.rtfd(doc, title: "Notes")   // a FileWrapper
try document.write(to: URL(fileURLWithPath: "Notes.rtfd"), options: .atomic, originalContentsURL: nil)
```

See [Converting Markdown into Documents](https://objecthub.github.io/swift-markdownkit/documentation/markdownkit/convertingmarkdownintodocuments) for details.

### Using the command-line tools

The _Swift MarkdownKit_ Xcode project also implements a [very simple command-line tool](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKitProcess/MarkdownKitProcess.swift) that outputs Markdown content (parsed with `FullMarkdownParser`) either as HTML, RTF, RTFD, or pretty-printed text, including the option to output ANSI-compliant markup. The tool either outputs a single Markdown text file into an output file or, when applied to a folder, outputs all Markdown files within the folder into output files in a target folder. Existing output files are not touched unless the option `--overwrite` is used.

The tool is a thin wrapper around `MarkdownUtil`, which provides the conversions. It is provided to serve as a demo and basis for customization to specific use cases. The simplest way to build the binary is to use the Swift Package Manager (SPM):

```sh
> git clone https://github.com/objecthub/swift-markdownkit.git
Cloning into 'swift-markdownkit'...
remote: Enumerating objects: 70, done.
remote: Counting objects: 100% (70/70), done.
remote: Compressing objects: 100% (54/54), done.
remote: Total 70 (delta 13), reused 65 (delta 11), pack-reused 0
Unpacking objects: 100% (70/70), done.
> cd swift-markdownkit
> swift run MarkdownKitProcess --help
Building for debugging...
[1/1] Write swift-version--58304C5D6DBC2206.txt
Build of product 'MarkdownKitProcess' complete! (0.07s)
USAGE: MarkdownKitProcess [<option> ...] <source> [<target>]
OPTIONS:
  -f, --format <format>
      Output format: 'text' (plain text, default), 'ansi' (text marked up with ANSI escape codes), 'html', 'rtf', or 'rtfd'.
  -w, --width <columns>
      Width in columns of the formats 'text' and 'ansi', at least 10 (default: the width of the terminal, or 80).
  -o, --overwrite
      Replaces output files which already exist. Without this option, they are not touched.
  -h, --help
      Prints this usage description.
PARAMETERS:
  <source>
      A Markdown file, or a directory of Markdown files (the files ending in '.md').
  <target>
      The file, or the directory into which the converted files are written. The converted
      file of 'a.md' is called 'a.txt' ('text' and 'ansi'), 'a.html', 'a.rtf' or 'a.rtfd'.
      '-' prints the output (not possible for 'rtfd'). If there is no target, the converted
      files are written next to the source files.
Diagrams in fenced code blocks with language 'mermaid' are drawn in the format 'rtfd'.
RTF files cannot contain images: the format 'rtf' shows the code of a diagram.
```

The format `rtfd` includes [Mermaid](https://mermaid.js.org) diagrams (see [Drawing Mermaid diagrams](#drawing-mermaid-diagrams)) and formulas (see [Drawing mathematical formulas](#drawing-mathematical-formulas)) as images, and the format `html` typesets formulas as MathML, which browsers display without a style sheet or fonts. RTF files cannot contain the images that `NSAttributedString` creates, so the format `rtf` shows the code of a diagram and the LaTeX of a formula instead, like the formats `text` and `ansi`. The images of an RTFD document are in the files `Image 1.png`, `Formula 1.png` and so on, and a formula within a line is aligned with the text. The directory [`Examples`](https://github.com/objecthub/swift-markdownkit/blob/master/Examples/Demo.md) contains a Markdown file with the demo document of the `MarkdownViewer` sample app, including two diagrams, for trying the tool:

```sh
> swift run MarkdownKitProcess --format rtfd Examples/Demo.md /tmp/Demo.rtfd
converted 'Demo.md' into 'Demo.rtfd'
> swift run MarkdownKitProcess --format rtfd Examples/Demo.md /tmp/Demo.rtfd
error: '/tmp/Demo.rtfd' already exists (use --overwrite to replace it)
> swift run MarkdownKitProcess --format rtfd --overwrite Examples/Demo.md /tmp/Demo.rtfd
converted 'Demo.md' into 'Demo.rtfd'
```

A second tool, [`MarkdownTermViewer`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownTermViewer/main.swift), does not read any files. It prints a demo document with the features of `FullMarkdownParser` (the document displayed by the `MarkdownViewer` sample app: formatted text, tables, task lists, code blocks, ...) either as plain text (`StringGenerator`) or marked up with ANSI escape codes (`TerminalGenerator`). This is a quick way to see what the text generators produce:

```sh
> swift run MarkdownTermViewer --help
USAGE: MarkdownTermViewer [<option> ...]
OPTIONS:
  -f, --format <format>
      Output format: 'text' (plain text, default) or 'ansi' (marked up with ANSI escape codes).
  -w, --width <columns>
      Width in columns, at least 10 (default: the width of the terminal, or 80).
  -h, --help
      Prints this usage description.
> swift run MarkdownTermViewer --format ansi --width 60
```

The output of `--format ansi` is only rendered correctly by a terminal. Xcode's console shows the escape sequences as raw characters.

## Displaying Markdown with SwiftUI

SwiftUI comes with support for Markdown-formatted snippets but does not have a full-fledged viewer for Markdown documents. Since version 1.4, _MarkdownKit_ includes a SwiftUI view for displaying Markdown documents. As opposed to many other custom created Markdown views, the one included in _MarkdownKit_ is based on the CommonMark-compliant _MarkdownKit_ parser as well as its attributed string generator. It is thus lightweight yet still quite configurable.

The initializer of [`MarkdownText`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/View/MarkdownText.swift) receives the parsed Markdown content of type `Block`, an optional `waitingMessage:` parameter which defines what is being displayed while the content is being rendered (especially if many images need to be loaded), as well as a `generator:` parameter defining how the parsed Markdown is transformed into an attributed string, which is then being shown in the view. The generator is not just called once, but every time the color scheme has changed to potentially update the colors in use. A variant of this initializer accepts a Markdown document as a string and parses it with the standard parser of a `MarkdownDialect`: the parameter `dialect:` selects it (the default is `.extendedCommonMark`, or `.fullMath` if `math:` is given; pass `dialect: .full` for `FullMarkdownParser` or `dialect: .fullLaTeX` for formulas with `\(…\)` and `\[…\]`). There are two initializers for each of the two ways of providing the document. Either you pass a `generator:`, or you do not provide one and the view uses the default generators for light and dark mode, which can be configured with `renderingOptions:` (see `AttributedStringGenerator.RenderingOptions`; the default is `.trusted`), `mermaid:` and `math:`. A view with a `generator:` that shows diagrams or formulas passes a `prepare:` function, which renders them in the background (the default generators call `prepareDiagrams(in:)` and `prepareMath(in:)`). The view generates the attributed string synchronously, which is why only the rendering options `baseUrl`, `localImages`, `imageExtensions`, `safeMode` and `textSizeMultiplier` have an effect (remote images are never loaded). Use `MarkdownText(string: text, renderingOptions: .untrusted)` if the Markdown does not come from a trusted source. The following code snippet shows the signatures of the initializers.

```swift
struct MarkdownText: View {
  init(_ text: Block,
       waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
       renderingOptions: AttributedStringGenerator.RenderingOptions = .trusted,
       mermaid: MermaidConfig? = nil,
       math: MathConfig? = nil) {
    ...
  }
  init(_ text: Block,
       waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
       generator: ((Block, ColorScheme) -> NSAttributedString?)?,
       prepare: (@Sendable (Block, ColorScheme) async -> Bool)? = nil) {
    ...
  }
  init(string: String,
       dialect: MarkdownDialect? = nil,
       waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
       renderingOptions: AttributedStringGenerator.RenderingOptions = .trusted,
       mermaid: MermaidConfig? = nil,
       math: MathConfig? = nil) {
    ...
  }
  init(string: String,
       dialect: MarkdownDialect? = nil,
       waitingMessage: NSAttributedString = NSAttributedString(string: "⏳"),
       generator: ((Block, ColorScheme) -> NSAttributedString?)?,
       prepare: (@Sendable (Block, ColorScheme) async -> Bool)? = nil) {
    ...
  }
  ...
}
```

Here is an example how view `MarkdownText` could be used in a simple Markdown viewer. It defines an attributed string generator that uses two color schemes depending on whether dark mode is active or not.

```swift
struct ContentView: View {
  private static let lightGenerator = AttributedStringGenerator()
  private static let darkGenerator = AttributedStringGenerator(
      fontColor: "#FFF", codeFontColor: "#FFF",
      codeBlockFontColor: "#FF6", codeBlockBackground: "#333",
      syntaxHighlighting: .defaultDark,
      borderColor: "#BBB", h1Color: "#FFF", h2Color: "#FFF",
      h3Color: "#FFF", h4Color: "#FFF")
  
  let content = ExtendedMarkdownParser.standard.parse("""
    Lorem ipsum dolor sit amet, **consectetur adipiscing** elit. Aliquam
    non risus in massa ornare lacinia. _Etiam_ at ullamcorper ligula.
    
    1. This is the first item
    2. This is the second item
    3. This is the third item
    
    Cras laoreet tellus dolor, ac `suscipit augue` molestie a.
    Integer efficitur odio massa, in dictum arcu dictum in.
    
    | Column 1           | Column 2          | Col 3 |
    | ------------------ | ----------------- | :---: |
    | Nunc at dignissim  | More `cell` text  | One   |
    | Integer **ligula** | Justo nec finibus | Two   |
    | Cras nibh ex       | Praesent congue   | Three |
    """)
  
  var body: some View {
    MarkdownText(self.content) { doc, colorScheme in
      switch colorScheme {
        case .dark:
          return Self.darkGenerator.generate(doc: doc)
        default:
          return Self.lightGenerator.generate(doc: doc)
      }
    }
    .padding()
  }
}
```

The Xcode project also contains a sample app, [`MarkdownViewer`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownViewer/ContentView.swift), which uses `MarkdownText` to display a demo document: formatted text, lists, task lists, syntax-highlighted code, tables, [Mermaid](https://mermaid.js.org) diagrams and mathematical formulas. Here are three screenshots of the app running on iOS:

<p align="center">
<img src="https://raw.githubusercontent.com/objecthub/swift-markdownkit/master/Examples/Screenshots/MarkdownViewer-1-Plain.png" alt="MarkdownViewer showing headings, paragraphs, lists and code spans" width="30%">
<img src="https://raw.githubusercontent.com/objecthub/swift-markdownkit/master/Examples/Screenshots/MarkdownViewer-2-TasksSyntax.png" alt="MarkdownViewer showing task lists, a block quote and highlighted code" width="30%">
<img src="https://raw.githubusercontent.com/objecthub/swift-markdownkit/master/Examples/Screenshots/MarkdownViewer-3-Advanced.png" alt="MarkdownViewer showing a table, a Mermaid diagram and mathematical formulas" width="30%">
</p>

## Known issues

The parser passes all 652 examples of the [CommonMark 0.31.2 specification](https://spec.commonmark.org/0.31.2/). The test suite compares the generated HTML with the reference HTML of the specification, ignoring differences that do not change how browsers render the output: whitespace outside of code, `&quot;` vs. `"`, `<ol start="1">` vs. `<ol>`, and percent-encoding of URLs (MarkdownKit does not encode URLs).

There are a number of limitations:

  - Extensions of GitHub Flavored Markdown other than tables, strikethrough and task lists (supported by `FullMarkdownParser`) are not supported: extended autolinks and footnotes.
  - The block parser keeps trailing spaces and backslashes at the end of the lines of a paragraph; whether a line ending is a hard line break is only decided by the inline parser (`EscapeTransformer`), because it depends on the inline markup (e.g. code spans). If you only parse the block structure (`blockOnly: true`), hard line breaks are not recognized.

## Requirements

The following technologies are needed to build the components of the _Swift MarkdownKit_ framework.
The command-line tools can be compiled with the _Swift Package Manager_, so _Xcode_ is not strictly needed
for that. Similarly, just for compiling the framework and trying the command-line tools in _Xcode_, the
_Swift Package Manager_ is not needed.

- [Xcode 16](https://developer.apple.com/xcode/) or later (the framework is developed with Xcode 26)
- [Swift 6](https://developer.apple.com/swift/) toolchain (the package is compiled in Swift 6 language mode; clients can use any language mode)
- [Swift Package Manager](https://swift.org/package-manager/)

_Swift MarkdownKit_ supports Apple platforms only: macOS 11, iOS 15, tvOS 15 and watchOS 8 or later. Linux and other non-Apple platforms are not supported. Syntax highlighting and typesetting formulas with KaTeX rely on JavaScriptCore and are not available on watchOS. Mermaid diagrams and images of formulas (`MathAttributedStringGenerator`) rely on WebKit and are only available on macOS and iOS. The SwiftUI view `MarkdownText` is available on macOS 14 and iOS 17 or later. The command-line tools are only functional on macOS.

## License

_MarkdownKit_ is released under an [Apache License 2.0](https://github.com/objecthub/swift-markdownkit/blob/master/LICENSE).

_MarkdownKit_ contains some code snippets from [HighlighterSwift](https://github.com/smittytone/HighlighterSwift) which is licensed under an [MIT license](https://github.com/smittytone/HighlighterSwift/blob/main/LICENCE.md). _HighlighterSwift_ is © 2026, Tony Smith. Portions are © 2016, Juan Pablo Illanes.

The _MarkdownKit_ framework comes with a copy of [Highlight.js](https://github.com/highlightjs/highlight.js/). _Highlight.js_ is released under a [BSD License](https://github.com/highlightjs/highlight.js/blob/main/LICENSE).

The _MarkdownKit_ framework also comes with a copy of [Mermaid](https://github.com/mermaid-js/mermaid). _Mermaid_ is released under an [MIT License](https://github.com/mermaid-js/mermaid/blob/develop/LICENSE).

The _MarkdownKit_ framework also comes with a copy of [KaTeX](https://github.com/KaTeX/KaTeX) (version 0.16.22: the script, the style sheet and the fonts). _KaTeX_ is released under an [MIT License](https://github.com/KaTeX/KaTeX/blob/main/LICENSE). Its fonts are derived from the Computer Modern and AMS fonts, which are available under the [SIL Open Font License 1.1](https://openfontlicense.org); the license texts are in the folder `Sources/MarkdownKit/Math`.

## Copyright

Author: Matthias Zenger (<matthias@objecthub.net>)  
Copyright © 2019-2025 Google LLC.  
Copyright © 2026 Matthias Zenger.  
_Please note: This is not an official Google product._
