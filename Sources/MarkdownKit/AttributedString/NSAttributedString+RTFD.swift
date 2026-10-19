//
//  NSAttributedString+RTFD.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 19/10/2026.
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

#if os(macOS) || os(iOS)

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension NSAttributedString {

  ///
  /// Returns a copy of the attributed string whose image attachments the RTFD format represents
  /// faithfully. Use it before you export an attributed string with images, such as the diagrams
  /// and formulas of ``MathAttributedStringGenerator``, as an RTFD document
  /// (`fileWrapper(from:documentAttributes:)` with the document type `rtfd`). This is what
  /// ``MarkdownUtil/rtfd(_:title:author:maxImageWidth:renderingOptions:)`` does.
  ///
  /// The RTFD format has no room for some of what an attachment says, and a viewer shows an
  /// image in a different way than a text view does. For every attachment that has PNG data
  /// (or any other image data that the system can read) and a size, the copy makes up for this:
  ///
  /// - The size of an image in an RTFD document results from the resolution of its file, not
  ///   from the `bounds` of its attachment. The image of the copy has a resolution which makes
  ///   it as large in points as the bounds say.
  /// - A viewer places an image on the baseline of the text, since the format does not keep the
  ///   vertical position of the bounds of an attachment (`bounds.origin.y`). The copy has the
  ///   position in the attribute `baselineOffset`, which the format keeps, so that a formula
  ///   within a line stays aligned with the text.
  /// - The files of the images have names that say what they are: `Formula 1.png` for a formula
  ///   of ``MathAttributedStringGenerator`` (see ``Foundation/NSAttributedString/Key/mathSource``)
  ///   and `Image 1.png` for any other image.
  /// - The numbers and bullets of list items sit on the baseline of the first line of their items,
  ///   also if a formula or another image makes that line taller than the text: a viewer lays out
  ///   an image that is lowered by `baselineOffset` differently than a text view, so the copy
  ///   lowers the markers again, for a text of 30 times the font size (see
  ///   ``AttributedStringGenerator/alignListMarkers``).
  ///
  /// The attachments of the copy are new objects: neither the attributed string nor its
  /// attachments are changed. Attachments without data or without a size are left as they
  /// are, and so is the rest of the string, except for the markers of lists.
  ///
  /// ```swift
  /// let document = try string.preparedForRTFD()
  ///                          .fileWrapper(from: NSRange(location: 0, length: string.length),
  ///                                       documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
  /// ```
  ///
  public func preparedForRTFD() -> NSAttributedString {
    let result = NSMutableAttributedString(attributedString: self)
    var images = 0, formulas = 0
    self.enumerateAttribute(.attachment,
                            in: NSRange(location: 0, length: self.length)) { value, range, _ in
      guard let attachment = value as? NSTextAttachment,
            let data = attachment.fileWrapper?.regularFileContents ?? attachment.contents,
            let png = NSAttributedString.pngData(data, displayedAs: attachment.bounds.size) else {
        return
      }
      let wrapper = FileWrapper(regularFileWithContents: png)
      if self.attribute(.mathSource, at: range.location, effectiveRange: nil) != nil {
        formulas += 1
        wrapper.preferredFilename = "Formula \(formulas).png"
      } else {
        images += 1
        wrapper.preferredFilename = "Image \(images).png"
      }
      // An attachment that also has an image would be written under a name of the exporter
      let copy = NSTextAttachment()
      copy.fileWrapper = wrapper
      let bounds = attachment.bounds
      copy.bounds = CGRect(x: bounds.origin.x, y: 0, width: bounds.width, height: bounds.height)
      result.addAttribute(.attachment, value: copy, range: range)
      if bounds.origin.y != 0 {
        result.addAttribute(.baselineOffset, value: bounds.origin.y, range: range)
      }
    }
    // A viewer lays out the images differently, so the markers of lists need to move again
    return ListMarkers.aligned(result)
  }

  /// Returns PNG data of the image in `data` that has a resolution which makes its size in points
  /// `size`, or `nil` if there is no image or the size is empty.
  private static func pngData(_ data: Data, displayedAs size: CGSize) -> Data? {
    guard size.width > 0,
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      return nil
    }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output,
                                                             UTType.png.identifier as CFString,
                                                             1,
                                                             nil) else {
      return nil
    }
    let resolution = 72.0 * Double(image.width) / Double(size.width)
    CGImageDestinationAddImage(destination, image,
                               [kCGImagePropertyDPIWidth: resolution,
                                kCGImagePropertyDPIHeight: resolution] as CFDictionary)
    return CGImageDestinationFinalize(destination) ? output as Data : nil
  }
}

#endif
