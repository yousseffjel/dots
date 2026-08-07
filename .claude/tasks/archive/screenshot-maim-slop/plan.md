# Plan — screenshot-maim-slop

## Goal
Roster Epic sub-task 5. Ship `config/dwm/bin/dwm-screenshot` — a two-level
dmenu (mode -> destination) over maim + slop + xclip, slop themed from xrdb —
and activate the `Print` bindings sxhkd already reserves.

## Scope
- config/dwm/bin/dwm-screenshot
- config/sxhkd/sxhkdrc
- packages/extra.lst
- KEYBINDINGS.md

## Allowed
- config/dwm/bin/dwm-screenshot
- config/sxhkd/sxhkdrc
- packages/extra.lst
- KEYBINDINGS.md

## Forbidden
- suckless/
- scripts/

## Steps
1. Add `xprop` to `packages/extra.lst` — the active-window ID lookup.
2. Write `dwm-screenshot`: modes full/window/region x dest clipboard/file/
   both, `~/Pictures/screenshots` overridable via `DOTS_SCREENSHOT_DIR`.
3. Theme the slop rectangle from `xrdb -query dwm.selbordercolor`, with a
   fallback to slop's default when unthemed.
4. Uncomment and finalise the `Print` / `shift + Print` bindings in `sxhkdrc`.
5. Move screenshot out of `KEYBINDINGS.md`'s "Not yet bound" into its own
   sxhkd section.
6. Test: fake maim/slop/xclip/xprop/dmenu on PATH; real sxhkd parse; lint.

## Out of scope
- Sub-task 6's lock binding, still commented out.

## Risks
- No dwm rebuild — `config.def.h` untouched, `Print` is unbound in dwm.
- `set -e` + `var="$(cmd)"` aborts silently; every capture read needs `|| true`.
