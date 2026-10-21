//
//  CustomTextFragment.swift
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
import CommandLineKit

///
/// Protocol `CustomTextFragment` defines the interface for custom Markdown text fragments
/// that are implemented externally (i.e. not by the MarkdownKit framework).
///
public protocol CustomTextFragment: CustomStringConvertible,
                                    CustomDebugStringConvertible,
                                    Sendable {
  
  /// Returns true if this fragment and `other` are equal. A custom fragment compares itself with
  /// another one by checking that `other` is of its own type and comparing their contents.
  func equals(to other: CustomTextFragment) -> Bool
  
  /// Returns the fragment that replaces this one when `transformer` processes a text. A fragment
  /// which contains text calls `transformer.transform(_:)` for it, so that inline markup within
  /// it is recognized.
  func transform(via transformer: InlineTransformer) -> TextFragment
  
  /// Returns the HTML for this fragment. `htmlGen` generates the HTML for the text within it.
  func generateHtml(via htmlGen: HtmlGenerator) -> String
  
  #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
  /// Returns the HTML for this fragment when an `AttributedStringGenerator` generates it. `htmlGen`
  /// is the HTML generator of `attrGen`, whose settings, such as fonts and colors, the HTML can
  /// use.
  func generateHtml(via htmlGen: HtmlGenerator, and attrGen: AttributedStringGenerator?) -> String
  #endif
  
  /// The text of the fragment without any markup.
  var rawDescription: String { get }
  
  /// Generates the plain text for this fragment in the text of a `StringGenerator`. This
  /// method has a default implementation, which returns `rawDescription` (without control
  /// characters), so it has to be implemented only to render markup in plain text.
  func generateText(via generator: StringGenerator) -> String
  
  /// Generates the styled text for this fragment in the text of a `TerminalGenerator`. This
  /// method has a default implementation, which returns `rawDescription` (without control
  /// characters), so it has to be implemented only to style the text on terminals.
  func generateText(via generator: TerminalGenerator) -> AnsiText.Normalized

  /// Returns the Markdown source of this fragment in the given context, or `nil` if the
  /// fragment cannot be written as Markdown there. A ``SourceGenerator`` calls this method. The
  /// source may contain `\n` for line breaks unless `context` has the flag `singleLine`.
  ///
  /// The source has to parse, with the parser of `generator`, into a fragment that is equal to
  /// this one (see `equals(to:)`). A fragment with text asks the generator to write it with
  /// ``SourceGenerator/generate(text:in:)``, passing `context` (or `context.inserting(_:)`
  /// if the fragment adds brackets); it does not escape anything itself. If the syntax of the
  /// fragment uses a character that plain text has to escape, the generator is created with this
  /// character as one of its `specialCharacters`. This method has a default implementation, which
  /// returns `nil`: the generator then writes `rawDescription` as plain text.
  func generateSource(via generator: SourceGenerator,
                      in context: SourceGenerator.InlineContext) -> String?
}

extension CustomTextFragment {
  public func generateSource(via generator: SourceGenerator,
                             in context: SourceGenerator.InlineContext) -> String? {
    return nil
  }

  public func generateText(via generator: StringGenerator) -> String {
    return self.rawDescription.sanitizingControlCharacters()
  }
  
  public func generateText(via generator: TerminalGenerator) -> AnsiText.Normalized {
    return AnsiText.Normalized(self.rawDescription.sanitizingControlCharacters())
  }
}
