//
//  MarkdownFactory.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 09/05/2019.
//  Copyright © 2019-2020 Google LLC.
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
@testable import MarkdownKit

protocol MarkdownKitFactory {
}

extension MarkdownKitFactory {

  func document(_ bs: Block...) -> Block {
    return .document(ContiguousArray(bs))
  }

  func paragraph(_ strs: String?...) -> Block {
    var res = Text()
    for str in strs {
      if let str = str {
        if let last = res.last {
          switch last {
            case .softLineBreak, .hardLineBreak:
              break
            default:
              res.append(fragment: .softLineBreak)
          }
        }

        res.append(fragment: .text(Substring(str)))
      } else {
        res.append(fragment: .hardLineBreak)
      }
    }
    return .paragraph(res)
  }

  func paragraph(_ fragments: TextFragment...) -> Block {
    var res = Text()
    for fragment in fragments {
      res.append(fragment: fragment)
    }
    return .paragraph(res)
  }

  func emph(_ fragments: TextFragment...) -> TextFragment {
    var res = Text()
    for fragment in fragments {
      res.append(fragment: fragment)
    }
    return .emph(res)
  }

  func strong(_ fragments: TextFragment...) -> TextFragment {
    var res = Text()
    for fragment in fragments {
      res.append(fragment: fragment)
    }
    return .strong(res)
  }

  func link(_ dest: String?, _ title: String?, _ fragments: TextFragment...) -> TextFragment {
    var res = Text()
    for fragment in fragments {
      res.append(fragment: fragment)
    }
    return .link(res, dest, title)
  }

  func image(_ dest: String?, _ title: String?, _ fragments: TextFragment...) -> TextFragment {
    var res = Text()
    for fragment in fragments {
      res.append(fragment: fragment)
    }
    return .image(res, dest, title)
  }

  func custom(_ factory: (Text) -> CustomTextFragment,
              _ fragments: TextFragment...) -> TextFragment {
    var res = Text()
    for fragment in fragments {
      res.append(fragment: fragment)
    }
    return .custom(factory(res))
  }

  func atxHeading(_ level: Int, _ title: String) -> Block {
    return .heading(level, Text(Substring(title)))
  }

  func setextHeading(_ level: Int, _ strs: String?...) -> Block {
    var res = Text()
    for str in strs {
      if let str = str {
        if let last = res.last {
          switch last {
          case .softLineBreak, .hardLineBreak:
            break
          default:
            res.append(fragment: .softLineBreak)
          }
        }
        res.append(fragment: .text(Substring(str)))
      } else {
        res.append(fragment: .hardLineBreak)
      }
    }
    return .heading(level, res)
  }

  func blockquote(_ bs: Block...) -> Block {
    return .blockquote(ContiguousArray(bs))
  }

  func indentedCode(_ strs: Substring...) -> Block {
    return .indentedCode(ContiguousArray(strs))
  }

  func fencedCode(_ info: String?, _ strs: Substring...) -> Block {
    return .fencedCode(info, ContiguousArray(strs))
  }

  func list(_ num: Int, tight: Bool = true, _ bs: Block...) -> Block {
    return .list(num, tight, ContiguousArray(bs))
  }

  func list(tight: Bool = true, _ bs: Block...) -> Block {
    return .list(nil, tight, ContiguousArray(bs))
  }

  func listItem(_ num: Int, _ sep: Character, tight: Bool = false, _ bs: Block...) -> Block {
    return .listItem(.ordered(num, sep), tight, ContiguousArray(bs))
  }

  func listItem(_ bullet: Character, tight: Bool = false, _ bs: Block...) -> Block {
    return .listItem(.bullet(bullet), tight, ContiguousArray(bs))
  }

  func htmlBlock(_ lines: Substring...) -> Block {
    return .htmlBlock(ContiguousArray(lines))
  }

  func referenceDef(_ label: String, _ dest: Substring, _ title: Substring...) -> Block {
    return .referenceDef(label, dest, ContiguousArray(title))
  }
  
  func table(_ hdr: [Substring?], _ algn: [Alignment], _ rw: [Substring?]...) -> Block {
    func toRow(_ arr: [Substring?]) -> Row {
      var res = Row()
      for a in arr {
        if let str = a {
          let components = str.components(separatedBy: "$")
          if components.count <= 1 {
            res.append(Text(str))
          } else {
            var text = Text()
            for component in components {
              text.append(fragment: .text(Substring(component)))
            }
            res.append(text)
          }
        } else {
          res.append(Text())
        }
      }
      return res
    }
    var rows = Rows()
    for r in rw {
      rows.append(toRow(r))
    }
    return .table(toRow(hdr), ContiguousArray(algn), rows)
  }
  
  func definitionList(_ decls: (Substring, [[Block]])...) -> Block {
    var defs = Definitions()
    for decl in decls {
      var res = Blocks()
      var tight = true
      for blocks in decl.1 {
        var content = Blocks()
        for block in blocks {
          content.append(block)
        }
        res.append(.listItem(.bullet(":"), tight, content))
        if content.count > 1 {
          tight = false
        }
      }
      defs.append(Definition(item: Text(decl.0), descriptions: res))
    }
    return .definitionList(defs)
  }
}
