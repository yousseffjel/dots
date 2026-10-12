# pertag-restart
Date: 2026-10-12
Files: 13 | Lines: +655/-14 (before this log)

Scope G slot 2 of 3 (`.claude/tasks/scope-g-release-0.2.0.md`, on main).

## What changed
- **`preservepertag`** (`suckless/dwm/dwm.c`, new
  `patches/dwm-preservepertag-20261012-local.diff` + PATCHES.md, rule 5).
  It extends preserveonrestart.
  - `savestate()` calls the new `savepertag()`, which writes `_DWM_PERTAG`
    on the root window. For each monitor it records curtag, the OTHER
    tagset slot, and then per tag (index 0 = all tags): nmaster, mfact
    x1000, sellt, both layouts as indexes into `layouts[]`, and showbar.
  - `restorestate()` calls `loadpertag()` first. That validates every
    field, fills the Pertag arrays, records the other tagset in the new
    field `restoredprevset`, and calls the new `applycurtag()`.
  - The view loop then replays `view(other slot)` and `view(saved view)`.
- **Tests** (new `tests/lib/dwm-runtime-pertag.sh`, wired in
  `tests/dwm-runtime.sh`):
  - `check_pertag_fresh_restart` runs FIRST, on the fresh dwm;
  - `check_pertag_restart` runs after `check_preserve`. It covers tag 1
    (the start view), tag 7 mfact, tag 8 monocle, tag 6 hidden bar and
    Mod+Tab.
- **Docs:**
  - KEYBINDINGS.md: the restart note.
  - CLAUDE.md: dwm roster 16 → 17 plus a note.
  - CHANGELOG `[Unreleased]` Fixed.
  - The `dwm-runtime.sh` header lists the patches with no count.

## Why
This was option 3 of 2026-10-12, owed since the 2026-10-07
dwm-rules-scratchpad follow-up. preserveonrestart kept tags, the view, the
stash, floating geometry and focus, but each restart (one per wallpaper
change) still reset every tag's layout, mfact, nmaster and bar, and lost
Mod+Tab's previous tag.

## Assumptions
- Type B: the other tagset slot lives in the new `_DWM_PERTAG`, not in
  `_DWM_VIEW`. A rebuilt dwm is usually first started by an OLD binary's
  restart, so `_DWM_VIEW`'s format must not change. A property the old
  binary never writes is simply absent.
- Type B: a tag with any out-of-range value keeps its defaults (nmaster
  0-64, mfact 0.05-0.95, booleans, layout index < LENGTH(layouts)), the
  same stance as `_DWM_CLIENT_INFO`.
- Deviations (task progress.md):
  - Mod+Tab: the first draft restored pertag's `prevtag`, which Mod+Tab
    never reads, since it swaps the tagset slots. Its check failed 3/3, and
    the history replay replaced it.
  - The tag-1 check first passed vacuously (700 → 700), because earlier
    restarts had already reset tag 1. It now widens tag 1 itself.

## Test coverage
- `tests/run-tests.sh` 47/47, lint green.
- dwm-runtime: 3 + 2 clean runs, 42 assertions.
- The diff reproduces `dwm.c` from HEAD.
- Mutations on copies: 6/6.
  - Caught: never saved; no applycurtag; no history replay; layout index
    always 0; all values rejected; bar not restored.
  - "no applycurtag" survived the first round: the replay covers it unless
    both tagset slots hold the start tag. That is the "log in, change tag
    1, Super+w" case, now `check_pertag_fresh_restart`.
- Reviewer: READY, first round.
- Not checked live on the VM. Xvfb only, which is fine for dwm's own
  state.

## Follow-ups
- Optional VM look after merge + push: `install-suckless.sh` (with `rm
  config.h`), change tag 2's layout, press Super+w.
- Next: scope G slot 3, `release-0.2.0`.
