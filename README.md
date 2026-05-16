# KeyPaste

A native macOS text expander. Type a short trigger anywhere — KeyPaste replaces
it with a longer snippet, optionally filled with live data: clipboard, date,
fresh UUID, custom cursor position, post-paste keys.

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/macOS-13%2B-lightgrey.svg)](#requirements)
[![Built with Swift](https://img.shields.io/badge/Swift-5.7%2B-orange.svg)](#build-from-source)
[![Tests](https://img.shields.io/badge/tests-127%20passing-brightgreen.svg)](#tests)

<p align="center">
  <img src="docs/screenshots/menu.png" alt="KeyPaste menu-bar dropdown" width="380">
</p>

| Trigger editor | Edit a trigger |
|---|---|
| <img src="docs/screenshots/edit_triggers.png" alt="Trigger list" width="420"> | <img src="docs/screenshots/edit_triggers_item.png" alt="Trigger editor with preview" width="420"> |

| Settings | Statistics |
|---|---|
| <img src="docs/screenshots/settings.png" alt="Settings" width="420"> | <img src="docs/screenshots/statistics.png" alt="Statistics" width="420"> |

## Features

- **Instant fire** — expansion the moment your typed buffer matches a trigger.
- **Templates** — `{{clipboard}}`, `{{date}}`, `{{time}}`, `{{uuid}}`,
  `{{name}}`, `{{datetime}}`, `{{weekday}}`, relative dates (`{{date:+1d}}`),
  custom formats (`{{date:yyyy-MM}}`).
- **Cursor placement** — `{{cursor}}` parks the caret in multi-line snippets.
- **Post-paste keys** — `{{enter}}` and `{{tab}}` press Return/Tab after the
  paste lands. Useful for `password{{enter}}` or form fields.
- **Per-app scope** — bind a trigger to a single app (`;addr` → work address
  in Mail, home in Messages).
- **Snippet packs** — one-click installs: Dates & Times, Identifiers,
  SQL skeletons, Python, HTML/Markdown, Lorem Ipsum.
- **Fire statistics** — per-trigger counts and last-fired timestamps.
- **Import / export** — lossless JSON round-trip.
- **Pause toggle** — menu-bar dot is filled when running, hollow when paused.

## Quick start

1. Download `KeyPaste.dmg` from the
   [latest release](https://github.com/colizej/keypaste/releases/latest),
   open it, drag `KeyPaste.app` to `/Applications`, launch it.
2. First launch shows *"KeyPaste can't be opened because it is from an
   unidentified developer"* (KeyPaste isn't notarized — Apple Developer ID
   coming in v1.0). Right-click → **Open** → confirm. One-time.
3. **System Settings → Privacy & Security → Accessibility** → enable
   `KeyPaste` → quit and relaunch.
4. Click the menu-bar icon → **Edit Triggers… (⌘N)** → create your first
   trigger.

> Trigger names that are prefixes of common words fire mid-word — prefix
> yours with `;` (e.g. `;email`) so they don't trigger inside `emailing`.

## Template tokens

| Token | Replaces with | Example |
|---|---|---|
| `{{clipboard}}` | Clipboard text | `https://example.com` |
| `{{name}}` | macOS user short name | `colizej` |
| `{{date}}` | `yyyy-MM-dd` | `2026-05-16` |
| `{{date:long}}` | Long format | `May 16, 2026` |
| `{{date:iso}}` | ISO 8601 | `2026-05-16T19:30:00Z` |
| `{{date:+1d}}` | `+/-N` `d`/`w`/`m`/`y` offset | `2026-05-17` |
| `{{date:yyyy-MM}}` | Custom DateFormatter pattern | `2026-05` |
| `{{time}}` | `HH:mm` | `19:30` |
| `{{datetime}}` | Date + time | `2026-05-16 19:30` |
| `{{weekday}}` | Day name | `Saturday` |
| `{{uuid}}` | Fresh UUID v4 | `5C8B9...` |
| `{{cursor}}` | Caret lands here after paste | *(invisible)* |
| `{{enter}}` / `{{tab}}` | Press Return/Tab after paste | *(invisible)* |

Multi-line letter with cursor placement:

```
Hi {{cursor}},

Best regards,
{{name}}
```

Auto-submit a password:

```
mySecret123{{enter}}
```

## Per-app scope

In the trigger editor, the **Scope** dropdown limits a trigger to a single
application. Two triggers with the same key, different scopes, route by the
focused app:

| Trigger | Scope | Content |
|---|---|---|
| `;addr` | `com.apple.mail` | `Acme Inc, 1 Main St, …` |
| `;addr` | `com.apple.MobileSMS` | `Home: 42 Garden Ln` |

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌘N` | New trigger |
| `⌘F` | Focus search field |
| `⌘⌫` | Delete selected trigger |
| `⌘↩` | Save current trigger |
| `⌘,` | Open Settings |
| `⌘Q` | Quit |

## Privacy

KeyPaste runs entirely on your Mac. Triggers and stats live as plain JSON in
`~/Library/Application Support/KeyPaste/`. There is no network activity, no
telemetry, no account. The engine drops events while macOS reports a focused
secure input (password fields, sudo, lock screen). Clipboard is briefly used
to deliver the paste and restored after a short delay.

## Requirements

macOS 13 Ventura or later. Intel and Apple Silicon both supported.

## Build from source

```bash
git clone https://github.com/colizej/keypaste.git
cd keypaste/app
./scripts/build-app.sh
open dist/KeyPaste.app
```

Needs Xcode 14.2+ (Swift 5.7+).

### Tests

```bash
swift test
```

127 tests across storage, engine, system, and template layers.

## Contributing

PRs welcome for code, snippet packs, bug reports, and docs. See
[CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through
[SECURITY.md](SECURITY.md).

Snippet packs currently live in
[`app/Sources/KeyPaste/Storage/SnippetPacks.swift`](app/Sources/KeyPaste/Storage/SnippetPacks.swift).
A separate `keypaste-snippets` community repo is on the roadmap.

## Roadmap

- **v0.1** — Native engine, templates, per-app scope, packs, stats,
  import/export. *(shipped)*
- **v0.2** — Sparkle auto-update.
- **v0.3** — `{{selection}}` token via Accessibility API.
- **v0.4** — Community snippet library (browse and install from the app).
- **v1.0** — Apple Developer ID + notarization.

## License & brand

Source: **GNU Affero General Public License v3.0 or later** (AGPL-3.0-or-later).
See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).

The **"KeyPaste" name and icon** are reserved trademarks. Forks must rename
before redistribution.

## Credits

Built by [Colin Joseph](https://github.com/colizej). The previous Rust + Swift
hybrid lives, archived, at
[keypaste-rust-legacy](https://github.com/colizej/keypaste-rust-legacy).
Inspired by atext, TextExpander, and Espanso.
