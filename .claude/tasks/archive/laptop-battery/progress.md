# Progress — laptop-battery

## Status
`in-progress`

## Steps
- [x] 1. read batteries
- [x] 2. label + colours
- [x] 3. alerts
- [x] 4. left click
- [x] 5. blocks.def.h
- [x] 6. tests
- [x] 7. docs

## Deviations
- tests/lib/blocks.sh: beyond passing DOTS_POWER_SUPPLY_ROOT, `rm` joined the
  sealed PATH and block() now tolerates a dying block (found while mutation
  testing: under set -e it aborted every block test silently).

## Blockers
