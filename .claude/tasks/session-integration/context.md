# Context — session-integration

## Background
Scope F slot 3. Decisions 9-11 in main's
`.claude/tasks/scope-f-desktop-integration.md` (DND = new 12th block;
xdg-user-dirs-update every login; I6 reduced to a dunst doctor check).

## Prior Decisions
- CLAUDE.md rule 6: autostart entry = template line + session_report_daemon
  call + DAEMONS in tests/autostart-daemons.sh (test runs both sides).
- Doctor reads its daemon list from the report (report_names), never a copy.
- Empty dwmblocks output gets no delimiter (dwmblocks.c getcmd).
- New block on an existing install needs `rm blocks.h` (NET precedent).

## References
- scripts/install-session-template.sh session_autostart_daemons (lxpolkit, blueman)
- scripts/doctor-session.sh daemon_applies, DAEMON_PROCESS
- config/sxhkd/sxhkdrc (Super+n night light)

## Notes
