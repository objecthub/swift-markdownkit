//
//  KaTeXEngine.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 17/10/2026.
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
#if !os(watchOS)
import JavaScriptCore
#endif

///
/// The options for typesetting a formula with KaTeX (see ``KaTeXEngine``). They correspond to
/// the [options of KaTeX](https://katex.org/docs/options). Whatever the options say, KaTeX never
/// creates links or images for the commands `\href`, `\url` and `\includegraphics` (the
/// option `trust` is always `false`), and it ignores the Unicode characters it does not know
/// instead of printing warnings (`strict` is `ignore`).
///
public struct KaTeXOptions: Sendable, Hashable {

  /// The kinds of markup that KaTeX can create for a formula.
  public enum Output: String, Sendable, Equatable {
    /// HTML for a visual rendering. The web page needs the style sheet and fonts of KaTeX.
    case html
    /// MathML only, which browsers typeset without a style sheet or fonts of KaTeX. The MathML
    /// contains the LaTeX in an `annotation` element.
    case mathml
    /// HTML for a visual rendering and MathML for accessibility, which is the default of KaTeX.
    /// The web page needs the style sheet and fonts of KaTeX, which hides the MathML.
    case htmlAndMathml
  }

  /// The kind of markup that is created. The default is `htmlAndMathml`.
  public var output: Output

  /// Macros which formulas can use: a dictionary from the name of the command, for example
  /// `\R`, to its expansion, for example `\mathbb{R}`. The default is empty.
  public var macros: [String : String]

  /// The maximal number of macro expansions in a formula (which protects against macros that
  /// do not terminate). The default is 1000.
  public var maxExpand: Int

  /// The maximal size in `em` of the sizes that a formula specifies, for example for `\rule`.
  /// If `nil`, which is the default, the sizes are not limited.
  public var maxSize: Double?

  /// The minimal thickness in `em` of fraction lines, rules and similar items. If `nil`, which
  /// is the default, KaTeX uses its own default.
  public var minRuleThickness: Double?

  /// The maximal length of the LaTeX in bytes (UTF-8). A longer formula is rejected with
  /// `KaTeXError.tooLong` without being processed: the script engine cannot interrupt KaTeX
  /// once it is running. The default is 10,000.
  public var maxLength: Int

  /// Creates options. See the properties for the meaning of the parameters.
  public init(output: Output = .htmlAndMathml,
              macros: [String : String] = [:],
              maxExpand: Int = 1000,
              maxSize: Double? = nil,
              minRuleThickness: Double? = nil,
              maxLength: Int = 10_000) {
    self.output = output
    self.macros = macros
    self.maxExpand = maxExpand
    self.maxSize = maxSize
    self.minRuleThickness = minRuleThickness
    self.maxLength = maxLength
  }
}

///
/// The reasons why ``KaTeXEngine`` cannot typeset a formula.
///
public enum KaTeXError: Error, Equatable, LocalizedError, Sendable {
  
  /// KaTeX is not available: JavaScriptCore does not exist on this platform (watchOS), or
  /// the script of KaTeX could not be loaded.
  case unavailable
  
  /// The LaTeX is longer than the given number of bytes, see ``KaTeXOptions/maxLength``.
  case tooLong(Int)
  
  /// KaTeX does not understand the LaTeX. The parameter is its message, for example
  /// "KaTeX parse error: Undefined control sequence: \badcmd at position 1: …".
  case parse(String)
  
  /// The script engine reported an error that KaTeX does not create for invalid LaTeX, for
  /// example because the stack was exhausted. The parameter describes the error.
  case script(String)

  public var errorDescription: String? {
    switch self {
      case .unavailable:
        return "KaTeX is not available"
      case .tooLong(let maxLength):
        return "The formula is longer than \(maxLength) bytes"
      case .parse(let message):
        return message
      case .script(let message):
        return "KaTeX failed: \(message)"
    }
  }
}

#if !os(watchOS)

///
/// `KaTeXEngine` typesets LaTeX formulas with [KaTeX](https://katex.org), which runs in
/// JavaScriptCore. It creates HTML or MathML as a string; a web view or browser displays it.
/// KaTeX needs no document: translating a formula takes a fraction of a millisecond. The
/// engine is available on all platforms with JavaScriptCore (every platform but watchOS).
///
/// ``MathHtmlGenerator`` uses the engine to put typeset formulas into HTML. The HTML that KaTeX
/// creates needs the style sheet and the fonts of KaTeX (``stylesheetURL``) to be displayed,
/// unless it is MathML only.
///
/// An engine is thread-safe: calls from several threads are executed one after the other.
/// The shared instance loads the version of KaTeX that comes with MarkdownKit, ``bundledVersion``.
///
/// ```swift
/// let html = try KaTeXEngine.shared?.render("x^2 + y^2", display: false,
///                                            options: KaTeXOptions(output: .mathml))
/// ```
///
public final class KaTeXEngine: @unchecked Sendable {

  /// The version of KaTeX that comes with MarkdownKit.
  public static let bundledVersion = "0.16.22"

