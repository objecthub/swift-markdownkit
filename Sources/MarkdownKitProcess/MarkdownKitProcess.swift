//
//  MarkdownKitProcess.swift
//  MarkdownKitProcess
//
//  Created by Matthias Zenger on 01/08/2019.
//  Copyright © 2019-2026 Google LLC.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if os(macOS)

import Foundation
import AppKit
import MarkdownKit
import CommandLineKit


// This is a command-line tool for converting a text file in Markdown format into other
// formats such as plain text, HTML, RTF, RTFD, and PDF. The tool also allows converting a
// whole folder of Markdown files into an output format. RTFD and PDF output include diagrams, which
// are written in fenced code blocks with language `mermaid`, and formulas (LaTeX between
// dollar signs or between `\(` and `\)`, or in fenced code blocks with language `math`), which
// are also typeset in HTML output. Existing output files are only replaced if the option
// `--overwrite` is used.

@main
struct MarkdownKitProcess {

  /// Supported output formats
  enum OutputFormat: String {
    case text
    case ansi
    case html
    case rtf
    case rtfd
    case pdf
    
    var pathExtension: String {
      switch self {
        case .text, .ansi:
          return "txt"
        case .html:
          return "html"
        case .rtf:
          return "rtf"
        case .rtfd:
          return "rtfd"
        case .pdf:
          return "pdf"
      }
    }
  }
  
  /// The result of converting a Markdown document.
  enum Output {
    /// The content of a file.
    case data(Data)
    /// An RTFD document, which is a directory (a file package).
    case document(FileWrapper)
  }

  /// A conversion that failed.
  struct ConversionError: Error {
    let message: String
  }

  /// Reads, converts and writes the files. Diagrams are drawn by a web view, which needs the main
  /// thread (and its run loop, which the program runs while it waits for a diagram).
  @MainActor
  static func main() async {
    let (format, width, overwrite, jobs) = parseCommandLine()
    var failures = 0
    for (source, optTarget) in jobs {
      // Do not do any work if the result cannot be written
      if let target = optTarget {
        let canonicalSource = source.resolvingSymlinksInPath().standardizedFileURL
        if target.resolvingSymlinksInPath().standardizedFileURL == canonicalSource {
          report("the target '\(target.path)' is the source file")
          failures += 1
          continue
        } else if FileManager.default.fileExists(atPath: target.path) && !overwrite {
          report("'\(target.path)' already exists (use --overwrite to replace it)")
          failures += 1
          continue
        }
      }
      guard let text = try? String(contentsOf: source, encoding: .utf8) else {
        report("cannot read source file '\(source.path)'")
        failures += 1
        continue
      }
      do {
        let output = try await convert(MarkdownDialect.fullLaTeX.parser.parse(text),
                                       from: source,
                                       into: format,
                                       width: width)
        if let target = optTarget {
          try write(output, to: target)
          print("converted '\(source.lastPathComponent)' into '\(target.lastPathComponent)'")
        } else if format != .pdf, case .data(let data) = output,
                  let string = String(data: data, encoding: .utf8) {
          print(string)
        } else {
          report("cannot print '\(source.lastPathComponent)' as \(format.rawValue)")
          failures += 1
        }
      } catch let error as ConversionError {
        report(error.message)
        failures += 1
      } catch {
        report("cannot convert '\(source.lastPathComponent)': \(error.localizedDescription)")
        failures += 1
      }
    }
    exit(failures == 0 ? 0 : 1)
  }

