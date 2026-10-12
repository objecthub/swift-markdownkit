//
//  MermaidError.swift
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

/// Errors thrown by `MermaidRenderer`.
public enum MermaidError: Error, Equatable, LocalizedError, Sendable {
  
  /// Diagrams cannot be rendered on this platform. Mermaid needs WebKit, which is only
  /// available on macOS and iOS.
  case unsupportedPlatform
  
  /// The resource `mermaid.min.js` could not be found or read.
  case resourcesMissing
  
  /// Mermaid rejected the diagram. The associated value is Mermaid's error message.
  case syntaxError(String)
  
  /// Rendering the diagram took longer than `MermaidConfig.timeout`.
  case timedOut
  
  /// The task which asked for the diagram was cancelled.
  case cancelled
  
  /// The web view could not render the diagram or create an image of it.
  case renderingFailed(String)

  public var errorDescription: String? {
    switch self {
      case .unsupportedPlatform:
        return "Mermaid diagrams are not supported on this platform"
      case .resourcesMissing:
        return "The Mermaid JavaScript resource is missing"
      case .syntaxError(let message):
        return "Invalid Mermaid diagram: \(message)"
      case .timedOut:
        return "Rendering the Mermaid diagram timed out"
      case .cancelled:
        return "Rendering the Mermaid diagram was cancelled"
      case .renderingFailed(let message):
        return "Rendering the Mermaid diagram failed: \(message)"
    }
  }

  /// A short, single-line description which is suitable for display below or above a
  /// diagram that could not be rendered.
  internal var summary: String {
    switch self {
      case .syntaxError(let message):
        let line = message.split(whereSeparator: \.isNewline).first.map(String.init) ?? message
        return line.count > 160 ? String(line.prefix(160)) + "…" : line
      default:
        return self.errorDescription ?? "unknown error"
    }
  }
}
