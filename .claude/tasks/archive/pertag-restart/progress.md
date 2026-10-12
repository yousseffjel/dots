# Progress — pertag-restart

## Status
`done`

## Steps
- [x] 1. Red test
- [x] 2. savestate _DWM_PERTAG
- [x] 3. restorestate + validation + apply
- [x] 4. Diff, PATCHES.md, docs, CHANGELOG
- [x] 5. Verify + mutations

## Deviations

## Blockers
- Step 3: Mod+Tab — first restored pertag's prevtag, which Mod+Tab does not
  use (it swaps the two tagset slots); the new check failed 3/3. Now the
  OTHER tagset slot is saved and the history replayed (view(prev) then
  view(cur)), in _DWM_PERTAG rather than _DWM_VIEW so an old dwm restarting
  into a rebuilt one never has its _DWM_VIEW misread.
- Step 1: the tag-1 check first passed vacuously (700 -> 700: earlier
  restarts had reset it); now it widens tag 1 itself and asserts that first.
- Step 5: mutation Q2 (no applycurtag) survived the first round — the history replay covers it unless both tagset slots hold the start tag; added check_pertag_fresh_restart, run FIRST on the fresh dwm.