  /// Defines the options of the tool, parses the command line, and returns the format, the width,
  /// whether existing files are replaced, and the files to convert. It terminates the tool if
  /// the command line is not valid, or if help was requested.
  static func parseCommandLine() -> (format: OutputFormat, width: Int, overwrite: Bool, jobs: [Job]) {
    let flags = Flags()
    let formatOption = flags.enum("f", "format",
                                  paramIdent: "<format>",
                                  description: "Output format: 'text' (plain text, default), " +
                                               "'ansi' (text marked up with ANSI escape " +
                                               "codes), 'html', 'rtf', 'rtfd', or 'pdf'.",
                                  value: OutputFormat.text)
    let widthOption = flags.int("w", "width",
                                paramIdent: "<columns>",
                                description: "Width in columns of the formats 'text' and 'ansi', " +
                                             "at least 10 (default: the width of the terminal, " +
                                             "or 80).")
    let overwriteOption = flags.option("o", "overwrite",
                                       description: "Replaces output files which already " +
                                                    "exist. Without this option, they are not " +
                                                    "touched.")
    let helpOption = flags.option("h", "help", description: "Prints this usage description.")
    let usage = flags.usageDescription(synopsis: "[<option> ...] <source> [<target>]") + """
      PARAMETERS:
        <source>
            A Markdown file, or a directory of Markdown files (the files ending in '.md').
        <target>
            The file, or the directory into which the converted files are written. The converted
            file of 'a.md' is called 'a.txt' ('text' and 'ansi'), 'a.html', 'a.rtf', 'a.rtfd' or
            'a.pdf'. '-' prints the output (not possible for 'rtfd' and 'pdf'). If there is no
            target, the converted files are written next to the source files.
      Diagrams in fenced code blocks with language 'mermaid' are drawn in the formats 'rtfd' and
      'pdf'. Formulas (LaTeX between '$' or '$$', between '\\(' and '\\)' or '\\[' and '\\]', or in
      fenced code blocks with language 'math') are typeset in the formats 'rtfd' and 'pdf' (as
      images) and 'html' (as MathML). RTF files cannot contain images: the format 'rtf' shows the
      code of a diagram and the LaTeX of a formula, as do the formats 'text' and 'ansi'.

      """
    if let failure = flags.parsingFailure() {
      fail(failure, usage: usage)
    }
    if helpOption.wasSet {
      print(usage, terminator: "")
      exit(0)
    }
    guard flags.parameters.count == 1 || flags.parameters.count == 2 else {
      fail("expected a source and optionally a target", usage: usage)
    }
    let format = formatOption.value ?? .text
    var width = Terminal.size?.columns ?? 80
    if let w = widthOption.value {
      guard w > 9 else {
        fail("error parsing flag `width`: `\(w)` is not greater than 9", usage: usage)
      }
      width = w
    }
    // Determining the files to convert
    let sourceUrl = URL(fileURLWithPath: flags.parameters[0])
    let sourceStatus = fileStatus(of: sourceUrl, for: format)
    guard sourceStatus.exists else {
      fail("source '\(flags.parameters[0])' does not exist")
    }
    let sources = sourceStatus.isDirectory ? markdownFiles(inDir: sourceUrl) : [sourceUrl]
    var jobs: [Job] = []
    if flags.parameters.count == 1 {
      // The converted files are next to the sources
      for source in sources {
        jobs.append((source, outputFile(for: source,
                                        in: source.deletingLastPathComponent(),
                                        format: format)))
      }
    } else if flags.parameters[1] == "-" {
      guard !sourceStatus.isDirectory else {
        fail("cannot print a directory of files to the terminal")
      }
      jobs.append((sourceUrl, nil))
    } else {
      let targetUrl = URL(fileURLWithPath: flags.parameters[1])
      let targetStatus = fileStatus(of: targetUrl, for: format)
      if sourceStatus.isDirectory {
        guard targetStatus.isDirectory else {
          fail("the target of a directory of files has to be an existing directory")
        }
        for source in sources {
          jobs.append((source, outputFile(for: source, in: targetUrl, format: format)))
        }
      } else if targetStatus.isDirectory {
        jobs.append((sourceUrl, outputFile(for: sourceUrl, in: targetUrl, format: format)))
      } else {
        jobs.append((sourceUrl, targetUrl))
      }
    }
    return (format, width, overwriteOption.wasSet, jobs)
  }

