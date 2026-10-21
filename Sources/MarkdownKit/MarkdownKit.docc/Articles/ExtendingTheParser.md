# Extending the Parser

Add your own inline markup to the Markdown syntax that MarkdownKit supports.

<!-- Adapted from the README section "Extending the parser". -->

## Overview

It is possible to extend the abstract syntax supported by MarkdownKit. Both the ``Block`` and the ``TextFragment`` enumerations include a `custom` case which refers to objects representing the extended syntax. These objects have to implement the protocol ``CustomBlock`` for blocks and ``CustomTextFragment`` for text fragments.

This article walks through a complete extension for inline markup. It adds support for "underline" (e.g. `this is ~underlined~ text`) and "strikethrough" (e.g. `this is using ~~strike-through~~`) by subclassing existing inline transformers. ``FullMarkdownParser`` supports this markup out of the box, with the text fragments `underline` and `strikethrough`; the example implements the same markup as a custom extension in order to show how the mechanism works. Use a different delimiter if you want to try it together with ``FullMarkdownParser``.

Extending the parser takes three steps: define the new syntax tree element, teach the inline transformers to recognize it, and create a parser that uses them.

### Define a custom text fragment

First, a new custom text fragment type has to be implemented for representing underlined and strike-through text. This is done with an enumeration which implements the ``CustomTextFragment`` protocol:

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
        return lhs.normalized == rhs.normalized
      case (.strikethrough(let lhs), .strikethrough(let rhs)):
        return lhs.normalized == rhs.normalized
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

The protocol has these requirements:

- `equals(to:)` compares two fragments, so that syntax trees can be compared. It compares ``Text/normalized`` text: the parser splits text into fragments in ways that do not matter, see <doc:GeneratingMarkdownSource>.
- `transform(via:)` lets an ``InlineTransformer`` process the text inside the fragment, so that other markup, such as emphasis or links, still works within it.
- `generateHtml(via:)` and `generateHtml(via:and:)` create the HTML for the fragment. The second variant is used by ``AttributedStringGenerator``, which converts HTML into an attributed string, and is passed the generator.
- `generateSource(via:in:)` writes the Markdown source of the fragment for a ``SourceGenerator`` (a ``CustomBlock`` has `generateSource(via:parent:)`). Both have default implementations which return `nil`, so you only implement them if the element is to be written back as Markdown, see below.
- `rawDescription` is the text of the fragment without any markup.
- `description` and `debugDescription` render the fragment for printing and debugging.

The plain text and terminal generators call `generateText(via:)` with a ``StringGenerator`` or a ``TerminalGenerator``. Both have default implementations which write `rawDescription` without control characters, so you only implement them to render the markup in text output.

A ``CustomBlock`` is defined in the same way for block-level syntax. Its `parse(via:)` method processes the inline markup of the block's content, and `generateHtml(via:tight:)` creates the HTML.

### Recognize the new delimiter

Next, two inline transformers need to be extended to recognize the new emphasis delimiter `~`. ``DelimiterTransformer`` finds the delimiter runs in the text and ``EmphasisTransformer`` matches them to create text fragments:

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

The `factory` receives `true` if the delimiter was doubled (`~~`) and the emphasized text.

### Create a parser

Finally, a new extended markdown parser can be created by overriding the list of default inline transformers:

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

Now `EmphasisTestMarkdownParser.standard.parse("some ~underlined~ text")` returns a syntax tree with a custom text fragment.

### Keep the inline transformers in order

The order of the inline transformers matters. In particular, ``EscapeTransformer`` needs to be the last transformer of the list, and it should not be left out:

- It resolves backslash escapes. This includes the escapes in link destinations and titles, which only exist after ``LinkTransformer`` has created the links.
- It decides which line endings are hard line breaks (a backslash or at least two spaces at the end of a line) and removes the trailing spaces of the other line endings. This has to happen after ``DelimiterTransformer`` has classified the delimiters (a `*` followed by a backslash is treated differently from a `*` at the end of a line), after ``CodeLinkHtmlTransformer`` has recognized code spans and HTML tags (a backslash or spaces at the end of a line are literal text in these, and the line ending is no line break), and after ``LinkTransformer`` has matched link reference labels (they are compared as written, including backslashes).

A parser without ``EscapeTransformer`` does not recognize hard line breaks; trailing spaces and backslashes at the end of lines remain in the text. Custom transformers for new inline markup, such as the ones above, belong in front of ``EscapeTransformer``.

### Write the source of the new elements

A ``SourceGenerator`` writes a syntax tree back as Markdown source (see <doc:GeneratingMarkdownSource>). To get the source of a custom text fragment, it calls `generateSource(via:in:)`, and for a custom block `generateSource(via:parent:)`. Without an implementation, the generator writes a fragment as plain text and a block as a code block, which read back as something else. For the fragment of the example, the source is the text between tildes:

```swift
extension LineEmphasis {
  func generateSource(via generator: SourceGenerator,
                      in context: SourceGenerator.InlineContext) -> String? {
    switch self {
      case .underline(let text):
        return "~" + generator.generate(text: text, in: context) + "~"
      case .strikethrough(let text):
        return "~~" + generator.generate(text: text, in: context) + "~~"
    }
  }
}
```

The generator passes the context in which the fragment is written. A fragment which contains text asks the generator to write it, handing on the context (a fragment that adds brackets passes `context.inserting(.linkText)`). It does not escape any characters or add prefixes itself. A block with text uses `generator.generate(lines:in:)`, a block with blocks `generator.generate(blocks:parent:)` with `.block(.custom(self), parent)` as parent; a block returns its lines relative to its container, and the generator adds the markers and the indentation of block quotes and list items.

The source of an element has to parse, with the parser of the generator, into an element that is equal to the original one. If it can not be written in the given place, return `nil`: a fragment cannot contain a line break in a table cell or in a heading (`context.contains(.singleLine)`). Create the generator for the parser with the characters that the new syntax adds, because plain text containing them needs an escape, too (`\~`):

```swift
let generator = SourceGenerator(syntax: .commonMark,
                                parser: EmphasisTestMarkdownParser.standard,
                                specialCharacters: ["~"])
```

### Make custom types Sendable

Custom types implementing ``CustomBlock``, ``CustomTextFragment`` or one of the table renderer protocols have to be `Sendable`, because syntax trees are shared between threads. Subclasses of parser and generator classes restate the conformance as `@unchecked Sendable`. See <doc:UsingMarkdownKitConcurrently>.

## See Also

- <doc:ConfiguringTheParser>
- <doc:ChoosingAParser>
