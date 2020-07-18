//
//  ParserUtil.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 10/06/2019.
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


public func isAsciiWhitespaceOrControl(_ ch: Character) -> Bool {
  return isWhitespace(ch) || isControlCharacter(ch)
}

public func isWhitespace(_ ch: Character) -> Bool {
  switch ch {
    case " ", "\t", "\n", "\r", "\u{b}", "\u{c}":
      return true
    default:
      return false
  }
}

public func isWhitespaceString(_ str: Substring) -> Bool {
  for ch in str {
    if !isWhitespace(ch) {
      return false
    }
  }
  return true
}

public func isUnicodeWhitespace(_ ch: Character) -> Bool {
  if let scalar = ch.unicodeScalars.first {
    return CharacterSet.whitespacesAndNewlines.contains(scalar)
  }
  return false
}

public func isSpace(_ ch: Character) -> Bool {
  return ch == " "
}

public func isDash(_ ch: Character) -> Bool {
  return ch == "-"
}

public func isAsciiPunctuation(_ ch: Character) -> Bool {
  switch ch {
    case "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", ":",
         ";", "<", "=", ">", "?", "@", "[", "\\", "]", "^", "_", "`", "{", "|", "}", "~":
      return true
    default:
      return false
  }
}

public func isUppercaseAsciiLetter(_ ch: Character) -> Bool {
  switch ch {
    case "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q",
         "R", "S", "T", "U", "V", "W", "X", "Y", "Z":
      return true
    default:
      return false
  }
}

public func isAsciiLetter(_ ch: Character) -> Bool {
  switch ch {
    case "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q",
         "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
         "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q",
         "r", "s", "t", "u", "v", "w", "x", "y", "z":
      return true
    default:
      return false
  }
}

public func isAsciiLetterOrDigit(_ ch: Character) -> Bool {
  switch ch {
    case "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q",
         "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
         "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q",
         "r", "s", "t", "u", "v", "w", "x", "y", "z",
         "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
      return true
    default:
      return false
  }
}

public func isControlCharacter(_ ch: Character) -> Bool {
  if let scalar = ch.unicodeScalars.first, CharacterSet.controlCharacters.contains(scalar) {
    return true
  }
  return false
}

public func isUnicodePunctuation(_ ch: Character) -> Bool {
  if let scalar = ch.unicodeScalars.first, CharacterSet.punctuationCharacters.contains(scalar) {
    return true
  }
  return isAsciiPunctuation(ch)
}

public func skipWhitespace(in str: Substring,
                           from index: inout Substring.Index,
                           to endIndex: Substring.Index) {
  while index < endIndex {
    let ch = str[index]
    if ch != " " {
      guard let scalar = ch.unicodeScalars.first, CharacterSet.whitespaces.contains(scalar) else {
        return
      }
    }
    index = str.index(after: index)
  }
}

public func isURI(_ str: String) -> Bool {
  var iterator = str.makeIterator()
  var next = iterator.next()
  guard next != nil, next!.isASCII, next!.isLetter else {
    return false
  }
  next = iterator.next()
  var n = 1
  while let ch = next {
    guard ch.isASCII else {
      return false
    }
    if ch == ":" {
      if n > 1 {
        break
      } else {
        return false
      }
    }
    guard ch.isLetter || ch.isHexDigit || ch == "+" || ch == "-" || ch == "." else {
      return false
    }
    next = iterator.next()
    n += 1
    guard n <= 32 else {
      return false
    }
  }
  guard next != nil else {
    return false
  }
  while let ch = iterator.next() {
    guard !isWhitespace(ch), !isControlCharacter(ch), ch != "<", ch != ">" else {
      return false
    }
  }
  return true
}

