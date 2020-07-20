//
//  ExtendedListItemParser.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 19/07/2019.
//  Copyright © 2020 Google LLC.
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

///
/// A block parser for parsing list items. There are two types of list items:
/// _bullet list items_ and _ordered list items_. They are represented using `listItem` blocks
/// using either the `bullet` or the `ordered list type`. `ExtendedListItemParser` also
/// accepts ":" as a bullet. This is used in definition lists.
///
open class ExtendedListItemParser: ListItemParser {
  
  public required init(docParser: DocumentParser) {
    super.init(docParser: docParser, bulletChars: ["-", "+", "*", ":"])
  }
}
