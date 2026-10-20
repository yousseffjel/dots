# Context — suite-host-hermetic

## Background
Session 2026-10-20 status check: tests/run-tests.sh on the Arch dev host, 92 OK, 2 failed; CI green on 784d203.

## Prior Decisions
- memory sealed-path-copies-are-symlinks, installer-test-sandbox-xdg, dots-testing-via-fake-binary-on-path
- install-live.sh already prints help by marker: `sed -n '/^# usage:/,/^[^#]/{...}'`

## References
- tests/dwm-display.sh:177 `rm -f "$TMP/bin/autorandr"` then PATH="$TMP/bin:$PATH" reaches /usr/bin/autorandr; Escape case logs `xrandr -q --verbose` (autorandr's own call)
- scripts/doctor-session.sh:130 check_gtk3_theme reads XDG_DATA_DIRS, default /usr/local/share:/usr/share
- nsxiv-package log follow-up: install-void.sh '2,50p', symlinks.sh '2,15p'

## Notes
- "degrades cleanly when autorandr is not installed" passes here for the wrong reason (no real profiles saved)
