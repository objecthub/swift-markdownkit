# Changelog

## 1.1.9 (2024-08-04)

- Support converting Markdown into a string without any markup

## 1.1.8 (2024-05-01)
- Fix `Color.hexString` on iOS to handle black correctly
- Clean up `Package.swift`
- Updated `CHANGELOG`

## 1.1.7 (2023-04-10)
- Fix handling of copyright sign when escaped as XML named character

## 1.1.6 (2023-04-10)
- Migrate framework to Xcode 14
- Fix tests related to images in attributed strings

## 1.1.5 (2022-02-27)
- Bug fixes to make `AttributedStringGenerator` work with images.

## 1.1.4 (2022-02-27)
- Allow customization of image sizes in the `AttributedStringGenerator`
- Support relative image links in the `AttributedStringGenerator`

## 1.1.3 (2022-02-07)
- Fix build breakage for Linux
- Encode predefined XML entities also for code blocks
- Migrate framework to Xcode 13

## 1.1.2 (2021-06-30)
- Allow creation of definition lists outside of MarkdownKit

## 1.1.0 (2021-05-12)
- Make abstract syntax trees extensible
- Provide a simple means to define new types of emphasis
- Document support for definition lists via `ExtendedMarkdownParser`
- Migrate framework to Xcode 12.5

## 1.0.4 (2021-02-15)
- Support Linux
- Fix handling of XML/HTML entities/named character references
- Escape angle brackets in HTML output
- Migrate project to Xcode 12.4

## 1.0.3 (2021-02-03)
- Make framework available to iOS

## 1.0.2 (2020-10-04)
- Improved extensibility of `AttributedStringGenerator` class

## 1.0.1 (2020-10-04)
- Ported to Swift 5.3
- Migrated project to Xcode 12.0

## 1.0 (2020-07-18)
- Implemented support for Markdown tables
- Made it easier to extend class `MarkdownParser`
- Included extended markdown parser `ExtendedMarkdownParser`

## 0.2.2 (2020-01-26)
- Fixed bug in AttributedStringGenerator.swift
- Migrated project to Xcode 11.3.1

## 0.2.1 (2019-12-28)
- Simplified extension/usage of NSAttributedString generator
- Migrated project to Xcode 11.3

## 0.2 (2019-10-19)
- Implemented support for backslash escaping
- Added support for using link reference definitions; not fully CommonMark-compliant yet
- Migrated project to Xcode 11.1

## 0.1 (2019-08-17)
- Initial version
