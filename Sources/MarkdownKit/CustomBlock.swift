//
//  CustomBlock.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 12/05/2021.
//  Copyright © 2021 Google LLC.
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

///
/// Protocol `CustomBlock` defines the interface of custom Markdown elements that are implemented
/// externally (i.e. not by the MarkdownKit framework).
///
public protocol CustomBlock: CustomStringConvertible, CustomDebugStringConvertible, Sendable {
  
  /// The raw text of the block, without any markup. A default implementation returns the empty
  /// string.
  var string: String { get }
  
  /// Returns true if this block and `other` are equal. A custom block compares itself with another
  /// one by checking that `other` is of its own type and comparing their contents.
  func equals(to other: CustomBlock) -> Bool
  
  /// Returns the block that replaces this one after the inline markup in its content has been
  /// parsed by `parser`. A block which contains text calls `parser.transform(_:)` for it.
  func parse(via parser: InlineParser) -> Block
  
  /// Returns the HTML for this block. `htmlGen` generates the HTML for the content of the block,
  /// and `tight` is true if the block is part of a tight list.
  func generateHtml(via htmlGen: HtmlGenerator, tight: Bool) -> String
  
  #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
  /// Returns the HTML for this block when an `AttributedStringGenerator` generates it. `htmlGen`
  /// is the HTML generator of `attGen`, whose settings, such as fonts and colors, the HTML can
  /// use. `tight` is true if the block is part of a tight list.
  func generateHtml(via htmlGen: HtmlGenerator,
                    and attGen: AttributedStringGenerator?,
                    tight: Bool) -> String
  #endif
  
  /// Returns the lines of the Markdown source of this block, without line terminators, or `nil`
  /// if the block cannot be written as Markdown. A ``SourceGenerator`` calls this method. The
  /// lines are relative to the container of the block: the generator adds the markers and the
  /// indentation of block quotes and list items. `parent` tells which blocks enclose this block.
  ///
  /// The source has to parse, with the parser of `generator`, into a block that is equal to this
  /// one (see `equals(to:)`). A block with text asks the generator to write it with
  /// ``SourceGenerator/generate(lines:in:)``, and a block with blocks with
  /// ``SourceGenerator/generate(blocks:parent:)``, passing `.block(.custom(self), parent)` as
  /// parent. The method has a default implementation, which returns `nil`: the generator then
  /// writes a fenced code block with the description of the block.
  func generateSource(via generator: SourceGenerator, parent: SourceGenerator.Parent) -> [String]?
}

extension CustomBlock {
  /// By default, the custom block does not have any raw string content.
  public var string: String {
    return ""
  }

  /// By default, the custom block has no Markdown source.
  public func generateSource(via generator: SourceGenerator,
                             parent: SourceGenerator.Parent) -> [String]? {
    return nil
  }
}
