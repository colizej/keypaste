# Changelog

All notable changes to KeyPaste are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/) and the
versions follow [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.0] — 2026-05-16

First public release. Native Swift rewrite of the legacy Rust + Swift
hybrid, packaged as an ad-hoc-signed `.app` bundle.

### Added

- **Instant-fire engine** — expansion happens the moment the typed
  buffer matches a trigger string. No boundary key needed.
- **Status-bar menu** with Edit Triggers… / Pause / Open Triggers
  Folder / Import / Export / Statistics… / Settings… / Quit.
- **SwiftUI trigger editor** — list with search (⌘F), add (⌘N),
  delete (⌘⌫), save (⌘↩), and a live preview that renders the same
  Template pass as production.
- **Template tokens** — `{{clipboard}}`, `{{name}}`, `{{date}}`,
  `{{date:long}}`, `{{date:iso}}`, `{{date:+1d}}` / `{{date:-2w}}`
  (relative offset, days/weeks/months/years), `{{date:yyyy-MM}}`
  (custom DateFormatter pattern), `{{time}}`, `{{datetime}}`,
  `{{weekday}}`, `{{uuid}}`.
- **`{{cursor}}`** — caret lands at the token's position after the
  paste completes.
- **`{{enter}}` and `{{tab}}`** — keys posted after the paste settles.
  Use case: `password{{enter}}` for auto-submission.
- **Per-app scope** — `Trigger.scope` filter; the matcher only fires
  triggers whose scope matches the frontmost bundle ID. UI picker in
  the editor lists every running app + the saved scope even when its
  app isn't currently running.
- **Snippet packs** — Settings → Snippet Packs installs Dates & Times,
  Identifiers, SQL, Python, HTML & Markdown, and Lorem Ipsum
  packs. Duplicate triggers are skipped, never overwritten.
- **Statistics window** — per-trigger fire counter, last-fired
  relative time, total fires, with a confirmable Reset.
- **Import / Export** of triggers via JSON (NSSavePanel/NSOpenPanel),
  tolerant decoder accepts v2 TriggerFile, bare `[Trigger]` array,
  and legacy v1 (one-shot migration from the old Rust + Swift app).
- **Pause toggle** — menu-bar dot goes from filled circle to hollow
  outline; engine short-circuits all key events while paused.
- **Settings** — Launch at login (via `SMAppService.mainApp`),
  clipboard restore delay slider (50–1000 ms).
- **Secure-input handling** — `IsSecureEventInputEnabled()` polling on
  every key event; engine flushes and short-circuits while true.
- **Legacy v1 migration** — first launch with the old Rust + Swift
  KeyPaste's `triggers.json` auto-migrates to v2 schema with a
  byte-identical `.bak` safety copy.
- **Ad-hoc codesign** with stable bundle identifier
  `com.dramius.keypaste` so TCC Accessibility grants survive rebuilds.
- **AGPLv3 license** and trademark reservation on the "KeyPaste" name
  and icon — see `NOTICE.md`.

### Tests

127 tests cover storage (atomic writes, legacy migration, ULID
generator, export/import, stats), engine (buffer, matcher, template
parser, instant-fire flow, pause), and system layer (event-tap
classification, paste-strategy contract, snippet pack installation).

### Known limitations

- **Not notarized.** First launch on another Mac shows
  *"can't be opened because it is from an unidentified developer."*
  Right-click → Open works around it for now. Apple Developer ID
  notarization is on the v1.0 roadmap.
- **`{{cursor}}` timing** — uses a 150 ms post-paste delay to wait for
  the Cmd+V to land. Works for AppKit / WebKit / most Electron apps
  on Intel and Apple Silicon Macs; if your specific app misbehaves,
  the delay is in [`SystemPasteStrategy.performExpand`](app/Sources/KeyPaste/System/PasteStrategy.swift).
- **No sync.** Triggers live in `~/Library/Application Support/KeyPaste/`
  on a single Mac. iCloud KVS sync is a possible later addition.

[Unreleased]: https://github.com/colizej/keypaste/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/colizej/keypaste/releases/tag/v0.1.0
