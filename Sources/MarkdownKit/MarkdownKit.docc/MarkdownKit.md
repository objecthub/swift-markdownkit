# ``MarkdownKit``

Parse, process and display text in Markdown format.

## Overview

_Swift MarkdownKit_ is a framework for parsing, processing and displaying text in [Markdown](https://daringfireball.net/projects/markdown/) format. The supported syntax is based on the [CommonMark Markdown specification](https://commonmark.org) (version 0.31.2). The framework also provides two extended versions of the parser: ``ExtendedMarkdownParser`` (tables and definition lists) and ``FullMarkdownParser`` (additionally underline, strikethrough, and task lists).

_Swift MarkdownKit_ defines an abstract syntax representation for Markdown, it provides a parser for parsing strings into abstract syntax trees, and comes with generators for creating output in plain text, HTML and [attributed strings](https://developer.apple.com/documentation/foundation/nsattributedstring). There is also a generator which can be used to display Markdown documents in ANSI-compliant terminals.

These are the supported Markdown features. The parser classes supporting a feature are given in parentheses:

- [CommonMark](https://commonmark.org) 0.31.2: headings, paragraphs, block quotes, lists, code blocks, thematic breaks, HTML, links, images, emphasis, code spans and line breaks (``MarkdownParser``, ``ExtendedMarkdownParser``, ``FullMarkdownParser``)
- [Tables](https://github.github.com/gfm/#tables-extension-) with column alignment, in the style of GitHub Flavored Markdown (``ExtendedMarkdownParser``, ``FullMarkdownParser``)
- [Definition lists](https://www.markdownguide.org/extended-syntax/#definition-lists) (``ExtendedMarkdownParser``, ``FullMarkdownParser``)
- Underlined text: `~underlined~` (``FullMarkdownParser``)
- Strikethrough text: `~~struck through~~` (``FullMarkdownParser``)
- Task lists: `- [ ] to do` and `- [x] done` (``FullMarkdownParser``)
- LaTeX math: `$a^2$`, `$$` … `$$` and fenced `math` code blocks (``MathMarkdownParser``)
- Custom syntax defined by extending the parser

MarkdownKit supports macOS 11, iOS 15, tvOS 15 and watchOS 8 or later.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Recipes>
- <doc:UsingMarkdownKitConcurrently>
- <doc:MigrationGuide>

### Parsing Markdown

- <doc:ChoosingAParser>
- <doc:ConfiguringTheParser>
- <doc:ExtendingTheParser>
- ``MarkdownParser``
- ``ExtendedMarkdownParser``
- ``FullMarkdownParser``
- ``MarkdownDialect``

### Mathematical formulas

- <doc:MathematicalFormulas>
- ``MathMarkdownParser``
- ``MathFragment``
- ``MathBlock``
- ``MathTransformer``
- ``MathBlockParser``
- ``MathInlineParser``
- ``MathHtmlGenerator``
- ``MathHtmlRendering``
- ``KaTeXEngine``
- ``KaTeXOptions``
- ``KaTeXError``

### Drawing formulas

- ``MathAttributedStringGenerator``
- ``MathRenderer``
- ``MathConfig``
- ``MathFormula``
- ``MathImage``
- ``MathError``
- ``MathContext``

### Representing Markdown documents

- <doc:UnderstandingTheSyntaxTree>
- <doc:ProcessingMarkdown>
- ``Block``
- ``Blocks``
- ``TextFragment``
- ``Text``
- ``ListType``
- ``ListDensity``
- ``Alignment``
- ``Alignments``
- ``Row``
- ``Rows``
- ``Definition``
- ``Definitions``
- ``AutolinkType``
- ``Lines``

### Extending the syntax tree

- ``CustomBlock``
- ``CustomTextFragment``

### Generating output

- <doc:GeneratingOutput>
- <doc:RenderingUntrustedMarkdown>
- <doc:UsingTheCommandLineTools>

### Generating HTML

- <doc:CustomizingHTMLOutput>
- ``HtmlGenerator``

### Generating attributed strings

- <doc:CustomizingAttributedStringOutput>
- ``AttributedStringGenerator``
- ``HRColor``
- ``HRFont``
- ``TextStorageEditActions``
- ``mdDefaultColor``
- ``mdDefaultBackgroundColor``

### Generating text and terminal output

- <doc:GeneratingTerminalOutput>
- ``StringGenerator``
- ``TerminalGenerator``
- ``GeneratorContext``
- ``TableDescriptor``

### Highlighting code

- <doc:SyntaxHighlighting>
- ``SyntaxHighlighter``
- ``HighlightingConfig``
- ``AnsiHighlightingConfig``

### Drawing Mermaid diagrams

- <doc:DrawingMermaidDiagrams>
- ``MermaidRenderer``
- ``MermaidConfig``
- ``MermaidImage``
- ``MermaidError``
- ``MermaidDiagramContext``

### Displaying Markdown with SwiftUI

- <doc:DisplayingMarkdownWithSwiftUI>
- ``MarkdownText``

### Extending the block parser

- ``BlockParser``
- ``RestorableBlockParser``
- ``DocumentParser``
- ``ExtendedDocumentParser``
- ``Container``
- ``NestedContainer``
- ``AtxHeadingParser``
- ``SetextHeadingParser``
- ``BlockquoteParser``
- ``CodeBlockParser``
- ``IndentedCodeBlockParser``
- ``FencedCodeBlockParser``
- ``ThematicBreakParser``
- ``LinkRefDefinitionParser``
- ``ListItemParser``
- ``ExtendedListItemParser``
- ``TableParser``
- ``HtmlBlockParser``
- ``HtmlBlockParserPlugin``
- ``CdataBlockParserPlugin``
- ``CommentBlockParserPlugin``
- ``CompleteTagBlockParserPlugin``
- ``DeclarationBlockParserPlugin``
- ``HtmlTagBlockParserPlugin``
- ``ProcessingInstructionBlockParserPlugin``
- ``ScriptBlockParserPlugin``

### Extending the inline parser

- ``InlineParser``
- ``InlineTransformer``
- ``CodeLinkHtmlTransformer``
- ``DelimiterTransformer``
- ``DelimiterRunType``
- ``EmphasisTransformer``
- ``EscapeTransformer``
- ``LineEmphasisDelimiterTransformer``
- ``LineEmphasisTransformer``
- ``LinkTransformer``
- ``TaskListInlineParser``

### Utility functions

- ``NamedCharacters``
- ``isAsciiLetter(_:)``
- ``isAsciiLetterOrDigit(_:)``
- ``isAsciiPunctuation(_:)``
- ``isAsciiWhitespaceOrControl(_:)``
- ``isControlCharacter(_:)``
- ``isDash(_:)``
- ``isEmailAddress(_:)``
- ``isHtmlTag(_:)``
- ``isSpace(_:)``
- ``isURI(_:)``
- ``isUnicodePunctuation(_:)``
- ``isUnicodeWhitespace(_:)``
- ``isUppercaseAsciiLetter(_:)``
- ``isWhitespace(_:)``
- ``isWhitespaceString(_:)``
- ``skipWhitespace(in:from:to:)``
