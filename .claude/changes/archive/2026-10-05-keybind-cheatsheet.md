# keybind-cheatsheet
Date: 2026-10-05
Files: 6 | Lines: about +210/-4 (two new files)

## What changed
- `config/dwm/bin/dwm-keys` (new): a dmenu list of every keybinding,
  parsed by awk at runtime from the `| Keys | Action |` and
  `| Action | Effect |` tables of `KEYBINDINGS.md`. Format:
  `<key padded to 32> <action>  [<### section>]`; `Mod+` shown as `Alt+`.
  Found through `readlink -f` of itself (`~/.config/dwm` is a linked dir);
  `DWM_KEYS_DOC` overrides it for tests. A missing doc is exit 1 plus a
  critical notification, never an empty menu. Display only.
- `config/sxhkd/sxhkdrc`: `super + slash` → `dwm-keys` (checked free in
  both grabbers).
- `KEYBINDINGS.md`: new `### Help` section with the Super+/ row.
- `tests/dwm-keys.sh` (new): fake dmenu, the real doc. Content checks, and
  every `sxhkdrc` binding (22) must have a row.
- `CHANGELOG.md`, `CLAUDE.md` project map.

## Why
Item 4 of the post-VM follow-ups, keybind cheat sheet row, ⭐ option chosen
by the user. KEYBINDINGS.md already said "nothing keeps them in sync
automatically"; now that the doc feeds a runtime feature, the sxhkd half is
held to it by a test.

## Assumptions
- Type B: the source is KEYBINDINGS.md rather than parsing sxhkdrc and
  config.def.h, because only the doc carries a description of each key.
- Type B: display only — picking a line does nothing.

## Test coverage
- `tests/dwm-keys.sh` passes. Mutations caught 7/7, including two doc
  mutations (a removed `Super+c` row and a removed `Super+/` row). Two
  checks were vacuous on the first draft (an empty menu passed the
  "no leaks" checks; the status-bar check looked at a column the parser
  never reads); both were tightened and re-mutated.
- `tests/run-tests.sh`: 32/32. Lint passed. Reviewer: READY.

## Follow-ups
- The same completeness check for dwm's `config.def.h` (XK_ names, TAGKEYS
  macro) is not done.
