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
import ImageIO
import UniformTypeIdentifiers
import MarkdownKit
import CommandLineKit


// This is a command-line tool for converting a text file in Markdown format into other
// formats such as plain text, HTML, RTF, and RTFD. The tool also allows converting a
// whole folder of Markdown files into an output format. RTFD output includes diagrams, which
// are written in fenced code blocks with language `mermaid`. Existing output files are only
// replaced if the option `--overwrite` is used.

@main
struct MarkdownKitProcess {

  /// Supported output formats
  enum OutputFormat: String {
    case text
    case ansi
    case html
    case rtf
    case rtfd
    
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
        let output = try await convert(FullMarkdownParser.standard.parse(text),
                                       from: source,
                                       into: format,
                                       width: width)
        if let target = optTarget {
          try write(output, to: target)
          print("converted '\(source.lastPathComponent)' into '\(target.lastPathComponent)'")
        } else if case .data(let data) = output, let string = String(data: data, encoding: .utf8) {
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
                                               "codes), 'html', 'rtf', or 'rtfd'.",
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
            file of 'a.md' is called 'a.txt' ('text' and 'ansi'), 'a.html', 'a.rtf' or 'a.rtfd'.
            '-' prints the output (not possible for 'rtfd'). If there is no target, the converted
            files are written next to the source files.
      Diagrams in fenced code blocks with language 'mermaid' are drawn in the format 'rtfd'.
      RTF files cannot contain images: the format 'rtf' shows the code of a diagram.

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
  /// `width` is the width in columns of the text formats. Diagrams are drawn by a web view, which
  /// needs the main thread: the function is bound to it.
  @MainActor
  static func convert(_ document: Block,
                      from source: URL,
                      into format: OutputFormat,
                      width: Int) async throws -> Output {
    /// The attributes of RTF and RTFD documents
    let attributes: [NSAttributedString.DocumentAttributeKey: Any] = [
      .author: "MarkdownKitProcess",
      .title: source.lastPathComponent,
      .creationTime: Date()
    ]
    switch format {
      case .text:
        return .data(Data(StringGenerator(numColumns: width).generate(doc: document).utf8))
      case .ansi:
        return .data(Data(TerminalGenerator(numColumns: width).generate(doc: document)
                            .encodedString.utf8))
      case .html:
        return .data(Data(HtmlGenerator.standard.generate(doc: document).utf8))
      case .rtf:
        guard let string = AttributedStringGenerator.standard.generate(doc: document) else {
          throw ConversionError(message: "cannot convert \(source.lastPathComponent)")
        }
        var rtfAttributes = attributes
        rtfAttributes[.documentType] = NSAttributedString.DocumentType.rtf
        return .data(try string.data(from: NSRange(location: 0, length: string.length),
                                     documentAttributes: rtfAttributes))
      case .rtfd:
        let generator = AttributedStringGenerator(mermaid: MermaidConfig(maxWidth: maxDiagramWidth))
        await generator.prepareDiagrams(in: document)
        guard let string = generator.generate(doc: document) else {
          throw ConversionError(message: "cannot convert \(source.lastPathComponent)")
        }
        prepareImagesForRtfd(string)
        var rtfdAttributes = attributes
        rtfdAttributes[.documentType] = NSAttributedString.DocumentType.rtfd
        return .document(try string.fileWrapper(from: NSRange(location: 0, length: string.length),
                                                documentAttributes: rtfdAttributes))
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

  // Diagrams

  /// The width in points up to which diagrams are shown at their natural size; wider diagrams
  /// are scaled down. The text on a page of the size US Letter or A4 with margins of one inch is
  /// about 450 points wide; diagrams are narrower so that they still fit into lists and block
  /// quotes. The images of an RTFD document do not shrink to fit the width of the text.
  static let maxDiagramWidth: CGFloat = 400

  /// Returns PNG data of the image in `data` that has a resolution which makes its size in points
  /// `size`.
  static func pngData(_ data: Data, displayedAs size: CGSize) -> Data? {
    guard size.width > 0,
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      return nil
    }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output,
                                                             UTType.png.identifier as CFString,
                                                             1,
                                                             nil) else {
      return nil
    }
    let resolution = 72.0 * Double(image.width) / Double(size.width)
    CGImageDestinationAddImage(destination, image,
                               [kCGImagePropertyDPIWidth: resolution,
                                kCGImagePropertyDPIHeight: resolution] as CFDictionary)
    return CGImageDestinationFinalize(destination) ? output as Data : nil
  }

  /// A viewer shows the images of an RTFD document in the size which results from the resolution
  /// of their PNG files, not in the size of their attachments. This sets the resolution of the
  /// image of every attachment that has a size (the diagrams), so that the image has this size,
  /// and gives the files of the images names that say what they are.
  static func prepareImagesForRtfd(_ string: NSAttributedString) {
    var number = 0
    string.enumerateAttribute(.attachment,
                              in: NSRange(location: 0, length: string.length)) { value, _, _ in
      guard let attachment = value as? NSTextAttachment,
            let data = attachment.fileWrapper?.regularFileContents,
            let png = pngData(data, displayedAs: attachment.bounds.size) else {
        return
      }
      number += 1
      let wrapper = FileWrapper(regularFileWithContents: png)
      wrapper.preferredFilename = "Diagram \(number).png"
      attachment.fileWrapper = wrapper
    }
  }
}

#else

// The tool is only available on macOS
@main
struct MarkdownKitProcess {
  static func main() {}
}

#endif
