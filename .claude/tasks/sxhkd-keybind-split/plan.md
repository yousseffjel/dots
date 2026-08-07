# Plan — sxhkd-keybind-split

## Goal
sxhkd owns every keybind dwm lacks: media, volume/mic, brightness, theming, two
app launchers. dwm's active bindings are untouched, so no dwm rebuild is needed.

## Scope
- config/sxhkd/*
- config/dwm/bin/*
- scripts/*.sh
- KEYBINDINGS.md

## Allowed
- config/sxhkd/*
- config/dwm/bin/*
- scripts/symlinks.sh
- scripts/install-suckless.sh
- packages/extra.lst
- suckless/dwm/config.def.h
- KEYBINDINGS.md
- docs/THEMING.md
- CLAUDE.md

## Forbidden
- suckless/dwm/dwm.c
- packages/core.lst

## Steps
1. `config/sxhkd/sxhkdrc` — media/volume/mic (+ dwmblocks RTMIN+7/8), theming, firefox/thunar, reload; screenshot + lock blocks commented for sub-tasks 5/6.
2. `config/dwm/bin/dwm-brightness` — xrandr gamma get/set with clamping, fires RTMIN+6.
3. `scripts/symlinks.sh` — add `config/sxhkd` to `LINKS`.
4. `scripts/install-suckless.sh` — launch sxhkd from the autostart template; yellow "add it yourself" branch when autostart.sh already exists. **DEVIATION:** the additions pushed the file to 253 lines, over the 250 cap; session wiring extracted to `scripts/install-session.sh` (user-approved).
5. `packages/extra.lst` — drop `brightnessctl`, document it under NOT LISTED HERE.
6. `suckless/dwm/config.def.h` — replace the commented theming keybind block with a pointer to sxhkdrc (comment-only, no active bind change).
7. `KEYBINDINGS.md` — sxhkd section + who-owns-what note.
8. **Added mid-task (user-approved):** correct `docs/THEMING.md` and `CLAUDE.md`, which still tell the reader to uncomment theming binds that now collide with sxhkd.

## Out of scope
- dwm-screenshot and lock wiring (sub-tasks 5/6); statusbar blocks (sub-task 7).

## Risks
- Double grab: a keysym bound in both dwm and sxhkd silently dies — keep the sets disjoint, verified against `config.def.h`.
- `autostart.sh` is user-owned once it exists (CLAUDE.md rule 6) — never rewrite it; print the line instead.
