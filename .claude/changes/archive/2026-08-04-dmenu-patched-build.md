# 2026-08-04 — Vendor dmenu 5.4 with seven patches, modern centered config

## Scope

- `suckless/dmenu/**` (new vendored tree)
- `scripts/install-suckless.sh`

## What changed

Vendored dmenu **5.4** (latest upstream release, `d893c63`) into `suckless/dmenu/`,
matching the existing dwm 6.8 / st 0.9.3 pattern: plain source tree, no nested
`.git`, upstream `.diff` files kept under `patches/`, `.gitignore` covering
`config.h`, `*.o`, `dmenu`, `stest`.

Seven patches integrated:

| Patch | File used | How it went in |
|-------|-----------|----------------|
| fuzzymatch | `dmenu-fuzzymatch-5.3.diff` | `git apply`, clean |
| mousesupport | `dmenu-mousesupport-5.4.diff` | `git apply`, clean |
| caseinsensitive | `dmenu-caseinsensitive-5.0.diff` | hand-merged |
| numbers | `dmenu-numbers-20220512-28fb3e2.diff` | hand-merged |
| lineheight | `dmenu-lineheight-5.2.diff` | hand-merged |
| center | `dmenu-center-20250407-b1e217b.diff` | hand-merged |
| border | `dmenu-border-20230512-0fe460d.diff` | hand-merged (upstream file is a corrupt diff) |

Only the first two applied mechanically. fuzzymatch rewrites `struct item`,
`usage()` and the `main()` option chain, which is exactly where the other five
patches anchor, so applying any of them afterwards fails on context. They were
merged by hand instead of reordering — reordering only moves which patch breaks.

`config.def.h` rewritten as a documented template: centered floating box
(`centered = 1`, `min_width = 700`, `menu_height_ratio = 3.0`), 2px border
matching dwm's `borderpx`, `lineheight = 28`, `lines = 10` vertical list, and a
palette mirroring `suckless/dwm/config.def.h`.

`scripts/install-suckless.sh` now builds dmenu (`PROGRAMS`, header comment, and
the closing hint line).

## Key technical decisions

- **dmenu 5.4, not git HEAD.** dwm and st are both vendored at release tags.
  `dmenu.c` is unchanged between 5.3 and 5.4 apart from two cosmetic lines, so
  the 5.2/5.3-era patches apply as well to 5.4 as to their nominal target.
- **Counter width is reserved, not overdrawn.** Upstream `numbers` paints the
  counter over whatever is already in the right-hand corner. Combined with
  `center` — where the box is only as wide as its content — that overlaps real
  text. `calcoffsets`, the input field, the horizontal item clamp and the `>`
  arrow all now subtract `TEXTW(numbers)`, and `setup()` seeds `numbers` with
  its widest form (`<total>/<total>`) before computing width so the centered box
  is sized with the corner already accounted for.
- **`buttonpress()` mirrors the same subtraction.** Otherwise the mouse hit
  regions drift from the drawn geometry by the counter's width.
- **Border is reserved in the geometry, not just requested.** `XCreateWindow`
  places the *outside* corner of the border at `(x, y)`, so all four placement
  branches size against `screen - 2 * bw`. Upstream's border patch does not do
  this, and overflows the screen edge by the border width.
- **Signed usable-area locals (`aw` / `ah`).** `bw` is `unsigned`, so
  `height - mh - 2 * bw` wraps to a huge value when a large `-l`/`-h` makes the
  menu taller than the screen. That fed a float divide and landed in `int y`.
- **`-i` kept as an accepted flag.** The caseinsensitive patch replaces `-i`
  with `-s`, which would make every existing script passing `-i` die in
  `usage()`. `-i` now re-asserts the (already case-insensitive) default.
- **`-nc` added.** With `centered = 1` as the default, upstream's `-c` is a
  no-op; `-nc` gives back the edge-to-edge bar from the command line.

## Assumptions made

- **Type B — `lines = 10`.** A centered box with `lines = 0` renders as a single
  centered row, which reads as a stray strip rather than a launcher. Set to a
  10-row vertical list. *If wrong:* `lines = 0` in `config.def.h`, or pass
  `-l 0`. Both were tested.
- **Type B — dmenu added to `install-suckless.sh`.** The request was to pair
  dmenu with the dwm environment; the script is what builds that environment.
  *If wrong:* drop `dmenu` from `PROGRAMS` on line 15.
- **Type C — font left at `monospace:size=10`.** Matches dwm's `dmenufont`, and
  dwm's `dmenucmd` passes `-fn` explicitly anyway. "Comfortable line height" is
  delivered through `lineheight`, which is the knob that actually controls it,
  rather than by guessing at a font that may not be installed.

## Verification

Built clean under the project's own flags (`-std=c99 -pedantic -Wall -Os`), zero
warnings. Under `-Wextra`: 5 warnings vs upstream 5.4's 4 — the extra one is
verbatim upstream mousesupport code. `groff -man` parses `dmenu.1`.

Runtime-tested on `:1`. Note this machine currently runs **Hyprland**, so dmenu
ran under XWayland; geometry was read back with `XGetWindowAttributes` and the
window's own pixels captured with `magick import -window`.

| Check | Result |
|-------|--------|
| centered, 12 items | `700x112+2528+321` — matches computed `x`,`y`,`mh` exactly |
| `-bw 20` | `+2510+309` — the extra 18px on each axis is the reserved border |
| `-nc` | `1916x28+1920+0` — full monitor width less `2 * bw` |
| `-nc -b` | `+1920+1048` — bottom-anchored, border reserved |
| `-h 44 -l 5` | `700x264` — `bh = 44`, `mh = 6 * 44` |
| fuzzymatch | `gmp` → `gimp`, counter `1/12` |
| caseinsensitive | `SIGNAL` → `signal-desktop`; `-s` + `FIRE` → `0/2`; `-i` + `FIRE` → `1/2` |
| numbers | counter tracks matches, clears the `>` arrow in horizontal mode |
| mousesupport | vertical rows and horizontal items select correctly; right-click exits |

**Not verified here:** the border is not *visible* on this machine. XWayland
zeroes `border_width` once the compositor realizes the window — confirmed with a
standalone Xlib probe that reads back `10 → 10 → 0` across the map. The code
path is confirmed live by the geometry shift under `-bw 20`. It will render on a
real X server under dwm, which is the target.

## Trade-offs

- Five of seven patches are hand-merged, so `patches/*.diff` document provenance
  but will no longer apply mechanically to this tree. A future dmenu bump means
  re-merging against the new base, not re-running `git apply`.
- The counter reservation is a deliberate divergence from all three upstream
  patches. It is the cost of making `numbers` and `center` coexist.

## Next steps

1. Build on the real target: `scripts/install-suckless.sh --skip-deps`.
2. Confirm the 2px border renders under dwm on X11.
3. Optional: add `-c`/`-h`/`-bw` to dwm's `dmenucmd` in
   `suckless/dwm/config.def.h` if the compiled-in defaults should be overridden
   per-invocation. Currently dwm passes only `-m`, `-fn` and the four colors, so
   the config defaults apply as-is.

## Protocol note

`.claude/changes/` did not exist in this repo before this entry — created here
per `session-protocol.md`. There is no prior project history to reconcile
against, so no conflict check was possible for this task.
