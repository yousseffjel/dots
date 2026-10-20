# blueman-applet-autostart
Date: 2026-10-05
Files: 4 | Lines: +20/-2

## What changed
- `scripts/install-session-template.sh` (`session_autostart_daemons`):
  `blueman-applet &`, guarded by `command -v`, a non-empty
  `/sys/class/bluetooth` and `pgrep -x`.
- `scripts/install-session-report.sh`: the paired `session_report_daemon`
  call with the line to paste.
- `tests/autostart-daemons.sh`: `blueman-applet` added to `DAEMONS`.
- `CHANGELOG.md`: Unreleased, Added.

## Why
Item 4 of the post-VM follow-ups ("desktop features"), bluetooth row, ⭐
option chosen by the user. bluez, blueman and the BT bar block already
existed; the tray applet never started because blueman's
`/etc/xdg/autostart/blueman.desktop` is not read by a dwm session.

## Assumptions
- Type B: started only when an adapter exists (`/sys/class/bluetooth` has
  entries). Without one the applet runs anyway and puts a dead icon in the
  tray. A USB dongle plugged in after login needs a re-login (or running
  `blueman-applet` by hand).
- Type C: `bluetooth.service` is enabled by Fedora's default preset, so
  nothing in `install-services.sh` enables it.

## Test coverage
- `tests/autostart-daemons.sh` passes with 11 daemons. A mutation that drops
  the report call is caught ("launched ... but NOT reported").
- The generated `autostart.sh` passes `sh -n`.
- `tests/run-tests.sh`: 29/29. Lint passed. Reviewer: READY.

## Follow-ups
- Existing installs: `autostart.sh` is user-owned; the services/install run
  prints the line to paste.