  /// The address of the style sheet that belongs to the bundled version of KaTeX. HTML which
  /// KaTeX creates is displayed correctly in a web page that links this style sheet, which
  /// loads the fonts of KaTeX from the same place.
  public static let stylesheetURL = URL(
    string: "https://cdn.jsdelivr.net/npm/katex@\(bundledVersion)/dist/katex.min.css")!

  /// The engine with the version of KaTeX that comes with MarkdownKit. It is `nil` if the
  /// script of KaTeX cannot be found or loaded. The script is loaded when this property is
  /// used for the first time.
  public static let shared: KaTeXEngine? = {
    guard let folder = Resources.katexFolder else {
      return nil
    }
    return KaTeXEngine(katexURL: folder.appendingPathComponent("katex.min.js"))
  }()

  /// The version of the loaded KaTeX.
  public let version: String

  private let lock = NSLock()
  private let context: JSContext
  private let function: JSValue

  /// The script which calls KaTeX. It reports invalid LaTeX as a result, not as an exception,
  /// and gets the LaTeX and the options as arguments, so that the LaTeX is never part of
  /// the source code that is evaluated.
  private static let glue = """
    function __mkRender(tex, optionsJSON) {
      try {
        return [true, katex.renderToString(tex, JSON.parse(optionsJSON))];
      } catch (e) {
        return [false, String((e && e.message) || e), String((e && e.name) || "")];
      }
    }
    """

  /// Creates an engine from the script `katex.min.js` (the UMD build) at the given URL. Returns
  /// `nil` if the script cannot be read or does not define KaTeX.
  public init?(katexURL: URL) {
    guard let context = JSContext(),
          let script = try? String(contentsOf: katexURL, encoding: .utf8) else {
      return nil
    }
    context.evaluateScript(script)
    guard let katex = context.objectForKeyedSubscript("katex"),
          katex.isObject,
          let version = katex.objectForKeyedSubscript("version"),
          version.isString,
          let versionString = version.toString() else {
      return nil
    }
    context.evaluateScript(Self.glue)
    guard let function = context.objectForKeyedSubscript("__mkRender"), function.isObject else {
      return nil
    }
    self.context = context
    self.function = function
    self.version = versionString
  }

  /// Typesets a formula and returns the markup.
  ///
  /// - Parameters:
  ///   - tex: The LaTeX of the formula, without dollar signs.
  ///   - display: True for display math, which is centered and uses larger operators; false
  ///              for a formula within a line of text.
  ///   - options: The options of KaTeX.
  /// - Returns: The markup, a `span` element with the class `katex` (or `katex-display`).
  /// - Throws: `KaTeXError.parse` if KaTeX does not understand the LaTeX, and other errors if
  ///           the formula is too long or the script engine fails.
  public func render(_ tex: String, display: Bool = false,
                     options: KaTeXOptions = KaTeXOptions()) throws -> String {
    guard tex.utf8.count <= options.maxLength else {
      throw KaTeXError.tooLong(options.maxLength)
    }
    var settings: [String : Any] = ["displayMode": display,
                                    "output": options.output.rawValue,
                                    "throwOnError": true,
                                    "strict": "ignore",
                                    "trust": false,
                                    "maxExpand": options.maxExpand,
                                    "macros": options.macros]
    if let maxSize = options.maxSize {
      settings["maxSize"] = maxSize
    }
    if let minRuleThickness = options.minRuleThickness {
      settings["minRuleThickness"] = minRuleThickness
    }
    guard let json = try? JSONSerialization.data(withJSONObject: settings),
          let optionsJSON = String(data: json, encoding: .utf8) else {
      throw KaTeXError.script("invalid options")
    }
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    // The result is converted to Swift values while the lock is held: a JSValue must not be
    // used by several threads at once.
    let result = self.function.call(withArguments: [tex, optionsJSON])?.toArray() ?? []
    guard let success = result.first as? Bool, result.count >= 2, let text = result[1] as? String else {
      throw KaTeXError.script("no result")
    }
    if success {
      return text
    }
    let name = result.count > 2 ? (result[2] as? String) ?? "" : ""
    throw name == "ParseError" ? KaTeXError.parse(text) : KaTeXError.script("\(name): \(text)")
  }
}

#else

///
/// `KaTeXEngine` typesets LaTeX formulas with KaTeX. It relies on JavaScriptCore, which is not
/// available on watchOS: there is no shared engine, and no engine can be created.
///
public final class KaTeXEngine: @unchecked Sendable {

  /// The version of KaTeX that comes with MarkdownKit.
  public static let bundledVersion = "0.16.22"

  /// The address of the style sheet that belongs to the bundled version of KaTeX.
  public static let stylesheetURL = URL(
    string: "https://cdn.jsdelivr.net/npm/katex@\(bundledVersion)/dist/katex.min.css")!

  /// There is no engine on watchOS.
  public static let shared: KaTeXEngine? = nil

  /// The version of the loaded KaTeX.
  public let version: String = KaTeXEngine.bundledVersion

  /// There is no engine on watchOS: this returns `nil`.
  public init?(katexURL: URL) {
    return nil
  }

  /// Always throws `KaTeXError.unavailable`.
  public func render(_ tex: String, display: Bool = false,
                     options: KaTeXOptions = KaTeXOptions()) throws -> String {
    throw KaTeXError.unavailable
  }
}

#endif
