# Security policy

## Reporting a vulnerability

If you've found a security issue in KeyPaste, please report it
privately rather than opening a public issue.

Preferred channel: open a private
[GitHub Security Advisory](https://github.com/colizej/keypaste/security/advisories/new).

Alternative: email `colizej` on GitHub via the address listed on
that profile.

Please include:

- macOS version and architecture (Intel / Apple Silicon)
- KeyPaste version (`KeyPaste.app/Contents/Info.plist`'s
  `CFBundleShortVersionString`)
- Reproduction steps
- What you observed and what you expected

I aim to acknowledge reports within **3 business days** and to
follow up with a triage outcome within **14 days**. Coordinated
disclosure is appreciated for anything more impactful than a typo
in a log line.

## Scope

The audit surface that matters most:

- The event tap (`EventTap.swift`) — anything that lets unrelated
  apps see keystrokes, or that lets KeyPaste forward keystrokes
  that should have been blocked by `IsSecureEventInputEnabled()`.
- The paste pipeline (`PasteStrategy.swift`) — anything that
  could leak the pasteboard snapshot, fail to restore the user's
  clipboard, or insert the wrong content.
- The trigger store (`TriggerStore.swift`) — anything that
  could lose user data on legacy migration, fail to write
  atomically, or write to a path the user didn't expect.
- The accessibility surface — anything that escalates the
  permissions KeyPaste actually needs.

Out of scope for now: cosmetic issues, denial-of-service that
requires injecting CGEvents (privileged anyway), and anything
specific to old / unsupported macOS versions.

## Privacy stance

- KeyPaste does not phone home. No telemetry, no analytics, no
  auto-update endpoint *(yet — Sparkle is on the roadmap and
  will be opt-in transparent when added)*.
- Trigger content is never logged.
- The clipboard is briefly modified during expansion (write our
  text → Cmd+V → restore original) and the snapshot is held in
  memory for `pasteRestoreDelay` (default 250 ms).
- All user data lives at
  `~/Library/Application Support/KeyPaste/`.
