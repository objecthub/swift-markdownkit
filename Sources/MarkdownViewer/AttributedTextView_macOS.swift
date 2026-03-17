//
//  NSAttributedTextView.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 17/03/2026.
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

#if os(macOS)

import AppKit
import SwiftUI

struct AttributedTextView: NSViewRepresentable {
  let attributedText: NSAttributedString
  let availableWidth: CGFloat
  @Binding var contentHeight: CGFloat
  @Binding var colorScheme: ColorScheme?
  
  func makeNSView(context: Context) -> NSTextView {
    // Configure an NSTextView to display the attributed string
    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.drawsBackground = false
    textView.textContainerInset = .zero
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.lineBreakMode = .byWordWrapping
    textView.textContainer?.widthTracksTextView = false
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = []
    textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    // Make links interactable
    textView.delegate = context.coordinator
    textView.linkTextAttributes = [
      .foregroundColor: NSColor.systemBlue,
      .underlineStyle: NSUnderlineStyle.single.rawValue
    ]
    
    context.coordinator.openURL = context.environment.openURL
    return textView
  }
  
  func updateNSView(_ textView: NSTextView, context: Context) {
    // Propagate the attributed text
    textView.textStorage?.setAttributedString(attributedText)
    // Set the text container width
    textView.textContainer?.containerSize = NSSize(width: self.availableWidth,
                                                   height: .greatestFiniteMagnitude)
    // Handle line limit constraints
    if let lineLimit = context.environment.lineLimit {
      textView.textContainer?.maximumNumberOfLines = lineLimit
    } else {
      textView.textContainer?.maximumNumberOfLines = 0
    }
    // Calculate the required height for the content
    textView.layoutManager?.ensureLayout(for: textView.textContainer!)
    let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? .zero
    let size = usedRect.size
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
  
  class Coordinator: NSObject, NSTextViewDelegate {
    var openURL: OpenURLAction? = nil
    
    func textView(_ textView: NSTextView,
                  clickedOnLink link: Any,
                  at charIndex: Int) -> Bool {
      // Handle link clicks
      if let url = link as? URL {
        openURL?(url)
        return true
      } else if let urlString = link as? String, let url = URL(string: urlString) {
        openURL?(url)
        return true
      }
      return false
    }
  }
}

#endif
