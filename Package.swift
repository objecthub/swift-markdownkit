// swift-tools-version:5.5
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
//  Copyright © 2019-2026 Google LLC.
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
    .macOS(.v11),
    .iOS(.v15),
    .tvOS(.v15),
    .watchOS(.v8)
  ],
  products: [
    .library(
      name: "MarkdownKit",
      targets: ["MarkdownKit"]
    ),
    .executable(
      name: "MarkdownKitProcess",
      targets: ["MarkdownKitProcess"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/objecthub/swift-commandlinekit.git", branch: "master")
  ],
  targets: [
    .target(
      name: "MarkdownKit",
      dependencies: [
        .product(name: "CommandLineKit", package: "swift-commandlinekit")
      ],
      exclude: [
        "Info.plist",
        "Highlighter/LICENSE (highlight.js)"
      ],
      resources: [
        .copy("Highlighter/highlight.min.js"),
        .copy("Highlighter/Themes/a11y-dark.css"),
        .copy("Highlighter/Themes/a11y-light.css"),
        .copy("Highlighter/Themes/agate.css"),
        .copy("Highlighter/Themes/an-old-hope.css"),
        .copy("Highlighter/Themes/androidstudio.css"),
        .copy("Highlighter/Themes/arduino-light.css"),
        .copy("Highlighter/Themes/arta.css"),
        .copy("Highlighter/Themes/ascetic.css"),
        .copy("Highlighter/Themes/atelier-cave-dark.css"),
        .copy("Highlighter/Themes/atelier-cave-light.css"),
        .copy("Highlighter/Themes/atelier-dune-dark.css"),
        .copy("Highlighter/Themes/atelier-dune-light.css"),
        .copy("Highlighter/Themes/atelier-estuary-dark.css"),
        .copy("Highlighter/Themes/atelier-estuary-light.css"),
        .copy("Highlighter/Themes/atelier-forest-dark.css"),
        .copy("Highlighter/Themes/atelier-forest-light.css"),
        .copy("Highlighter/Themes/atelier-heath-dark.css"),
        .copy("Highlighter/Themes/atelier-heath-light.css"),
        .copy("Highlighter/Themes/atelier-lakeside-dark.css"),
        .copy("Highlighter/Themes/atelier-lakeside-light.css"),
        .copy("Highlighter/Themes/atelier-plateau-dark.css"),
        .copy("Highlighter/Themes/atelier-plateau-light.css"),
        .copy("Highlighter/Themes/atelier-savanna-dark.css"),
        .copy("Highlighter/Themes/atelier-savanna-light.css"),
        .copy("Highlighter/Themes/atelier-seaside-dark.css"),
        .copy("Highlighter/Themes/atelier-seaside-light.css"),
        .copy("Highlighter/Themes/atelier-sulphurpool-dark.css"),
        .copy("Highlighter/Themes/atelier-sulphurpool-light.css"),
        .copy("Highlighter/Themes/atom-one-dark-reasonable.css"),
        .copy("Highlighter/Themes/atom-one-dark.css"),
        .copy("Highlighter/Themes/atom-one-light.css"),
        .copy("Highlighter/Themes/brown-paper.css"),
        .copy("Highlighter/Themes/codepen-embed.css"),
        .copy("Highlighter/Themes/color-brewer.css"),
        .copy("Highlighter/Themes/darcula.css"),
        .copy("Highlighter/Themes/dark.css"),
        .copy("Highlighter/Themes/default.css"),
        .copy("Highlighter/Themes/docco.css"),
        .copy("Highlighter/Themes/dracula.css"),
        .copy("Highlighter/Themes/far.css"),
        .copy("Highlighter/Themes/foundation.css"),
        .copy("Highlighter/Themes/github-dark.css"),
        .copy("Highlighter/Themes/github-gist.css"),
        .copy("Highlighter/Themes/github.css"),
        .copy("Highlighter/Themes/gml.css"),
        .copy("Highlighter/Themes/googlecode.css"),
        .copy("Highlighter/Themes/gradient-light.css"),
        .copy("Highlighter/Themes/gradient-dark.css"),
        .copy("Highlighter/Themes/grayscale.css"),
        .copy("Highlighter/Themes/gruvbox-dark.css"),
        .copy("Highlighter/Themes/gruvbox-light.css"),
        .copy("Highlighter/Themes/hopscotch.css"),
        .copy("Highlighter/Themes/hybrid.css"),
        .copy("Highlighter/Themes/idea.css"),
        .copy("Highlighter/Themes/ir-black.css"),
        .copy("Highlighter/Themes/isbl-editor-dark.css"),
        .copy("Highlighter/Themes/isbl-editor-light.css"),
        .copy("Highlighter/Themes/kimbie-dark.css"),
        .copy("Highlighter/Themes/kimbie-light.css"),
        .copy("Highlighter/Themes/lightfair.css"),
        .copy("Highlighter/Themes/lioshi.css"),
        .copy("Highlighter/Themes/magula.css"),
        .copy("Highlighter/Themes/markdownkit.css"),
        .copy("Highlighter/Themes/markdownkit-dark.css"),
        .copy("Highlighter/Themes/mono-blue.css"),
        .copy("Highlighter/Themes/monokai-sublime.css"),
        .copy("Highlighter/Themes/monokai.css"),
        .copy("Highlighter/Themes/night-owl.css"),
        .copy("Highlighter/Themes/nnfx-light.css"),
        .copy("Highlighter/Themes/nnfx-dark.css"),
        .copy("Highlighter/Themes/nord.css"),
        .copy("Highlighter/Themes/obsidian.css"),
        .copy("Highlighter/Themes/ocean.css"),
        .copy("Highlighter/Themes/paraiso-dark.css"),
        .copy("Highlighter/Themes/paraiso-light.css"),
        .copy("Highlighter/Themes/pojoaque.css"),
        .copy("Highlighter/Themes/purebasic.css"),
        .copy("Highlighter/Themes/qtcreator_dark.css"),
        .copy("Highlighter/Themes/qtcreator_light.css"),
        .copy("Highlighter/Themes/railscasts.css"),
        .copy("Highlighter/Themes/rainbow.css"),
        .copy("Highlighter/Themes/routeros.css"),
        .copy("Highlighter/Themes/school-book.css"),
        .copy("Highlighter/Themes/shades-of-purple.css"),
        .copy("Highlighter/Themes/solarized-dark.css"),
        .copy("Highlighter/Themes/solarized-light.css"),
        .copy("Highlighter/Themes/srcery.css"),
        .copy("Highlighter/Themes/stackoverflow-light.css"),
        .copy("Highlighter/Themes/stackoverflow-dark.css"),
        .copy("Highlighter/Themes/sunburst.css"),
        .copy("Highlighter/Themes/tomorrow-night-blue.css"),
        .copy("Highlighter/Themes/tomorrow-night-bright.css"),
        .copy("Highlighter/Themes/tomorrow-night-eighties.css"),
        .copy("Highlighter/Themes/tomorrow-night.css"),
        .copy("Highlighter/Themes/tomorrow.css"),
        .copy("Highlighter/Themes/vs.css"),
        .copy("Highlighter/Themes/vs2015.css"),
        .copy("Highlighter/Themes/xcode.css"),
        .copy("Highlighter/Themes/xcode-dusk.css"),
        .copy("Highlighter/Themes/xt256.css"),
        .copy("Highlighter/Themes/zenburn.css"),
        .copy("Highlighter/Themes/snazzy.css"),
        .copy("Highlighter/Themes/silk-light.css"),
        .copy("Highlighter/Themes/silk-dark.css"),
        .copy("Highlighter/Themes/vulcan.css")
      ]
    ),
    .executableTarget(
      name: "MarkdownKitProcess",
      dependencies: [
        "MarkdownKit",
        .product(name: "CommandLineKit", package: "swift-commandlinekit")
      ],
      exclude: []
    ),
    .testTarget(
      name: "MarkdownKitTests",
      dependencies: ["MarkdownKit"],
      exclude: ["Info.plist"]
    )
  ],
  swiftLanguageVersions: [.v5]
)
