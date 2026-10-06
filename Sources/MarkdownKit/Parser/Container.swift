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
  
  open func append(block: Block, tight: Bool) {
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
                            startIndex: String.Index,
                            endIndex: String.Index) -> (String.Index, Container) {
    return (startIndex, self)
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

  open override func makeBlock(_ docParser: DocumentParser) -> Block {
    preconditionFailure("makeBlock() not defined")
  }

  internal final override var enclosing: Container? {
    return self.outer
  }

  internal final override func parseIndent(input: String,
                                           startIndex: String.Index,
                                           endIndex: String.Index) -> (String.Index, Container) {
    let (index, container) = self.outer.parseIndent(input: input,
                                                    startIndex: startIndex,
                                                    endIndex: endIndex)
    guard container === self.outer else {
      return (index, container)
    }
    guard let res = self.skipIndent(input: input, startIndex: index, endIndex: endIndex) else {
      return (index, self.outer)
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
      self.outer.append(block: self.makeBlock(docParser), tight: self.density?.isTight ?? true)
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
