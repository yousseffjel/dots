# ly-console-colours
Date: 2026-10-12
Files: 5 | Lines: +132/-16

## What changed
- `scripts/theme/ly-theme.sh`: new `console_colour()`. It computes the
  theme colour's HSV hue (integer), picks the nearest of six console hues,
  and writes the RGB the kernel maps exactly to that hue's bright variant
  (`FF5555` … `FF55FF`). Saturation under 1/5 is written as `FFFFFF`.
  `fg` and `border_fg` both pass through it.
- `tests/ly-theme.sh`: restates the kernel's `rgb_foreground()` rule and a
  float HSV hue in awk, independently of the SUT. For every shipped theme it
  asserts two things: the raw accent would be drawn white (the bug), and the
  written value is drawn bright, not white, and within 30° of the accent's hue.
  The awk takes decimal components from bash because `strtonum` is gawk-only.
- `docs/THEMING.md` (table and console paragraph rewritten) and the CHANGELOG
  `[Unreleased]` ly entry.

## Why
After `dots update` and a reboot, the user's screenshot of the VM showed ly
themed (big clock, no version) but with a plain white border. The kernel's VT
lights a colour bit only when that component exceeds half the largest one.
All four shipped accents are pastels with every component over half, so all
four were drawn white, and the colour half of the ly theme had no visible
effect. The previous doc called the result "close to the theme", which was
wrong. The user picked the nearest-console-colour fix over recolouring the
VT palette or going monochrome.

## Assumptions
- Type A, asked: map to the nearest console colour (not setvtrgb, not
  monochrome).
- Type B: the 1/5 saturation threshold for "grey → white". If it is wrong,
  change the `d * 5 < max` test in console_colour.
- Note: nord (`#9AB3E6`, hue ~220°) maps to blue, not cyan as I first guessed
  when asking the user.

## Test coverage
- `tests/ly-theme.sh` passes, with the new per-theme section. The suite
  exits 0 and lint is clean.
- Mutations on copies (7/7 caught): raw border, blue→cyan, blue→magenta,
  pastel table, always-white, floor instead of nearest, not-bright table. The
  first property check let blue→cyan and floor-not-nearest through, so it was
  tightened to the 30° hue check.
- Reviewer: READY, first round.
- NOT verified on the VM yet: the border colour as drawn.

## Follow-ups
- On the VM: `dots update`, reboot, and check that the border is blue.
