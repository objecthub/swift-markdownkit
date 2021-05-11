//
//  MarkdownPlayground.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 02/08/2019.
//  Copyright © 2019-2021 Google LLC.
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
import AppKit
import PlaygroundSupport
import MarkdownKit

public class MarkdownView: NSView {
  let str: NSAttributedString
  let rect: NSRect

  init(str: NSAttributedString?, width: Double, height: Double) {
    self.str = str ?? NSAttributedString(string: "<undefined text>")
    self.rect = NSRect(x: 0.0, y: 0.0, width: width, height: height)
    super.init(frame: self.rect)
  }

  required init?(coder decoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override public func draw(_ dirtyRect: NSRect) {
    str.draw(in: rect)
  }
}

public func loadText(file: String) -> String? {
  if let fileUrl = Bundle.main.url(forResource: file, withExtension: "md") {
    return try? String(contentsOf: fileUrl, encoding: String.Encoding.utf8)
  } else {
    return nil
  }
}

public func markdownView(text: String, width: Double, height: Double) -> NSView {
  let markdown = ExtendedMarkdownParser.standard.parse(text)
  return MarkdownView(str: AttributedStringGenerator.standard.generate(doc: markdown),
                      width: width,
                      height: height)
}

public func markdownView(file: String, width: Double, height: Double) -> NSView {
  return markdownView(text: loadText(file: file) ?? "<cannot load file>",
                      width: width,
                      height: height)
}
