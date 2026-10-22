# scratchpad-tag-leave
Date: 2026-10-22
Files: 7 | Lines: +142/-17 (code + docs; plus this log)

## What changed
- `scratchpad_leave()` (dwm.c), called by `tag()` and `toggletag()`: a
  Super+s set member given a tag (`Super+Shift+<N>`, `Super+Ctrl+Shift+<N>`,
  `Super` + a tag-bar click) leaves the set and is tiled: `isfloating` set to
  `isfixed`, as `manage()` does, or `oldstate` while fullscreen. Others are
  untouched (the dropterm is never a member).
- `dwm-scratchpadgroup-20261022-local.diff` regenerated against the same
  base. Method, recorded in PATCHES.md: `diff -u` of
  `bfb8a12^:suckless/dwm/dwm.c` and the tree, labels `a/`/`b/`, under a
  `diff --git` line. Before regenerating, it was checked to reproduce the
  committed diff byte for byte.
- PATCHES.md dated note; KEYBINDINGS.md Scratchpads paragraph; CHANGELOG
  [Unreleased] Fixed entry.
- Test: `check_scratchpad_leave` (`tests/lib/dwm-runtime-scratchpad.sh`,
  wired in `tests/dwm-runtime.sh`).

## Why
User question: how to move a scratchpad window back to tag 2. The answer
was `Super+=` while it was still focused, then `Super+Shift+2`. Using
`Super+Shift+2` alone sent it to tag 2 but left it in the set, so the next
`Super+s` pulled it back. The user asked for that to be fixed.

## Assumptions Made
- Type B (user choice): re-tile on leaving, over keeping it floating as
  `Super+=` does. Cost: a window that floated before it was stashed (a
  dialog) is tiled too; `Super+Shift+space` floats it again.
- Type B (user choice): toggletag also takes a window out of the set.
- Type C: `tagmon` (move to another monitor) keeps membership. Super+s
  gathers members from every monitor (scratchpad-follow).

## Test coverage
- `tests/dwm-runtime.sh` passes under Xvfb (built from `rm config.h; make`);
  `tests/dwm-multimon.sh`, `tests/build.sh`, `tests/changelog-version.sh`
  and `tests/lint.sh` pass.
- Mutants, built in scratch copies: no tiling, no call in `tag()`, no call
  in `toggletag()`. Each one fails both new checks.
- First test draft named the wrong window: Super+s focuses the NEWEST
  member (attach() prepends). Also, focus-follows-mouse onto a floating
  member did not take, so the test hides and re-shows the remaining member
  with Super+s to focus it. Its tag-8 check also rejects 640px, the
  floating two-member half, which `< 1200` alone let through.

## Next Steps
- Merge, rebuild dwm, `pkill -HUP -x dwm`, then try Super+Shift+2 on a
  shown scratchpad.
