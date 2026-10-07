# Context — session-end-orphan-daemons

## Background
User on Fedora VM 2026-10-07: bar empty ("dwm-6.8") after logout+login, fine after `dots theme dark`. Floating tray icons too (out of scope).

## Prior Decisions
- rule 6: non-X daemons are stopped in dots_session_end; .xinitrc is user-owned (report paste lines).
- 2026-10-07 xinitrc-clipmenud-cleanup introduced dots_session_end.

## Notes
- X-event-loop clients (sxhkd, picom, xsettingsd, udiskie, lxpolkit, spice-vdagent, xss-lock) exit when X closes.
- dwmblocks sleeps, writes only on change -> lazy death. dwm-nightlight daemon holds no X connection.
