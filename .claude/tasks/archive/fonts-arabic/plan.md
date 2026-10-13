# Plan — fonts-arabic

## Goal
Arabic + English font stack for a QWERTY-only user: Noto Sans Arabic / Noto Naskh
Arabic installed, a user fontconfig that hands Arabic to them behind the Latin
families, GTK UI font Noto Sans 10, and fribidi shaping/bidi in dwm's title and
dmenu so Arabic renders joined and right-to-left there. Terminals: documented limit.

## Scope
- packages/*.lst
- config/fontconfig/**
- scripts/symlinks.sh, scripts/install-suckless.sh, scripts/install-restore-flatpak.sh
- themes/*/theme.conf
- suckless/dwm/**, suckless/dmenu/**
- tests/*.sh
- docs/**, CLAUDE.md, CHANGELOG.md, README.md

## Allowed

## Forbidden
- HyDE/, dwm-titus/

## Steps
1. Packages: Arabic vf fonts in desktop.lst (with consequence text), fribidi-devel in build.lst, pacman/apt fallbacks in install-suckless.sh.
2. config/fontconfig/fonts.conf (aliases + lang=ar prefs + rendering) linked by symlinks.sh; fix Flatpak comment.
3. All four theme.conf: font=Noto Sans 10.
4. dwm: hardened fribidi on the title (dwm.c, config.mk) + -local diff + PATCHES.md.
5. dmenu: same for items + input (dmenu.c, config.mk) + -local diff + PATCHES.md.
6. tests/fontconfig-stack.sh: fonts.conf parses, every family it names is packaged, Arabic resolves when installed; build check for fribidi linkage.
7. docs/FONTS.md (terminal limit, QWERTY), CLAUDE.md map, CHANGELOG [Unreleased].

## Out of scope
- Arabic XKB layout / input method (user types QWERTY only)
- st/alacritty shaping (decided: document the limit)
- dwm status text / tags bidi (dwmblocks output is ASCII + glyphs)

## Risks
- Upstream patches overflow (3-byte presentation forms into 256-byte buffer) — size output 4n+1, test with a long Arabic title.
- Presentation-forms glyphs missing from the bar font — verify coverage with fc-query; Noto Sans Arabic as fallback in fonts[].
- symlinking ~/.config/fontconfig clobbers user config — symlinks.sh already backs up.
