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

## The static palettes

Each `themes/<name>/colors.dcol` is seeded from four colours published by an
upstream theme — a background plus three accents — and is then the **output of
running this repo's own `scripts/theme/colorgen.sh` over those seeds**. Only
the four `dcol_pry` values are upstream's; every accent ramp and text colour
comes from this engine's dark curve. They are *flavoured by* these themes
rather than faithful ports, and none of them vendors upstream code.

| Theme | Seeded from | Upstream | Licence |
| --- | --- | --- | --- |
| `dark` | Catppuccin **Mocha** — base, red, blue, green | [catppuccin/catppuccin](https://github.com/catppuccin/catppuccin) | MIT |
| `gruvbox` | dark0 + bright red / aqua / green | [morhetz/gruvbox](https://github.com/morhetz/gruvbox) | MIT/X11 |
| `nord` | Polar Night nord0 + nord11 / nord8 / nord14 | [nordtheme/nord](https://github.com/nordtheme/nord) | MIT |
| `tokyo-night` | night background + red / blue / green | [folke/tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | Apache-2.0 |

Licences verified against each repository's GitHub page on 2026-08-12. Each
palette's own header records the exact seed hex, so it can be regenerated.

## Bibata (cursor theme)

`assets/cursors/Bibata-Modern-Classic.tar.xz` is an **unmodified upstream
release artifact** from [ful1e5/Bibata_Cursor](https://github.com/ful1e5/Bibata_Cursor),
release `v2.0.7`, **GPL-3.0** licensed. Unlike the palettes above — which are
this repo's own output, merely seeded by upstream colours — this one is
upstream's own binary, redistributed as-is.

The GPL-3.0 text is vendored beside it as `assets/cursors/LICENSE.Bibata`,
because the release tarball ships without one. This is aggregation, not
derivation: no Bibata code is linked into or built against anything here, and
it imposes nothing on the rest of this repo. All four `themes/*/theme.conf`
name it as `cursor_theme`. Licence verified against the repository's GitHub
API on 2026-08-13.

## suckless

dwm, st, dmenu, dwmblocks and slock are from [suckless.org](https://suckless.org)
(MIT/X Consortium licensed), vendored under `suckless/`. The xresources
patches that let them read colours at runtime are adapted from the
upstream patch pages; each tool's `patches/PATCHES.md` credits the
individual patch author and records every deviation.
