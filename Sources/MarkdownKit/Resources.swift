//
//  Resources.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 12/10/2026.
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

///
/// Gives access to the resources that ship with this package: `highlight.min.js` and the
/// highlighting themes (see `SyntaxHighlighter`), `mermaid.min.js` (see `MermaidRenderer`) and
/// the folder `KaTeX` with `katex.min.js` (see `KaTeXEngine`), `katex.min.css` and the fonts (see
/// `MathRenderer`).
///
enum Resources {

  /// The folder `KaTeX` of the resources, or `nil` if it cannot be found. (The lookup by the name
  /// of a folder is not reliable in the resource bundles of SwiftPM, hence the path is built.)
  static var katexFolder: URL? {
    guard let folder = Resources.bundle?.resourceURL?.appendingPathComponent("KaTeX", isDirectory: true),
          FileManager.default.fileExists(atPath: folder.appendingPathComponent("katex.min.js").path) else {
      return nil
    }
    return folder
  }

  /// Only used to find the bundle of this module via `Bundle(for:)`.
  private final class BundleToken {}

  /// Locates the bundle containing this package's resources.
  ///
  /// `Bundle.module`, SwiftPM's generated accessor, assumes the resource bundle
  /// ships right next to the compiled binary under a fixed name and calls
  /// `fatalError` if it isn't found there — which is unrecoverable. That
  /// assumption breaks whenever this package is resolved through SwiftPM (which
  /// sets `SWIFT_PACKAGE` and is what selects `Bundle.module` in the first
  /// place) but then repackaged by a tool that doesn't preserve loose resource
  /// bundles, e.g. Carthage producing an xcframework from a project that
  /// depends on MarkdownKit via Xcode's own Package Dependencies. To stay
  /// usable in that case, this searches the same candidate locations
  /// `Bundle.module` would, then falls back to treating resources as having
  /// been copied directly into the consuming target/framework (no nested
  /// bundle at all), instead of crashing the host app.
  static nonisolated let bundle: Bundle? = {
  #if SWIFT_PACKAGE
    let bundleName = "MarkdownKit_MarkdownKit"
    let overrides: [URL]
    #if DEBUG
      // The 'PACKAGE_RESOURCE_BUNDLE_PATH' name is preferred since the expected value
      // is a path. The check for 'PACKAGE_RESOURCE_BUNDLE_URL' will be removed when all
      // clients have switched over. This removal is tracked by rdar://107766372.
      if let override = ProcessInfo.processInfo.environment["PACKAGE_RESOURCE_BUNDLE_PATH"]
                     ?? ProcessInfo.processInfo.environment["PACKAGE_RESOURCE_BUNDLE_URL"] {
        overrides = [URL(fileURLWithPath: override)]
      } else {
        overrides = []
      }
    #else
      overrides = []
    #endif
    let candidates = overrides + [
      // Bundle should be present here when the package is linked into an App.
      Bundle.main.resourceURL,
      // Bundle should be present here when the package is linked into a framework.
      Bundle(for: BundleToken.self).resourceURL,
      // For command-line tools.
      Bundle.main.bundleURL,
    ]
    for candidate in candidates {
      let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
      if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
        return bundle
      }
    }
    return Bundle(identifier: "net.objecthub.MarkdownKit")
  #else
    return Bundle(for: BundleToken.self)
  #endif
  }()
}
