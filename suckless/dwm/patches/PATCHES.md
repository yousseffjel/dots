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

**Retired:** `dwm-dragmfact-6.2.diff` was removed on 2026-10-22. Its
behaviour (Super+right-drag on a tiled window warps the pointer to the split
and drags mfact) was replaced by `dwm-dragtile-20261022-local.diff`, which
does not warp and adds the vertical axis. Nothing of dragmfact is left in
`resizemouse()`.

**Chords are config, not patch behaviour.** The 2026-10-13 keymap moved
several `keys[]` entries (scratchpads to `Super+s`/`Super+Shift+s`, quit to
`Super+Shift+Escape`, killclient to `Super+Shift+q`, the layout toggle to
`Super+Ctrl+space`). The two `*-local.diff` records that add a binding were
updated to the new chord; upstream diffs (restartsig, actualfullscreen) keep
the chords they were published with in their context lines, because they are
records of what upstream shipped, not of this tree's keymap.

## dwm-scratchpadfill-20261022-local.diff

**Source**: written for this tree, on top of dynamicscratchpads. A window
stashed with `scratchpad_hide()` is made floating at whatever size it had,
so `Super` + `s` brought it back at that size, often a tiled column's or a
near-full leftover (the user saw 1851x1043 on a 1920x1080 monitor).
`scratchpad_show_client()` now `resize()`s it to the selected monitor's
window area (`wx`/`wy`/`ww`/`wh`, borders inside) before `arrange()`, on
every show, so a scratchpad dragged smaller fills again the next time. It
stays floating: tiled windows stay behind it and Super+drag still works.
**Skipped**: the dropterm (it has its own top-centre placement,
`droptermgeom()`) and a fullscreen window. Size hints still apply
(`resize()`, not `resizeclient()`), so a terminal with size increments can
stop a cell short. User choice 2026-10-22 over "join the tiling" and
"centred at 90%". `check_scratchpad_fill` in `tests/lib/dwm-runtime-floating.sh`.

## Hyprland-style mouse (2026-10-22)

Six records, merged together in one slot (`dwm-hyprland-mouse`). The user
asked for Hyprland's `Super` + mouse move/resize; the Hyprland wiki
(configuring/core/dispatchers: `drag()`, `resize()`; config-options:
`general.snap`) was the reference. Three are upstream, all from
`bakkeby/patches` at `d99bbe2`, vendored byte-for-byte; three are local.
`tests/dwm-runtime.sh` covers all six (`tests/lib/dwm-runtime-mouse.sh`).

### dwm-cfacts-6.6-d99bbe2.diff

**Source**: the first of the two commits in bakkeby's
`dwm-cfacts-dragcfact-6.6_full.diff`, cut at its `-- ` trailer. Per-client
weights (`Client.cfact`) in `tile()`, so windows in one column can differ in
height. **Deviations**: `setcfact()` is merged in the form the second commit
(dragcfact) leaves it — it clamps to 0.25–4.0 instead of refusing, and
`arg > 4.0` sets the weight absolutely. The keys are `Super+Shift+k`/`j`/`o`,
not upstream's `Super+Shift+h`/`l`/`o`: sxhkd owns `Super+Shift+l` (lock).
**Interactions**: pertag does not store cfacts; they belong to the window,
whatever tag it is on.

**dragcfact itself was not merged.** It moves cfact for both axes and warps
the pointer to the window's centre; dragtile below replaces it.

### dwm-resizepoint-6.6-d99bbe2.diff

**Source**: bakkeby's resizepoint: a floating window resizes from the corner
nearest the grab point, the pointer is never warped, the cursor shows that
corner, and `resizeclient()` is called directly, so size hints do not make a
terminal resize in steps. **Merged by hand**: this tree's `resizemouse()`
carried dragmfact's tiled branch where upstream's context has stock dwm's
"resize a tiled window and it floats". Both are gone: a tiled window goes to
`dragtile()` before the grab. The cursor enum keeps `CurResize` after
`CurNormal` (dragtile uses it); the four corner cursors must stay first,
because `cursor[left | top << 1]` indexes them.

### dwm-placemouse-6.6-d99bbe2.diff

**Source**: bakkeby's placemouse. `Super` + left-drag on a tiled window
detaches it and re-inserts it next to the window under its centre
(`moveorplace`, `{.i = 1}`), live, across monitors; it stays tiled, as in
Hyprland. A floating window, or any window in the floating layout, still
goes to `movemouse()`. **Deviations**: (1) the motion throttle is
`1000 / refreshrate`, as in `movemouse()`, not a hard-coded 60; (2) both
places that move the window to another monitor clear `hashome`, as
`sendmon()` does (replug: a window moved by hand stays); (3) a failed
`getrootptr()` after the grab ungrabs and clears `beingmoved` instead of
returning with both left set, which froze the window. **Lost on purpose**:
dragging a tiled window no longer floats it; `Super` + middle-click
(togglefloating) does that. `beingmoved` makes `resizeclient()` record the
tiled geometry without configuring the window, so the window follows the
pointer while `tile()` lays the others out around its slot.

