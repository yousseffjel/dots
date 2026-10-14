# installer-honest-status
Date: 2026-10-14
Files: 6 | Lines: +260/-8

## What changed
- `scripts/install-pkg-tiers.sh` `install_tier`: a package that
  `rpm -q --whatprovides` already finds is counted and skipped, with no dnf
  call and no output line. Each tier ends with one
  `ok      N already installed`. `installed: <pkg>` and its PACKAGE row now
  mean that this run really installed it. A dry run prints `would install`
  only for missing packages, and never `installed:`.
- The already-check moved from `rpm -q <name>` to `rpm -q --whatprovides`,
  the same question doctor's check_packages asks.
- New `tests/pkg-tiers.sh`, the first direct test of the tier loop.
- CHANGELOG [Unreleased], Fixed.

## Why
The user saw on the f44 VM that every `dots update` re-run printed
`installed:` for all ~150 packages, and that a dry run said both "would
install" and "installed". While auditing the fix, the name-only `rpm -q`
turned out to miss `thunar`, a Provides of Fedora's `Thunar`. Where Thunar
was preinstalled, the installer wrote a PACKAGE row for it, and `dots
uninstall` would have removed it.

## Key Technical Decisions
- Skip dnf for an installed package instead of only changing the message.
  `dnf install` never upgrades an installed package, so the result is
  identical, and a re-run saves one dnf process per package.
- One summary line per tier rather than a line per package: the output now
  shows only what changed.

## Assumptions Made
- (B) The VM's real rpm database shows `thunar` is the only list entry that
  is a Provides rather than a package name: every entry in core, desktop
  and extra was scanned with `rpm -q` vs `rpm -q --whatprovides` on the
  f44 VM.

## Test coverage
- `tests/pkg-tiers.sh`: a mixed tier (only missing packages reach dnf,
  rows only for them, a summary line); a re-run makes zero dnf calls; dry
  run; a Provides name (thunar→Thunar) gets no dnf call and no row; an
  extra failure is skipped and continues; a desktop failure is FAILED with
  its consequence; a hard failure aborts.
- Mutations: 5 of 5 caught. Reverting to name-only `rpm -q` fails the
  Thunar case. On its first run the test had a check passing for the wrong
  reason (`awk` was missing from the sealed PATH, so `manifest_rows`
  printed nothing); fixed before it counted.
- Full suite exit 0 (68 scripts). Lint passed. Reviewer READY.

## Follow-ups
- Release 0.3.0 next (the user's second pick). It needs
  `scripts/migrations/0.2.0-to-0.3.0.sh`: without it migrate.sh stops and
  the manifest stays at 0.2.0.
