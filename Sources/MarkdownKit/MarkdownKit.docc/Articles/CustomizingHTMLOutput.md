# Customizing HTML Output

Change the HTML that MarkdownKit generates by subclassing ``HtmlGenerator``.

<!-- The first example is adapted from the README section "Generating text, HTML, and Attributed Strings". -->

## Overview

Beyond the `safeMode` option (see ``HtmlGenerator/init(safeMode:)``), there are currently no means to customize ``HtmlGenerator`` other than subclassing. The generator is a recursive traversal of the syntax tree with one method for each level, and a subclass overrides the methods for the elements it wants to change:

| Method | Called for |
|---|---|
| ``HtmlGenerator/generate(doc:)`` | the whole document |
| ``HtmlGenerator/generate(blocks:parent:tight:)`` | a sequence of blocks |
| ``HtmlGenerator/generate(block:parent:tight:)`` | one block |
| ``HtmlGenerator/generate(text:)`` | inline text |
| ``HtmlGenerator/generate(textFragment:)`` | one inline fragment |

Override a method, handle the cases that you want to change, and call `super` for the others.

### Change how a block is generated

Here is an example that defines a customized HTML generator which formats `blockquote` Markdown blocks using HTML tables:

```swift
open class CustomizedHtmlGenerator: HtmlGenerator, @unchecked Sendable {
  open override func generate(block: Block, parent: Parent, tight: Bool = false) -> String {
    switch block {
      case .blockquote(let blocks):
        return "<table><tbody><tr><td style=\"background: #bbb; width: 0.2em;\"  />" +
               "<td style=\"width: 0.2em;\" /><td>\n" +
               self.generate(blocks: blocks, parent: .block(block, parent)) +
               "</td></tr></tbody></table>\n"
      default:
        return super.generate(block: block, parent: parent, tight: tight)
    }
  }
}
```

When you generate the content of a block, pass `.block(block, parent)` as the parent, as above. The ``HtmlGenerator/Parent`` value tells a generator where a block appears: `.none` for a top-level block, and otherwise the enclosing block together with the blocks that enclose it. This example adds an anchor to top-level headings only:

```swift
final class AnchorHtmlGenerator: HtmlGenerator, @unchecked Sendable {
  override func generate(block: Block, parent: Parent, tight: Bool = false) -> String {
    if case .heading(let level, let text) = block, case .none = parent {
      let anchor = text.rawDescription.lowercased()
                       .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                       .joined(separator: "-")
      return "<h\(level) id=\"\(anchor)\">\(self.generate(text: text))</h\(level)>\n"
    }
    return super.generate(block: block, parent: parent, tight: tight)
  }
}
```

The `tight` parameter is `true` for the content of a tight list. A tight list item shows its paragraph without a `<p>` element.

### Change how an inline element is generated

Override ``HtmlGenerator/generate(textFragment:)`` to change the HTML of emphasis, links and other inline fragments. This generator opens links in a new tab:

```swift
final class NewTabHtmlGenerator: HtmlGenerator, @unchecked Sendable {
  override func generate(textFragment fragment: TextFragment) -> String {
    if case .link(let text, let uri, let title) = fragment {
      return "<a href=\"\(self.hrefAttribute(uri ?? ""))\"\(self.titleAttribute(title))" +
             " target=\"_blank\" rel=\"noopener\">\(self.generate(text: text))</a>"
    }
    return super.generate(textFragment: fragment)
  }
}
```

Use ``HtmlGenerator/hrefAttribute(_:decode:image:)`` and ``HtmlGenerator/titleAttribute(_:)`` for URLs and titles. They escape the values so that they cannot break out of the attribute, and in safe mode they empty URLs with unsafe schemes. A subclass that writes these attributes itself has to do the same; see <doc:RenderingUntrustedMarkdown>.

### Generate HTML for custom elements

A ``CustomBlock`` and a ``CustomTextFragment`` create their own HTML, see <doc:ExtendingTheParser>. The generator calls `generateHtml(via:tight:)` of a custom block and `generateHtml(via:)` of a custom text fragment and passes itself, so a custom element can use the generator's methods for its content, e.g. ``HtmlGenerator/generate(text:)``.

### Know the thread-safety rules

A generator is shared between threads like the other classes, so a subclass restates `@unchecked Sendable` as above and must not keep mutable state, unless it synchronizes it. See <doc:UsingMarkdownKitConcurrently>.

## See Also

- <doc:GeneratingOutput>
- <doc:CustomizingAttributedStringOutput>
