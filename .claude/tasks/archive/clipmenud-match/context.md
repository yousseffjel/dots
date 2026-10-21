# Context — clipmenud-match

## Background
VM: pid 1929 `bash /usr/sbin/clipmenud`, comm "bash", ppid 1, stderr /dev/tty2, started 11:14:22, session ended 11:42:38.

## Prior Decisions
- dwm-nightlight already matched by -f (its comment explains comm=bash).
- Rule 6: xinitrc/autostart are user-owned; report, never edit.

## References
- config/dwm/bin/dwm-nightlight:103; clipmenud 6.2.0_1 session_lock (second copy dies 2).

## Notes
- python3-shebang daemons (udiskie, blueman-applet) keep their names; to confirm live.
