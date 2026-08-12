# Progress — dwm-bin-tests

## Status
`in-progress`

## Steps
- [x] 1. `tests/dwm-colorpicker.sh` — hex across 4 PNG variants + 4 failure paths.
- [x] 2. Mutant it: drop `-alpha off -depth 8` from a COPY; the test must fail.
- [x] 3. `tests/dwm-display.sh` — menu derivation, single-monitor, autorandr first, one call per preset, Escape exits 0.
- [x] 4. Mutant it too — one keeping the menu right but breaking a command.
- [x] 5. TESTING.md entries for both.
- [x] 6. CLAUDE.md's `tests/` enumeration (appears TWICE).
- [x] 7. Full suite + `tests/lint.sh --strict`.

## Deviations

## Blockers
