# Progress — dwm-hyprland-mouse

## Status
`in-progress`

## Steps
- [x] 1. cfacts + preserveonrestart cfact
- [x] 2. resizepoint
- [x] 3. local dragtile
- [x] 4. placemouse
- [x] 5. local snapwindows
- [x] 6. config cleanup + records/docs
- [x] 7. runtime tests + build + lint

## Deviations
- Step 3: dragtile trades cfact with the one neighbour on the grabbed side (pair keeps its height) instead of rescaling the whole column — matches Hyprland's edge-drag.
- Step 6: dwm-dragmfact-6.2.diff retired (its behaviour no longer exists); TESTING.md entry appended.
- Step 7: dwm-keys.sh needs a bare chord in the key column — mouse rows fold tiled/floating into the effect text.

## Blockers
