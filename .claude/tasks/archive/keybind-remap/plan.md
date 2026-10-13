# Plan — keybind-remap

## Goal
Remap dwm + sxhkd keys to the user's list (2026-10-13) and replace dmenu_run on
the launcher key with a new `.desktop`-driven GUI app launcher (rofi-drun style).

## Scope
- suckless/dwm/config.def.h, suckless/dwm/dwm.1, suckless/dwm/patches/*
- config/sxhkd/sxhkdrc, config/dwm/bin/*
- tests/*.sh, tests/lib/*.sh
- KEYBINDINGS.md, CHANGELOG.md, CLAUDE.md, docs/*.md, ROADMAP.md, packages/*.lst, scripts/*.sh

## Allowed
## Forbidden
- HyDE/, dwm-titus/

## Steps
1. dwm keys[]: Super+space -> launcher (dwm-apps); Super+Return -> alacritty, zoom -> Super+Shift+Return; Super+Shift+q -> killclient (drop Shift+c); quit -> Super+Shift+Escape; scratchpad hide/show -> Super+Shift+s / Super+s (drop minus); layout-toggle -> Super+Ctrl+space. Update the dynamicscratchpads/dropterm diff records + PATCHES.md + dwm.1 (rule 5).
2. sxhkdrc: Super+Shift+w picker, Super+w random, Super+Shift+t theme (drop Ctrl+w), Super+Shift+l lock (drop Escape), Super+p region->clipboard, Super+Alt+p full->both. Keep Print / Shift+Print.
3. New config/dwm/bin/dwm-apps: XDG data dirs -> Type=Application .desktop, skip NoDisplay/Hidden/OnlyShowIn mismatch, dedupe by desktop-id precedence, strip %field codes, Terminal=true via alacritty -e; dmenu pick -> launch detached. Test with fixture .desktop files (tests/dwm-apps.sh).
4. Tests: key-collisions stays green; dwm-runtime libs press new chords (super+shift+s); dwm-keys + any asserted chord updated.
5. Docs: KEYBINDINGS.md, every live reference to moved keys (dwm-lock, powermenu, desktop.lst consequence text, install-session-report*, THEMING.md, CLAUDE.md, config.def.h header comment), CHANGELOG [Unreleased].
6. Verify: run-tests.sh, lint.sh, build.sh, dwm-runtime.sh under Xvfb.

## Out of scope
- Mouse bindings, tag keys, tmux keys. Packaging a third-party launcher.

## Risks
- Existing installs keep old config.h — install-suckless-headers.sh refreshes an unedited one; note in log.
- Stale references to old chords in docs — grep every old chord after the edit.
- .desktop Exec quoting — execute via sh -c after field-code strip, test with quoted args.
