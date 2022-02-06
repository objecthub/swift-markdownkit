// swift-tools-version:5.4
//
//  Package.swift
//  MarkdownKit
//
//  Build targets by calling the Swift Package Manager in the following way for debug purposes:
//  `swift build`
//
//  A release can be built with these options:
//  `swift build -c release`
//
//  The tests can be executed via:
//  `swift test`
//
//  Created by Matthias Zenger on 09/08/2019.
//  Copyright © 2019-2022 Google LLC.
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

import PackageDescription

let package = Package(
  name: "MarkdownKit",
  platforms: [
    .macOS(.v10_12),
    .iOS(.v13)
  ],
  products: [
    .library(name: "MarkdownKit", targets: ["MarkdownKit"]),
    .executable(name: "MarkdownKitProcess", targets: ["MarkdownKitProcess"])
  ],
  dependencies: [
  ],
  targets: [
    .target(name: "MarkdownKit",
            dependencies: [],
            exclude: ["Info.plist"]),
    .executableTarget(name: "MarkdownKitProcess",
                      dependencies: ["MarkdownKit"],
                      exclude: []),
    .testTarget(name: "MarkdownKitTests",
                dependencies: ["MarkdownKit"],
                exclude: ["Info.plist"])
  ],
  swiftLanguageVersions: [.v5]
)