### dwm-dragtile-20261022-local.diff

**Source**: written for this tree. `Super` + right-drag on a tiled window in
`tile()`. Horizontal motion moves the split (mfact, into pertag's slot as
`setmfact()` does), only while both columns are on screen. Vertical motion
moves the window's edge nearest the grab point by trading cfact with the
neighbour on that side: the pair keeps its summed weight and its pixel
height, so no other window in the column moves. The first or last window of
a column has one movable edge, used whichever half was grabbed. In monocle
it does nothing. The pointer never warps.

### dwm-preservecfact-20261022-local.diff

**Source**: written for this tree. preserveonrestart's per-window record
gains a 16th value, cfact x1000, so a restart (every wallpaper change) keeps
a window's height. A value outside 250–4000 is ignored: any client can write
the property on its own window.

### dwm-snapwindows-20261022-local.diff

**Source**: written for this tree; stock dwm snaps only to the monitor's
edges. A floating window being moved snaps by whichever of its edges is
nearer to another visible window's edge, after the monitor-edge snap; a
resize snaps the edges being dragged. `windowsnap` (10 px, Hyprland's
`general.snap.window_gap` default) is separate from `snap` (32 px), which a
screen edge keeps. Only windows whose span meets the moving one's on the
other axis count. Tiled windows count too.

## dwm-bidi-20261013-local.diff

**Source**: adapted from upstream's
[bidi](https://dwm.suckless.org/patches/bidi/) patch
(`dwm-bidi-restricted-20230512-e81f17d.diff`, the window-title-only variant),
by Mahdi Mirzadeh. Captured against this tree rather than vendored as
published, for two reasons below.

**What**: `bidi()` runs a string through fribidi's `fribidi_log2vis`, which
reorders it into visual order and — because log2vis applies
`FRIBIDI_FLAGS_ARABIC` — shapes Arabic into its joined presentation forms.
`drawbar()` draws `bidi(m->sel->name)` in place of the title. `config.mk`
gains `FRIBIDIINC`/`FRIBIDILIBS`; `packages/build.lst` gains
`fribidi-devel`. `config.def.h` adds `"Noto Sans Arabic:size=10"` as the
second `fonts[]` entry: Cascadia Code NF has the base Arabic letters but not
the presentation forms (U+FE70-FEFF) the shaping emits.

**Why**: Xft draws codepoints left to right as given and shapes nothing, so
an Arabic title rendered as isolated letters in reverse order.

**Where it departs from upstream**:
- **Buffer sizes.** Upstream wrote the result into a buffer the size of the
  input (256 bytes). An Arabic letter is 2 bytes in UTF-8 and its
  presentation form 3, so a title over ~170 bytes of Arabic overflowed it.
  Here the output holds 4 bytes per codepoint of a 255-byte input, and the
  input copy is zero-padded: fribidi's UTF-8 decoder reads a lead byte's
  continuation bytes without checking the length, and the 255-byte cut can
  split a sequence. `tests/bidi.sh` reproduces the upstream overflow under
  ASan and guards against it.
- **ASCII fast path.** A string with no byte >= 0x80 cannot contain a
  strong RTL character, so `bidi()` returns it untouched — the bar redraws
  on every focus change and most titles are ASCII.
- **Title only, like upstream's restricted variant.** Status text comes
  from dwmblocks (ASCII and Nerd glyphs), drawn by status2d's own parser,
  and the tags are digits.

## dwm-preservepertag-20261012-local.diff

**Source**: written for this tree; extends preserveonrestart (below) to the
state the pertag patch keeps per tag. Apply after preserveonrestart and
wakeonsignal.

**What**: `savepertag()`, called from `savestate()`, writes `_DWM_PERTAG` on
the root window. For each monitor, in list order, it records `curtag`, the
monitor's OTHER tagset slot, and then for every tag (index 0 is the all-tags
view): nmaster, mfact x1000, sellt, both layouts as indexes into `layouts[]`
(pointers do not survive `execvp()`), and showbar. `restorestate()` calls
`loadpertag()` before its view loop. That validates every value (tag bounds,
mfact 0.05-0.95, layout index < LENGTH(layouts), booleans); a tag with any
bad value keeps its defaults. `applycurtag()` then puts the current tag's
values on the monitor, and the view loop replays the history, `view(other
slot)` and then `view(saved view)`.

