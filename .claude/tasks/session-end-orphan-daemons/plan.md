# Plan — session-end-orphan-daemons

## Goal
After a logout + quick re-login the dwm bar shows "dwm-6.8": the previous
session's dwmblocks is still alive (it only notices X died on its next bar
write), autostart.sh's `pgrep -x dwmblocks` guard finds it and starts nothing,
then the orphan dies. `dwm-nightlight daemon` (a shell loop, no X connection)
has the same flaw permanently. Stop both in the .xinitrc session-end step, the
mechanism already used for clipmenud.

## Scope
- scripts/install-session.sh
- scripts/install-session-report.sh
- docs/THEMING.md
- tests/*.sh
- CHANGELOG.md
- TESTING.md

## Allowed
## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. Template dots_session_end: pkill dwmblocks (-x) and the nightlight daemon (-f, its DAEMON_PATTERN), with a comment on which daemons outlive X and why
2. Report: an .xinitrc whose session-end lacks dwmblocks gets the updated paste block
3. docs/THEMING.md paste block + rule-6 note in sync (tests hold them equal)
4. Tests: END expectations, a pre-dwmblocks .xinitrc report case, the nightlight pattern equal to dwm-nightlight's DAEMON_PATTERN
5. Verify: lint, full suite, mutation; CHANGELOG/TESTING; audit + reviewer

## Out of scope
- the floating tray icons (cause unknown — re-check on the VM after this lands)
- changing autostart.sh guards (user-owned on existing installs)

## Risks
- pkill -f pattern drift from dwm-nightlight — test reads DAEMON_PATTERN from the script
- tests/xinitrc-theme.sh near the 250 cap — new cases go to a sibling test if needed
- VM's hand-edited .xinitrc lacks the >/dev/null forms — paste block stays the plain form
