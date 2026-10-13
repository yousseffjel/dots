# Progress — fonts-arabic

## Status
`in-progress`

## Steps
- [x] 1. Packages
- [x] 2. fontconfig + symlinks
- [x] 3. theme.conf font
- [x] 4. dwm fribidi
- [x] 5. dmenu fribidi
- [x] 6. tests
- [x] 7. docs

## Deviations

## Blockers
- Steps 4/5: dwm and dmenu fonts[] gained an explicit "Noto Sans Arabic:size=10"
  entry (config.def.h) — Cascadia lacks Presentation Forms-B (U+FE70-FEFF),
  which fribidi's shaping emits. Found during step 2 coverage probe.
- Step 2: fonts.conf also names Noto Serif + Noto Sans Mono, so
  google-noto-serif-vf-fonts and google-noto-sans-mono-vf-fonts joined extra.lst.
- Step 3: reverses scope-b locked decision 14 (JetBrains Mono for UI) — user
  chose Noto Sans 10 in-session; jetbrains-mono-fonts-all kept, comment updated.
- Step 6: tests/bidi.sh added beside fontconfig-stack.sh (extracts shipped bidi(),
  ASan); wired into build-suckless as `--strict`.
