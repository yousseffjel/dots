# dmenu patches — merge notes

Existing patches (border, caseinsensitive, center, fuzzymatch,
lineheight, mousesupport, numbers) were already baked into
`dmenu.c`/`config.def.h` before this project started tracking merge
notes — this file starts from the xresources patch onward.

## dmenu-xresources-20260805-local.diff

**Source**: adapted from the upstream dmenu xresources patch
(`tools.suckless.org/dmenu/patches/xresources/
dmenu-xresources-20260510-7175c48.diff`, by Justinas Grigas). "local" in
the filename flags this as a hand-adapted merge, not a verbatim upstream
commit — merged directly into the already-7-patches-deep
`dmenu.c`/`config.def.h` rather than applied with `patch -p1` (same
reasoning as the dwm merge note: this repo's `config.def.h` no longer
matches upstream's plain-vanilla context lines).

**Resource names — a deliberate deviation from upstream**: upstream
resource names are `dmenu.foreground` / `dmenu.background` /
`dmenu.foregroundSel` / `dmenu.backgroundSel`. The theming-engine spec
asks for `dmenu.background` / `dmenu.foreground` / `dmenu.selbackground`
/ `dmenu.selforeground` instead — kept the spec's names verbatim rather
than upstream's, so all four tools share one `sel`-prefix-suffix
convention across their `.Xresources` entries instead of dwm using a
`Sel`-suffix and dmenu using a mix of prefix/suffix.

**Conflict points checked against the other 7 patches** (all clean):

- `colors[SchemeLast][2]` layout (fg/bg per scheme, no border column —
  dmenu has no window border color in its `colors[]`, unlike dwm) is
  untouched structurally; only new `resources[]` entries were added
  that point *into* the existing array.
- The **center** patch's `-nb`/`-nf`/`-sb`/`-sf` CLI flags already write
  into `colors[SchemeNorm/SchemeSel][ColBg/ColFg]` directly (see
  `dmenu.c`'s arg-parsing block) — this establishes CLI-flags-win
  precedence over resources. To preserve that expected precedence
  (X resources are defaults, CLI flags override them, same as e.g.
  xterm), `xresupdate()` runs at the very top of `main()`, *before* the
  CLI arg-parsing loop, using its own short-lived `XOpenDisplay()` /
  `XCloseDisplay()` pair rather than the program's real `dpy` (which
  isn't opened until after arg parsing). This matches upstream's own
  approach — the reference patch does the same "temporary display
  just for resource loading" trick for the same reason.
- fuzzymatch/caseinsensitive/lineheight/numbers/mousesupport/border —
  none touch `colors[]`, `cleanup()`, or the top of `main()`; no
  overlap.

**Build verified**: `make clean && make` — clean compile with
`-std=c99 -pedantic -Wall`, zero warnings.
