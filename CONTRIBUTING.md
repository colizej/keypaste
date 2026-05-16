# Contributing to KeyPaste

Thanks for thinking about contributing! KeyPaste is a personal-scale
project — small, focused, and friendly to PRs. Read this once before
your first contribution.

## What you can help with

- **Bug reports** — file an issue with macOS version, KeyPaste
  version, reproduction steps, and what you expected vs got.
- **Feature ideas** — open a discussion first if the change is large.
  Small, focused PRs (one feature per PR) merge faster.
- **Snippet packs** — for now, packs are coded in
  [`app/Sources/KeyPaste/Storage/SnippetPacks.swift`](app/Sources/KeyPaste/Storage/SnippetPacks.swift).
  Add a new `SnippetPack` to `SnippetPacks.all`, then PR.
  A separate `keypaste-snippets` community repository is on the
  roadmap so packs can ship independently.
- **Docs** — README, comments, this file. PR straight to main.

## Dev setup

```bash
git clone https://github.com/colizej/keypaste.git
cd keypaste/app
./scripts/build-app.sh     # builds dist/KeyPaste.app
open dist/KeyPaste.app
```

Requires macOS 13+ and Xcode 14.2+ (Swift 5.7+).

Run the test suite before pushing:

```bash
swift test
```

## Code style

- Match the patterns already in the file you're touching.
- Default to writing **no comments**. Add one only when the
  *why* is non-obvious — a hidden constraint, a subtle invariant,
  a workaround for a specific bug.
- Don't log key contents. Ever. Even at debug level.
- Don't add telemetry or analytics.
- Don't introduce dependencies without discussion. The project has
  a deliberately tiny dependency surface.
- Tests for new behaviour are expected. Storage + engine code is
  well-covered; UI views aren't.

## Commit + PR

- Conventional-style prefixes are appreciated (`feat:`, `fix:`,
  `docs:`, `chore:`, `ci:`, `test:`, `refactor:`).
- Keep PRs focused — one feature or one fix per PR.
- Run `swift test` locally. CI runs the same suite on every PR.

## License agreement

By contributing, you agree your changes are licensed under
**AGPLv3** (same as the rest of the project) and that the "KeyPaste"
name and icon remain reserved trademarks of the project owner
(see [NOTICE.md](NOTICE.md)).
