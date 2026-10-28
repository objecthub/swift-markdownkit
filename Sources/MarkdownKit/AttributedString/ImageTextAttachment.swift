//
//  ImageTextAttachment.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 28/10/2026.
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

#if os(iOS)

import Foundation
import ImageIO
import UIKit

///
/// The attachment of an image of a document, for attributed strings that are generated with
/// `scaleImages: true` (see `AttributedStringGenerator/generateAsync(doc:options:scaleImages:)`).
///
/// The system's HTML loader creates attachments that show an image in its natural size, whatever
/// the style of `img` says, and a text view does not scale attachments by itself: an image that is
/// wider than the text is cut off. This attachment is scaled down to the width that a text view
/// offers for its line whenever the text is laid out, keeping the aspect ratio of the image. It is
/// never scaled up. The text view can be resized later, and the lines of list items and other
/// blocks have different widths, which is why this cannot be done once, when the string is
/// generated. The attachments of formulas and diagrams (`MermaidTextAttachment` etc.) do the same.
///
/// This is only done on iOS. On macOS, the HTML importer creates attachments of a different kind
/// (they wrap a file, and their size is that of the attachment cell that AppKit creates for it).
///
final class ImageTextAttachment: NSTextAttachment {

  /// The size in points at which the image is shown if there is enough room: `bounds` if the
  /// importer has set them, otherwise the size of the image. Zero if it is not known; then the
  /// attachment is laid out like any other attachment.
  private lazy var naturalSize: CGSize = {
    if self.bounds.width > 0 && self.bounds.height > 0 {
      return self.bounds.size
    } else if let size = self.image?.size, size.width > 0 && size.height > 0 {
      return size
    } else if let data = self.contents ?? self.fileWrapper?.regularFileContents,
              let size = ImageTextAttachment.pixelSize(of: data) {
      return size
    } else {
      return .zero
    }
  }()

  /// Creates an attachment that shows the same image as `attachment`.
  init(copying attachment: NSTextAttachment) {
    super.init(data: attachment.contents, ofType: attachment.fileType)
    self.image = attachment.image
    self.fileWrapper = attachment.fileWrapper
    self.bounds = attachment.bounds
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  /// Returns the size of an image in pixels, as it is displayed (taking the orientation of the
  /// image into account), without decoding the image. `nil` if `data` is not an image.
  private static func pixelSize(of data: Data) -> CGSize? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
          let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
          width > 0 && height > 0 else {
      return nil
    }
    // The orientations 5 to 8 turn the image by 90 degrees
    if let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue,
       orientation >= 5 && orientation <= 8 {
      return CGSize(width: height, height: width)
    }
    return CGSize(width: width, height: height)
  }

  /// Returns the bounds of the image scaled down so that it is at most `width` points wide, or
  /// `nil` if it does not have to be scaled.
  private func fittedBounds(width: CGFloat) -> CGRect? {
    let size = self.naturalSize
    guard size.width > 0 && size.height > 0 && width > 0 && size.width > width else {
      return nil
    }
    let factor = width / size.width
    return CGRect(x: self.bounds.origin.x * factor,
                  y: self.bounds.origin.y * factor,
                  width: width,
                  height: size.height * factor)
  }

  override func attachmentBounds(for textContainer: NSTextContainer?,
                                 proposedLineFragment lineFrag: CGRect,
                                 glyphPosition position: CGPoint,
                                 characterIndex charIndex: Int) -> CGRect {
    return self.fittedBounds(width: lineFrag.width) ??
           super.attachmentBounds(for: textContainer,
                                  proposedLineFragment: lineFrag,
                                  glyphPosition: position,
                                  characterIndex: charIndex)
  }

  @available(iOS 15.0, *)
  override func attachmentBounds(for attributes: [NSAttributedString.Key : Any],
                                 location: any NSTextLocation,
                                 textContainer: NSTextContainer?,
                                 proposedLineFragment: CGRect,
                                 position: CGPoint) -> CGRect {
    return self.fittedBounds(width: proposedLineFragment.width) ??
           super.attachmentBounds(for: attributes,
                                  location: location,
                                  textContainer: textContainer,
                                  proposedLineFragment: proposedLineFragment,
                                  position: position)
  }

  /// Returns `string` with the images that the HTML importer has created replaced by attachments
  /// that scale. `string` itself is returned if there is no such image.
  ///
  /// Only objects of the class `NSTextAttachment` itself are replaced. This is what the
  /// importer creates; attachments of formulas and diagrams are objects of subclasses and are
  /// not touched. They are not in `string` yet when `AttributedStringGenerator` calls this method
  /// anyway: at this point the formulas and diagrams are placeholders in the text.
  static func scalingImages(in string: NSAttributedString) -> NSAttributedString {
    var images: [(range: NSRange, attachment: NSTextAttachment)] = []
    string.enumerateAttribute(.attachment,
                              in: NSRange(location: 0, length: string.length)) { value, range, _ in
      if let attachment = value as? NSTextAttachment,
         type(of: attachment) == NSTextAttachment.self {
        images.append((range, attachment))
      }
    }
    guard !images.isEmpty else {
      return string
    }
    let result = NSMutableAttributedString(attributedString: string)
    result.beginEditing()
    for image in images {
      result.addAttribute(.attachment,
                          value: ImageTextAttachment(copying: image.attachment),
                          range: image.range)
    }
    result.endEditing()
    return result
  }
}

#endif
