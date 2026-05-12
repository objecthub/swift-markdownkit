//
//  main.swift
//  MarkdownKitProcess
//
//  Created by Matthias Zenger on 01/08/2019.
//  Copyright © 2019 Google LLC.
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

import Foundation
import MarkdownKit
import CommandLineKit

enum OutputFormat {
  case html
  case text
  case rich
}

// This is a command-line tool for converting a text file in Markdown format into
// HTML. The tool also allows converting a whole folder of Markdown files into HTML.

let fileManager = FileManager.default

// Utility functions

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

guard CommandLine.arguments.count > 1 && CommandLine.arguments.count < 5 else {
  print("usage: mdkitprocess <format> <source> [<target>]")
  print("where: <format> is either 'html' or 'text'")
  print("       <source> is either a Markdown file or a directory containing Markdown files")
  print("       <target> is either an HTML file or a directory in which HTML files are written")
  exit(0)
}

var format: OutputFormat = .html

switch CommandLine.arguments[1] {
  case "html":
    format = .html
  case "text":
    format = .text
  case "rich":
    format = .rich
  default:
    print("unknown format: \(CommandLine.arguments[1])")
}

var sourceTarget: [(URL, URL?)] = []

let (sourceBaseUrl, sourceIsDir) = baseUrl(for: CommandLine.arguments[2], role: "source")
if CommandLine.arguments.count == 3 {
  let sources = sourceIsDir ? markdownFiles(inDir: sourceBaseUrl) : [sourceBaseUrl]
  for source in sources {
    let target = source.deletingPathExtension().appendingPathExtension("html")
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
                                .appendingPathExtension("html")
      sourceTarget.append((source, target))
    }
  } else {
    sourceTarget.append((sourceBaseUrl, targetBaseUrl))
  }
}

// Processing

for (sourceUrl, optTargetUrl) in sourceTarget {
  if let textContent = try? String(contentsOf: sourceUrl) {
    let markdownContent = ExtendedMarkdownParser.standard.parse(textContent)
    let output: String
    switch format {
      case .html:
        output = HtmlGenerator.standard.generate(doc: markdownContent)
      case .text:
        output = StringGenerator(numColumns: 80) // Terminal.size?.columns ?? 80)
                  .generate(doc: markdownContent)
      case .rich:
        output = TerminalGenerator(numColumns: 80) // Terminal.size?.columns ?? 80)
                  .generate(doc: markdownContent)
                  .encodedString
    }
    if let targetUrl = optTargetUrl {
      if fileManager.fileExists(atPath: targetUrl.path) {
        print("cannot overwrite target file '\(targetUrl.path)'")
      } else {
        do {
          try output.write(to: targetUrl, atomically: false, encoding: .utf8)
          print("converted '\(sourceUrl.lastPathComponent)' into '\(targetUrl.lastPathComponent)'")
        } catch {
          print("cannot write target file '\(targetUrl.path)'")
        }
      }
    } else {
      print(output)
    }
  } else {
    print("cannot read source file '\(sourceUrl.path)'")
  }
}
