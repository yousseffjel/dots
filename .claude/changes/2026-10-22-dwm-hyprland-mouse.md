# dwm-hyprland-mouse
Date: 2026-10-22
Files: 17 | Lines: +1483/-122 (seven new files: six patch records, one test lib)

## What changed
- **cfacts** (bakkeby 6.6, `dwm-cfacts-6.6-d99bbe2.diff`): `Client.cfact`,
  weighted `tile()`, `setcfact()` on `Super+Shift+k`/`j`/`o` (taller /
  shorter / reset).
- **resizepoint** (bakkeby 6.6): `Super` + right-drag on a floating window
  resizes from the corner nearest the grab, never warps the pointer, shows a
  per-corner cursor, and skips size hints while dragging.
- **dragtile** (local): `Super` + right-drag on a tiled window — x moves the
  master split (mfact, pertag slot), y moves the grabbed edge by trading
  cfact with the neighbour on that side. Retires `dwm-dragmfact-6.2.diff`
  (its warp-to-split behaviour is gone from `resizemouse()`).
- **placemouse** (bakkeby 6.6): `Super` + left-drag = `moveorplace {.i = 1}`;
  a tiled window is re-inserted next to the window under its centre and
  stays tiled, across monitors; floating windows still use `movemouse()`.
- **snapwindows** (local): floating move and resize snap to other visible
  windows' edges within `windowsnap` = 10 px (`snap` = 32 stays for screen
  edges).
- **preservecfact** (local): `_DWM_CLIENT_INFO` gains a 16th value (cfact
  x1000, range-checked); 7- and 15-value records are still read.
- `config.def.h`: the duplicated `ClkTagBar` `MODKEY` Button1/Button3 rows
  removed (the pair at the end of `buttons[]` stays).
- Records: six `.diff` files + `PATCHES.md` entries (one section, merge
  notes and deviations), retired-dragmfact note, preserveonrestart's
  "15 values" paragraph superseded by an appended one. `KEYBINDINGS.md`,
  `CHANGELOG.md` [Unreleased], `CLAUDE.md` roster (20 → 25 dwm diffs),
  `TESTING.md` entry appended.
- New `tests/lib/dwm-runtime-mouse.sh` (`check_mouse`, tag 9), called by
  `tests/dwm-runtime.sh` after `check_launch_keys`.

## Why
The user asked for Hyprland's mouse freedom (`Super` + drag to move and
resize, placing windows anywhere) in dwm, and chose the complete option
(items 1+2+3+4) after a comparison against the Hyprland wiki
(configuring/core/dispatchers: `drag()`, `resize()`; config-options:
`general.snap.*`). dwm already had `Super` + LMB/RMB, but resize warped the
pointer to the bottom-right corner, moving a tiled window floated it, tiled
resize covered only the master width, and nothing snapped to other windows.

## Key Technical Decisions
- **Tiled windows stay tiled when dragged** (Hyprland semantics; Type B).
  Floating a tiled window is `Super` + middle-click.
- **dragcfact not merged**: it drives cfact from both axes and warps the
  pointer to the window centre. dragtile replaces it.
- **Edge-pair trade, not column rescale**: only the grabbed edge moves; the
  rest of the column is untouched.
- **cfact keys on `Super+Shift+k`/`j`/`o`**: upstream's `Super+Shift+l` is
  sxhkd's lock.
- **placemouse deviations**: refreshrate throttle; `hashome = 0` on both
  monitor changes (replug); a failed `getrootptr()` after the grab now
  ungrabs and clears `beingmoved` (upstream froze the window).

## Assumptions Made
- Type B: tiled-stays-tiled on drag (the open question from the comparison
  was not answered; Hyprland's behaviour chosen). If wrong: bind
  `movemouse` back on `MODKEY Button1` in `config.def.h`.
- Type B: `windowsnap` = 10 px (Hyprland's `window_gap` default).

## Test coverage
- `tests/run-tests.sh`: 107/107 OK (the /test gate), incl. `dwm-runtime.sh`
  with 10 new checks (resizepoint corner + no warp, snapwindows, free move,
  dragtile vertical + horizontal + no warp, placemouse, cfacts keys,
  preservecfact across a restart, reset), `dwm-multimon.sh`, `dwm-keys.sh`,
  `lint.sh`; `tests/build.sh` builds every suckless program.
- Mutation check in scratch copies (never the worktree): stock dwm and the
  final tree minus each local diff. Each fails its own check. The first
  dragtile-horizontal check passed without dragtile (the master window was
  resized over the stack); it now also asserts the stack starts where the
  master ends.
- Each local `.diff` reverse-applies cleanly to the final tree
  (`patch -R --dry-run`).
- Reviewer: WARN. (1) "tag/toggletag bindings dropped" was a false
  positive — only the duplicate pair went; (2) resizepoint skipping size
  hints is intended and recorded.
- Not verified on a real desktop or the Void VM: the drags ran under Xvfb.

## Trade-offs
- Floating resizes ignore size hints (terminals end between cell sizes);
  smooth over stepped, as upstream resizepoint chose.
- Window snapping also counts tiled windows, which cover the screen; 10 px
  keeps that from grabbing too eagerly.

## Next Steps
- On main after merge: `make -C suckless/dwm` (or
  `scripts/install-suckless.sh --skip-deps`), restart dwm, and feel-test the
  drags; tune `windowsnap` if snapping to tiled windows gets in the way.
- Fold this log into `CURRENT_AUDIT.md`; add a Recently Closed line to
  `MASTER_PLAN.md`.
- Not done, by scope: border drag without `Super`, aspect-ratio resize,
  keyboard move/resize of floating windows, keeping client order across a
  restart.
