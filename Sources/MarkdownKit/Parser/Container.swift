//
//  Container.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 01/05/2019.
//  Copyright © 2019 Google LLC.
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

/// A position within a line, which is used for skipping the indentation required by containers.
/// Tabs are not expanded, but they behave as if they were replaced by spaces up to the next tab
/// stop (a multiple of 4 columns). A tab can be consumed partially: a block quote marker `>`
/// followed by a tab consumes one column of the tab, the remaining columns are indentation.
internal struct LinePosition {
  /// The index of the character at this position
  var index: String.Index
  /// The column at which the character at `index` starts
  var column: Int
  /// The number of columns of the tab at `index` which are already consumed (0 if the
  /// character at `index` is not a tab)
  var partialTab: Int = 0

  /// The number of columns of a tab starting at `column`.
  static func tabWidth(at column: Int) -> Int {
    return 4 - column % 4
  }

  /// Consumes at most `columns` columns of white space (spaces and tabs) starting at this
  /// position. A tab is consumed partially if there are fewer columns left than the tab
  /// spans. Returns the resulting position and the number of columns consumed.
  func consumingWhitespace<S: StringProtocol>(in input: S,
                                              endIndex: String.Index,
                                              columns: Int) -> (position: LinePosition,
                                                                consumed: Int)
                                              where S.Index == String.Index {
    var pos = self
    var remaining = columns
    while remaining > 0 && pos.index < endIndex {
      let ch = input[pos.index]
      if ch == " " {
        pos.index = input.index(after: pos.index)
        pos.column += 1
        remaining -= 1
      } else if ch == "\t" {
        let width = LinePosition.tabWidth(at: pos.column)
        if width - pos.partialTab <= remaining {
          remaining -= width - pos.partialTab
          pos.column += width
          pos.partialTab = 0
          pos.index = input.index(after: pos.index)
        } else {
          pos.partialTab += remaining
          remaining = 0
        }
      } else {
        break
      }
    }
    return (pos, columns - remaining)
  }
}

///
/// A `Container` contains a sequence of blocks that are in the process of being parsed.
/// Containers can be nested. The subclass `NestedContainer` implements a nested container;
/// i.e. a container that has an enclosing container.
///
open class Container: CustomDebugStringConvertible {
  public private(set) var content: [Block] = []
  public var density: ListDensity? = nil

  /// The number of containers enclosing this container (0 for the document container).
  public internal(set) var depth: Int = 0

  /// True if there was no blank line in front of the line on which this container started.
  /// This is what the enclosing container needs to know about this container when determining
  /// whether it is loose (i.e. whether it directly contains blocks which are separated by
  /// blank lines); it is not the same as the density of this container.
  public internal(set) var startedTight: Bool = true

  /// True if a blank line within this container separates the blocks surrounding it. This is
  /// not the case for block quotes: a blank line at the end of a block quote does not make an
  /// enclosing list loose.
  internal var blankLinesSeparateBlocks: Bool {
    return true
  }
  
  open func append(block: Block, tight: Bool) {
    // Successive items of a list are not blocks which are separated by a blank line in the
    // sense of this container. Blank lines between them make the list loose, which is
    // determined from the density of the items.
    if case .listItem(let type, _, _) = block,
       case .listItem(let prevType, _, _)? = self.content.last,
       type.compatible(with: prevType) {
      self.content.append(block)
      return
    }
    if !content.isEmpty || self.density == nil {
      self.density = self.density?.merge(tight: tight) ?? .tight
    }
    self.content.append(block)
  }
  
  open func makeBlock(_ docParser: DocumentParser) -> Block {
    return .document(docParser.bundle(blocks: self.content))
  }

  fileprivate final func removeContent(from index: Int) {
    self.content.removeSubrange(index...)
  }

  /// The container enclosing this container, if there is one.
  internal var enclosing: Container? {
    return nil
  }

