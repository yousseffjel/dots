# void-i2b-cascadia-font — I-2b: vendor Cascadia Code NF (decision D3)

## What changed
- `assets/fonts/`: `CascadiaCodeNF-2407.24.tar.xz` (1,246,860 bytes; the two
  variable NF TTFs from upstream v2407.24), `.sha256`, `LICENSE.CascadiaCode`
  (OFL 1.1, from the repo at the tag), and a README with provenance and the
  reproducible rebuild recipe.
- `scripts/install-restore-vendored.sh` (new): the select/verify/extract/claim
  logic, moved out of `install-restore-cursor.sh`. The cursor file is now
  thin wrappers under the same names.
- `scripts/install-restore-font.sh` (new): `restore_font_assets` extracts to
  `~/.local/share/fonts/CascadiaCodeNF` with a THEME row. It is called from
  `restore_theme`.
- Tests: `tests/font-asset.sh` (new). `fontconfig-stack.sh` gains
  FAMILY_VENDORED in place of the I-2 "pending" entry, and the symmetry test
  requires the font's THEME row.
- Docs: FONTS.md, UNINSTALL.md, CLAUDE.md map, CHANGELOG, scope; comments
  in alacritty, starship and dwm config.def.h.

## Key Technical Decisions
- Repack, not the upstream artifact: the release is one 150 MB zip. Only the
  two variable TTFs are kept, byte-identical (sha256 of each recorded), and
  they carry every named weight. The tar is reproducible (sorted names, fixed
  mtime and owner, xz -9e -T1); two builds produced the same SHA-256.
- Shared helper rather than a copy of the cursor code.
- **No fc-cache at install.** The first version ran it. The symmetry test
  showed ~/.cache/fontconfig left behind after uninstall. fontconfig rescans
  a new user font dir by mtime on the next app start, so the call was not
  needed.

## Assumptions Made
- (B) Xft (dwm, st, dmenu) and alacritty select the named instances of the
  variable fonts correctly. Fedora's package was also the upstream release,
  but whether its files were static or variable was not checked. This needs a
  visual check on the Void VM (I-10).

## Test coverage
- `fc-scan` on the extracted faces: family `Cascadia Code NF` with
  Regular/Bold/Italic/... instances.
- `tests/font-asset.sh` 11/11. Mutations on a tree copy, 6/6 caught: no
  restore call, tampered tarball, claims a pre-existing dir, wrong
  destination, asset removed, fc-cache reintroduced.
- `tests/run-tests.sh` 76 OK, 1 SKIP (dwm-runtime). `tests/lint.sh --strict`
  passes.
- Reviewer: BLOCK (README still said fc-cache runs), fixed, then READY.

## Follow-ups
- I-3: the xbps package engine.
