# Swift MarkdownKit

<p>
<a href="https://developer.apple.com/osx/"><img src="https://img.shields.io/badge/Platform-macOS%20%7C%20iOS%20%7C%20Linux-blue.svg?style=flat" alt="Platform: macOS | iOS | Linux" /></a>
<a href="https://developer.apple.com/swift/"><img src="https://img.shields.io/badge/Language-Swift%205.5-green.svg?style=flat" alt="Language: Swift 5.5" /></a>
<a href="https://developer.apple.com/xcode/"><img src="https://img.shields.io/badge/IDE-Xcode%2013-orange.svg?style=flat" alt="IDE: Xcode 13" /></a>
<a href="https://raw.githubusercontent.com/objecthub/swift-markdownkit/master/LICENSE"><img src="http://img.shields.io/badge/License-Apache-lightgrey.svg?style=flat" alt="License: Apache" /></a>
</p>

## Overview

_Swift MarkdownKit_ is a framework for parsing text in [Markdown](https://daringfireball.net/projects/markdown/)
format. The supported syntax is based on the [CommonMark Markdown specification](https://commonmark.org).
_Swift MarkdownKit_ also provides an extended version of the parser that is able to handle Markdown tables.

_Swift MarkdownKit_ defines an abstract syntax for Markdown, it provides a parser for parsing strings into
abstract syntax trees, and comes with generators for creating HTML and
[attributed strings](https://developer.apple.com/documentation/foundation/nsattributedstring).

## Using the framework

### Parsing Markdown

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

Executing this code will result in the follwing data structure of type `Block` getting printed:

```swift
document(heading(1, text("Header")),
         heading(2, text("Sub-header")),
         paragraph(text("And this is a "),
                   strong(text("paragraph")),
                   text("."))))
```

[`Block`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Block.swift)
is a recursively defined enumeration of cases with associated values (also called an _algebraic datatype_).
Case `document` refers to the root of a document. It contains a sequence of blocks. In the example above, two
different types of blocks appear within the document: `heading` and `paragraph`. A `heading` case consists
of a heading level (as its first argument) and heading text (as the second argument). A `paragraph` case simply
consists of text.

Text is represented using the struct
[`Text`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Text.swift)
which is effectively a sequence of `TextFragment` values.
[`TextFragment`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/TextFragment.swift)
is yet another recursively defined enumeration with associated values. The example above shows two different
`TextFragment` cases in action: `text` and `strong`. Case `text` represents plain strings. Case `strong`
contains a `Text`  object, i.e. it encapsulates a sequence of `TextFragment` values which are
"marked up strongly".

### Parsing "extended" Markdown

Class `ExtendedMarkdownParser` has the same interface like `MarkdownParser` but supports tables and
definition lists in addition to the block types defined by the [CommonMark specification](https://commonmark.org).
[Tables](https://github.github.com/gfm/#tables-extension-) are based on the
[GitHub Flavored Markdown specification](https://github.github.com/gfm/) with one extension: within a table
block, it is possible to escape newline characters to enable cell text to be written on multiple lines. Here is an example:

```
| Column 1     | Column 2       |
| ------------ | -------------- |
| This text \
  is very long | More cell text |
| Last line    | Last cell      |        
```

[Definition lists](https://www.markdownguide.org/extended-syntax/#definition-lists) are implemented in an
ad hoc fashion. A definition consists of terms and their corresponding definitions. Here is an example of two
definitions:

```
Apple
: Pomaceous fruit of plants of the genus Malus in the family Rosaceae.

Orange
: The fruit of an evergreen tree of the genus Citrus.
: A large round juicy citrus fruit with a tough bright reddish-yellow rind.
```

### Configuring the Markdown parser

The Markdown dialect supported by `MarkdownParser` is defined by two parameters: a sequence of
_block parsers_ (each represented as a subclass of
[`BlockParser`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Parser/BlockParser.swift)),
and a sequence of _inline transformers_ (each represented as a subclass of
[`InlineTransformer`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Parser/InlineTransformer.swift)).
The initializer of class `MarkdownParser` accepts both components optionally. The default configuration
(neither block parsers nor inline transformers are provided for the initializer) is able to handle Markdown based on the
[CommonMark specification](https://commonmark.org).

Since `MarkdownParser` objects are stateless (beyond the configuration of block parsers and inline
transformers), there is a predefined default `MarkdownParser` object accessible via the static property
`MarkdownParser.standard`. This default parsing object is used in the example above.

New markdown parsers with different configurations can also be created by subclassing
[`MarkdownParser`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Parser/MarkdownParser.swift)
and by overriding the class properties `defaultBlockParsers` and `defaultInlineTransformers`. Here is
an example of how class
[`ExtendedMarkdownParser`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/Parser/ExtendedMarkdownParser.swift)
is derived from `MarkdownParser` simply by overriding
`defaultBlockParsers` and by specializing `standard` in a covariant fashion.

```swift
open class ExtendedMarkdownParser: MarkdownParser {
  override open class var defaultBlockParsers: [BlockParser.Type] {
    return self.blockParsers
  }
  private static let blockParsers: [BlockParser.Type] =
    MarkdownParser.defaultBlockParsers + [TableParser.self]
  override open class var standard: ExtendedMarkdownParser {
    return self.singleton
  }
  private static let singleton: ExtendedMarkdownParser = ExtendedMarkdownParser()
}
```

### Extending the Markdown parser

With version 1.1 of the MarkdownKit framework, it is now also possible to extend the abstract
syntax supported by MarkdownKit. Both `Block` and `TextFragment` enumerations now include
a `custom` case which refers to objects representing the extended syntax. These objects have to
implement protocol [`CustomBlock`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/CustomBlock.swift) for blocks and [`CustomTextFragment`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/CustomTextFragment.swift) for text fragments.

Here is a simple example how one can add support for "underline" (e.g. `this is ~underlined~ text`)
and "strikethrough" (e.g. `this is using ~~strike-through~~`) by subclassing existing inline transformers.

First, a new custom text fragment type has to be implemented for representing underlined and
strike-through text. This is done with an enumeration which implements the `CustomTextFragment` protocol:

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
final class EmphasisTestMarkdownParser: MarkdownParser {
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

### Processing Markdown

The usage of abstract syntax trees for representing Markdown text has the advantage that it is very easy to
process such data, in particular, to transform it and to extract information. Below is a short  _Swift_  snippet
which illustrates how to process an abstract syntax tree for the purpose of extracting all top-level headers
(i.e. this code prints the top-level outline of a text in Markdown format).

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

### Converting Markdown into other formats

_Swift MarkdownKit_ currently provides two different _generators_, i.e. Markdown processors which
output, for a given Markdown document, a corresponding representation in a different format.

[`HtmlGenerator`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/HTML/HtmlGenerator.swift)
defines a simple mapping from Markdown into HTML. Here is an example for the usage of the generator: 

```swift
let html = HtmlGenerator.standard.generate(doc: markdown)
```

There are currently no means to customize `HtmlGenerator` beyond subclassing. Here is an example that
defines a customized HTML generator which formats `blockquote` Markdown blocks using HTML tables:

```swift
open class CustomizedHtmlGenerator: HtmlGenerator {
  open override func generate(block: Block, tight: Bool = false) -> String {
    switch block {
      case .blockquote(let blocks):
        return "<table><tbody><tr><td style=\"background: #bbb; width: 0.2em;\"  />" +
               "<td style=\"width: 0.2em;\" /><td>\n" +
               self.generate(blocks: blocks) +
               "</td></tr></tbody></table>\n"
      default:
        return super.generate(block: block, tight: tight)
    }
  }
}
```

_Swift MarkdownKit_ also comes with a generator for attributed strings.
[`AttributedStringGenerator`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKit/AttributedString/AttributedStringGenerator.swift)
uses a customized HTML generator internally to define the translation from Markdown into
`NSAttributedString`. The initializer of `AttributedStringGenerator` provides a number of
parameters for customizing the style of the generated attributed string. 

```swift
let generator = AttributedStringGenerator(fontSize: 12,
                                          fontFamily: "Helvetica, sans-serif",
                                          fontColor: "#33C",
                                          h1Color: "#000")
let attributedStr = generator.generate(doc: markdown)
```

## Using the command-line tool

The _Swift MarkdownKit_ Xcode project also implements a
[very simple command-line tool](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKitProcess/main.swift)
for either translating a single Markdown text file into HTML or for translating all Markdown files within a given
directory into HTML.

The tool is provided to serve as a basis for customization to specific use cases. The simplest way to build the
binary is to use the Swift Package Manager (SPM):

```sh
> git clone https://github.com/objecthub/swift-markdownkit.git
Cloning into 'swift-markdownkit'...
remote: Enumerating objects: 70, done.
remote: Counting objects: 100% (70/70), done.
remote: Compressing objects: 100% (54/54), done.
remote: Total 70 (delta 13), reused 65 (delta 11), pack-reused 0
Unpacking objects: 100% (70/70), done.
> cd swift-markdownkit
> swift build -c release
[1/3] Compiling Swift Module 'MarkdownKit' (25 sources)
[2/3] Compiling Swift Module 'MarkdownKitProcess' (1 sources)
[3/3] Linking ./.build/x86_64-apple-macosx/release/MarkdownKitProcess
> ./.build/x86_64-apple-macosx/release/MarkdownKitProcess
usage: mdkitprocess <source> [<target>]
where: <source> is either a Markdown file or a directory containing Markdown files
       <target> is either an HTML file or a directory in which HTML files are written
```

## Known issues

There are a number of limitations and known issues:

  - The Markdown parser currently does not fully support _link reference definitions_ in a CommonMark-compliant
    fashion. It is possible to define link reference definitions and use them, but for some corner cases, the current
    implementation behaves differently from the spec.

## Requirements

The following technologies are needed to build the components of the _Swift MarkdownKit_ framework.
The command-line tool can be compiled with the _Swift Package Manager_, so _Xcode_ is not strictly needed
for that. Similarly, just for compiling the framework and trying the command-line tool in _Xcode_, the
_Swift Package Manager_ is not needed.

- [Xcode 13](https://developer.apple.com/xcode/)
- [Swift 5.5](https://developer.apple.com/swift/)
- [Swift Package Manager](https://swift.org/package-manager/)

## Copyright

Author: Matthias Zenger (<matthias@objecthub.net>)  
Copyright © 2019-2022 Google LLC.  
_Please note: This is not an official Google product._
