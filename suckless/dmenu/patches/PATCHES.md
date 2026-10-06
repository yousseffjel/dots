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

## dmenu-pathcache-20261006-local.diff

**Source**: written for this repo (2026-10-06); no upstream patch. Touches
`dmenu_path` only — no C, so no conflict with the other patches.

**The bug**: upstream `dmenu_path` rebuilds `~/.cache/dmenu_run` only when
`stest -dqr -n "$cache" $PATH` finds a PATH directory *newer than the cache*.
A directory that **joins** PATH after the cache was written, and is older than
it, is never scanned until something inside it changes. Found on the Fedora 44
VM: `~/.local/share/flatpak/exports/bin` (mtime 13:11) was added to PATH by
`config/zsh/.zshenv`; the cache dated from 13:13, so `dmenu_run` never listed
the Flatpak apps even though dwm's own PATH had the directory.

**The fix**: also rebuild when `$PATH` differs from the PATH the cache was
built for, recorded in `$cache.path` after each rebuild. An install that
predates the patch has no `.path` file yet, so its first run rebuilds once —
which is what clears the stale cache. A PATH that merely changes order also
triggers one rebuild; the output is `sort -u`'d, so that costs one rescan and
nothing else.

**Verified**: `tests/dmenu-path-cache.sh` runs this script and the unpatched
one against the real `stest`, compiled from this directory's `stest.c`.
