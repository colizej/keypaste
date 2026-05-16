---
name: Bug report
about: KeyPaste did the wrong thing
title: "[bug] "
labels: bug
---

### What happened

<!-- One sentence summary. -->

### To reproduce

1.
2.
3.

### Expected

<!-- What you thought would happen. -->

### Actual

<!-- What did happen. -->

### Environment

- macOS version: (e.g. 13.7.8)
- Architecture: (Intel / Apple Silicon)
- KeyPaste version: (Info.plist's `CFBundleShortVersionString`, or `dev` if built locally)
- Host app where it misbehaved (e.g. Notes, TextEdit, Claude desktop, Telegram, …):

### Logs (optional but very helpful)

Capture KeyPaste's structured logs while reproducing:

```bash
log stream --predicate 'subsystem == "com.dramius.keypaste"' --info
```

Paste the relevant lines here. **Don't paste the actual content of
your triggers** — Logger never writes them, but if you've worked
around that, please scrub before posting.
