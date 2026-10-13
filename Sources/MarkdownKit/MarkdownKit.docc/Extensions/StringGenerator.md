# ``MarkdownKit/StringGenerator``

## Topics

### Creating a generator

- ``init(numColumns:alignDisplayWidth:tableRenderers:)``
- ``standard``
- ``numColumns``
- ``alignDisplayWidth``

### Generating text

- ``generate(doc:)``
- ``generate(blocks:context:)``
- ``generate(block:context:)``
- ``generate(text:maxColumns:)``
- ``generate(textFragment:)``

### Laying out the text

- ``newContext(doc:maxColumns:)``
- ``skipNewline(for:and:in:)``
- ``headingUnderlineCharacter(level:)``
- ``blockquoteIndent``
- ``listIndent``
- ``listPrefix(type:context:columns:)``
- ``definitionPrefix(definitions:context:)``
- ``definitionIndent(definitions:context:)``

### Wrapping words

- ``tokenize(_:)``
- ``wordWrap(_:maxColumns:)``
- ``displayWidth(of:)-(String)``
- ``displayWidth(of:)-([String])``
- ``displayWidth(of:default:)``

### Drawing tables

- ``tableRenderers``
- ``tableDescriptor(header:alignments:rows:)``
- ``TableRenderer``
- ``MinimalisticTableRenderer``
- ``FullTableRenderer``
