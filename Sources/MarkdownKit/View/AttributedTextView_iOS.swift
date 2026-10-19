//
//  AttributedTextView_iOS.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 17/03/2026.
//  Copyright © 2026 Matthias Zenger. All rights reserved.
//

#if os(iOS)

import UIKit
import SwiftUI

@available(iOS 17.0, watchOS 10.0, tvOS 17.0, *)
struct AttributedTextView: UIViewRepresentable {
  let attributedText: NSAttributedString
  let availableWidth: CGFloat
  @Binding var contentHeight: CGFloat
  @Binding var colorScheme: ColorScheme?
  /// True if the markers of list items are put on the baseline of the first line of their items
  /// after each layout (see `ListMarkers`).
  var alignsListMarkers = false
  
  func makeUIView(context: Context) -> UITextView {
    // Configure a UITextView to display the attributed string
    let textView = ListAligningTextView()
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
    // Propagate the attributed text and line limit constraints. Setting the text resets the
    // text selection; it is only done if the text changed.
    let textChanged = context.coordinator.attributedText !== attributedText
    if textChanged {
      context.coordinator.attributedText = attributedText
      textView.attributedText = attributedText
    }
    // Finding the markers of lists costs time: only do it if it is asked for
    if textChanged || context.coordinator.alignsListMarkers != self.alignsListMarkers {
      context.coordinator.alignsListMarkers = self.alignsListMarkers
      (textView as? ListAligningTextView)?.pairs =
        self.alignsListMarkers ? ListMarkers.pairs(in: attributedText) : []
    }
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
  
  /// A text view which puts the markers of list items on the baseline of the first line of
  /// their items after each layout: the first line depends on the width of the text.
  final class ListAligningTextView: UITextView {
    /// The markers of lists in the text. The layout of a text view is only touched if there are
    /// any (using its layout manager makes it use TextKit 1, as lists need anyway).
    var pairs: [ListMarkers.Pair] = []
    private var isAligning = false

    // The initializers are declared here because the implicit ones are available on earlier
    // versions of Mac Catalyst than this view, which the compiler warns about.
    override init(frame: CGRect, textContainer: NSTextContainer?) {
      super.init(frame: frame, textContainer: textContainer)
    }

    required init?(coder: NSCoder) {
      super.init(coder: coder)
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      guard !pairs.isEmpty, !isAligning else {
        return
      }
      isAligning = true
      defer {
        isAligning = false
      }
      let layout = self.layoutManager
      layout.ensureLayout(for: self.textContainer)
      ListMarkers.align(self.textStorage, layoutManager: layout, pairs: pairs)
    }
  }

  class Coordinator: NSObject, UITextViewDelegate {
    var openURL: OpenURLAction? = nil
    /// The attributed text that was set last
    var attributedText: NSAttributedString? = nil
    /// Whether the markers of lists were looked for in that text
    var alignsListMarkers = false
    
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