  /// Converts the Markdown `document`, which was read from `source`, into the format `format`.
  /// `width` is the width in columns of the text formats. The conversion is done by `MarkdownUtil`.
  /// Diagrams and formulas are drawn by a web view, which needs the main thread: the function is
  /// bound to it.
  @MainActor
  static func convert(_ document: Block,
                      from source: URL,
                      into format: OutputFormat,
                      width: Int) async throws -> Output {
    let util = MarkdownUtil.standard
    let title = source.lastPathComponent
    // The tool does not load any images from the web
    let options = AttributedStringGenerator.RenderingOptions(remoteImages: .none)
    switch format {
      case .text:
        return .data(Data(util.text(document, width: width).utf8))
      case .ansi:
        return .data(Data(util.ansi(document, width: width).utf8))
      case .html:
        return .data(Data(util.html(document).utf8))
      case .rtf:
        return .data(try await util.rtf(document, title: title, author: "MarkdownKitProcess",
                                        renderingOptions: options))
      case .rtfd:
        return .document(try await util.rtfd(document, title: title, author: "MarkdownKitProcess",
                                             renderingOptions: options))
      case .pdf:
        return .data(try await util.pdf(document, title: title, author: "MarkdownKitProcess",
                                        renderingOptions: options))
    }
  }

  /// Writes `output` into `target`. If `target` exists, it is replaced. The output is written into a
  /// temporary file first, so an existing target is only replaced if writing was successful.
  static func write(_ output: Output, to target: URL) throws {
    let fileManager = FileManager.default
    let temporary = target
                      .deletingLastPathComponent()
                      .appendingPathComponent(".\(target.lastPathComponent).\(UUID().uuidString)")
    do {
      switch output {
        case .data(let data):
          try data.write(to: temporary)
        case .document(let wrapper):
          try wrapper.write(to: temporary, originalContentsURL: nil)
      }
      if fileManager.fileExists(atPath: target.path) {
        _ = try fileManager.replaceItemAt(target, withItemAt: temporary)
      } else {
        try fileManager.moveItem(at: temporary, to: target)
      }
    } catch {
      try? fileManager.removeItem(at: temporary)
      throw error
    }
  }

  /// Reports an error and the usage description, and terminates.
  static func fail(_ message: String, usage: String? = nil) -> Never {
    FileHandle.standardError.write(Data((message + "\n" + (usage ?? "")).utf8))
    exit(1)
  }

  /// Reports an error.
  static func report(_ message: String) {
    FileHandle.standardError.write(Data(("error: " + message + "\n").utf8))
  }

  /// Returns whether there is a file or directory at `url`, and whether it is a directory that
  /// contains files. A directory with the path extension of the output format 'rtfd' is a
  /// document, i.e. a file.
  static func fileStatus(of url: URL, for format: OutputFormat) -> (exists: Bool, isDirectory: Bool) {
    var isDir = ObjCBool(false)
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
      return (false, false)
    }
    return (true, isDir.boolValue && !(format == .rtfd && url.pathExtension == "rtfd"))
  }

  /// A source file, and the file into which it is converted; `nil` stands for the terminal.
  typealias Job = (source: URL, target: URL?)

  /// The file that the Markdown file `source` is converted into in the directory `directory`.
  static func outputFile(for source: URL, in directory: URL, format: OutputFormat) -> URL {
    return directory.appendingPathComponent(source.lastPathComponent)
                    .deletingPathExtension()
                    .appendingPathExtension(format.pathExtension)
  }


  // Utility functions

  static func markdownFiles(inDir baseUrl: URL) -> [URL] {
    var res: [URL] = []
    if let urls = try? FileManager.default.contentsOfDirectory(
                         at: baseUrl,
                         includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
                         options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
      for url in urls {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        if !(values?.isDirectory ?? false) && url.lastPathComponent.hasSuffix(".md") {
          res.append(url)
        }
      }
    }
    return res.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }
}

#else

// The tool is only available on macOS
@main
struct MarkdownKitProcess {
  static func main() {}
}

#endif
