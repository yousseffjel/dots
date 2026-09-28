# Plan — split-dwm-runtime-test

## Goal
`tests/dwm-runtime.sh` is 377 lines, over the 250-line hard cap, and slot C's
log never flagged it. Split it into an entry script plus two sourced
libraries under `tests/lib/`, with identical behaviour. Widen `tests/lint.sh`
so the new files are linted: its `find -maxdepth 2` never reached
`tests/lib/`, and it has also never reached `scripts/theme/*.sh` or
`scripts/migrations/*.sh` (both pass shellcheck + shfmt today).

## Scope
- tests/dwm-runtime.sh
- tests/lib/*.sh
- tests/lint.sh
- .shellcheckrc
- CLAUDE.md
- TESTING.md
- .claude/**

## Allowed
## Forbidden
- suckless/
- scripts/

## Steps
1. Move X helpers (Xvfb/dwm start, spawn_win, border_pixel, master_width) to tests/lib/dwm-runtime-x.sh
2. Move the five check sections into functions in tests/lib/dwm-runtime-checks.sh (each <= 60 lines)
3. Reduce tests/dwm-runtime.sh to header + prereqs + cleanup + ordered calls
4. Drop -maxdepth from tests/lint.sh's find (git check-ignore already filters)
5. Document tests/lib/ in TESTING.md (sourced, never globbed as a test)
6. Verify: same assertions pass under Xvfb, both mutations still caught, lint green

## Out of scope
- the restartsig advisory question (separate follow-up)

## Risks
- tests/lib/*.sh picked up by run-tests.sh's glob — it globs tests/*.sh only (depth 1); verify
- sourced files alter `rc` scoping — functions share the global; verify a FAIL still exits 1
