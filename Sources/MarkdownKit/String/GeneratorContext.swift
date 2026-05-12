//
//  GeneratorContext.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 12/05/2026.
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

/// 
/// Class `Context` provides information about the environment in which a Markdown
/// construct is being mapped to a string.
/// 
open class GeneratorContext {
  public let parent: Block
  public let context: GeneratorContext?
  public let tight: Bool
  public let itemIndent: Int?
  public let maxColumns: Int
  
  public init(doc: Block, maxColumns: Int) {
    self.parent = doc
    self.context = nil
    self.tight = false
    self.itemIndent = nil
    self.maxColumns = maxColumns
  }
  
  internal init(parent: Block,
                context: GeneratorContext?,
                tight: Bool,
                itemIndent: Int?,
                maxColumns: Int) {
    self.parent = parent
    self.context = context
    self.tight = tight
    self.itemIndent = itemIndent
    self.maxColumns = maxColumns
  }
  
  public func new(parent: Block? = nil,
                  tight: Bool? = nil,
                  itemIndent: Int? = nil,
                  indent: Int) -> GeneratorContext {
    return GeneratorContext(parent: parent ?? self.parent,
                            context: self,
                            tight: tight ?? self.tight,
                            itemIndent: itemIndent,
                            maxColumns: self.maxColumns - indent)
  }
  
  public var numEnclosingLists: Int {
    let num = self.context?.numEnclosingLists ?? 0
    if case .list(_, _, _) = self.parent {
      return num + 1
    } else {
      return num
    }
  }
  
  public var inDefinitionList: Bool {
    if case .definitionList(_) = self.parent {
      return true
    } else {
      return false
    }
  }
}
