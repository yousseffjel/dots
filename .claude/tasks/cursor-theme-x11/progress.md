# Progress — cursor-theme-x11

## Status
`in-progress`

## Steps
- [x] 1. writers
- [x] 2. call sites
- [x] 3. merge points
- [x] 4. doctor
- [x] 5. tests
- [x] 6. verify

## Deviations
- Step 5 also touched tests/doctor.sh + tests/lib/doctor-sandbox.sh: the healthy fixture warned on the new cursor check, so it now runs the installer's theme_write_cursor_default and passes FAKE_XCURSOR through.
- Cursor .xinitrc report assertions live in tests/cursor-x11.sh, not xinitrc-theme.sh (250-line cap).

## Blockers
