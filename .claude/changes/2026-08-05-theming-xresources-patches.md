# theming-xresources-patches
Date: 2026-08-05
Files: 9 tracked modified + 8 new (4x patches/PATCHES.md, 4x patches/*.diff) | Lines: +287/-3

## What changed
- Added xresources runtime color support to all 4 vendored suckless
  programs that render UI: dwm, st, dmenu, slock (dwmblocks needs no
  patch — it drives colors via status2d escape codes from block scripts,
  a later sub-task).
- **dwm** (`suckless/dwm/config.def.h`, `dwm.c`): reads `dwm.normbgcolor`,
  `dwm.normfgcolor`, `dwm.normbordercolor`, `dwm.selbgcolor`,
  `dwm.selfgcolor`, `dwm.selbordercolor` at startup via a new
  `xresupdate()`/`xresload()` pair, hand-merged against the 10 patches
  already baked into this repo's `dwm.c`/`config.def.h` (status2d,
  systray, statuscmd, pertag, hide_vacant_tags, dragmfact, scratchpads,
  actualfullscreen, autostart, restartsig). Reload path is the existing
  `restartsig` patch (`kill -HUP $(pidof dwm)` re-execs and re-reads).
- **st** (`suckless/st/x.c`): reads `st.background`, `st.foreground`,
  `st.color0`-`st.color255`, `st.cursorColor` at startup and on
  `SIGUSR1` (`killall -USR1 st`), via the xresources-signal-reload
  variant — the only variant that live-reloads a running terminal
  without killing its shell. st had zero prior patches, so this was a
  clean apply.
- **dmenu** (`suckless/dmenu/config.def.h`, `dmenu.c`): reads
  `dmenu.background`, `dmenu.foreground`, `dmenu.selbackground`,
  `dmenu.selforeground`, hand-merged against the 7 patches already
  applied (border, caseinsensitive, center, fuzzymatch, lineheight,
  mousesupport, numbers). `xresupdate()` runs before CLI arg parsing on
  its own temporary `Display`, so `-nb`/`-nf`/`-sb`/`-sf` keep their
  existing precedence over X resources.
- **slock** (`suckless/slock/{config.def.h,slock.c,util.h}`): reads
  `slock.initcolor`, `slock.inputcolor`, `slock.failedcolor` once at
  launch (slock is one-shot per lock, so no reload path needed) — first
  patch ever applied to slock in this repo.
- Every tool's `patches/PATCHES.md` documents the exact merge decisions,
  scope trimmed from each upstream patch, and any deviation from
  upstream (resource naming, precedence handling, dropped resources).
  Vendored `.diff` files follow the existing `<patch>-<date>-<hash>.diff`
  convention, with `-local` in place of a hash since these are
  hand-adapted merges, not verbatim upstream commits.

## Why
Sub-task 1 of the theming-engine Epic
(`.claude/tasks/scope-a-theming-engine.md`) — every later sub-task
(color extraction, template engine, atomic reload) needs something to
actually target. Without xresources support, none of the 4 tools can
read a generated color palette at runtime.

## Assumptions
- **Type B** — resource names for dwm/st/dmenu follow the user's spec
  verbatim (`normbgcolor`/`selbgcolor` style, not upstream's mixed
  `background`/`Sel`-suffix style). slock has no spec-given names, so it
  follows the same descriptive convention as the other 3 rather than
  upstream's numbered `color0`/`color1`/`color3` scheme. Alternative
  considered: keep upstream's exact resource names for a smaller diff
  against the reference patches — rejected for consistency across the
  4-tool `.Xresources` surface the templates in later sub-tasks will
  generate. If incorrect: rename the `resources[]` entries in each
  `config.def.h`/`config.h` (dwm/dmenu/slock) or the `XRESOURCE_LOAD_*`
  macro calls in `xrdb_load()` (st).
- **Type B** — scope trimmed to colors only on all 4 tools (dropped
  font/geometry/timing resources and dwm's Mod+F5 reload hotkey that
  upstream patches also offer). Alternative considered: port upstream's
  full resource set — rejected as out-of-scope for a color-only theming
  engine and unnecessary risk against dwm's 10-deep patch stack. If
  incorrect: re-add the dropped `XResPref`/`ResourcePref` entries per
  tool; see each PATCHES.md for exactly what was cut.

## Test coverage
- `make clean && make` verified clean (zero new warnings) for all 4
  tools, both before and after the reviewer-caught fix below.
- No test suite for C sources in this repo — verification is
  compile-clean + manual code reading, per repo convention.
- Two-gate review: in-thread audit-loop (4 iterations, adapted from the
  kit's React Native checklist to C/patch-equivalent checks since this
  repo has no frontend) reported ✅ READY with 0 issues on the first
  pass. Independent reviewer subagent then caught a real bug (below) on
  its first pass; a second reviewer pass after the fix returned READY.

## Follow-ups
- Sub-task 2 (colorgen.sh) can now target these exact resource names
  when generating `~/.cache/dots/theme/xresources`.
- st's `xrdb_load()` intentionally leaks its `XrmDatabase` on every
  `SIGUSR1` reload (documented in `suckless/st/patches/PATCHES.md`) —
  not expected to matter in practice (a few KB per reload, would need
  thousands of reloads in one session to be noticeable), but worth
  knowing if st's memory footprint is ever profiled.

## Bug caught during review
The independent reviewer subagent (first pass) found a real
use-after-free: an earlier draft of st's `xrdb_load()` called
`XrmDestroyDatabase(xrdb)` right after populating `colorname[]` from
that database's `XrmGetResource` results. `XrmGetResource` returns
pointers *into* the database's own string storage, not copies, so
destroying it immediately freed memory `colorname[]` still pointed to —
hit by `xloadcols()` on every st launch and every `SIGUSR1` reload, not
just a reload-only edge case. Fixed by removing the destroy call
entirely (matches upstream's own `xrdb_load()`, which never destroys it
either, for the same reason). Rebuilt clean; a second reviewer pass
confirmed the fix and returned READY.
