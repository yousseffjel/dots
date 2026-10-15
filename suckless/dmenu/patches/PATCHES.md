# dmenu patches — merge notes

Existing patches (border, caseinsensitive, center, fuzzymatch,
lineheight, mousesupport, numbers) were already baked into
`dmenu.c`/`config.def.h` before this project started tracking merge
notes — this file starts from the xresources patch onward.

## dmenu-bidi-20261013-local.diff

**Source**: adapted from upstream's
[bidi](https://tools.suckless.org/dmenu/patches/bidi/) patch
(`dmenu-bidi-20210723-b34d318.diff`, by Eyal Yardeni Seelig), captured
against this tree — the companion of dwm's `dwm-bidi-20261013-local.diff`,
which has the full rationale.

**What**: the same `bidi()` (fribidi reorder + Arabic shaping) applied to
each item in `drawitem()` and to the input line in `drawmenu()`. `config.mk`
gains `FRIBIDIINC`/`FRIBIDILIBS`. `config.def.h` adds
`"Noto Sans Arabic:size=10"` as a second `fonts[]` entry; `-fn` replaces only
`fonts[0]`, so every `dwm-*` menu keeps the Arabic face for the presentation
forms Cascadia lacks.

**Where it departs from upstream**: upstream's output buffer was `BUFSIZ`
bytes for a `BUFSIZ`-byte input, which Arabic overflows (2-byte letters,
3-byte forms). Here input is cut at `BIDI_MAX` (`BUFSIZ - 1`) bytes — far
past anything `drw_text` can show — the output holds 4 bytes per codepoint,
the input copy is zero-padded, and the buffers are static rather than ~96 KB
of stack per call. Pure ASCII returns untouched, so every typed QWERTY query
draws exactly as before.

**Known limit**: only the drawn copy is reordered. Matching and the cursor
work on the logical text, so inside an RTL run the cursor sits at its
logical offset, not under the visual character. Typing is QWERTY-only here,
so that run only appears in pasted text.

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

## dmenu-xyw-20261015-local.diff

**Source**: adapted from upstream's
[xyw](https://tools.suckless.org/dmenu/patches/xyw/) patch
(`dmenu-xyw-5.2.diff`), captured against this tree. Upstream rewrites the
`x`/`y`/`mw` assignments in `setup()`, which the center and border patches
had already rewritten, so it cannot apply here.

**What**: `-x xoffset`, `-y yoffset` and `-z width`. One helper,
`placexyw()`, runs after whichever branch (centered or edge-to-edge) sized
the box, in both the Xinerama and the embedded path, against the same
border-adjusted usable area (`aw`/`ah`) those branches use.

**Where it departs from upstream**:
- A **negative `-x` is the gap from the right edge**. Upstream adds it to the
  monitor's left edge, which puts the window off-screen. `dwm-notify` uses
  `-x -12` to drop the notification centre under the bar's right end.
- `-x`/`-y` given as `0` still count — `dmxset`/`dmyset` record that the flag
  was passed, so `-x 0` pins the left edge even while centered.
- `-z` alone under the default centering keeps the box centered at the new
  width; upstream had no centering to keep.
- The result is clamped onto the monitor, and `-z` is capped at its width.
- `-z` parses into a temporary first: `MAX()` evaluates its argument twice,
  so `MAX(0, atoi(argv[++i]))` advanced `i` twice and crashed on a NULL
  `argv` entry (found while testing this patch).

**Verified**: Xvfb at 1920x1080, `xwininfo` on the mapped window:
`-x -12 -y 30 -z 400 -bw 2` lands at x=1504 (outer right edge 12 px from
the screen edge), `-x 5000 -y 5000 -z 9999` clamps onto the screen, `-b -y
20` counts from the bottom, and the plain default and `-nc` are unchanged.
