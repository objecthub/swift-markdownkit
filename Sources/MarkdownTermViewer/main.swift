//
//  main.swift
//  MarkdownTermViewer
//
//  Created by Matthias Zenger on 10/10/2026.
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

import Foundation
import MarkdownKit
import CommandLineKit


// This is a command-line tool for trying out the text generators of MarkdownKit. It prints
// the same demo document the MarkdownViewer app displays to the standard output, either as
// plain text (`StringGenerator`) or marked up with ANSI escape codes (`TerminalGenerator`).

// The demo document (it is a copy of the document in `ContentView.swift` of MarkdownViewer)

let document = FullMarkdownParser.standard.parse("""
  # Critical Document Title

  ## Summary

  Lorem ipsum dolor sit amet, **consectetur adipiscing** elit.
  Aliquam non risus in massa ornare lacinia. Etiam at ullamcorper
  ligula. Mauris et orci ut lectus convallis euismod. _Mauris_
  vitae purus congue, finibus tellus nec, lacinia felis.

  Etiam eget lectus quis leo tincidunt venenatis. Duis iaculis
  tristique tempor. _Maecenas vestibulum_ vehicula dui:
  [objecthub.com](https://objecthub.com).

  ## Considering More Options

  Nullam gravida `suscipit placerat`. Vivamus gravida fermentum
  magna vitae condimentum. Interdum et **malesuada fames** ac ante
  ipsum primis in faucibus.

  1. This is the first item
  2. This is the second item
  3. This is the third item

  Cras laoreet ~tellus dolor~, ac `suscipit augue` molestie a.
  Integer efficitur odio massa, in dictum arcu dictum in.
  Aliquam dapibus congue malesuada. Vestibulum dignissim
  mauris ~~id ipsum volutpat~~, in dignissim nisi luctus.
  Praesent scelerisque nisi non porttitor dictum. Etiam
  finibus ac libero at rhoncus.
      
  * This is the first item
  * This is the second item
  * This is the third item
  
  Lorem ipsum dolor sit amet, **consectetur adipiscing** elit.
  Aliquam non risus in massa ornare lacinia. Etiam at ullamcorper
  ligula. Mauris et orci ut lectus convallis euismod.

  ## Left To Do

  Some items are already done, others are still open:
      
  - [x] Review the **summary** of the document
  - [x] ~~Remove~~ the duplicate section about `options` and verify the outcome.
  - [ ] Check all links, in particular [objecthub.com](https://objecthub.com).
        Nullam gravida `suscipit placerat`. Vivamus gravida fermentum magna vitae condimentum.
  - [ ] Ask for a second opinion

  The final steps have to be completed in this order:

  1. [x] Collect the feedback of the reviewers
  2. [x] Merge the changes into the final text and proof-read is one more time.
        Nullam gravida `suscipit placerat`. Vivamus gravida fermentum magna vitae condimentum.
  3. [ ] Publish the document
  4. [ ] Archive the _previous_ versions

  ## Final Remarks

  Nunc at dignissim lectus. Integer ligula velit, ullamcorper
  id rutrum vel, iaculis aliquet quam. Praesent congue viverra
  lorem vel faucibus.

  > Cras nibh ex, lobortis a tincidunt vel, cursus a dolor.
  > Proin accumsan a risus in venenatis. Etiam eleifend, nisi
  > in auctor tristique, felis risus sodales nibh, eu sodales
  > nunc diam ut sapien.

  ## Last But Not Least

  Pellentesque ac lectus aliquam, efficitur lacus eu, efficitur justo.

  ```scheme
  ;; This is the first definition
  (define foo 12)
  ; This is the second one
  (define (bar n)
    (if (> n 12345)
        (foo 'end '(one two) (foo x) #t)
        "hello world"))
  ```

  **Aenean libero nunc**, elementum at justo congue, tristique tincidunt
  lorem. Donec ultrices ante mi, vehicula euismod neque egestas quis.

  ```swift
  /// A generic stack for equatable items.
  public struct Stack<T>: Equatable where T: Equatable {
    private(set) var items: [T]
    public init(items: [T] = []) {
      self.items = items
    }
    public mutating func push(item: T) { items.append(item) }
    fileprivate var description: String {
      if items.isEmpty {
        "The stack is empty"
      } else {
        "\\(items.count) items in the stack"
      }
    }
  }
  ```

  Vestibulum vitae ex ut tellus auctor mattis. Aenean eget ornare
  arcu. Lorem ipsum dolor sit amet, consectetur adipiscing elit.

  - Morbi ut dui laoreet, euismod libero sed, tincidunt mi. Proin
    pellentesque tellus augue, vel volutpat nulla euismod sed.
      1. Sub-item 1
      2. Sub-item 2
      3. Sub-item 3

  - Cras scelerisque ac turpis consequat vulputate. Quisque
    pellentesque mi a imperdiet lobortis. Nulla nec pretium dui.

  - Phasellus dolor magna, feugiat et dapibus sed, sodales a eros.
    Aliquam eget sem non nisl viverra placerat sagittis eget tellus.

  **Maecenas viverra**, justo nec finibus iaculis, diam turpis malesuada
  nulla, et pharetra nisi diam id nisi. Nam nunc purus, condimentum
  vitae risus tempor, gravida faucibus dolor. Fusce facilisis nisi
  erat, et cursus justo dignissim sed.

  ## Conclusion

  ### Represented as a Table

  | Column 1     | Column 2       | Col 3 |
  | ------------ | -------------: | :------: |
  | This text \
    is very long | More `cell` text | One |
  | Last **line**    | Last cell justo nec finibus. | Two |
  | Ok one more | And this also | Three |

  Lorem ipsum dolor sit amet, consectetur adipiscing elit.
  Aliquam non risus in massa ornare lacinia. Etiam at ullamcorper
  ligula. Mauris et orci ut lectus convallis euismod.

  ***

  This is the end.
  """)

// Command-line argument handling

enum OutputFormat: String {
  case text
  case ansi
}

let flags = Flags()
let formatOption = flags.enum("f", "format",
                              paramIdent: "<format>",
                              description: "Output format: 'text' (plain text, default) or " +
                                           "'ansi' (marked up with ANSI escape codes).",
                              value: OutputFormat.text)
let widthOption = flags.int("w", "width",
                            paramIdent: "<columns>",
                            description: "Width in columns, at least 10 (default: the width " +
                                         "of the terminal, or 80).")
let helpOption = flags.option("h", "help", description: "Prints this usage description.")

let usage = flags.usageDescription(synopsis: "[<option> ...]")

// Reports an error and the usage description, and terminates. The function does not access
// any global state, so it can be called from top-level code in any language mode.
func fail(_ message: String, usage: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n" + usage).utf8))
  exit(1)
}

if let failure = flags.parsingFailure() {
  fail(failure, usage: usage)
}

if helpOption.wasSet {
  print(usage, terminator: "")
  exit(0)
}

if let parameter = flags.parameters.first {
  fail("unexpected parameter `\(parameter)`", usage: usage)
}

var width = Terminal.size?.columns ?? 80

if let w = widthOption.value {
  guard w > 9 else {
    fail("error parsing flag `width`: `\(w)` is not greater than 9", usage: usage)
  }
  width = w
}

// Generating and printing the output

switch formatOption.value ?? .text {
  case .text:
    print(StringGenerator(numColumns: width).generate(doc: document))
  case .ansi:
    print(TerminalGenerator(numColumns: width).generate(doc: document).encodedString)
}

#endif
