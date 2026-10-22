# Highlighting Code

Color the code of fenced code blocks in attributed strings and terminal output, or highlight code on its own.

## Overview

MarkdownKit uses [Highlight.js](https://github.com/highlightjs/highlight.js/) to find the keywords, strings, comments and other elements of the source code in fenced code blocks. Highlight.js runs in JavaScriptCore, which is why syntax highlighting is not available on watchOS. The generators style the result with a _theme_, which is a CSS style sheet with rules for the classes that Highlight.js assigns, such as `.hljs-keyword`. The framework ships with over 100 themes, and you can pass your own CSS.

``AttributedStringGenerator`` and ``TerminalGenerator`` highlight by default. The attributed string generator highlights code only with its default `version: .OS26`. The older `.preOS26` generator shows code blocks without colors, so that the output of existing code does not change. ``HtmlGenerator`` does not highlight: it marks the code block with the language as a `class` (`<pre><code class="language-swift">`), so a web page can load Highlight.js itself.

### Configure highlighting in generators

Both generators take a `syntaxHighlighting:` parameter with a `SyntaxHighlightingConfig` value. Setting this parameter to `nil` disables syntax highlighting.

| Property | Meaning |
|---|---|
| `theme` | either the name of a bundled theme (e.g. `"github"`) or CSS to be used with Highlight.js |
| `ignoreSyntacticIssues` | highlight the code even if Highlight.js finds a syntax error |
| `ignoredLanguages` | languages that are not highlighted; the empty string stands for fenced code blocks without a language |
| `highlightIndentedCodeBlocks` | whether Highlight.js infers the language of indented code blocks |

The default configurations are `.default`, which has a light theme, and `.defaultDark`. The default ignores fenced code blocks without a language, so no language is guessed for them. The language of a fenced code block is the first word of its info string:

````markdown
```swift
let x = 42
```
````

The terminal generator's configuration has one more property, `fullColorSupport`, which selects the 256-color palette. Its default is `true`.

```swift
let generator = AttributedStringGenerator(
  syntaxHighlighting: AttributedStringGenerator.SyntaxHighlightingConfig(
                        theme: "monokai", ignoredLanguages: ["text"]))
let terminal = TerminalGenerator(
  syntaxHighlighting: TerminalGenerator.SyntaxHighlightingConfig(
                        theme: "github", fullColorSupport: false))
```

For attributed strings in dark mode, use `.defaultDark` or a dark theme, as in the example of <doc:DisplayingMarkdownWithSwiftUI>.

### Use a custom highlighter

The generators use the shared highlighter ``SyntaxHighlighter/proxy``, which is `nil` if its resources are missing. To use another version of Highlight.js or your own themes, create a ``SyntaxHighlighter`` with the location of the JavaScript file and a directory of theme files (each `.css` file in it is a theme), and pass it as `syntaxHighlighter:` to the generator:

```swift
let highlighter = SyntaxHighlighter(highlightJSURL: URL(fileURLWithPath: "/path/to/highlight.min.js"),
                                    themeDirectory: URL(fileURLWithPath: "/path/to/themes"))
let generator = AttributedStringGenerator(syntaxHighlighter: highlighter)
```

``MarkdownUtil`` takes the highlighter as well (`MarkdownUtil(syntaxHighlighter: highlighter)`), and uses it for the code in its terminal text, RTF, RTFD and PDF documents.

### Write themes

A theme is CSS with rules for the classes that Highlight.js assigns to the parts of highlighted code, for example `.hljs-keyword{color:#f00;font-weight:bold}`. The selectors consist of classes: `.a`, `.a.b`, descendant selectors (`.a .b`) and child selectors (`.a > .b`). The cascade follows CSS: a rule with a higher specificity (more classes) wins over one with a lower specificity, otherwise the last rule wins. The properties `color`, `background-color`, `font-weight` and `font-style` are used for attributed strings; terminal output also uses `text-decoration`.

``SyntaxHighlighter/availableThemes`` lists the names of the themes in the highlighter's theme directory, and ``SyntaxHighlighter/supportedLanguages`` the languages that Highlight.js knows.

### Highlight code on its own

You can also highlight code without a generator: ``SyntaxHighlighter/highlight(code:as:ignoreIllegals:)`` returns HTML, and ``SyntaxHighlighter/asAttributedString(_:using:fastRender:lineNumbering:)`` turns it into an attributed string for a ``HighlightingConfig``:

```swift
guard let highlighter = SyntaxHighlighter.proxy else { return }
let config = highlighter.getConfig(forTheme: "github", withFont: "Monaco", ofSize: 14.0)
if let highlighted = highlighter.highlight(code: "let x = 42", as: "swift"),
   let config {
  let attributed = highlighter.asAttributedString(highlighted, using: config)
}
```

Pass a `SyntaxHighlighter.LineNumberConfig` as `lineNumbering:` to add line numbers. For terminals, ``SyntaxHighlighter/getAnsiConfig(forTheme:fullColorSupport:)`` and ``SyntaxHighlighter/asAnsiTerminalString(_:using:)`` do the same with ANSI escape codes.

## See Also

- <doc:GeneratingOutput>
