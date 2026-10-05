# ci-build-deps-from-lst
Date: 2026-09-03
Files: 2 | Lines: +25/-12 (excludes state/plan.md bookkeeping)

## What changed
- `.github/workflows/ci.yml`'s `build-suckless` job no longer hardcodes a
  12-package dnf install list under a comment claiming it "matches
  `install-suckless.sh`'s `install_deps()` exactly" — it didn't.
  `packages/build.lst` declares 13 packages; the missing one was `patch`,
  which applies the repo's vendored suckless `.diff` files (CLAUDE.md rule
  5). The step now parses `packages/build.lst` directly with the same
  sed/tr/grep one-liner already used by `read_pkg_list()` in
  `scripts/install-pkg-tiers.sh`, `scripts/install-suckless.sh` and
  `tests/pkglist.sh` (CLAUDE.md rule 10).
- New `tests/ci-build-deps.sh`: extracts the step's `run:` block directly
  out of the YAML (line-anchored `awk`, not retyped), executes it against a
  shimmed `dnf` on `$PATH` that records its argv instead of installing
  anything, and asserts the captured package set equals
  `packages/build.lst`'s declared set exactly. This is the guard against the
  list drifting back into a hardcoded restatement.

## Why
This is scope-d slot A (`.claude/tasks/scope-d-verification-harvest.md`),
opened from the 2026-08-24 dwm-titus comparison. `install-suckless.sh`
itself already reads `build.lst`; only the CI job's copy of the dependency
list had drifted from it — a live, if low-consequence, bug (the build has
never actually needed `patch`, since nothing in the repo applies the
vendored `.diff` files at build time — see the CLAUDE.md rule 5 / build.lst
queue item in MASTER_PLAN.md, decision 7 in the scope-d file).

## Assumptions
- **Type B** — per scope-d locked decision 7, this slot is deliberately
  mechanical only: it makes CI read the same list `install-suckless.sh`
  reads, and guards that with a test. It does **not** touch
  `packages/build.lst`'s content, and does **not** fix CLAUDE.md rule 5's
  stale "applied at build time" claim. **Consequence, stated rather than
  hidden:** CI now installs `patch` in its container, and `patch` is still
  unused by any build step in this repo. That contradiction is exactly as
  documented in the existing MASTER_PLAN.md queue item and is not resolved
  here.

## Test coverage
- `bash tests/ci-build-deps.sh` — passes; confirms CI installs exactly
  `packages/build.lst`'s 13 packages.
- `bash tests/lint.sh --strict` — shellcheck/shfmt/markdownlint all clean
  (covers the new test file too).
- `bash tests/pkglist.sh` — unaffected, still green (build.lst untouched).
- Generic `/test` full-suite run skipped: no `.claude/config.yml` ->
  `test_command`, `package.json`, or `Makefile` exists yet (this is the gap
  scope-d slot B closes), and the theming-engine tests are known to `pkill`
  live desktop daemons on this dev host — not run speculatively. The three
  tests above are the ones this diff actually touches.
- Reviewer subagent: **READY**.

## Follow-ups
- Start scope-d slot B: `tests/run-tests.sh` + `.claude/config.yml`.
- The CLAUDE.md rule 5 / `patch`-is-unused correction remains its own queued
  item in `MASTER_PLAN.md` (unchanged by this slot, per decision 7).
