# emoji-picker
Date: 2026-10-05
Files: 7 | Lines: about +230/-4 (two new files)

## What changed
- `config/dwm/bin/dwm-emoji` (new): awk over
  `/usr/share/unicode/emoji/emoji-test.txt`, keeping data lines with
  `; fully-qualified`, as `<emoji> <name>  [<group>]`; dmenu; the pick is
  copied with `xclip -selection clipboard` (no trailing newline) and
  confirmed with `notify-send`. Missing data or xclip: critical
  notification, exit 1. Escape: exit 0, nothing copied.
- `config/sxhkd/sxhkdrc`: `super + period` → `dwm-emoji`.
- `packages/desktop.lst`: `unicode-emoji` with consequence text, under a new
  "emoji picker, keybound" section.
- `KEYBINDINGS.md`: `### Emoji` section (the dwm-keys test requires it).
- `tests/dwm-emoji.sh` (new): a fixture in the real v18.0 format.
- `CHANGELOG.md`, `CLAUDE.md` project map.

## Why
Item 4 of the post-VM follow-ups, emoji picker row, ⭐ option chosen by the
user (dmenu over Unicode's data, not rofimoji).

## Assumptions
- Type B: copy only, never typed into the focused window.
- Type B: `unicode-emoji` goes in `desktop.lst` (it backs a keybind and
  would otherwise fail quietly), the colour font stays in `extra.lst`
  (without it the names still show and the copy still works).
- Rule 8: `unicode-emoji` 18.0.0 verified on mdapi.fedoraproject.org for
  f43 and f44, with the file list confirming the data path.

## Test coverage
- A real run against Unicode's emoji-test.txt v18.0 (fetched from
  unicode.org) listed 3963 entries, the file's own fully-qualified count.
- `tests/dwm-emoji.sh`: mutations caught 7/7 meaningful ones. One mutation
  (dropping the leading-code-point guard) survived because the real file
  has no comment line with "; fully-qualified"; the guard is defensive, and
  its comment now says so instead of claiming it does the filtering. A
  bare-word match is caught.
- `tests/run-tests.sh`: 33/33. Lint passed. Reviewer: READY.

## Follow-ups
- none
