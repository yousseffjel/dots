# update-upstream-gone
Date: 2026-10-20
Files: 3 | Lines: +59/-9

## What changed
- `scripts/update.sh`: `git fetch --prune`, and a new `need_upstream`
  helper, called in preflight and again after the fetch. It refuses with
  exit 1 in two cases, each with its own message:
  - the branch has no upstream configured (unchanged hint: `--set-upstream-to`);
  - the branch tracks one the remote deleted (new: names the branch, hint
    `git switch main`).
  The header and the preflight comment now list the new refusal.
- `tests/dots-update.sh`: new case "an upstream deleted on the remote". It
  runs `--dry-run` (refused after its own fetch's prune) and then a real run
  (refused in preflight, the ref already pruned). Both exit 1, HEAD stays
  where it was, the installer never runs, and after `git switch main` the
  update goes through. The no-upstream case now also asserts the refusal
  comes before any fetch.
- `CHANGELOG.md` [Unreleased] Fixed: one line.

## Why
Found on the Void VM (192.168.122.242) while setting up the 0.4.0 → 0.5.0
upgrade check. Its checkout was on `void` (the I-10 install, 2026-10-15),
which has been deleted on GitHub since the port merged into main. `git fetch`
without `--prune` keeps `origin/void`, so `dots update --dry-run` said
"nothing to pull" and the install would have stayed on 0.4.0 with no hint.

## Assumptions
- Type B: refuse and point to `git switch main` instead of switching for the
  user. The branch may hold local commits, and the switch is their decision.
  The refusal is the fix. Alternative: auto-switch to the remote's default branch.
- Type B: `--prune` also drops other stale remote-tracking refs. That is
  standard git behaviour and harmless in a dots checkout.

## Test coverage
- `tests/dots-update.sh` passes. 5 mutants, all CAUGHT: no prune; no
  post-fetch check; always "gone"; always "no upstream"; no preflight call.
  The preflight-call mutant first SURVIVED, which led to the "before any
  fetch" assertion.
- Full suite: 95 OK, exit 0. Lint passes. Reviewer READY.
- On the VM, against a throwaway copy of `~/dots` with the fixed update.sh
  committed: `--dry-run` printed "the branch 'void' tracks 'void', which no
  longer exists on the remote" and the switch hint, exit 1. The real `~/dots`
  was then moved with `git fetch --prune && git switch main` for the upgrade
  check.

## Follow-ups
- The VM's 0.4.0 → 0.5.0 upgrade itself (`dots update` run by the user):
  results go in the records on main.
