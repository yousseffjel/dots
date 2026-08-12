# Context — colorpicker-display

## Background
Epic scope-c sub-task 4, the last one. Closes the final two ROADMAP §3 rows and
carries the documentation corrections the Epic accumulated.

## Prior Decisions
- `.claude/tasks/scope-c-roster-gap-fill.md` locked decision 1: **`xcolor` is
  not an option — it does not exist in Fedora** (only `texlive-xcolor`, a LaTeX
  package; verified against packages.fedoraproject.org 2026-08-12). The picker
  is a script instead, matching the seven existing `dwm-*` dmenu scripts and
  reusing maim/ImageMagick/xclip, all already installed. `gpick` (0.4, in
  43/44/Rawhide) goes to `extra.lst` for anyone wanting a real palette tool;
  `gcolor3` was considered and dropped as a redundant middle ground.
- Locked decision 4: **`arandr` is OUT** — `dwm-display` covers the manual
  presets and autorandr (sub-task 3, already merged) covers hotplug.
- Locked decision 6: **`xdotool` is a dependency, not a feature.** It is here
  solely because the picker needs `getmouselocation`. It belongs in
  `desktop.lst` — a dead picker keybind is exactly that tier's criterion. If
  this sub-task were ever dropped, xdotool goes with it.

## References
- `config/dwm/bin/dwm-brightness` — the closest analogue and the style to
  match: `set -euo pipefail`, own `red()` per CLAUDE.md rule 2, `usage()`, a
  `case` dispatch, and long comments explaining *why*. Note its two documented
  traps, both of which apply here: `|| true` around a command substitution
  because `set -e` aborts silently on assignment, and no `awk exit` because it
  SIGPIPEs the producer under pipefail.
- `scripts/theme/colorgen.sh:54-59` — the `magick`-then-`convert` fallback to
  reuse verbatim. Local ImageMagick is **7.1.2**, where `convert` is gone.
- `config/sxhkd/sxhkdrc` — 18 binds today; the ownership note at its top
  explains the dwm/sxhkd split.
- `suckless/dwm/config.def.h:76` — `MODKEY` is **Mod1Mask (Alt)**, not Super.
  dwm's only Super binds are `Mod4Mask|ShiftMask XK_x` (powermenu) and
  `Mod4Mask XK_v` (clipmenu). Everything else Super-side belongs to sxhkd.

## Notes
- **Key check already done at plan time.** Super namespace in use: dwm compiles
  `Super+Shift+x` and `Super+v`; sxhkd holds `w`, `Shift+w`, `Ctrl+w`, `b`, `e`,
  `Ctrl+r`, `l`, plus `Print`/`Shift+Print`. **`super+c` and `super+d` are
  free.** Re-confirm before binding: dwm and sxhkd both `XGrabKey`, and a
  doubly-bound key dies with no error in either log.
- A false alarm worth not repeating: `MODKEY+b`/`MODKEY+l` look like they
  collide with sxhkd's `super+b`/`super+l` until you check line 76 and see
  MODKEY is Alt. The two sets really are disjoint.
- Picker mechanism: `eval "$(xdotool getmouselocation --shell)"` gives `X`/`Y`,
  then `maim -g 1x1+$X+$Y` to a temp PNG, then
  `"$MAGICK" <png> -format '%[hex:p{0,0}]' info:`. dunst can show a swatch via
  a generated PNG passed as `-i`, which is nicer than text alone.
- `dwm-display` presets to offer: internal only, external only, mirror, extend
  left/right — derived from `xrandr` connected outputs rather than hardcoded.
  When `autorandr` is installed, list its saved profiles first.
- Neither script can be truly verified here: no second monitor, and picking a
  pixel needs a live pointer. Shim `xdotool`/`maim`/`xrandr`/`xclip`/`notify-send`
  on PATH per [[dots-testing-via-fake-binary-on-path]] and test the logic; be
  explicit in the change log about what stayed unproven.
- CLAUDE.md's project map enumerates the `dwm/bin` scripts — an enumeration that
  must be updated here (see [[enumerations-are-drift-sites]]).
