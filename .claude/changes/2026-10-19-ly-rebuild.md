# ly-rebuild
Date: 2026-10-19
Files: 7 | Lines: +185/-33

## What changed
- `scripts/install-services-ly-place.sh` (new, sourced by
  install-services-ly.sh): ly_place moved here; files go in by copy to
  `<dst>.dots-new` + `mv -fT` (a stale .dots-new removed first); the record
  `META ly_build v<ver> <commit>` (ly_pinned / ly_built; no record + LYBUILD
  rows = LY_FIRST_BUILD, v1.4.1 afb1dc6); ly_prune removes paths the new
  stage lacks, with their rows, never config.ini.
- `ly_install`: our build at the pinned record → ok (and backfills the
  record); otherwise a rebuild through the same checks, keeping an existing
  /etc/ly/config.ini. The record moves only after place + prune succeed. A
  failed rebuild says the old version stays. ly is never restarted.
- tests/ly-build.sh: record, backfill, raised pins (new binary by rename —
  inode changes — config.ini kept, en.ini pruned with its row, de.ini
  added, no .dots-new, record moved, re-run no-op), failed rebuild, dry-run.
- docs/THEMING.md (ly config paragraph), CLAUDE.md map, CHANGELOG Fixed.

## Why
User item 3 (queue: "A ly pin bump never reaches an existing install").
Renaming instead of copying in place matters because a rebuild normally runs
while ly is the active login manager: cp onto a running binary fails with
ETXTBSY.

## Assumptions
- Type B: an install with LYBUILD rows and no record was built from
  1.4.1/afb1dc6 — the only pin since f6e4948 (git log -S LY_VERSION=).
- Type B: config.ini is always kept on a rebuild, even if unedited; a new
  ly's stock config is not applied. Checking key compatibility stays with
  whoever bumps the pin (the 1.4.1 comment in install-services-ly.sh).
- Type C: no uninstall change: the state dir (and the META row) goes at the
  end of `dots uninstall`.

## Test coverage
- tests/ly-build.sh: 12 new checks; 10/10 mutants caught on scratch copies.
- run-tests rc 0, 94 OK; lint ✓; audit READY; reviewer READY.
- Not on the VM: there is no newer ly to bump to.

## Follow-ups
- none
