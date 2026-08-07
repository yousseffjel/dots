# dwm patches — merge notes

This file documents manual merge decisions for every patch vendored under
`patches/`. Existing patches (status2d, systray, statuscmd, pertag,
hide_vacant_tags, dragmfact, scratchpads, actualfullscreen, autostart,
restartsig) were already baked into `dwm.c`/`config.def.h` before this
project started tracking merge notes — this file starts from the
xresources patch onward.

**Retired:** `dwm-scratchpads-20200414-728d397b.diff` was removed on
2026-08-07, replaced by `dwm-dynamicscratchpads-20260807-local.diff`. The two
are mutually exclusive — see that entry.

## dwm-dynamicscratchpads-20260807-local.diff

**Source**: adapted from the upstream dynamicscratchpads patch
(`dwm.suckless.org/patches/dynamicscratchpads/`, diff
`dwm-scratchpad-20200727-bb2e7222baeec7776930354d0e9f210cc2aaad5f.diff`, by
Gaspar Vardanyan). Like the xresources entry below, this is **not** a verbatim
`patch -p1` apply — hand-merged into the already-patched sources, then
re-diffed against the pre-merge baseline. "local" flags that distinction.

**Why it replaced the static scratchpads patch**: the user asked for dynamic
assignment — stash whichever window is focused, whatever it is — rather than
the old model of spawning pre-declared commands as scratchpad N. The two
patches cannot coexist: the old one defined
`SPTAG(i) ((1 << LENGTH(tags)) << (i))` and this one defines
`SCRATCHPAD_MASK (1u << LENGTH(tags))`, i.e. both claim bit `LENGTH(tags)`
of the tag bitmask. So the old patch had to be un-baked from `dwm.c` and
`config.def.h` before this one went in; this diff contains both halves of
that swap, which is why it removes as well as adds.

**What was un-baked**: `NUMTAGS`, `SPTAG`, `SPTAGMASK` and the `TAGMASK`
redefinition; `togglescratch()` and its three call sites in `applyrules()`
and `showhide()`; and in `config.def.h` the `Sp` typedef, `spcmd1..3`,
`scratchpads[]`, three `rules[]` entries and three keybinds. `TAGMASK` is back
to vanilla `((1 << LENGTH(tags)) - 1)`.

**Conflict points checked against the other 11 patches** (all clean):

- `pertag` — **not affected**, despite sharing the tag bitmask. Its arrays are
  sized `LENGTH(tags) + 1`, never `NUMTAGS`, so removing that macro touches
  nothing there. Verified by reading `struct Pertag`, not assumed.
- `hide_vacant_tags` — **not affected**. `drawbar()` loops
  `i < LENGTH(tags)`, so bit `LENGTH(tags)` is never drawn regardless of
  which patch owns it. Its `occ |= c->tags == TAGMASK ? 0 : c->tags` line
  tests for "shown on all tags" and is indifferent to the scratchpad bit.
- `actualfullscreen` — `applyrules()`'s `isfullscreen`/`setfullscreen(c, 1)`
  block sits above the line this patch wraps; the wrap is the last statement
  in the function, so the two do not interleave.
- `statuscmd`/`status2d`/`systray`/`dragmfact`/`restartsig`/`autostart`/
  `xresources` — none touch the tag bitmask, `applyrules()`, `showhide()` or
  `unmanage()`'s tail.

**Deviations from upstream, all deliberate**:

1. **Function signatures.** Upstream declares `static void scratchpad_hide ()`
   — an empty parameter list, meaning *unspecified* arguments in C. dwm's
   `Key` struct requires `void (*func)(const Arg *)`, so these take
   `(const Arg *arg)` here. Same behaviour, correct prototype, no reliance on
   pre-C99 function-pointer compatibility rules under `-std=c99 -pedantic`.
2. **`_Bool` → `int`.** `scratchpad_last_showed_is_killed()` returns `int`;
   dwm uses `int` for booleans everywhere and never includes `stdbool.h`.
3. **House style.** Reformatted from upstream's `selmon -> sel` /
   `Client * c` spacing to dwm's `selmon->sel` / `Client *c`, tabs, and K&R
   braces, so future patches' diff context matches the rest of the file.
   Control flow is unchanged — `scratchpad_show()` keeps the same
   early-return structure, just with guard clauses instead of nesting.
4. **`SCRATCHPAD_MASK` spelled with `LENGTH(tags)`** rather than upstream's
   `sizeof tags / sizeof * tags`. Identical expansion; `LENGTH` is already
   the idiom in this file.

