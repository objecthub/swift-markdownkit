//
//  ImageTestSupport.swift
//  MarkdownKitTests
//
//  Created by Matthias Zenger on 07/10/2026.
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

import AppKit
import Network
@testable import MarkdownKit

/// A minimal HTTP server on the loopback interface which records the requests it receives
/// and answers every request with a PNG image (or a CSS file for paths ending in `.css`).
/// The state which is changed concurrently is guarded by a lock; the port is set before the
/// server is used.
final class LoopbackImageServer: @unchecked Sendable {
  private let listener: NWListener
  private let queue = DispatchQueue(label: "LoopbackImageServer")
  private let lock = NSLock()
  private var recorded: [String] = []
  private(set) var port: UInt16 = 0
  private let png: Data

  init(png: Data) throws {
    let parameters = NWParameters.tcp
    parameters.requiredInterfaceType = .loopback
    self.listener = try NWListener(using: parameters, on: .any)
    self.png = png
  }

  var requests: [String] {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    return self.recorded
  }

  func start() throws {
    let ready = DispatchSemaphore(value: 0)
    self.listener.stateUpdateHandler = { state in
      if case .ready = state {
        ready.signal()
      }
    }
    self.listener.newConnectionHandler = { [weak self] connection in
      self?.handle(connection)
    }
    self.listener.start(queue: self.queue)
    guard ready.wait(timeout: .now() + 5) == .success, let port = self.listener.port?.rawValue else {
      throw NSError(domain: "LoopbackImageServer", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "server did not start"])
    }
    self.port = port
  }

  func stop() {
    self.listener.cancel()
  }

  private func handle(_ connection: NWConnection) {
    connection.start(queue: self.queue)
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, _, _ in
      guard let self = self else {
        connection.cancel()
        return
      }
      let request = String(decoding: data ?? Data(), as: UTF8.self)
      let line = request.components(separatedBy: "\r\n").first ?? ""
      self.lock.lock()
      self.recorded.append(line)
      self.lock.unlock()
      let path = line.split(separator: " ").dropFirst().first.map(String.init) ?? ""
      let (type, body): (String, Data) = path.hasSuffix(".css")
        ? ("text/css", Data("body { color: red }".utf8))
        : ("image/png", self.png)
      let header = "HTTP/1.1 200 OK\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n" +
                   "Connection: close\r\n\r\n"
      connection.send(content: Data(header.utf8) + body,
                      completion: .contentProcessed { _ in connection.cancel() })
    }
  }
}

func makeTestPNG() -> Data {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  for x in 0..<8 {
    for y in 0..<8 {
      rep.setColor(.red, atX: x, y: y)
    }
  }
  return rep.representation(using: .png, properties: [:])!
}

#endif
