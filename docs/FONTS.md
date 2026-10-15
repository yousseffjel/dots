# Fonts — English and Arabic

dots renders two scripts: English in a Latin face, and Arabic in a matching
Noto Arabic face behind it. The keyboard is **QWERTY only**: there is no
Arabic XKB layout and no layout switch, so Arabic reaches the desktop as text
you read or paste, never as something you type.

## The stack

| Surface | English | Arabic | Configured in |
| ------- | ------- | ------ | ------------- |
| GTK apps (Thunar, dialogs, menus) | Noto Sans 10 | Noto Sans Arabic | `themes/*/theme.conf` `font=`, then fontconfig fallback |
| Browser / anything asking for `sans-serif` | Noto Sans | Noto Sans Arabic | `config/fontconfig/fonts.conf` |
| … asking for `serif` | Noto Serif | Noto Naskh Arabic | `config/fontconfig/fonts.conf` |
| … asking for `monospace` | Cascadia Code NF | Noto Sans Arabic | `config/fontconfig/fonts.conf` |
| dwm bar, dmenu and every `dwm-*` menu | Cascadia Code NF | Noto Sans Arabic | `fonts[]` in `suckless/{dwm,dmenu}/config.def.h` |
| alacritty, st | Cascadia Code NF | Cascadia's own Arabic letters, **unjoined** | see [Terminals](#terminals) |

Text explicitly tagged Arabic (an HTML `lang="ar"` page, a GTK label under an
Arabic locale) goes to the Arabic face *first*, so its digits and punctuation
match the script around them. Everything else reaches the Arabic face by
fallback: the Latin face has no Arabic glyphs, and `fonts.conf` puts the
Arabic face directly behind it, ahead of whatever the system ranks next
(DejaVu Sans on most installs, whose Arabic is a minimal fallback set).

Every Noto face comes from one Void package, `noto-fonts-ttf`, declared in
`packages/desktop.lst` because without it Arabic silently renders as tofu.
Cascadia Code NF is not packaged on Void: it is vendored in `assets/fonts/`
and extracted to `~/.local/share/fonts/` by the restore stage (see that
directory's README.md). `tests/fontconfig-stack.sh` fails the build if any
family named anywhere in the repo is neither installed by some list nor
vendored, and `tests/font-asset.sh` checks the vendored faces really register
as `Cascadia Code NF`.

## fontconfig

`config/fontconfig/` is symlinked to `~/.config/fontconfig` by
`scripts/symlinks.sh`, so an edit there applies to the next app you start.
An existing `~/.config/fontconfig` is moved to `~/.dotfiles-backup/` first,
like every other linked directory, and `symlinks.sh --restore` puts it back.

Besides the families, `fonts.conf` sets the rendering: antialiasing with
`rgb` subpixel order, slight hinting, the default LCD filter. Those values must
agree with the `Xft/*` keys `xsettingsd` serves to GTK
(`theme_write_xsettingsd_conf` in `scripts/install-restore-theme-identity.sh`):
xsettingsd reaches only GTK, `fonts.conf` reaches everything else.

**Flatpak apps get the same stack.** `install-restore-flatpak.sh` grants
`xdg-config/fontconfig:ro`; Flatpak follows the symlink and mounts the file
into each app's own config directory, where the sandbox's fontconfig loads
it. Checked against Flatpak 1.18 on 2026-10-13.

## dwm and dmenu: bidi and shaping

Xft draws codepoints left to right, exactly as given. On its own that renders
an Arabic window title as isolated letters in reverse order. dwm's title and
dmenu's items and input line therefore go through `bidi()` first, from the
`bidi-local` patches (`suckless/{dwm,dmenu}/patches/PATCHES.md`). It uses GNU
FriBiDi to reorder the text into visual order and shape Arabic into its
joined presentation forms. Mixed lines follow the Unicode bidi algorithm: in
`Firefox — محادثة` the Latin run stays on the left.

The shaping emits Arabic Presentation Forms-B (U+FE70–FEFF), which Cascadia
Code NF does not carry, so both programs name `Noto Sans Arabic` as their
second `fonts[]` entry. `-fn` replaces only the first, so every `dwm-*` menu
keeps it.

Two limits:

- **dmenu's cursor** sits at its *logical* offset inside an Arabic run. Only
  the drawn copy is reordered; matching works on the real text. With a
  QWERTY-only keyboard that run only appears in pasted text.
- **The bar's status blocks and tag labels are not reordered.** dwmblocks
  emits ASCII and Nerd glyphs, and the tags are digits.

## Terminals

**alacritty and st cannot shape Arabic or lay it out right to left**, and no
patch fixes that properly: shaping changes glyph widths and order, which
breaks a terminal's fixed character grid, so cursor movement and selection on
mixed lines go wrong. Cascadia Code NF does include the base Arabic letters,
so Arabic in a terminal shows as legible but **unjoined letters, left to
right**. Read Arabic in a GTK app or the browser instead.

This was a decision, not an oversight (2026-10-13). The alternative was a
second, VTE-based terminal (ptyxis or gnome-terminal), which does have real
BiDi and shaping, at the cost of a GTK4/VTE stack beside alacritty. Revisit it
if Arabic in the terminal turns out to matter.

## Changing a font

- **The UI font:** `font=` in the active theme's `theme.conf`, then
  `dots theme <name>` to re-render `settings.ini` and `xsettingsd.conf`.
- **A generic family:** the `<prefer>` lists in `config/fontconfig/fonts.conf`.
- **The bar or dmenu:** `fonts[]` in `config.def.h`, then
  `scripts/install-suckless.sh --skip-deps`.

Whichever you change, add the new family's package to `packages/*.lst` and
its name to `FAMILY_PKG` in `tests/fontconfig-stack.sh` (or, for a vendored
font, to `FAMILY_VENDORED`). Then check what
fontconfig actually picks:

```sh
fc-match sans-serif            # Noto Sans
fc-match 'sans-serif:lang=ar'  # Noto Sans Arabic
fc-match 'serif:lang=ar'       # Noto Naskh Arabic
fc-match monospace             # Cascadia Code NF
```
