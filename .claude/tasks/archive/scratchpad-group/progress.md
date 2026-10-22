# Progress — scratchpad-group

## Status
`in-progress`

## Steps
- [x] 1. isscratchpad flag, drop cycle
- [x] 2. show/hide group + gather + layout
- [x] 3. restart record value 17
- [x] 4. records + docs
- [x] 5. tests

## Deviations
- Step 4: scratchpadfill retired (subsumed: n=1 case); its record removed.
- Step 5: new lib tests/lib/dwm-runtime-scratchpad.sh (floating lib was at 201 lines). Gather check had two false passes (pointer never selected the right monitor; hidden windows read as on_left) — both fixed, mutant now caught.

## Blockers
