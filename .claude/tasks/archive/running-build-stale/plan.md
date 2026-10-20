# Plan — running-build-stale

## Goal
After a rebuild, a running dwm and dwmblocks keep executing the old binary
(`/proc/<pid>/exe` -> `... (deleted)`) until a theme change or a new login,
and nothing says so (found on the Void VM after `dots update`, 2026-10-20).
Detect it — replaced AND different content, so an identical rebuild is quiet —
and say how to restart each one: at the end of install-suckless.sh and
install-void.sh, and as a `dots doctor` session check.

## Scope
- scripts/running-build.sh
- scripts/install-suckless.sh
- scripts/install-void.sh
- scripts/doctor-session.sh
- tests/running-build.sh
- CHANGELOG.md
- CLAUDE.md

## Allowed

## Forbidden

## Steps
1. scripts/running-build.sh (sourced): running_build_stale <name> scans $DOTS_PROC (default /proc) by comm, own processes only; running_build_report prints the restart hint per stale program
2. install-suckless.sh + install-void.sh: call running_build_report after their closing line
3. doctor-session.sh: check_running_builds (ok / warn) from check_session
4. tests/running-build.sh: fake proc root (replaced+different, replaced+identical, not replaced, other comm); doctor + report output
5. CHANGELOG line; CLAUDE.md project map line
6. Verify on the VM: rebuild under a live session, warn shown, restart hints work, doctor ok after

## Out of scope
- st/dmenu/slock: short-lived, each new start uses the new build

## Risks
- Tests scanning the real /proc — DOTS_PROC resolved at call time, every caller fakes it
