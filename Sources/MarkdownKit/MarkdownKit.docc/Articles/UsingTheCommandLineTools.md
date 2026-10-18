# Using the Command-Line Tools

Convert Markdown files from the terminal and preview the text generators.

<!-- Adapted from the README section "Using the command-line tools". -->

## Overview

The MarkdownKit package contains two command-line tools. Both are provided to serve as a demo and as a basis for customization to specific use cases, and both are only functional on macOS. The simplest way to build and run them is the Swift Package Manager (SPM), in a checkout of the repository.

### Convert Markdown files

`MarkdownKitProcess` is a [very simple command-line tool](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownKitProcess/MarkdownKitProcess.swift) that outputs Markdown content (parsed with ``FullMarkdownParser``) either as HTML, RTF, RTFD, or pretty-printed text, including the option to output ANSI-compliant markup. The tool either outputs a single Markdown text file into an output file or, when applied to a folder, outputs all Markdown files within the folder into output files in a target folder. Existing output files are not touched unless the option `--overwrite` is used.

The tool is a thin wrapper around ``MarkdownUtil``: it reads the files, calls ``MarkdownUtil/text(_:width:)``, ``MarkdownUtil/ansi(_:width:)``, ``MarkdownUtil/html(_:math:safeMode:)``, ``MarkdownUtil/rtf(_:title:author:renderingOptions:)`` or ``MarkdownUtil/rtfd(_:title:author:maxImageWidth:renderingOptions:)`` and writes the result, so you can do the same in your own code, see <doc:ConvertingMarkdownIntoDocuments>.

```sh
> git clone https://github.com/objecthub/swift-markdownkit.git
> cd swift-markdownkit
> swift run MarkdownKitProcess --help
USAGE: MarkdownKitProcess [<option> ...] <source> [<target>]
OPTIONS:
  -f, --format <format>
      Output format: 'text' (plain text, default), 'ansi' (text marked up with ANSI escape codes), 'html', 'rtf', or 'rtfd'.
  -w, --width <columns>
      Width in columns of the formats 'text' and 'ansi', at least 10 (default: the width of the terminal, or 80).
  -o, --overwrite
      Replaces output files which already exist. Without this option, they are not touched.
  -h, --help
      Prints this usage description.
PARAMETERS:
  <source>
      A Markdown file, or a directory of Markdown files (the files ending in '.md').
  <target>
      The file, or the directory into which the converted files are written. The converted
      file of 'a.md' is called 'a.txt' ('text' and 'ansi'), 'a.html', 'a.rtf' or 'a.rtfd'.
      '-' prints the output (not possible for 'rtfd'). If there is no target, the converted
      files are written next to the source files.
Diagrams in fenced code blocks with language 'mermaid' are drawn in the format 'rtfd'.
RTF files cannot contain images: the format 'rtf' shows the code of a diagram.
```

### Include diagrams

The format `rtfd` includes [Mermaid](https://mermaid.js.org) diagrams (see <doc:DrawingMermaidDiagrams>) and formulas (see <doc:MathematicalFormulas>) as images, and the format `html` typesets formulas as MathML, which browsers display without a style sheet or fonts. RTF files cannot contain the images that `NSAttributedString` creates, so the format `rtf` shows the code of a diagram and the LaTeX of a formula instead, like the formats `text` and `ansi`. The images of an RTFD document are in the files `Image 1.png`, `Formula 1.png` and so on, and a formula within a line is aligned with the text. The directory [`Examples`](https://github.com/objecthub/swift-markdownkit/blob/master/Examples/Demo.md) contains a Markdown file with the demo document of the `MarkdownViewer` sample app, including two diagrams, for trying the tool:

```sh
> swift run MarkdownKitProcess --format rtfd Examples/Demo.md /tmp/Demo.rtfd
converted 'Demo.md' into 'Demo.rtfd'
> swift run MarkdownKitProcess --format rtfd Examples/Demo.md /tmp/Demo.rtfd
error: '/tmp/Demo.rtfd' already exists (use --overwrite to replace it)
> swift run MarkdownKitProcess --format rtfd --overwrite Examples/Demo.md /tmp/Demo.rtfd
converted 'Demo.md' into 'Demo.rtfd'
```

### Preview the text generators

A second tool, [`MarkdownTermViewer`](https://github.com/objecthub/swift-markdownkit/blob/master/Sources/MarkdownTermViewer/main.swift), does not read any files. It prints a demo document with the features of ``FullMarkdownParser`` (the document displayed by the `MarkdownViewer` sample app: formatted text, tables, task lists, code blocks, ...) either as plain text (``StringGenerator``) or marked up with ANSI escape codes (``TerminalGenerator``). This is a quick way to see what the text generators produce:

```sh
> swift run MarkdownTermViewer --help
USAGE: MarkdownTermViewer [<option> ...]
OPTIONS:
  -f, --format <format>
      Output format: 'text' (plain text, default) or 'ansi' (marked up with ANSI escape codes).
  -w, --width <columns>
      Width in columns, at least 10 (default: the width of the terminal, or 80).
  -h, --help
      Prints this usage description.
> swift run MarkdownTermViewer --format ansi --width 60
```

The output of `--format ansi` is only rendered correctly by a terminal. Xcode's console shows the escape sequences as raw characters.

## See Also

- <doc:GeneratingTerminalOutput>
