# Plan — dwm-bin-tests (2026-09-28; archived as dwm-bin-tests-remaining — the 2026-08-12 task of the same slug is archive/dwm-bin-tests)

## Goal
Seven of nine config/dwm/bin scripts have no test (queued 2026-08-12, with
dwm-brightness named highest value). Cover all seven, as the user asked
2026-09-28: brightness, lock, screenshot each get a file (real logic); the
four thin menu front ends (powermenu, clipmenu, theme, wallpaper) share one.
Everything faked on a SEALED PATH so "not installed" cases cannot fall
through to a real binary, and nothing touches the tester's desktop.

## Scope
- tests/dwm-{brightness,lock,screenshot,menus}.sh
- tests/lib/sealed-path.sh
- TESTING.md, CHANGELOG.md
- .claude/**

## Allowed
## Forbidden
- config/dwm/bin/ (tests only — a finding becomes a follow-up or its own fix)
- scripts/

## Steps
1. tests/lib/sealed-path.sh (seal_path by absolute path; fake)
2. dwm-brightness.sh (fake xrandr --verbose in the real, checked format)
3. dwm-lock.sh and dwm-screenshot.sh
4. dwm-menus.sh (theme/wallpaper from a sandbox copy with fake engine scripts)
5. Mutation-test each script under test (copies only)
6. TESTING.md + CHANGELOG

## Out of scope
- dwm-colorpicker / dwm-display (already tested)

## Risks
- Fakes that call tools missing from the sealed PATH (hit once in drafting: dmenu fake needed cat)
- Theming-engine hazard — dwm-theme/wallpaper exec scripts/theme/*; run from a copy with fakes
