# Plan — super-modkey

## Goal
Every keybinding is on Super. dwm's MODKEY becomes Mod4Mask; the four sxhkd
chords that would then be grabbed twice move (firefox Super+Shift+b, lock
Super+Escape, display Super+Shift+d, emoji Super+semicolon). Existing installs
pick it up because the build now refreshes an unedited, stale config.h.

## Scope
- suckless/dwm/config.def.h
- config/sxhkd/sxhkdrc
- config/dwm/bin/dwm-keys
- KEYBINDINGS.md
- scripts/install-suckless*.sh
- tests/*.sh
- tests/lib/dwm-runtime*.sh
- CHANGELOG.md
- suckless/dwm/patches/PATCHES.md
- docs/*.md

## Allowed

## Forbidden
- HyDE/
- dwm-titus/
- scripts/migrations/0.1.0-to-0.2.0.sh

## Steps
1. config.def.h: MODKEY Mod1Mask -> Mod4Mask.
2. sxhkdrc: move the 4 colliding chords; rewrite the "checked free" comments.
3. KEYBINDINGS.md, dwm-keys (Mod shown as Super), PATCHES.md/docs Alt refs.
4. New tests/key-collisions.sh: no chord grabbed by both dwm and sxhkd.
5. Tests: dwm-keys.sh + dwm-runtime libs press super+, not alt+.
6. scripts/install-suckless-headers.sh: build-time refresh of unedited stale
   generated headers (scope G decision 1 rule); test; wire into the build.
7. CHANGELOG [Unreleased]; run suite + lint.

## Out of scope
- ly theming (its own slot); tmux Alt bindings (now unshadowed, unchanged).

## Risks
- Double grab dies silently — step 4 test parses both sides.
- Stale config.h on test host compiles old MODKEY — rm config.h before build.
