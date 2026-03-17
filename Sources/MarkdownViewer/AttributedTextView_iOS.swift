//
//  AttributedTextView.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 17/03/2026.
//  Copyright © 2026 Matthias Zenger. All rights reserved.
//

#if os(iOS) || os(watchOS) || os(tvOS)

import UIKit
import SwiftUI
import MarkdownKit

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

#endif
