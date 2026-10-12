# Plan — ly-console-colours

## Goal
ly's themed colours were invisible on the VM: the Linux VT maps 24-bit colour
to its 16 by a component-threshold rule, so every pastel theme accent became
white. Map each theme colour to the hue-nearest console colour and write the
RGB the kernel maps exactly to that colour's bright variant.

## Scope
- scripts/theme/ly-theme.sh
- tests/ly-theme.sh
- docs/THEMING.md
- CHANGELOG.md

## Allowed

## Forbidden

## Steps
1. console_colour(): hue -> nearest of red/yellow/green/cyan/blue/magenta,
   low saturation -> white; emit the kernel-exact bright RGB.
2. Test: each shipped theme's border renders as the colour the kernel's own
   rule (reimplemented from vt.c, separately) puts on screen, never white
   unless the accent is grey.
3. Docs + CHANGELOG; suite + lint.

## Out of scope
- Recolouring the VT palette (setvtrgb).

## Risks
- Hue rule disagrees with eyes on borderline hues — test pins each theme.
