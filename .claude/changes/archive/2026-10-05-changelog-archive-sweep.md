# changelog-archive-sweep
Date: 2026-10-05
Files: 60 | Lines: +6/-6 (54 renames + 6 reference rewrites)

## What changed
- Moved the 54 dated logs older than 14 days (prefix < 2026-09-21) from
  `.claude/changes/` into `.claude/changes/archive/` with `git mv`.
  Filenames are unchanged. 12 files remain in the active window, counting
  `CURRENT_AUDIT.md` and `MICRO.md`.
- Rewrote the six links from live, editable files to
  `.claude/changes/archive/<name>`:
  - `CLAUDE.md`
  - `packages/desktop.lst`
  - `scripts/theme/colorgen.sh`
  - `scripts/theme/apply-templates.sh`
  - `themes/CREDITS.md`
  - `.claude/tasks/scope-d-verification-harvest.md`

## Why
The archival sweep in the change-log-write skill / session-protocol had
never run in this repo, so the active window held logs back to 2026-08-04.
The user asked for it ("do all of them") after it was raised as a follow-up
in first-boot-fixes.

## Assumptions
- Links inside immutable records stay as written:
  - the change logs themselves;
  - `CURRENT_AUDIT.md` (append-only);
  - the 11 archived task folders' `context.md` files.

  session-protocol.md preserves filenames across the move precisely so
  those links can still be followed into `archive/`.
- Done on main, not in a slot: session-protocol assigns the archival sweep
  to main.

## Test coverage
- `tests/run-tests.sh`: 27/27 OK, all on main; this does not include the
  unmerged quoting slot's new test. `tests/lint.sh` clean.
- No tracked, editable file outside those immutable records still links to a
  moved log (checked with grep).

## Follow-ups
- none
