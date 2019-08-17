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
  public var content: [Block] = []
  
  open func makeBlock() -> Block {
    return .document(.bundle(self.content))
  }

  internal func parseIndent(input: String,
                            startIndex: String.Index,
                            endIndex: String.Index) -> (String.Index, Container) {
    return (startIndex, self)
  }

  internal func outermostIndentRequired(upto: Container) -> Container? {
    return nil
  }
  
  internal func returnTo(_ container: Container? = nil) -> Container {
    return self
  }

  internal final func returnToTopLevel() -> Container {
    return self.returnTo()
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
  }

  open var indentRequired: Bool {
    return false
  }

  open func skipIndent(input: String,
                       startIndex: String.Index,
                       endIndex: String.Index) -> String.Index? {
    return startIndex
  }

  open override func makeBlock() -> Block {
    preconditionFailure("makeBlock() not defined")
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

  internal final override func returnTo(_ container: Container? = nil) -> Container {
    if self === container {
      return self
    } else {
      self.outer.content.append(self.makeBlock())
      return self.outer.returnTo(container)
    }
  }
}
