# ``MarkdownKit/TerminalGenerator``

## Topics

### Creating a generator

- ``init(numColumns:headerProperties:linkProperties:codeProperties:codeBlockBorderProperties:codeBlockLangProperties:emphasisProperties:strongProperties:underlineProperties:strikethroughProperties:defTermProperties:defDescrProperties:blockquoteProperties:breakProperties:syntaxHighlighting:syntaxHighlighter:tableRenderers:)``
- ``standard``
- ``numColumns``

### Generating text

- ``generate(doc:)``
- ``generate(blocks:context:)``
- ``generate(block:context:)``
- ``generate(text:maxColumns:)``
- ``generate(textFragment:)``

### Styling the text

- ``headerProperties``
- ``linkProperties``
- ``codeProperties``
- ``codeBlockBorderProperties``
- ``codeBlockLangProperties``
- ``emphasisProperties``
- ``strongProperties``
- ``underlineProperties``
- ``strikethroughProperties``
- ``defTermProperties``
- ``defDescrProperties``
- ``blockquoteProperties``
- ``breakProperties``

### Highlighting code

- ``SyntaxHighlightingConfig``
- ``syntaxHighlighter``
- ``codeBlockHighlightingConfig``
- ``ignoreSyntacticIssues``
- ``ignoredLanguages``
- ``highlightIndentedCodeBlocks``

### Laying out the text

- ``newContext(doc:maxColumns:)``
- ``skipNewline(for:and:in:)``
- ``headingUnderlineCharacter(level:)``
- ``codeBlockBorder(lang:maxColumns:)``
- ``blockquoteIndent``
- ``listIndent``
- ``listPrefix(type:context:columns:)``
- ``definitionPrefix(definitions:context:)``
- ``definitionIndent(definitions:context:)``

### Wrapping words

- ``tokenize(_:)``
- ``wordWrap(_:maxColumns:)``
- ``width(of:)``

### Drawing tables

- ``tableRenderers``
- ``tableDescriptor(header:alignments:rows:)``
- ``TableDescriptor``
- ``TableRenderer``
- ``MinimalisticTableRenderer``
- ``FullTableRenderer``
