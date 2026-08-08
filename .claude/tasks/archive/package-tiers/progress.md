# Progress — package-tiers

## Status
`in-progress`

## Steps
- [x] 1. `packages/build.lst` + `install-suckless.sh` reads it (drops inline array).
- [x] 2. Classify the roster into core/desktop/extra; rewrite all three headers.
- [x] 3. `install-pkg.sh`: tier-driven loop + end-of-run failure summary.
- [x] 4. `tests/pkglist.sh`: glob every list, all-pairs overlap, non-empty.
- [x] 5. New test: every desktop.lst package carries a consequence note.
- [x] 6. `ci.yml` dry-run validation over all four lists.
- [x] 7. Docs: CLAUDE.md map/rule 10/pending, TESTING.md, THUNAR.md, ROADMAP.md.

## Deviations

- **Step 3 added a file the plan did not name: `scripts/install-pkg-tiers.sh`.**
  Folding the tier machinery into `install-pkg.sh` took it to 279 lines, over
  the 250-line cap in `rules/foundations/file-architecture.md` — a hard stop,
  not a warning. Split along the pattern `install-restore.sh` already uses
  with `install-restore-theme.sh`: 181 + 117. In scope (`scripts/install-*.sh`
  is listed under `## Scope`), so no re-confirmation needed, but it is a file
  the plan did not anticipate.

## Blockers
