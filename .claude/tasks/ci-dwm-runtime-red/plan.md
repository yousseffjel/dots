# Plan — ci-dwm-runtime-red

## Goal
Turn CI on main green again. `build-suckless` has failed on both legs since
`tests/dwm-runtime.sh` landed (last green run 2026-08-14): the EXIT trap's
`pkill` is "command not found" (no procps-ng in the container), and under
`set -e` that 127 becomes the script's exit code although every check passed.
Also make the restartsig check real: dwm only acts on SIGHUP at the next X
event, and the test sends none, so it has always warned.

## Scope
- .github/workflows/ci.yml
- tests/dwm-runtime.sh
- tests/lib/dwm-runtime-*.sh
- TESTING.md
- CHANGELOG.md

## Allowed
## Forbidden
- suckless/dwm/

## Steps
1. ci.yml: add `procps-ng` to the "Install dwm-runtime.sh test dependencies" line.
2. dwm-runtime.sh: add `pgrep`/`pkill` to the skip prerequisites; make `cleanup()` unable to change the exit status (each kill/pkill `|| true`).
3. check_restartsig: after `kill -HUP`, send one X event (root property poke); rewrite the wrong "signal delivery is unreliable" comment in both headers.
4. Verify in a `fedora:latest` container (the CI steps, on a copy): first unmodified exit=127 already reproduced; then the fixed tree must exit 0 and show whether restartsig passes.
5. If restartsig passes reliably in the container: promote it from WARN to a hard FAIL. If not: keep advisory, record why.
6. TESTING.md + CHANGELOG.md (Fixed); tests/run-tests.sh + tests/lint.sh green.

## Out of scope
- The post-restart "selected client lost" follow-up noted in the test header.
- Changing dwm's event loop (live desktops always have events; not a dwm bug).

## Risks
- Container run is slow (~5-10 min) — run it once per change, not per tweak.
- Promoting restartsig could make CI flaky — only promote after repeated passes (3 runs).
- set -e in the EXIT trap still aborts on other commands — audit the whole trap, not just pkill.
