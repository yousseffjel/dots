# Progress — alacritty-main-terminal

## Status
`audit-passed`

## Steps
- [x] 1. `config/alacritty/alacritty.toml` — base config + import of cache palette.
- [x] 2. `always/alacritty.dcol` — render palette to `${cacheDir}`.
- [x] 3. dwm — `termcmd` -> alacritty; `fonts[]`/`dmenufont` -> Cascadia Code NF.
- [x] 4. dmenu + st — same font, kept in step.
- [x] 5. `symlinks.sh` — link `config/alacritty`.
- [x] 6. Docs — `KEYBINDINGS.md` terminal row + rebuild caveat; templates `README.md`.
- [x] 7. Verify — toml parse, render against `themes/dark/`, `make` all three.

## Deviations

- **Step 4 changed st's font size, not just its family.** The plan said
  "same font, kept in step"; st went from `Liberation Mono:pixelsize=12` to
  `Cascadia Code NF:size=11`, i.e. a point spec rather than a pixel spec.
  Reason: pixelsize=12 is roughly 9pt at 96 dpi, so a family-only swap would
  have left the fallback terminal visibly smaller than the primary one and
  scaling differently with DPI. Smoke-tested (`st -e true` exits 0) because
  this touches st's `usedfontsize` code path.
- **Step 3 added a fallback entry to dwm's `fonts[]`** (`monospace:size=10`
  after the Nerd Font) rather than replacing the single entry. The bar
  renders the status blocks' glyphs, so it is the one surface where a
  missing family is worth guarding. dmenu deliberately did *not* get one —
  its `config.def.h` comment warns that a colour-font fallback kills the
  process with BadLength, and it must mirror dwm's `dmenufont` exactly.
- **Step 6 fixed one extra line**: `KEYBINDINGS.md` pointed at
  `config/zsh/conf.d/20-path.zsh`, deleted in sub-task 1. In-file, in-scope,
  and knowingly false otherwise.

## Blockers

None.
