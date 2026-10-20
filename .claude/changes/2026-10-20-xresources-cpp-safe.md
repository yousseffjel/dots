# xresources-cpp-safe
Date: 2026-10-20
Files: 3 | Lines: +61/-1

## What changed
- `config/theme/templates/always/xresources.dcol`: the nsxiv comment line
  "Void's package" now reads "the Void package".
- New `tests/xresources-cpp-safe.sh`. It checks the template body (line 1 is
  the target|command header, never rendered) for `'` and `/*`. When cpp is
  installed it also runs `cpp -P` over the body and fails on any stderr.
- `CHANGELOG.md` [Unreleased] Fixed: one line.

## Why
On the Void VM, every `dots theme` and wallpaper change printed
`xresources:17:65: warning: missing terminating ' character`. xrdb runs cpp
over the merged file, comments included. The 2026-10-19 nsxiv-package edit
put an apostrophe in a `!` comment. docs/THEMING.md already forbids `'` and
`/*` in xresources.dcol, but only the xcursor output had a test
(tests/cursor-x11.sh), so the template itself was unguarded.

## Assumptions
- Type C: `cpp -P` stands in for xrdb's own preprocessing, as the test
  pattern (a real tool when present, a grep otherwise) does elsewhere in the
  suite.

## Test coverage
- The new test passes. Against the old template it fails with the VM's exact
  message (`body:17:65: warning: missing terminating ' character`) from both
  the grep and cpp.
- Full suite: 98 OK, exit 0. Lint passes. Reviewer READY.
- On the VM, a `theme-apply.sh dark` from a copy with the fixed template
  printed no warning, xrdb merged, and 6 `dwm.*` resources were loaded.

## Follow-ups
- none
