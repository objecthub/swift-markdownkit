//
//  MermaidDiagrams.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 12/10/2026.
//  Copyright © 2026 Matthias Zenger. All rights reserved.
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

// MARK: - Finding diagrams in Markdown

extension Block {

  /// True if the info string of a fenced code block says that its content is a Mermaid
  /// diagram: its first word is `mermaid`.
  static func isMermaid(info: String?) -> Bool {
    guard let info else {
      return false
    }
    return info.split(whereSeparator: \.isWhitespace).first == "mermaid"
  }

  /// The Mermaid source of the lines of a fenced code block (the lines include their line
  /// terminators).
  static func mermaidSource(of lines: Lines) -> String {
    return lines.joined(separator: "")
  }
  
  /// The sources of all Mermaid diagrams in this block, in document order, without duplicates.
  var mermaidSources: [String] {
    var sources: [String] = []
    self.collectMermaidSources(into: &sources)
    return sources
  }
  
  /// Appends the sources of all Mermaid diagrams in this block and its sub-blocks to `sources`
  /// in document order. Sources which are already contained in `sources` are skipped.
  func collectMermaidSources(into sources: inout [String]) {
    switch self {
      case .document(let blocks),
           .blockquote(let blocks),
           .list(_, _, let blocks),
           .listItem(_, _, let blocks):
        for block in blocks {
          block.collectMermaidSources(into: &sources)
        }
      case .definitionList(let definitions):
        for definition in definitions {
          for block in definition.descriptions {
            block.collectMermaidSources(into: &sources)
          }
        }
      case .fencedCode(let info, let lines):
        if Block.isMermaid(info: info) {
          let source = Block.mermaidSource(of: lines)
          if !sources.contains(source) {
            sources.append(source)
          }
        }
      default:
        break
    }
  }
}

extension ContiguousArray where Element == Block {

  /// The sources of all Mermaid diagrams in these blocks, in document order, without duplicates.
  var mermaidSources: [String] {
    var sources: [String] = []
    for block in self {
      block.collectMermaidSources(into: &sources)
    }
    return sources
  }
}
