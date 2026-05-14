# KeyPaste — macOS app

Pure Swift, SwiftPM, single executable.

## Build

```bash
swift build              # debug
swift build -c release   # release
swift run KeyPaste       # build and launch
swift test               # run unit tests
```

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ (Command Line Tools or Xcode)
- Accessibility permission (granted on first launch)

## Layout

```
Sources/KeyPaste/
├── App.swift           Entry point
├── Logger.swift        os_log wrapper
├── Engine/             Trigger model, matcher, template renderer
├── Storage/            Atomic JSON file + future iCloud sync
├── System/             CGEventTap, status bar, paste strategy
└── UI/                 SwiftUI views

Tests/KeyPasteTests/    XCTest target
```
