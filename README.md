# KeyPaste

A lightweight macOS text expander with templates and a community snippet library.

> 🚧 **Status: early development.** Swift rewrite in progress. The previous Rust+Swift
> hybrid lives in the [keypaste-rust-legacy](https://github.com/colizej/keypaste-rust-legacy)
> repository (archived).

## What it does

Type a short trigger like `email` or `sig` — KeyPaste replaces it with a longer
snippet, optionally filled with templates: clipboard contents, the current date,
your username, and more.

## Roadmap

- **Sprint 1** — Swift MVP: trigger engine, status bar, SwiftUI editor.
- **Sprint 2** — Landing page on `keypaste.dramius.com`, downloadable `.dmg`.
- **Sprint 3** — iCloud sync, Sparkle auto-updates.
- **Sprint 4** — Community snippet packs (Django API).
- **Sprint 5** — Code signing, notarization, public launch.

## Repository layout

```
app/    Swift application (SwiftPM)
web/    Landing page (static)
api/    Django API for community packs
docs/   Public documentation
```

## License

MIT — see [LICENSE](LICENSE).
