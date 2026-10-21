# ``MarkdownKit/SourceGenerator``

## Topics

### Creating a generator

- ``init(dialect:)``
- ``init(syntax:parser:specialCharacters:)``
- ``standard``
- ``syntax``
- ``parser``
- ``specialCharacters``
- ``MarkdownDialect/Syntax``

### Generating source

- ``generate(doc:)``
- ``generate(blocks:parent:)``
- ``generate(block:parent:)``
- ``generate(customBlock:parent:)``
- ``Parent``

### Writing text

- ``generate(text:in:)``
- ``generate(lines:in:)``
- ``generate(textFragment:in:)``
- ``generate(customFragment:in:)``
- ``escape(_:in:)``
- ``InlineContext``

### Checking the result

- ``roundTrips(_:)``
- ``firstMismatch(of:)``
