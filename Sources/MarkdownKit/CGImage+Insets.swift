//
//  CGImage+Insets.swift
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

import Foundation
import CoreGraphics

extension CGImage {

  /// Returns the area of the image which is not transparent, in pixels and with the origin in the
  /// upper left corner, or `nil` if the whole image is transparent.
  ///
  /// - Parameter transparentAlpha: The pixels whose alpha value (0 to 255) is at most this value
  ///   count as transparent. The default ignores the faint edges that antialiasing creates.
  func contentBounds(transparentAlpha: UInt8 = 4) -> CGRect? {
    let width = self.width, height = self.height
    guard width > 0, height > 0,
          let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let data = context.data else {
      return nil
    }
    // The alpha values do not depend on the color space; the bytes of a pixel are red, green,
    // blue and alpha, and the first row is the top one.
    context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
    let pixels = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
    var minX = width, maxX = -1, minY = height, maxY = -1
    for y in 0..<height {
      let row = y * context.bytesPerRow
      for x in 0..<width where pixels[row + x * 4 + 3] > transparentAlpha {
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)
      }
    }
    guard maxX >= minX, maxY >= minY else {
      return nil
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
  }

  /// Returns a copy of the image whose content has transparent space of exactly the given widths
  /// in pixels (insets) between it and the edges of the image: the transparent area around the
  /// content of the image is removed, and transparent space of the width of each inset is added
  /// instead. Returns `nil` if the image is completely transparent (it has no content) or if
  /// there is not enough memory for the image.
  ///
  /// - Parameters:
  ///   - top: The width of the inset at the upper edge, in pixels.
  ///   - left: The width of the inset at the left edge, in pixels.
  ///   - bottom: The width of the inset at the lower edge, in pixels.
  ///   - right: The width of the inset at the right edge, in pixels.
  ///   - transparentAlpha: The pixels whose alpha value (0 to 255) is at most this value count as
  ///     transparent, see `contentBounds(transparentAlpha:)`.
  func withInsets(top: Int, left: Int, bottom: Int, right: Int,
                  transparentAlpha: UInt8 = 4) -> CGImage? {
    guard let bounds = self.contentBounds(transparentAlpha: transparentAlpha),
          let content = self.cropping(to: bounds) else {
      return nil
    }
    let contentWidth = Int(bounds.width), contentHeight = Int(bounds.height)
    let top = max(0, top), left = max(0, left), bottom = max(0, bottom), right = max(0, right)
    // Keep the color space of the image if the bitmap can have it, and use sRGB otherwise
    var space = self.colorSpace
    if space == nil || space?.model != .rgb {
      space = CGColorSpace(name: CGColorSpace.sRGB)
    }
    guard let space,
          let context = CGContext(data: nil,
                                  width: left + contentWidth + right,
                                  height: top + contentHeight + bottom,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
      return nil
    }
    // The origin of the context is in the lower left corner
    context.draw(content, in: CGRect(x: left, y: bottom, width: contentWidth, height: contentHeight))
    return context.makeImage()
  }
}
