# update-stale-wording
Date: 2026-10-13
Files: 2 | Lines: +7/-3

## What changed
- `scripts/update.sh` `stale_reason`: with no `complete` stamp it now says
  "no finished install is recorded yet (the checkout is at <sha>)"; with one,
  the existing "the last finished install ran from <sha>, the checkout is at
  <sha>".
- `tests/dots-update.sh`: the missing-manifest and interrupted-install checks
  expect the new wording.

## Why
On the VM (2026-10-13), the first `dots update` after update-resilience printed
"the last finished install ran from no finished install recorded, the checkout
is at 02fa8f7" — the empty-stamp fallback was spliced into a sentence that
assumed a commit. User asked for the wording fix.

## Assumptions
- none

## Test coverage
- `tests/run-tests.sh`: exit 0, 57/57 OK; `tests/dots-update.sh` passes with
  the new expectations; lint passed. Rendered line checked by evaluating the
  shipped `stale_reason` with an empty stamp.
- Audit (Small tier): 0 issues. Reviewer: READY.

## Follow-ups
- none
