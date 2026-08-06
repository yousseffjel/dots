# Credits

## HyDE — the wallbash architecture

The theming engine in this repository is a reimplementation of the
**wallbash** design from [HyDE-Project/HyDE](https://github.com/HyDE-Project/HyDE)
(**GPL-3.0** licensed). What was taken is the *architecture*, arrived at
by reading HyDE's source as a reference:

- The `.dcol` template format: line 1 is `target_path|post_command`, the
  body carries `<wallbash_NAME>` placeholders.
- The `always/` vs `theme/` template-group split — always on every
  wallpaper change, theme only on a theme switch.
- The dcol palette naming: `dcol_pry1..4` primaries, `dcol_txt1..4` text
  colours, `dcol_NxaJ` accent ramps, `_rgba` siblings, `dcol_mode`.
- The colour-derivation approach: ImageMagick k-means + histogram
  extraction, text colour by inversion and brightness modulation, accent
  shades generated along a fixed HSB brightness/saturation curve.

**No HyDE code is vendored, copied, or executed here.** This matters
because HyDE is GPL-3.0: copying its sources would place obligations on
this repository that reimplementing the design does not. Every script was
written against this repo's own conventions for a different stack, and
the differences are substantial:

| HyDE | This repo |
| --- | --- |
| Arch + Hyprland + Wayland | Fedora + dwm + X11 |
| waybar, rofi, hyprlock, swaync | dwmblocks, dmenu, slock, dunst |
| Light and dark, mode switching | Dark only, hardcoded |
| `source`s the palette file | Parses it, never executes it |
| `eval`s the template's target path | Plain string substitution |
| Backgrounded post-commands | Synchronous, with visible failures |
| GNU `parallel` | Plain bash job control |
| Colour-curve profiles (vibrant/pastel/mono/custom) | One fixed dark curve |

The security-relevant rows are deliberate: a theme is data, so this
implementation never gives a palette or template file the ability to run
shell code. See `.claude/changes/2026-08-05-theming-apply-templates.md`.

Thanks to the HyDE authors for a genuinely good design.

## Catppuccin — the static dark palette

`themes/dark/colors.dcol` is seeded from the
[Catppuccin](https://github.com/catppuccin/catppuccin) **Mocha** flavour
(MIT licensed) — its base, blue, red and green anchor the four primaries.
The committed file is the output of running this repo's own
`scripts/theme/colorgen.sh` over those seed colours, so the accent ramps
and text colours are this engine's, not Catppuccin's published values.
It is Catppuccin-flavoured rather than a faithful Catppuccin port.

## suckless

dwm, st, dmenu, dwmblocks and slock are from [suckless.org](https://suckless.org)
(MIT/X Consortium licensed), vendored under `suckless/`. The xresources
patches that let them read colours at runtime are adapted from the
upstream patch pages; each tool's `patches/PATCHES.md` credits the
individual patch author and records every deviation.
