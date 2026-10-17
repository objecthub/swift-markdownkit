# ``MarkdownKit/AttributedStringGenerator``

## Topics

### Creating a generator

- ``init(version:options:fontSize:fontFamily:fontColor:lineSpacing:codeFontSize:codeFontFamily:codeFontColor:codeBlockFontSize:codeBlockFontColor:codeBlockLineSpacing:codeBlockBackground:syntaxHighlighting:syntaxHighlighter:mermaid:mermaidRenderer:borderColor:blockquoteColor:h1Color:h2Color:h3Color:h4Color:maxImageWidth:maxImageHeight:customStyle:imageBaseUrl:renderingOptions:)``
- ``standard``
- ``Version``
- ``version-swift.property``
- ``Options``
- ``options-swift.property``

### Generating attributed strings

- ``generate(doc:)``
- ``generate(block:)``
- ``generate(blocks:)``
- ``generateAsync(doc:options:)``
- ``generateAsync(block:options:)``
- ``generateAsync(blocks:options:)``
- ``generateAsync(doc:options:completionHandler:)``
- ``generateAsync(block:options:completionHandler:)``
- ``generateAsync(blocks:options:completionHandler:)``

### Rendering the HTML

- ``RenderingOptions``
- ``ImageAccess``
- ``RenderingError``
- ``renderingOptions-swift.property``
- ``imageBaseUrl``

### Choosing fonts, colors and line spacing

- ``fontSize``
- ``fontFamily``
- ``fontColor``
- ``lineSpacing``
- ``codeFontSize``
- ``codeFontFamily``
- ``codeFontColor``
- ``codeBlockFontSize``
- ``codeBlockFontColor``
- ``codeBlockLineSpacing``
- ``codeBlockBackground``
- ``borderColor``
- ``blockquoteColor``
- ``h1Color``
- ``h2Color``
- ``h3Color``
- ``h4Color``
- ``maxImageWidth``
- ``maxImageHeight``
- ``customStyle``

### Highlighting code

- ``SyntaxHighlightingConfig``
- ``syntaxHighlighter``
- ``codeBlockHighlightingConfig``
- ``ignoreSyntacticIssues``
- ``ignoredLanguages``
- ``highlightIndentedCodeBlocks``

### Drawing Mermaid diagrams

- ``mermaidConfig``
- ``mermaidRenderer``
- ``diagramRenderer``
- ``prepareDiagrams(in:)-(Block)``
- ``prepareDiagrams(in:)-(Blocks)``
- ``prepareDiagrams(in:completionHandler:)-(Block,_)``
- ``prepareDiagrams(in:completionHandler:)-(Blocks,_)``
- ``insertingDiagrams(into:from:)``
- ``addingDiagrams(to:from:)``

### Creating the HTML

- ``htmlGenerator(options:)``
- ``InternalHtmlGenerator``
- ``OS26HtmlGenerator``
- ``generateHtml(_:)``
- ``htmlHead``
- ``htmlBody(_:)``
- ``docStyle``

### Styling the document and the text

- ``bodyStyle``
- ``pStyle``
- ``imgStyle``
- ``codeStyle``
- ``preStyle``
- ``preCodeStyle``
- ``codeBoxStyle``
- ``thematicBreakStyle``
- ``blockquoteStyle``
- ``quoteStyle``

### Styling headings

- ``h1Style``
- ``h2Style``
- ``h3Style``
- ``h4Style``
- ``h1GapStyle``
- ``h2GapStyle``

### Styling lists

- ``ulStyle``
- ``olStyle``
- ``ulNestedStyle``
- ``olNestedStyle``
- ``liStyle``
- ``simpleLiStyle``
- ``itemStyle``
- ``simpleItemStyle``
- ``numberStyle``
- ``bulletStyle``
- ``checkboxStyle``

### Styling tables

- ``TableBorders``
- ``tableBorders-swift.property``
- ``tableBorderSpec``
- ``tableStyle``
- ``tableHeaderStyle``
- ``tableRowStyle``
- ``tableCellStyle``
- ``tableHeaderPadding``
- ``tableRowPadding``
- ``tableCellPadding``
