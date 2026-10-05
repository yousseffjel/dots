# volume-brightness-osd
Date: 2026-10-05
Files: 6 | Lines: about +230/-6 (two new files)

## What changed
- `config/dwm/bin/dwm-osd` (new): `volume|mic|brightness`. Reads the level
  (`pamixer`, `pamixer --default-source`, `dwm-brightness get`) and sends one
  `dunstify` notification with `x-dunst-stack-tag:dwm-osd-<kind>` and
  `int:value:<n>`. Muted shows "muted" with no bar. No dunstify, no audio
  server or a non-numeric reading is a silent exit 0.
- `config/sxhkd/sxhkdrc`: the six volume/mic/brightness bindings end in
  `; dwm-osd <kind>`.
- `tests/dwm-osd.sh` (new): sealed PATH, fake pamixer/dwm-brightness/dunstify.
- `KEYBINDINGS.md`, `CHANGELOG.md`, and `CLAUDE.md`'s project map.

## Why
Item 4 of the post-VM follow-ups, "volume/brightness pop-up" row, ⭐ option
chosen by the user: no new package, themed through the existing dunst
template (which already set `progress_bar = true`).

## Assumptions
- Type B: `;` not `&&` before `dwm-osd`, so the pop-up shows even when
  dwmblocks is not running to be signalled.
- Type B: one stack tag per kind, so a volume and a brightness pop-up never
  replace each other.
- Type B: 1500 ms timeout, low urgency.
- Bar clicks on the VOL/MIC blocks do not show the pop-up; the bar already
  shows the change there.

## Test coverage
- `tests/dwm-osd.sh`: 15 checks. Mutations caught 4/5: a shared tag, mute
  ignored, mic reading the sink, no numeric guard. The surviving one (drop
  the `command -v dunstify` guard) is behaviour-neutral: `notify` already
  swallows a failed dunstify.
- `tests/run-tests.sh`: 30/30. Lint passed. Reviewer: READY.

## Follow-ups
- On the VM the VOL and MIC blocks read `n/a`: pamixer reaches no audio
  server there (likely no sound device in the VM). The volume pop-up will
  show nothing on the VM for the same reason; brightness will work.
