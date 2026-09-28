# changelog-contributing
Date: 2026-09-28
Files: 9 + task folder | Lines: ~+270/-8

## What changed
- **`CHANGELOG.md`** in Keep a Changelog format. The release boundary is the
  user's choice today: everything up to 2026-09-03 is **0.1.0**, which was
  never tagged, and `VERSION` is unchanged. It is grouped by feature, not by
  commit, with the four installer bugs that reached real machines listed
  under Fixed. `[Unreleased]` holds today's merged slots.
- **`CONTRIBUTING.md`**: setup, testing (the sandboxing and prove-it-fails
  rules from memory), a conventions table that **points at** CLAUDE.md rule
  numbers and files rather than restating them, and the release steps.
- **`tests/changelog-version.sh`**: the newest released heading must equal
  `VERSION`, and `[Unreleased]` must exist above it.
- `README.md` links both files. It keeps its own semver definitions, and the
  CHANGELOG points to them rather than copying.
- `.markdownlint.yaml`: MD024 `siblings_only`, because Keep a Changelog
  repeats `### Fixed` under each version by design. Same-parent duplicates
  are still caught.
- CLAUDE.md's dwm-titus paragraph counted "the two open framework-parity
  queue items", a count that went stale the moment this merged. It now
  defers to MASTER_PLAN.
- `tests/tmux-xdg-paths.sh` mode 644 -> 755. That slipped in slot 3; the
  other 20 tests are executable.

## Why
The HyDE-parity queue item "CHANGELOG.md + CONTRIBUTING.md". The work was
choosing a release boundary, and the user picked "0.1.0 + Unreleased".

## Assumptions
- Type B: 0.1.0 is dated 2026-09-03, the last commit before today's work.
  Alternative: undated, since there is no tag.
- Type B: today's slots are listed under `[Unreleased]` rather than folded
  into 0.1.0, because they landed after the boundary.

## Test coverage
- The new test passes. 4/4 sandboxed mutations were CAUGHT.
- `run-tests.sh` and `lint.sh` pass.
- Reviewer: READY, after re-checking every CHANGELOG fact against the tree.

## Follow-ups
- Tagging `v0.1.0` is the user's call. Its commit would be `d997704`.
- Slots after this one add their own `[Unreleased]` lines.
