# Context — xinitrc-clipmenud-cleanup

## Background
User screenshot 2026-10-07: after logout the ly TTY floods with
"Can't open X display" / "xsel: Can't open display: (null) : Connection refused".

## Prior Decisions
- 2026-10-06 portal-session-target: EXIT trap + `trap 'exit 0' HUP INT TERM` around dwm.
- Rule 6: existing ~/.xinitrc is user-owned — report paste lines, never rewrite.

## References
- scripts/install-session-template.sh:153 (clipmenud launch)
- config/dwm/bin/dwm-powermenu:27 (logout = pkill -TERM -x dwm)

## Notes
clipmenud is a script; it holds no X connection, so it survives X. Its loop is
clipnotify (one "Can't open X display") + xsel per selection.