**Tag arithmetic verified numerically** (not reasoned about): with 9 tags,
`TAGMASK` is `0x1FF` and `SCRATCHPAD_MASK` is `0x200`, so
`SCRATCHPAD_MASK & TAGMASK == 0` — the scratchpad bit sits cleanly outside
the tag range, and `drawbar`'s loop stops one index short of it. The
`NumTags` compile-time guard was moved from `> 31` to `> 30` to reserve that
bit, matching upstream.

**Round-trip verified**: applying this diff to the pre-merge baseline
reproduces the current `dwm.c` and `config.def.h` byte-for-byte
(`patch -p1` then `diff -q`, both clean).

**Build verified**: `rm -f config.h && make clean && make` — clean compile,
zero warnings, `dwm` binary links.

## dwm-xresources-20260805-local.diff

**Source**: adapted from the upstream dwm xresources patch
(`dwm.suckless.org/patches/xresources/dwm-xresources-20260524-44dbc68.diff`,
by Justinas Grigas). Not a verbatim `patch -p1` apply — hand-merged
directly into the already-patched `dwm.c`/`config.def.h`, then re-diffed
against the pre-merge baseline to produce this file. "local" in the
filename flags that distinction (no real upstream commit hash applies to
this exact diff).

**Why hand-merged instead of applied**: this repo has no `config.h` file —
only `config.def.h`, which already contains 10 other patches' worth of
baked-in changes (status2d's extra `scheme[LENGTH(colors)]` default
entry, systray fields, statuscmd, pertag, scratchpads, etc.). A literal
`patch -p1 < dwm-xresources-upstream.diff` against a *vanilla* dwm 6.8
tree would not apply cleanly here — the upstream diff's context lines
(the plain `col_gray1`/`col_cyan` color block, the plain `colors[][3]`
initializer) no longer match this file's actual content. Editing the
current source directly and capturing the resulting diff was the only
way to merge without fighting `patch`'s fuzzy-context matching on an
11-patch-deep file.

**Scope trimmed from upstream**: the upstream patch also exposes
`borderpx`, `snap`, `showbar`, `topbar`, `nmaster`, `resizehints`,
`mfact`, and dmenu's launch colors as X resources, plus a `Mod+F5`
`xresreload()` hotkey for in-place reload. None of that shipped here —
only the 6 border/fg/bg color resources the theming-engine spec asked
for (`dwm.normbgcolor`, `dwm.normfgcolor`, `dwm.normbordercolor`,
`dwm.selbgcolor`, `dwm.selfgcolor`, `dwm.selbordercolor`). Reasons:

1. Smaller diff against an already 10-patches-deep file — every extra
   `const` removed from `borderpx`/`snap`/`showbar`/`topbar` is one more
   place a future patch's diff context could break.
2. `restartsig` (already applied) covers the reload path: `kill -HUP
   $(pidof dwm)` re-execs the binary, which calls `xresupdate()` again
   at fresh startup. A live in-place `xresreload()` + hotkey would be a
   second, redundant reload mechanism for a program that already has a
   cheap full-restart path — st needed its own in-place `SIGUSR1`
   reload instead because restarting st would kill the shell session
   inside it; dwm has no such cost.

**Resource names**: the theming-engine spec (this project) specifies
`dwm.normbgcolor` / `dwm.normfgcolor` / `dwm.normbordercolor` /
`dwm.selbgcolor` / `dwm.selfgcolor` / `dwm.selbordercolor`, not
upstream's `dwm.background` / `dwm.foreground` / `dwm.border` /
`dwm.backgroundSel` / `dwm.foregroundSel` / `dwm.borderSel`. Kept the
spec's names verbatim.

**Conflict points checked against the other 10 patches** (all clean,
none required edits beyond the new code itself):

- `colors[][3]` / `SchemeNorm` / `SchemeSel` indices — status2d's extra
  `scheme[LENGTH(colors)]` entry at `dwm.c` setup() is built from
  `colors[0]` (i.e. `colors[SchemeNorm]`) at *runtime*, after
  `xresupdate()` has already run in `main()` — so it naturally picks up
  the resource-loaded values with no extra plumbing.
- `pertag`, `scratchpads`, `dragmfact`, `hide_vacant_tags`,
  `actualfullscreen` — none touch `colors[]`, `cleanup()`, or `main()`'s
  init sequence; no overlap.
- `statuscmd`/`systray` — both read `scheme[...]` at draw time, after
  colors are resolved; no ordering conflict with `xresupdate()` running
  early in `main()` (right after `checkotherwm()`, before `setup()`).

**Build verified**: `make clean && make` — clean compile, zero warnings,
`dwm` binary links.
