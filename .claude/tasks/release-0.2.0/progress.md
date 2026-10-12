# Progress — release-0.2.0

## Status
`done`

## Steps
- [x] 1. migrate.sh tests
- [x] 2. 0.1.0-to-0.2.0 migration + tests
- [x] 3. dots update + tests
- [x] 4. Release cut
- [x] 5. Verify + mutations

## Deviations

## Blockers
- Step 5: mutation R7 (no dirty-tree check) survived — the test dirtied
  VERSION, which upstream also changes, so git's own merge refusal produced
  the exit 1. Now a file upstream never touches is dirtied, and the message
  is asserted. 10/10 after.
- Step 5: read-only classification of the dev host's own headers: dwm
  config.h (2026-08-07) and dwmblocks blocks.h (2026-08-04) would be
  refreshed, dmenu/st/slock are current — the migration's exact use case.
