# update-stale-install
Date: 2026-10-12
Files: 4 | Lines: +105/-19

## What changed
- `scripts/update.sh`: sources `global_fn.sh` (as `migrate.sh` does) for
  `manifest_get_meta`. New `install_is_current` — the manifest's `META commit`
  must resolve to HEAD — plus `stale_reason`, `run_installer` and
  `finish_unpulled`. The two "nothing pulled" exits (already up to date; branch
  only ahead of its upstream) now re-run the installer when the install is
  stale, saying `nothing to pull, but the last install ran from <c>, the
  checkout is at <HEAD>`. `--dry-run` reports the same case. Header documents
  the rule and its limit.
- `tests/dots-update.sh`: the stub installer now stamps the manifest commit
  like every real install stage. New cases: a hand pull (`--dry-run` says it
  would install and doesn't; a real run installs with args passed through;
  a second run installs nothing), no manifest at all, and the ahead-only
  branch (installs once, then not again).
- `README.md` upgrade paragraph and `CHANGELOG.md` `[Unreleased]` → Fixed.

## Why
Found while writing the VM test steps for scope G, and confirmed on the VM
the same day: every 0.1.0 install gets `update.sh` from a `git pull` done by
hand, after which `dots update` saw nothing to pull and said "already up to
date" while the install was still 0.1.0. The user worked around it by running
`install-fedora.sh` directly (migration 0.1.0 → 0.2.0 ran, doctor all green).
Up to date has to mean the install, not the checkout.

## Assumptions
- Type B: compare the installed **commit**, not the version — it also covers a
  hand pull with no version bump, and local commits never installed.
  Alternative: compare VERSION with the manifest version (misses both).
- Type B: an ahead-only branch whose HEAD was never installed now runs the
  installer (it used to exit 0 with nothing done). Consistent with the rule
  above; the test was changed to assert it.
- Type C: a missing manifest, or a commit git cannot resolve (the installer
  writes `unknown` without git), counts as stale.

## Test coverage
- `tests/run-tests.sh`: 50/50 OK; `tests/dots-update.sh` with the new cases;
  shellcheck + `tests/lint.sh` clean.
- Mutations on tree copies: always-current, never-current, dry-run ignoring
  staleness, ahead path exiting early, installer args dropped — 5/5 caught.
  The `!= unknown` guard SURVIVED because it was redundant (rev-parse already
  rejects it) and was removed rather than tested.
- Reviewer: READY, first round.

## Follow-ups
- Every install stage stamps the commit when it STARTS, so an install that
  failed partway reads as current; re-run `install-fedora.sh` by hand. Not
  fixed here (would mean stamping at the end of `install-fedora.sh`).
- Releasing 0.2.1 needs an empty `scripts/migrations/0.2.0-to-0.2.1.sh`, or
  `migrate.sh` stops with "no migration path" — user decision, as are tags.
