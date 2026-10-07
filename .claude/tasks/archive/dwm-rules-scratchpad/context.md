# Context — dwm-rules-scratchpad

## Background
Scope F slot 1. Locked decisions + xprop class table: main worktree
`.claude/tasks/scope-f-desktop-integration.md` (decisions 3, 4, 6, 7, 8).

## Prior Decisions
- Rule 5: sources pre-patched; `.diff` + PATCHES.md are the record.
- dynamicscratchpads replaced scratchpads 2026-08-07; bit LENGTH(tags).
- MODKEY = Mod1 (Alt); Super chords dwm owns: Shift+x, v — sxhkd must stay disjoint.

## References
- scripts/theme/reload.sh:117 reload_dwm (SIGHUP every wallpaper change)
- suckless/dwm/dwm.c manage() 1414, scan() 1926, applyrules() ~403
- tests/dwm-runtime.sh header lines 30-36 (the original F5 note)

## Notes
- blueman-manager is DIALOG-typed → already floats; no rule.
- Firefox class is `org.mozilla.firefox` (VM, 2026-10-07).
