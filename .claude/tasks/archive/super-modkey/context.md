# Context — super-modkey

## Background
User request 2026-10-12: switch dwm from Alt to Super ("super key be the super
key to my keybinding"). Decisions: sxhkd keys move (not dwm's); existing
installs refreshed at build time, not via a release + migration.

## Prior Decisions
- Scope G decision 1: regenerate a generated header ONLY when byte-identical to
  some past *.def.h in git history; keep an edited one and print what to merge.
- Collisions: a key grabbed by both dwm and sxhkd dies with no error.

## References
- scripts/migrations/0.1.0-to-0.2.0.sh (rule source, left untouched)

## Notes
- tmux Alt+h/j/k/l, Alt+1..9, Alt+Tab were shadowed by dwm's Alt binds; freed now.
- Mod4Mask lines (powermenu/clipmenu/dropterm) stay as written — they match the
  vendored diffs and equal MODKEY now.
