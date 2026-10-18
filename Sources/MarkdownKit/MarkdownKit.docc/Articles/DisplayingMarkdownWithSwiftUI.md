# Displaying Markdown with SwiftUI

Show a Markdown document in a SwiftUI view, and adapt it to light and dark mode.

<!-- Adapted from the README section "Displaying Markdown with SwiftUI". -->

## Overview

SwiftUI comes with support for Markdown-formatted snippets but does not have a full-fledged viewer for Markdown documents. MarkdownKit includes a SwiftUI view for displaying Markdown documents. As opposed to many other custom created Markdown views, the one included in MarkdownKit is based on the CommonMark-compliant MarkdownKit parser as well as its attributed string generator. It is thus lightweight yet still quite configurable. ``MarkdownText`` is available on macOS 14 and iOS 17 or later.

The initializer of ``MarkdownText`` receives the parsed Markdown content of type ``Block``, an optional `waitingMessage:` parameter which defines what is being displayed while the content is being rendered (especially if many images need to be loaded), as well as a `generator:` parameter defining how the parsed Markdown is transformed into an attributed string, which is then being shown in the view. The generator is not just called once, but every time the color scheme has changed to potentially update the colors in use.

A variant of this initializer accepts a Markdown document as a string and parses it with the standard parser of a ``MarkdownDialect``: the `dialect:` parameter selects it, and the default is ``MarkdownDialect/extendedCommonMark`` (``MarkdownDialect/fullMath`` if you pass `math:`, see below). Pass `dialect: .full` for the syntax of ``FullMarkdownParser``. There are two initializers for each of the two ways of providing the document. Either you pass a `generator:`, or you do not provide one and the view uses the default generators for light and dark mode, which can be configured with `renderingOptions:` (see ``AttributedStringGenerator/RenderingOptions``; the default is `.trusted`), `mermaid:` and `math:`.

The following code snippet shows the signatures of the initializers.

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

### Keep untrusted content in check

The view generates the attributed string synchronously, which is why only the rendering options `baseUrl`, `localImages`, `imageExtensions`, `safeMode` and `textSizeMultiplier` have an effect (remote images are never loaded). Use `MarkdownText(string: text, renderingOptions: .untrusted)` if the Markdown does not come from a trusted source. See <doc:RenderingUntrustedMarkdown>.

### Show Mermaid diagrams

Pass `mermaid: .default` to draw diagrams. The view first shows the code of a diagram and replaces it with the diagram once it has been rendered in the background. In dark mode, it uses ``MermaidConfig/darkVariant``. See <doc:DrawingMermaidDiagrams>.

### Show formulas

Pass `math: MathConfig()` to show LaTeX formulas as images. A string is parsed with ``MathMarkdownParser`` (``MarkdownDialect/fullMath``) then, unless you pass another `dialect:`. Like diagrams, the formulas are rendered in the background: the view first shows the LaTeX as code. In dark mode, the formulas are white (the colour of the text). See <doc:MathematicalFormulas>.

### Customize the generators for light and dark mode

Here is an example how view ``MarkdownText`` could be used in a simple Markdown viewer. It defines an attributed string generator that uses two color schemes depending on whether dark mode is active or not.

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

### Prepare diagrams and formulas for custom generators

A custom `generator:` is called synchronously, so it can only show Mermaid diagrams and formulas which have been rendered before. The default generators render them in the background and generate the text again once they are ready. To get the same with your own generators, pass a `prepare:` function: the view calls it after it has shown the text for the first time, for each document and color scheme, and generates the text again if it returns `true`.

```swift
struct ContentView: View {
  private static let lightGenerator = MathAttributedStringGenerator(mermaid: .default)
  private static let darkGenerator = MathAttributedStringGenerator(
      fontColor: "#FFF", codeFontColor: "#FFF", mermaid: MermaidConfig.default.darkVariant)
  
  let content = MathMarkdownParser.standard.parse("The area is $\\pi r^2$.")
  
  var body: some View {
    MarkdownText(self.content, generator: { doc, colorScheme in
      let generator = colorScheme == .dark ? Self.darkGenerator : Self.lightGenerator
      return generator.generate(doc: doc)
    }, prepare: { doc, colorScheme in
      let generator = colorScheme == .dark ? Self.darkGenerator : Self.lightGenerator
      let diagrams = await generator.prepareDiagrams(in: doc)
      let formulas = await generator.prepareMath(in: doc)
      return diagrams || formulas
    })
    .padding()
  }
}
```

## See Also

- <doc:GeneratingOutput>
- <doc:CustomizingAttributedStringOutput>
