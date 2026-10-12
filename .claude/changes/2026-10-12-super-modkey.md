# super-modkey
Date: 2026-10-12
Files: 36 | Lines: +~680/-149

## What changed
- `suckless/dwm/config.def.h`: `#define MODKEY Mod4Mask` (was `Mod1Mask`).
  Every dwm binding is now on Super. The three chords already spelled
  `Mod4Mask` (powermenu, clipmenu, dropterm) are unchanged: they equal MODKEY
  now and still match their vendored diffs.
- `config/sxhkd/sxhkdrc`: the four chords that would otherwise be grabbed twice
  moved — firefox `super + shift + b`, lock `super + Escape`, monitor menu
  `super + shift + d`, emoji `super + semicolon`. The stale
  "checked free in both grabbers" comments were replaced by a pointer to the
  new test.
- New `tests/key-collisions.sh`: parses `keys[]` (MODKEY taken from its
  `#define`, TAGKEYS expanded to its four chords) and every sxhkdrc chord, then
  fails when the two sets share a chord. A planted overlap proves the check
  itself, and a parser failure aborts loudly rather than reading as "no
  chords".
- New `scripts/install-suckless-headers.sh`, sourced by `install-suckless.sh`
  and called before `make` for each program. A generated `config.h` /
  `blocks.h` that matches some past committed `*.def.h` is moved to
  `<name>.pre-<timestamp>` and regenerated. An edited one is kept, and the
  build prints the `diff -u` to merge by. Without git it is kept, and the build
  says why. `--dry-run` renames nothing. New `tests/suckless-headers.sh`.
- Docs: KEYBINDINGS.md (modifier section, moved rows, the "delete config.h"
  note), `dwm-keys` shows Mod as Super, `dwm.1` man page Mod1 -> Mod4,
  PATCHES.md (Super+minus; the shared key space), the dwm.c dropterm comment and
  its `dwm-dropterm-20261007-local.diff` record (rule 5), plus every live
  reference to the moved keys: dwm-lock, dwm-powermenu, dwm-display, autorandr
  hook, desktop.lst consequence text, install-session-report-applets.sh,
  THEMING.md, TESTING.md, ROADMAP.md, CLAUDE.md.
- Tests: the dwm-runtime Xvfb libs press `super+…`, and `dwm-keys.sh` expects
  Super and maps `semicolon`.
- CHANGELOG `[Unreleased]` -> Changed (two entries).

## Why
User request: "switch from alt to super key". Their follow-up note was that
every keybinding should use Super. Since dwm's MODKEY and sxhkd now share one
key namespace, and a double grab dies silently, the overlap check became a
test instead of a comment. Each Makefile generates `config.h` only when it is
absent, so without the header refresh an existing install (the VM included)
would rebuild and quietly keep Alt.

## Assumptions
- Type A, asked: sxhkd's keys move, not dwm's (user picked option 1). Existing
  installs are refreshed at build time, not through a 0.3.0 release and
  migration (user picked "Build-time refresh").
- Type B: the replacement chords themselves (Super+Shift+b, Super+Escape,
  Super+Shift+d, Super+;), as previewed to the user and accepted.
  Alternative: Super+Shift+l for lock. If wrong: sxhkdrc plus KEYBINDINGS.md.
- Type B: the header-refresh rule duplicates `matches_history` from the
  0.1.0 -> 0.2.0 migration instead of sharing it. The migration has shipped,
  and its test copies that file alone. If wrong: extract a lib and update both.
- Type C: the backup is named `.pre-<timestamp>` (the migration used
  `.pre-0.2.0`). Builds have no version to name a backup after.

## Test coverage
- `tests/run-tests.sh`: 52/52 OK (50 + the two new tests). `tests/lint.sh`
  clean (shellcheck, shfmt, markdownlint).
- `tests/dwm-runtime.sh` was run against a real dwm built from this tree under
  Xvfb: every section passed with `super+` key presses.
- `tests/build.sh` builds all five programs.
- Mutations on copies: always-refresh, dry-run ignored, the call unwired,
  first-def-only and the no-git branch removed (5/5 caught). On the collision
  test, an Alt MODKEY reads as disjoint and putting super+l back is caught.
- Not tested: the VM. After merging, `dots update` there should print
  `refresh suckless/dwm/config.h`, and Super should then drive dwm after
  logging out and back in.
- Reviewer: WARN (dwm.1 + dwm.c comment), then WARN (PATCHES.md ownership
  note), then READY.

## Follow-ups
- ly login-screen theming: next slot (`ly-theme`), decisions already taken.
- tmux's Alt bindings now reach tmux for the first time. Worth checking on the
  VM that nothing in them surprises.
