# dwm patches — merge notes

This file documents manual merge decisions for every patch vendored under
`patches/`. Existing patches (status2d, systray, statuscmd, pertag,
hide_vacant_tags, dragmfact, scratchpads, actualfullscreen, autostart,
restartsig) were already baked into `dwm.c`/`config.def.h` before this
project started tracking merge notes — this file starts from the
xresources patch onward.

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
