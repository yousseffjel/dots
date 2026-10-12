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

## dwm-wakeonsignal-20261012-local.diff

**Source**: written for this tree; no upstream patch. A self-pipe in the
classic form: `quit()` writes one byte to a non-blocking, close-on-exec pipe,
and `run()` waits with `select()` on both the X connection and that pipe
instead of blocking in `XNextEvent()`.

**Why**: the SIGHUP/SIGTERM handlers (restartsig) only call `quit()`, which
clears `running`; a loop blocked in `XNextEvent()` saw that at the NEXT X
event. An idle desktop may send none for many seconds. On the Fedora 44 VM
(2026-10-12) a power-menu logout (`pkill -TERM -x dwm`) took 20-25 s, and a
`kill -HUP` restart, which every wallpaper change sends via
`scripts/theme/reload.sh`, took 6.1 s. `tests/dwm-runtime.sh` had hidden this
since 2026-10-06 by setting a throwaway root property after each kill; that
workaround is gone, and `check_sigterm` asserts an exit with no X event.

**Why not `pselect()` with the signals blocked**: the mask would be inherited
by every client `spawn()` forks and by `popen()`'s `pidof`, so programs started
from dwm would ignore SIGHUP/SIGTERM. The pipe changes no mask. On Linux
`select()` is also never restarted after a handler, so the pipe matters only
for the race where a signal lands between the `running` check and the wait.
That race is why mutation W2 (no write) survives: no test can hit that window
on demand.

**Interactions**: `quit()` saves and restores `errno` and makes only
async-signal-safe calls, because the handlers reach it. The restart path's
`execvp()` closes both ends (FD_CLOEXEC), and the new instance makes its own.


**Source**: modelled on the upstream preserveonrestart patch
(`dwm.suckless.org/patches/preserveonrestart/`), written against this tree
rather than applied — "local" for the same reason as the entries below. It
differs from upstream on purpose:

- **Saved once, on the restart path** (`savestate()` just before `execvp()` in
  `main()`), not on every tag change. Upstream writes `_NET_CLIENT_INFO` from
  each function that mutates `c->tags`; with dynamicscratchpads that is half
  a dozen call sites, and every future one would need remembering.
- **Private atoms, not advertised**: `_DWM_CLIENT_INFO` per window and
  `_DWM_VIEW` on the root. Upstream's `_NET_CLIENT_INFO` is not an EWMH atom
  and does not belong in `_NET_SUPPORTED`.
- **More state**: tags, monitor, floating flag and floating geometry per
  window (upstream: tags and monitor), plus each monitor's view, the selected
  monitor and the focused window. The view is restored through `view()`, so
  pertag's per-tag layout and mfact follow it.
- **Read once**: both properties are fetched with `delete = True`.

**Why**: `scripts/theme/reload.sh` SIGHUPs dwm on every wallpaper change and
theme switch (restartsig re-exec). Without this, `scan()` re-managed every
window through `applyrules()`, which knows nothing about the old instance:
all windows piled onto the starting view, stashed scratchpads came back out,
floating windows were tiled and focus was lost. `tests/dwm-runtime.sh`
(`check_preserve`, in `tests/lib/dwm-runtime-restart.sh`) failed 7/7 on the
tree before this diff and passes 7/7 after it.

**Interactions**: SCRATCHPAD_MASK (dynamicscratchpads) is accepted as a saved
tag set on its own; any other value must lie inside TAGMASK, or the window
keeps what `applyrules()` gave it. Floating geometry is restored before
`manage()`'s clamp, so an off-screen position still lands on the monitor.

## dwm-dropterm-20261007-local.diff

**Source**: written for this tree, no upstream patch. Builds on
dynamicscratchpads instead of the retired static `scratchpads`, so the two
mutually exclusive tag bits stay one.

**What**: `dropterm()` on `Mod4+grave` — spawn `droptermcmd` when no client is
marked `isdropterm`; stash it (SCRATCHPAD_MASK) when it is showing and focused;
otherwise move it to the focused monitor's view, re-place it top-centre
(`droptermgeom()`, sized by `droptermw`/`droptermh`) and focus it.
`applyrules()` marks the client when its class OR instance equals
`droptermclass`, because terminals differ in which one their class flag sets,
and makes it floating without a `rules[]` entry.

**Interactions**: while stashed it is an ordinary scratchpad client, so
`Alt+minus` cycles it with the rest and preserveonrestart keeps it stashed
across a restart (diff above — apply that one first; this diff's `manage()`
hunk reads its `loadclientinfo()` return value). Super is sxhkd's space
except for dwm's three Super chords (`Shift+x`, `v`, `grave`) — keep
`config/sxhkd/sxhkdrc` off them.

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
