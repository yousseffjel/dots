# Plan — colorpicker-display

## Goal
Close Epic scope-c: a colour picker and a display-preset menu as dmenu-idiom
`dwm-*` scripts, plus the ROADMAP §3 corrections the whole Epic earned —
including that `xcolor`, which §3 names, does not exist in Fedora.

## Scope
- config/dwm/bin/dwm-*
- config/sxhkd/sxhkdrc
- packages/*.lst
- KEYBINDINGS.md
- ROADMAP.md
- CLAUDE.md

## Allowed

## Forbidden
- suckless/dwm/config.def.h
- scripts/install-session.sh

## Steps
1. Declare `xdotool` (desktop.lst) and `gpick` (extra.lst) with their comments.
2. Write `dwm-colorpicker`; reuse colorgen.sh's magick/convert fallback.
3. Write `dwm-display` — xrandr presets, autorandr profiles when present.
4. Bind `super + c` and `super + d` in sxhkdrc.
5. KEYBINDINGS.md entries for both.
6. ROADMAP §3: mark the rows this Epic closed, correct the `xcolor` row.
7. CLAUDE.md dwm/bin list; full suite + `tests/lint.sh --strict`.

## Out of scope
- Rebinding dwm's config.def.h (Forbidden — needs a rebuild, and the Super
  namespace is already disjoint).

## Risks
- Neither script is fully verifiable without a live X session; shim the
  binaries on PATH, test the logic, and say plainly what stayed unproven.
- `super+c`/`super+d` checked free at plan time. Re-check before binding — a
  doubly-grabbed key dies silently, with no error in either log.
- ImageMagick 7 drops `convert`; reuse colorgen.sh's `magick`-first fallback.
- `dwm-display` must degrade when autorandr is absent, not fail.
