# Context — pertag-restart

## Background
Scope G slot 2 (main: `.claude/tasks/scope-g-release-0.2.0.md`). Follows the
2026-10-07 dwm-rules-scratchpad log follow-up "persist pertag's per-tag
mfact/layout across a restart".

## Prior Decisions
- preserveonrestart: saved once on the restart path (savestate), read once
  (delete=True), private atoms, view restored through view().
- wakeonsignal: restarts are immediate; tests send no wake event.
- Rule 5: sources pre-patched; a change = sources + .diff + PATCHES.md.

## References
- suckless/dwm/dwm.c: struct Pertag, createmon() pertag init, view(),
  savestate(), restorestate().
- tests/lib/dwm-runtime-restart.sh (check_preserve), dwm-runtime-x.sh restart_dwm.

## Notes
- Pertag arrays have LENGTH(tags)+1 entries (index 0 = all-tags view).
