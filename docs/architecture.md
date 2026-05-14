# Architecture

> This document describes the high-level design of KeyPaste. For local
> development setup, see `.local/DEV-SETUP.md` (not in the public repo).

## Overview

KeyPaste is a single Swift application running on macOS. Unlike the previous
Rust+Swift hybrid (see [keypaste-rust-legacy](https://github.com/colizej/keypaste-rust-legacy)),
the new version runs entirely in one process. There is no IPC, no separate
keyproxy/tray binaries, and no Unix domain sockets.

## Components

```
┌─────────────────────────────────────────────────┐
│  KeyPaste.app  (single Swift process)           │
│                                                 │
│  ┌───────────────┐    ┌────────────────────┐    │
│  │ System layer  │    │ Engine             │    │
│  │ CGEventTap    │───▶│ Buffer + Matcher   │    │
│  │ Status bar    │    │ Template renderer  │    │
│  │ IME-safe      │    │                    │    │
│  │ paste         │◀───│                    │    │
│  └───────────────┘    └────────────────────┘    │
│         ▲                       ▲               │
│         │                       │               │
│  ┌──────┴───────┐    ┌──────────┴──────────┐    │
│  │ UI (SwiftUI) │    │ Storage             │    │
│  │ Settings     │    │ JSON file + iCloud  │    │
│  │ Editor       │    │ KVS (sync, future)  │    │
│  └──────────────┘    └─────────────────────┘    │
└─────────────────────────────────────────────────┘
                       │
                       │ HTTPS (read-only, no auth)
                       ▼
              keypaste.dramius.com/api/v1
                  (community packs)
```

## Module responsibilities

- **`System/`** — global keyboard event tap (CGEventTap), status bar item,
  paste strategy (IME-safe, falls back to clipboard+Cmd-V if direct typing
  fails).
- **`Engine/`** — input buffer with boundary reset (space, return, Esc, app
  switch), trigger matcher (Aho-Corasick for O(1) per key), template renderer
  (`{{clipboard}}`, `{{date}}`, `{{name}}`).
- **`Storage/`** — local `triggers.json` (atomic writes), optional iCloud
  Key-Value Store sync, schema versioning + migration.
- **`UI/`** — SwiftUI windows: trigger list, editor, settings, community
  pack browser.

## Trigger format (v2 schema)

```json
{
  "schema_version": 2,
  "updated_at": "2026-01-15T10:30:00Z",
  "triggers": [
    {
      "id": "01HJ8X9...",
      "trigger": "email",
      "content": "user@example.com",
      "title": "Personal email",
      "scope": null,
      "created_at": "2026-01-15T10:30:00Z",
      "updated_at": "2026-01-15T10:30:00Z"
    }
  ]
}
```

Differences from legacy v1:
- `id` is now a ULID (sortable) instead of a millisecond timestamp.
- `scope` (nullable) reserved for future app-specific triggers.
- File has `schema_version` at the top level — migrations are explicit.

## Privacy

- KeyPaste **never logs key contents**, even at debug level. Only event
  metadata (timestamps, modifier flags) is logged.
- The application checks `IsSecureEventInputEnabled()` and pauses the input
  buffer when a password field is focused.
- No telemetry. No analytics. No remote crash reporting unless the user opts
  in (and even then, only for explicit "Send report" actions).

## Distribution

- DTC only (Mac App Store sandbox forbids global event taps).
- Signed with a Developer ID certificate, notarized by Apple.
- Auto-updates via Sparkle, EdDSA-signed, appcast hosted on
  `keypaste.dramius.com/releases/`.