  /// True if this container ends when it is empty and followed by a blank line. This is the
  /// case for list items: an item can begin with at most one blank line.
  internal var endsAtBlankLineIfEmpty: Bool {
    return false
  }

  /// Records the content size and density of this container and of all enclosing containers.
  internal func snapshot() -> [ContainerSnapshot] {
    var res: [ContainerSnapshot] = []
    var current: Container? = self
    while let container = current {
      res.append(ContainerSnapshot(container: container,
                                   count: container.content.count,
                                   density: container.density))
      current = container.enclosing
    }
    return res
  }

  internal func parseIndent(input: String,
                            position: LinePosition,
                            endIndex: String.Index) -> (LinePosition, Container) {
    return (position, self)
  }

  internal func outermostIndentRequired(upto: Container) -> Container? {
    return nil
  }
  
  internal func `return`(to container: Container? = nil, for: DocumentParser) -> Container {
    return self
  }

  open var debugDescription: String {
    return "doc"
  }
}

///
/// A `NestedContainer` represents a container that has an "outer" container.
///
open class NestedContainer: Container {
  internal let outer: Container

  public init(outer: Container) {
    self.outer = outer
    super.init()
    self.depth = outer.depth + 1
  }

  open var indentRequired: Bool {
    return false
  }
  
  open func skipIndent(input: String,
                       startIndex: String.Index,
                       endIndex: String.Index) -> String.Index? {
    return startIndex
  }

  /// Skips the indentation required by this container at the given position, taking tab stops
  /// into account. Returns `nil` if the line does not have the required indentation. Subclasses
  /// in this module override this method; the default implementation uses `skipIndent`
  /// (without support for partially consumed tabs).
  internal func skipIndent(input: String,
                           position: LinePosition,
                           endIndex: String.Index) -> LinePosition? {
    guard let index = self.skipIndent(input: input,
                                      startIndex: position.index,
                                      endIndex: endIndex) else {
      return nil
    }
    var column = position.column
    var i = position.index
    while i < index {
      column += input[i] == "\t" ? LinePosition.tabWidth(at: column) : 1
      i = input.index(after: i)
    }
    return LinePosition(index: index, column: column)
  }

  open override func makeBlock(_ docParser: DocumentParser) -> Block {
    preconditionFailure("makeBlock() not defined")
  }

  internal final override var enclosing: Container? {
    return self.outer
  }

  internal final override func parseIndent(input: String,
                                           position: LinePosition,
                                           endIndex: String.Index) -> (LinePosition, Container) {
    let (outerPosition, container) = self.outer.parseIndent(input: input,
                                                            position: position,
                                                            endIndex: endIndex)
    guard container === self.outer else {
      return (outerPosition, container)
    }
    guard let res = self.skipIndent(input: input,
                                    position: outerPosition,
                                    endIndex: endIndex) else {
      return (outerPosition, self.outer)
    }
    return (res, self)
  }

  internal final override func outermostIndentRequired(upto container: Container) -> Container? {
    if self === container {
      return nil
    } else if self.indentRequired {
      return self.outer.outermostIndentRequired(upto: container) ?? self.outer
    } else {
      return self.outer.outermostIndentRequired(upto: container)
    }
  }

  internal final override func `return`(to container: Container? = nil,
                                        for docParser: DocumentParser) -> Container {
    if self === container {
      return self
    } else {
      self.outer.append(block: self.makeBlock(docParser), tight: self.startedTight)
      return self.outer.return(to: container, for: docParser)
    }
  }
}

/// The state of a `Container` at some point in time. Used for undoing changes to containers
/// when a `DocumentParser` state is restored.
internal struct ContainerSnapshot {
  let container: Container
  let count: Int
  let density: ListDensity?

  func restore() {
    self.container.truncate(to: self.count, density: self.density)
  }
}

extension Container {
  fileprivate func truncate(to count: Int, density: ListDensity?) {
    if self.content.count > count {
      self.removeContent(from: count)
    }
    self.density = density
  }
}
