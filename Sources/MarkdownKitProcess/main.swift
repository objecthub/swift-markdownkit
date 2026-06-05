//
//  main.swift
//  MarkdownKitProcess
//
//  Created by Matthias Zenger on 01/08/2019.
//  Copyright © 2019-2006 Google LLC.
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
import MarkdownKit
import CommandLineKit


// This is a command-line tool for converting a text file in Markdown format into other
// formats such as plain text, HTML, RTF, and RTFD. The tool also allows converting a
// whole folder of Markdown files into an output format.

// Supported formats

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

// Utility functions

let fileManager = FileManager.default

func markdownFiles(inDir baseUrl: URL) -> [URL] {
  var res: [URL] = []
  if let urls = try? fileManager.contentsOfDirectory(
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
  return res
}

func baseUrl(for path: String, role: String) -> (URL, Bool) {
  var isDir = ObjCBool(false)
  guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
    print("\(role) '\(path)' does not exist")
    exit(1)
  }
  return (URL(fileURLWithPath: path, isDirectory: isDir.boolValue), isDir.boolValue)
}

// Command-line argument handling

guard CommandLine.arguments.count > 2 && CommandLine.arguments.count < 6 else {
  print("usage: mdkitprocess <format> <source> [<target>] [<width>]")
  print("where: <format> is either 'text', 'ansi', 'html', 'rtf', or 'rtfd'")
  print("       <source> is either a Markdown file or a directory of Markdown files")
  print("       <target> is either a file path or an existing directory into which")
  print("                the output files are written into. '-' writes the output")
  print("                into the termimal.")
  print("       <width>  defines a terminal width in columns for the formats 'text'")
  print("                and 'ansi'")
  exit(0)
}

guard let format = OutputFormat(rawValue: CommandLine.arguments[1]) else {
  print("unknown format: \(CommandLine.arguments[1])")
  exit(1)
}

var width = Terminal.size?.columns ?? 80

if CommandLine.arguments.count == 5 {
  guard let w = Int(fromString: CommandLine.arguments[4]), w > 9 else {
    print("not a positive number greater than 9: \(CommandLine.arguments[4])")
    exit(1)
  }
  width = w
}

var sourceTarget: [(URL, URL?)] = []

let (sourceBaseUrl, sourceIsDir) = baseUrl(for: CommandLine.arguments[2], role: "source")
if CommandLine.arguments.count < 4 {
  let sources = sourceIsDir ? markdownFiles(inDir: sourceBaseUrl) : [sourceBaseUrl]
  for source in sources {
    let target = source.deletingPathExtension().appendingPathExtension(format.pathExtension)
    sourceTarget.append((source, target))
  }
} else if CommandLine.arguments[3] == "-" {
  guard !sourceIsDir else {
    print("cannot print source directory to console")
    exit(1)
  }
  sourceTarget.append((sourceBaseUrl, nil))
} else {
  let (targetBaseUrl, targetIsDir) = baseUrl(for: CommandLine.arguments[3], role: "target")
  guard sourceIsDir == targetIsDir else {
    print("source and target either need to be directories or individual files")
    exit(1)
  }
  if sourceIsDir {
    let sources = markdownFiles(inDir: sourceBaseUrl)
    for source in sources {
      let target = targetBaseUrl.appendingPathComponent(source.lastPathComponent)
                                .deletingPathExtension()
                                .appendingPathExtension(format.pathExtension)
      sourceTarget.append((source, target))
    }
  } else {
    sourceTarget.append((sourceBaseUrl, targetBaseUrl))
  }
}

// Loading, processing and writing files

for (sourceUrl, optTargetUrl) in sourceTarget {
  if let textContent = try? String(contentsOf: sourceUrl) {
    let markdownContent = ExtendedMarkdownParser.standard.parse(textContent)
    var fileWrapper: FileWrapper? = nil
    let output: Data?
    switch format {
      case .text:
        output = StringGenerator(numColumns: width)
                  .generate(doc: markdownContent).data(using: .utf8)
      case .ansi:
        output = TerminalGenerator(numColumns: width)
                  .generate(doc: markdownContent)
                  .encodedString.data(using: .utf8)
      case .html:
        output = HtmlGenerator.standard.generate(doc: markdownContent)
                  .data(using: .utf8)
      case .rtf:
        guard let astr = AttributedStringGenerator.standard.generate(doc: markdownContent) else {
          print("cannot convert \(sourceUrl.lastPathComponent)")
          continue
        }
        output = try astr.data(
          from: NSRange(location: 0, length: astr.length),
          documentAttributes: [
            .documentType: NSAttributedString.DocumentType.rtf,
            .author: "MarkdownKitProcess",
            .title: sourceUrl.lastPathComponent,
            .creationTime: Date()
          ])
      case .rtfd:
        guard let astr = AttributedStringGenerator.standard.generate(doc: markdownContent) else {
          print("cannot convert \(sourceUrl.lastPathComponent)")
          continue
        }
        output = nil
        fileWrapper = try astr.fileWrapper(
          from: NSRange(location: 0, length: astr.length),
          documentAttributes: [
            .documentType: NSAttributedString.DocumentType.rtfd,
            .author: "MarkdownKitProcess",
            .title: sourceUrl.lastPathComponent,
            .creationTime: Date()
          ])
    }
    if let targetUrl = optTargetUrl {
      if fileManager.fileExists(atPath: targetUrl.path) {
        print("cannot overwrite target file '\(targetUrl.path)'")
      } else {
        do {
          if let fileWrapper {
            try fileWrapper.write(to: targetUrl, originalContentsURL: nil)
          } else {
            try output?.write(to: targetUrl)
          }
          print("converted '\(sourceUrl.lastPathComponent)' into '\(targetUrl.lastPathComponent)'")
        } catch {
          print("cannot write target file '\(targetUrl.path)'")
        }
      }
    } else if let output,
              format == .text || format == .ansi || format == .html,
              let string = String(data: output, encoding: .utf8) {
      print(string)
    } else {
      print("cannot output converted file '\(sourceUrl.lastPathComponent)'")
    }
  } else {
    print("cannot read source file '\(sourceUrl.path)'")
  }
}

#endif