**Why**: preserveonrestart kept tags, view, stash, floating geometry and
focus, but every restart (one per wallpaper change) reset each tag's
layout, mfact, nmaster and bar to the defaults.

**Two traps, both tested** (`check_pertag_restart`):
- **A fresh dwm starts on tag 1.** Restoring a saved view of tag 1 is a
  no-op in `view()`, so nothing applied that tag's values. `applycurtag()`
  exists for this case.
- **`Mod+Tab` swaps the two `tagset` slots; it never reads pertag's
  `prevtag`.** A first draft restored `prevtag` and Mod+Tab still went
  nowhere. Replaying the history fixes both.

**Format choice**: the other tagset lives in the new property, not in
`_DWM_VIEW`. A rebuilt dwm is often first started by an OLD binary's
restart, and changing `_DWM_VIEW`'s layout would make the new binary misread
the old one's data. A property the old binary never writes is simply absent.

## dwm-replug-20261021-local.diff

**Source**: written for this tree; no upstream patch does this. Stock
`updategeom()` moves a vanished monitor's windows to the first monitor and
forgets where they came from, so plugging the screen back in left it empty.

**Why geometry, not the Monitor struct**: dwm reuses Monitor structs by
index and frees the LAST one when a monitor goes. Unplug the left screen
and struct 0 takes the right screen's geometry, carrying the left screen's
windows with it; replug and it takes the left geometry back. A struct is no
identity across a hotplug, so a window's home is the geometry it was on.

**What it does**: `sethomes()`, from `updategeom()` only when the monitor
COUNT changes (a mode change records nothing), gives every client not
already away from home its monitor's geometry, that monitor's view, and
its own position (used when floating). `restorehomes()`, from
`configurenotify()` after `updatebars()`, moves each client whose home
geometry is a monitor again back to it, keeping its tags, and clears the
home; one still away keeps it. A monitor created by the hotplug (`fresh`)
takes back its returning windows' view through `view()`, so pertag's
layout follows. `sendmon()` clears the home: a window moved by hand stays
where it was put. preserveonrestart's record carries the home across a
restart (see that entry).

**Tests**: `tests/dwm-multimon.sh` unplugs and replugs the right monitor of
two (Xvfb's screen shrunk through an added RandR mode, the ConfigureNotify a
real unplug sends): tiled and floating windows return, the view comes back,
the left monitor's window stays, and a second cycle with a restart in the
middle does the same with the view the window had then. Stock dwm failed the
first return. Mutation-checked, except the `sendmon()` clear — with two
monitors there is nowhere to move a window while one is gone.

## dwm-statusallmons-20261021-local.diff

**Source**: modelled on the upstream statusallmons patch
(`dwm.suckless.org/patches/statusallmons/`), written against this tree
because upstream's two-line change assumes stock dwm. Here status2d's
`drawstatusbar()` and statuscmd's click mapping in `buttonpress()` both
subtracted the systray width unconditionally — harmless while the status
was drawn only on the selected monitor, which is where a
`systraypinning = 0` tray sits.

**What it changes**: `drawbar()` draws the status on every monitor (the
`m == selmon` guard is gone), `updatestatus()` redraws every bar
(`drawbars()`), and a new `traywidth(m)` returns the tray's width on the
monitor that holds it (`systraytomon()`) and 0 elsewhere, used by both
the status drawing and the click mapping. `statusw` stays one global: it is
the text's width, the same on every bar.

**Why**: the user runs two monitors (2026-10-21); the clock, volume, battery
and notification button sat on whichever monitor held the pointer, and
jumped with it. The tray still follows the selected monitor
(`systraypinning` unchanged).

**Interactions**: statuscmd clicks work on any bar — `buttonpress()` makes
the clicked monitor `selmon` before mapping the click, so `selmon->ww` and
`traywidth(selmon)` are that bar's. `tests/dwm-multimon.sh` (two RandR
monitors under Xvfb) asserts the status on both bars, pixel-identical,
across a selection change and a status update; it catches each of the three
changes reverted on its own.

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

**Since 2026-10-21** (`dwm-replug-20261021-local.diff`) the per-window record
is 15 values, not 7: the replug home follows the original seven. A 7-value
record is still read, because the first restart after an upgrade is the old
binary handing over to the new one.

**Since 2026-10-22** (`dwm-preservecfact-20261022-local.diff`) it is 16: the
window's cfact, x1000, follows the replug home. 7- and 15-value records are
still read.

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
`Super+s` cycles it with the rest and preserveonrestart keeps it stashed
across a restart (diff above — apply that one first; this diff's `manage()`
hunk reads its `loadclientinfo()` return value). Since 2026-10-12 dwm's
`MODKEY` is Super too, so dwm and `config/sxhkd/sxhkdrc` share one key space;
`tests/key-collisions.sh` fails the build if they grab the same chord.

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
