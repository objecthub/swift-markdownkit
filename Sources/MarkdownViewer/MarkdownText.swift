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
  
  /// What to display until the markdown document has been converted into an
  /// attributed string.
  private let waitingText = NSAttributedString(string: "⏳")
  
  var body: some View {
    GeometryReader { geometry in
      ScrollView(.vertical) {
        AttributedTextView(attributedText: self.attributedText ?? self.waitingText,
                           availableWidth: geometry.size.width,
                           contentHeight: self.$contentHeight)
        .frame(width: geometry.size.width, height: contentHeight)
      }
    }
    .task {
      self.attributedText = AttributedStringGenerator.standard.generate(doc: self.text)
    }
    .onChange(of: self.colorScheme) { scheme in
      self.attributedText = AttributedStringGenerator.standard.generate(doc: self.text)
    }
  }
}

private struct AttributedTextView: UIViewRepresentable {
  let attributedText: NSAttributedString
  let availableWidth: CGFloat
  @Binding var contentHeight: CGFloat
  
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
    textView.textContainer.lineBreakMode = .byWordWrapping // CONFIG
    textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return textView
  }
  
  func updateUIView(_ textView: UITextView, context: Context) {
    // Propagate the attributed text and line limit constraints
    textView.attributedText = attributedText
    textView.textContainer.maximumNumberOfLines = context.environment.lineLimit ?? 0
    // Calculate the required height for the content
    let size = textView.sizeThatFits(CGSize(width: self.availableWidth,
                                            height: .greatestFiniteMagnitude))
    // Update the height binding on the main thread
    DispatchQueue.main.async {
      if self.contentHeight != size.height {
        self.contentHeight = size.height
      }
    }
  }
}
