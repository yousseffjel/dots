# Progress — screenshot-maim-slop

## Status
`in-progress`

## Steps
- [x] 1. Add `xprop` to `packages/extra.lst` — the active-window ID lookup.
- [x] 2. Write `dwm-screenshot`: modes full/window/region x dest clipboard/file/both, `~/Pictures/screenshots` overridable via `DOTS_SCREENSHOT_DIR`.
- [x] 3. Theme the slop rectangle from `xrdb -query dwm.selbordercolor`, with a fallback to slop's default when unthemed.
- [x] 4. Uncomment and finalise the `Print` / `shift + Print` bindings in `sxhkdrc`.
- [x] 5. Move screenshot out of `KEYBINDINGS.md`'s "Not yet bound" into its own sxhkd section.
- [x] 6. Test: fake maim/slop/xclip/xprop/dmenu on PATH; real sxhkd parse; lint.

## Deviations

- **Steps 2 and 3 landed as one file write** rather than sequentially — the
  slop theming is six lines inside `dwm-screenshot`, not a separable edit.
- **Three fixes came out of the audit, not the plan:** `xclip` was gated at
  startup though `--file` never needs it; `slop`'s stderr was discarded,
  which made a failed pointer grab indistinguishable from a user cancel and
  totally silent; and the destination was only validated in `deliver()`,
  after the capture, so a bogus value wasted a whole region drag.
- **The `*)` arms in `capture()` and `deliver()` were removed** once the
  up-front validation landed — they had become a second copy of the valid-value
  lists, the exact drift the 250-line cap exists to discourage.

## Blockers
