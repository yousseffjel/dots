# Progress — dwm-rules-scratchpad

## Status
`done`

## Steps
- [x] 1. Red restart test
- [x] 2. preserveonrestart
- [x] 3. Dropterm
- [x] 4. Rules + dwm-net class
- [x] 5. Diffs, PATCHES.md, KEYBINDINGS.md, CLAUDE.md
- [x] 6. Verify + mutations

## Deviations
- Step 4/5: `config/sxhkd/sxhkdrc` edited although outside `## Scope` — comments
  only. Its header and the Super+/ note enumerate dwm's Super chords ("the two");
  Super+grave makes three, and leaving it would invite an sxhkd binding on it.
- Step 4: the dropterm test lib became `tests/lib/dwm-runtime-floating.sh`
  (dropterm + new float-rules check, which reads rules[] from config.def.h).
- Step 1 → 2: F5 reclassified (scope file, decision 6) — the fix is
  preserveonrestart, not a scan() focus patch.

## Blockers
