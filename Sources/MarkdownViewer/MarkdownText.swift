//
//  MarkdownText.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 01/03/2026.
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

import UIKit
import SwiftUI
import MarkdownKit

struct MarkdownText: View {
  @Environment(\.colorScheme) var colorScheme
  
  /// The markdown document to display.
  let text: Block
  
  /// The attributed string generated from the markdown document.
  @State private var attributedText: NSAttributedString? = nil
  
  /// The height of the markdown content when displayed.
  @State private var contentHeight: CGFloat = .zero
  
  /// The color scheme propagated back from the UITextView as well as the last color
  /// scheme used to generate the attributed string from the markdown text.
  /// This is a hack since `onChange(of: colorScheme)` triggers false positives.
  @State private var cachedColorScheme: ColorScheme? = nil
  @State private var lastUsedColorScheme: ColorScheme? = nil
  
  /// What to display until the markdown document has been converted into an
  /// attributed string.
  private let waitingText = NSAttributedString(string: "⏳")
  
  var body: some View {
    GeometryReader { geometry in
      ScrollView(.vertical) {
        AttributedTextView(attributedText: self.attributedText ?? self.waitingText,
                           availableWidth: geometry.size.width,
                           contentHeight: self.$contentHeight,
                           colorScheme: self.$cachedColorScheme)
        .frame(width: geometry.size.width, height: contentHeight)
      }
    }
    .onChange(of: self.cachedColorScheme, initial: true) {
      if self.cachedColorScheme == nil {
        self.cachedColorScheme = self.colorScheme
      }
      if self.lastUsedColorScheme != self.colorScheme {
        self.lastUsedColorScheme = self.colorScheme
        self.attributedText = AttributedStringGenerator.standard.generate(doc: self.text)
      }
    }
  }
}

private struct AttributedTextView: UIViewRepresentable {
  let attributedText: NSAttributedString
  let availableWidth: CGFloat
  @Binding var contentHeight: CGFloat
  @Binding var colorScheme: ColorScheme?
  
  func makeUIView(context: Context) -> UITextView {
    // Configure a UITextView to display the attributed string
    let textView = UITextView()
    textView.isEditable = false
    textView.isScrollEnabled = false
    textView.isSelectable = true
    textView.textColor = .label
    textView.backgroundColor = .clear
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.textContainer.lineBreakMode = .byWordWrapping
    textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    // Make links interactable
    textView.delegate = context.coordinator
    textView.linkTextAttributes = [
      .foregroundColor: UIColor.systemBlue,
      .underlineStyle: NSUnderlineStyle.single.rawValue
    ]
    context.coordinator.openURL = context.environment.openURL
    return textView
  }
  
  func updateUIView(_ textView: UITextView, context: Context) {
    // Propagate the attributed text and line limit constraints
    textView.attributedText = attributedText
    textView.textContainer.maximumNumberOfLines = context.environment.lineLimit ?? 0
    // Calculate the required height for the content
    let size = textView.sizeThatFits(CGSize(width: self.availableWidth,
                                            height: .greatestFiniteMagnitude))
    let colorScheme = context.environment.colorScheme
    // Update the height binding and color scheme on the main thread
    DispatchQueue.main.async {
      if self.contentHeight != size.height {
        self.contentHeight = size.height
      }
      if self.colorScheme != colorScheme {
        self.colorScheme = colorScheme
      }
    }
  }
  
  func makeCoordinator() -> Coordinator {
    return Coordinator()
  }
  
  class Coordinator: NSObject, UITextViewDelegate {
    var openURL: OpenURLAction? = nil
    
    func textView(_ textView: UITextView,
                  primaryActionFor textItem: UITextItem,
                  defaultAction: UIAction) -> UIAction? {
      // Handle link taps
      if case .link(let url) = textItem.content {
        return UIAction { _ in
          self.openURL?(url)
        }
      }
      // Return default action for other text items
      return defaultAction
    }
  }
}
