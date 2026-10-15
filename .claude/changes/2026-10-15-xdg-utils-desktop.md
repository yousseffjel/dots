# xdg-utils-desktop — declare xdg-utils in the desktop tier

Date: 2026-10-15
Files: 2 | Lines: +4/-2

## What changed
- `packages/desktop.lst`: `xdg-utils` after `jq`, with consequence text — links
  never open (notification centre "open", dunst's link menu).
- `CHANGELOG.md`: the [Unreleased] jq line now names xdg-utils too.

## Why
Follow-up from `2026-10-15-notify-center.md`: `dwm-notify`'s open calls
`xdg-open` for a notification's link and skips it silently when missing, and
dunstrc's `browser = /usr/bin/env xdg-open` had the same undeclared dependency.
Silent absence is exactly the desktop.lst criterion. User decision, 2026-10-15.

## Key Technical Decisions
- desktop.lst (red closing summary), not extra.lst: the failure is otherwise silent.
- dwm-notify's `command -v xdg-open` guard kept — a failed install still degrades
  to "re-show only" rather than an error.

## Assumptions Made
- none

## Test coverage
- Name verified on mdapi: xdg-utils 1.2.1 in f43 and f44.
- `tests/desktop-consequences.sh`, `tests/pkglist.sh`, `tests/lint.sh --strict`: pass.

## Follow-ups
- none
