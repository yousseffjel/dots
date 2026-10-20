# Context — running-build-stale

## Background
Void VM, 2026-10-20: `dots update` (0.4.0 -> 0.5.0) ran over ssh while the
user was logged into dwm. make install replaced /usr/local/bin/dwm and
dwmblocks; the running ones showed `(deleted)` and kept the old code. Only a
theme apply (reload.sh: HUP dwm, restart dwmblocks) picked the new builds up.

## Prior Decisions
- restartsig + preserveonrestart: `kill -HUP dwm` re-execs in place, tags kept.
- reload_dwmblocks: no reload signal; kill + setsid restart.
- Memory: kill-loop tests never scan the real /proc; overrides resolve at call time.

## References
- scripts/theme/reload.sh reload_dwm / reload_dwmblocks
- scripts/doctor-session.sh check_session

## Notes
- cmp of /proc/<pid>/exe against the path keeps an identical rebuild quiet.
