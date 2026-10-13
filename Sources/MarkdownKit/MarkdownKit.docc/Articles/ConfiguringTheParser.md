# Configuring the Parser

Change which Markdown syntax a parser understands by choosing its block parsers and inline transformers.

<!-- Adapted from the README section "Configuring the parser". -->

## Overview

The Markdown dialect supported by ``MarkdownParser`` is defined by two parameters:

- a sequence of _block parsers_, each represented as a subclass of ``BlockParser``, which recognize the block structure of a document, and
- a sequence of _inline transformers_, each represented as a subclass of ``InlineTransformer``, which recognize markup within the text of a block.

The initializer of ``MarkdownParser`` accepts both components optionally. The default configuration (neither block parsers nor inline transformers are provided for the initializer) is able to handle Markdown based on the [CommonMark specification](https://commonmark.org).

```swift
let parser = MarkdownParser(blockParsers: MarkdownParser.headingParsers + [
                              FencedCodeBlockParser.self,
                              BlockquoteParser.self,
                              ListItemParser.self
                            ])
```

The order of the block parsers and of the inline transformers matters. The block parsers are tried in order on each line, the first one that recognizes the line starts a block, and a line that none of them recognizes belongs to a paragraph. A configuration without ``IndentedCodeBlockParser``, as above, therefore treats indented text as a paragraph.

### Use the predefined parser

Since ``MarkdownParser`` objects are stateless (beyond the configuration of block parsers and inline transformers), there is a predefined default ``MarkdownParser`` object accessible via the static property ``MarkdownParser/standard``. ``ExtendedMarkdownParser`` and ``FullMarkdownParser`` have their own shared instances, too.

### Derive a parser with a different configuration

New Markdown parsers with different configurations can also be created by subclassing ``MarkdownParser`` and by overriding the class properties ``MarkdownParser/defaultBlockParsers`` and ``MarkdownParser/defaultInlineTransformers``. Here is an example of how class ``ExtendedMarkdownParser`` is derived from ``MarkdownParser`` by overriding `defaultBlockParsers`, by specializing `standard` in a covariant fashion, and by overriding the factory method ``MarkdownParser/documentParser(blockParsers:input:)``, which is needed for supporting definition lists.

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

A subclass that adds state has to take care of its thread safety. See <doc:UsingMarkdownKitConcurrently>.

## See Also

- <doc:ChoosingAParser>
- <doc:ExtendingTheParser>
