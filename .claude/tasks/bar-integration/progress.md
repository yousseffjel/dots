# Progress — bar-integration

## Status
`done`

## Steps
- [x] 1. dwm-blockutil
- [x] 2. dots-float- rule
- [x] 3. I2 + I3 clicks
- [x] 4. I4 upgrade click
- [x] 5. Test hooks + real formats
- [x] 6. A2 tests + docs
- [x] 7. Verify + mutations

## Deviations

## Blockers
- Audit 1: `suckless/dwmblocks/Makefile` edited (outside `## Scope`): install
  `dwm-blockutil` 644 like `dwm-colors` — it is sourced, never run.
- Step 7: added a coupling check (blocks-info) that block_term's class is
  floated by a rules[] entry — neither half's test caught a renamed prefix.
- Step 6: real bug found by the dnf5 fixture — the left-click list included
  dnf5's "Upgrades" header; count and list now share one filter.
