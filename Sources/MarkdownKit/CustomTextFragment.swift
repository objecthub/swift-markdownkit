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
public protocol CustomTextFragment: CustomStringConvertible, CustomDebugStringConvertible, Sendable {
  func equals(to other: CustomTextFragment) -> Bool
  func transform(via transformer: InlineTransformer) -> TextFragment
  func generateHtml(via htmlGen: HtmlGenerator) -> String
  #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
  func generateHtml(via htmlGen: HtmlGenerator, and attrGen: AttributedStringGenerator?) -> String
  #endif
  var rawDescription: String { get }
  
  /// Generates the plain text for this fragment in the text of a `StringGenerator`. This
  /// method has a default implementation, which returns `rawDescription` (without control
  /// characters), so it has to be implemented only to render markup in plain text.
  func generateText(via generator: StringGenerator) -> String
  
  /// Generates the styled text for this fragment in the text of a `TerminalGenerator`. This
  /// method has a default implementation, which returns `rawDescription` (without control
  /// characters), so it has to be implemented only to style the text on terminals.
  func generateText(via generator: TerminalGenerator) -> AnsiText.Normalized
}

extension CustomTextFragment {
  public func generateText(via generator: StringGenerator) -> String {
    return self.rawDescription.sanitizingControlCharacters()
  }
  
  public func generateText(via generator: TerminalGenerator) -> AnsiText.Normalized {
    return AnsiText.Normalized(self.rawDescription.sanitizingControlCharacters())
  }
}
