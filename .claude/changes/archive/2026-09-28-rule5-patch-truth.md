# rule5-patch-truth
Date: 2026-09-28
Files: 3 | Lines: ~+20/-12

## What changed
- **CLAUDE.md rule 5 now describes what the repo actually does.** The
  vendored `.diff` files are a record. Each was merged into the sources once,
  when it was vendored (some by a clean `patch -p1`, the conflicting ones by
  hand, as each `PATCHES.md` records). Nothing applies them at build time, and
  `PATCHES.md` is the authority. A change to patched behaviour goes into the
  sources plus its `.diff`/`PATCHES.md` entry in the same commit. The old
  claim is noted inline as corrected rather than silently replaced. The
  project-map line was changed the same way.
- `packages/build.lst`: `patch` **stays** (the user's decision today), but its
  comment no longer claims it applies the diffs. It now says what the package
  is for (hand-merging or re-vendoring on the target machine) and what it
  costs: `build.lst` is the tier that aborts the build stage, so a missing
  `patch` would stop a build that does not need it.
- `tests/ci-build-deps.sh` header: the same false claim, corrected.

## Why
This closes the MASTER_PLAN queue item split out of scope-d slot A on
2026-08-24 (locked decision 7). Re-verified today: no `patch(1)` or
`git apply` call exists in `scripts/`, `tests/`, `.github/` or any suckless
`Makefile`/`config.mk`.

## Assumptions
- None beyond the user's keep-`patch` decision.

## Test coverage
- `tests/pkglist.sh`, `tests/ci-build-deps.sh` and `tests/lint.sh` pass (the
  build.lst edit is comment-only, and both tests parse that file).
- Reviewer: **WARN.** "Every patch is hand-merged" overstated it, because
  `PATCHES.md` records clean `patch -p1` applies for some patches. Reworded
  before this commit to "merged once — clean apply or by hand".

## Follow-ups
- none
