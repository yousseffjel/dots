# Plan — dynamic-scratchpads

## Goal
Epic sub-task 11. Replace the pre-declared `scratchpads` patch with
`dynamicscratchpads`: stash the focused window whatever it is, cycle stashed
windows back, drop one out. Both claim bit `LENGTH(tags)` of the tag bitmask,
so this is a swap — un-bake the old one from `dwm.c`, capture a new local diff.

## Scope
- suckless/dwm/{dwm.c,config.def.h}, suckless/dwm/patches/**, KEYBINDINGS.md

## Allowed
- suckless/dwm/dwm.c, suckless/dwm/config.def.h
- suckless/dwm/patches/, KEYBINDINGS.md

## Forbidden
- config/sxhkd/ (dwm and sxhkd both XGrabKey — a double-bound key dies silently)
- scripts/, config/theme/, packages/, suckless/st|dmenu|dwmblocks|slock

## Steps
1. Un-bake static scratchpads from `dwm.c`: `NUMTAGS`, `SPTAG`, `SPTAGMASK`,
   `togglescratch` (decl + body) and its 3 call sites; restore vanilla `TAGMASK`.
2. Un-bake from `config.def.h`: `Sp` typedef, `spcmd1..3`, `scratchpads[]`,
   3 `rules[]` entries, 3 `togglescratch` keybinds.
3. Hand-merge dynamicscratchpads into `dwm.c`: `SCRATCHPAD_MASK`, its 6
   functions, `NumTags` guard 31 -> 30.
4. Add its 3 keybinds to `config.def.h` (`XK_minus`, `XK_equal` — both free).
5. Capture `dwm-dynamicscratchpads-<date>-local.diff`, delete the retired
   `dwm-scratchpads-20200414-728d397b.diff`, update `PATCHES.md`.
6. `KEYBINDINGS.md`: new bindings, removed ones, and the rebuild note.
7. Verify: `make clean && make`, no orphan `SPTAG`/`spcmd` refs, tag maths.

## Out of scope
- namedscratchpads (scope file locked dynamicscratchpads).
- Rebinding anything in sxhkd — the patch's default keys are unused.

## Risks
- Hand-merge: 2020 patch vs dwm 6.8, 11 patches deep. `patch -p1` will not
  apply; same local-diff route as `dwm-xresources-20260805-local.diff`.
- Losing `Mod+y` spterm, the one scratchpad that works today.
