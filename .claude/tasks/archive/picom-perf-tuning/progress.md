# Progress — picom-perf-tuning

## Status
`complete`

## Steps
- [x] 1. Tune `picom.conf`: shadows off + dead options removed,
      `unredir-if-possible = true`, drop `detect-rounded-corners`, trim `wintypes`.
- [x] 2. Mirror identical settings into `picom.dcol`, dropping `<wallbash_pry1>`.
- [x] 3. `tests/picom-lockstep.sh` — generate via apply-templates.sh, diff vs picom.conf.
- [x] 4. Update `docs/THEMING.md`.
- [x] 5. Verify: lockstep test, lint, libconfig syntax sanity.
- [x] 6. (added) CI `tests` job running every dependency-free `tests/*.sh`.

## Deviations

- **CI does not run `tests/*.sh`.** Discovered at step 5. `.github/workflows/
  ci.yml` lints them (shellcheck/shfmt over `find . -maxdepth 2 -name '*.sh'`)
  but re-implements the build and package checks inline rather than invoking
  `tests/build.sh` / `tests/pkglist.sh`. So `tests/picom-lockstep.sh` is linted
  and never executed, and step 3's "makes drift a hard test failure" holds only
  for a manual run. Wiring it up needs `.github/workflows/ci.yml` (or
  `tests/lint.sh`), neither of which is in this plan's Allowed list — surfaced
  to the user rather than expanded into.

  **Resolved:** user chose to add a CI job. `.github/workflows/ci.yml` gained a
  `tests` job running every `tests/*.sh` by glob, so tests added later are
  picked up automatically. `build.sh` and `lint.sh` are skipped by name with
  the reason printed — the first needs the X11 toolchain (covered by
  `build-suckless` in a Fedora container), the second needs
  shellcheck/shfmt/markdownlint (covered by the `lint` job). Running them
  unconditionally on ubuntu-latest would have made the job red from the first
  push. `plan.md ## Allowed` updated to record the expansion.

## Blockers

[none]