public func isHtmlTag(_ str: String) -> Bool {
  var iterator = str.makeIterator()
  var next = iterator.next()
  guard let ch = next else {
    return false
  }
  switch ch {
    case "/":
      next = iterator.next()
      guard skipTagName(&next, &iterator) else {
        return false
      }
      _ = skipWhitespace(&next, &iterator)
      return next == nil
    case "?":
      return str.count > 1 && str.last! == "?"
    case "!":
      guard let fst = iterator.next() else {
        return false
      }
      if fst == "-" {
        guard let snd = iterator.next(), snd == "-" else {
          return false
        }
        guard str.count > 4,
              !str.hasPrefix("!-->"),
              !str.hasPrefix("!--->"),
              !str.hasSuffix("---")  else {
          return false
        }
        return !str[str.index(str.startIndex, offsetBy: 3)..<str.index(str.endIndex,
                                                                       offsetBy: -2)].contains("--")
      } else if fst == "[" {
        return str.hasPrefix("![CDATA[") &&
               str.hasSuffix("]]") &&
               !str[str.index(str.startIndex, offsetBy: 8)..<str.index(str.endIndex,
                                                                       offsetBy: -2)].contains("]]")
      } else if isUppercaseAsciiLetter(fst) {
        while let ch = next, isUppercaseAsciiLetter(ch) {
          next = iterator.next()
        }
        _ = skipWhitespace(&next, &iterator)
        while let ch = next, ch != ">" {
          next = iterator.next()
        }
        return next == nil
      } else {
        return false
      }
    default:
      guard skipTagName(&next, &iterator) else {
        return false
      }
      loop: while skipWhitespace(&next, &iterator), let ch = next, ch != "/", ch != ">" {
        var skipped = skipAttribute(&next, &iterator)
        while skipped == nil {
          if next == nil || next == "/" || next == ">" {
            break loop
          }
          skipped = skipAttribute(&next, &iterator)
        }
        guard skipped! else {
          return false
        }
      }
      if case .some("/") = next {
        next = iterator.next()
      }
      return next == nil
  }
}

fileprivate func skipAttribute(_ next: inout Character?,
                               _ iterator: inout String.Iterator) -> Bool? {
  guard skipAttributeName(&next, &iterator) else {
    return false
  }
  _ = skipWhitespace(&next, &iterator)
  guard case .some("=") = next else {
    return nil
  }
  next = iterator.next()
  _ = skipWhitespace(&next, &iterator)
  guard let fst = next else {
    return false
  }
  next = iterator.next()
  switch fst {
    case "'":
      while let ch = next, ch != "'" {
        next = iterator.next()
      }
      guard next != nil else {
        return false
      }
      next = iterator.next()
    case "\"":
      while let ch = next, ch != "\"" {
        next = iterator.next()
      }
      guard next != nil else {
        return false
      }
      next = iterator.next()
    default:
      while let ch = next, !isWhitespace(ch),
            ch != "\"", ch != "'", ch != "=", ch != "<", ch != ">", ch != "`" {
        next = iterator.next()
      }
  }
  return true
}

fileprivate func skipAttributeName(_ next: inout Character?,
                                   _ iterator: inout String.Iterator) -> Bool {
  guard let fst = next, isAsciiLetter(fst) || fst == "_" || fst == ":" else {
    return false
  }
  next = iterator.next()
  while let ch = next {
    guard isAsciiLetterOrDigit(ch) || ch == "_" || ch == "-" || ch == "." || ch == ":" else {
      return true
    }
    next = iterator.next()
  }
  return true
}

fileprivate func skipTagName(_ next: inout Character?,
                         _ iterator: inout String.Iterator) -> Bool {
  guard let fst = next, isAsciiLetter(fst) else {
    return false
  }
  next = iterator.next()
  while let ch = next {
    guard isAsciiLetterOrDigit(ch) || ch == "-" else {
      return true
    }
    next = iterator.next()
  }
  return true
}

fileprivate func skipWhitespace(_ next: inout Character?,
                                _ iterator: inout String.Iterator) -> Bool {
  guard let fst = next, isWhitespace(fst) else {
    return false
  }
  next = iterator.next()
  while let ch = next {
    guard isWhitespace(ch) else {
      return true
    }
    next = iterator.next()
  }
  return true
}

// Detect email addresses

fileprivate let emailRegExpr: NSRegularExpression =
  try! NSRegularExpression(pattern: #"^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9]"#
                                  + #"(?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9]"#
                                  + #"(?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"#)

public func isEmailAddress(_ str: String) -> Bool {
  return emailRegExpr.firstMatch(in: str,
                                 range: NSRange(location: 0, length: str.utf16.count)) != nil
}
