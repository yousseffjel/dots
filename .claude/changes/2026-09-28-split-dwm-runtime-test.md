# split-dwm-runtime-test
Date: 2026-09-28
Files: 9 | Lines: +~350/-293 (2 new libs + task folder)

## What changed
- `tests/dwm-runtime.sh` 377 -> 128 lines. The X helpers (`start_xvfb`,
  `start_dwm`, `spawn_win`, `border_pixel`, `master_width`, `hex_of`) moved to
  `tests/lib/dwm-runtime-x.sh` (111), and the five check sections became
  functions in `tests/lib/dwm-runtime-checks.sh` (188). The longest function
  is `check_pertag` at 43 lines. The check order is unchanged, and the entry
  script now lists the calls in order with the reason.
- **`tests/lint.sh` no longer uses `find -maxdepth 2`.** That depth limit
  meant CI's lint job had **never** linted `scripts/theme/*.sh` (5 files) or
  `scripts/migrations/*.sh` (1). All six pass shellcheck 0.11.0 and
  `shfmt -i 4 -ci -bn` as-is. `git check-ignore` already did the real
  filtering (the reference clones), so the depth limit only ever acted as a
  stale list of where scripts are allowed to live.
- `.shellcheckrc`'s scope comment ("scripts/*.sh and any *.sh at the repo
  root") was the same stale list and now points at `tests/lint.sh`.
- TESTING.md and CLAUDE.md's project map now say that `tests/lib/` holds
  sourced helpers, outside `run-tests.sh`'s depth-1 glob.
- The Xvfb ready line prints its PID. This was the fix for SC2034 (the lib
  writes `XVFB_PID` for the caller's cleanup trap), chosen over a suppression.

## Why
Found by the 2026-09-28 codebase scan. It was the only file over the 250-line
hard cap in `scripts/`, `tests/` and `config/dwm/bin/`, and slot C's log
(`2026-09-03-dwm-runtime-xvfb.md`) never mentioned it. The user asked for the
split first, ahead of every other item.

## Assumptions
- Type B: the libraries go in `tests/lib/`, not beside the entry script. A
  `tests/*.sh` sibling would be run as a test by `run-tests.sh`.
  Alternative considered: `_`-prefixed names in `tests/` plus a skip-list
  entry, rejected because it means another hand-maintained list.
- Type B: `-maxdepth` removed entirely, not raised to 3, so that the next
  nested directory is covered too.

## Test coverage
- The live Xvfb run was normalized and diffed against a pre-split baseline.
  The only difference is the added Xvfb PID.
- Slot C's two dwm mutations were re-run on **sandboxed copies** of
  `suckless/dwm` (rebuilt, never the worktree), and both were CAUGHT:
  xresources (the `xresupdate()` loop skipped, border `#5294E2` != `#123456`)
  and pertag (`view()` mfact restore removed, tag2 inherited 892 px).
  `git status` afterwards showed only the intended changes.
- `tests/run-tests.sh` passed (16 OK, 3 dedicated). `tests/lib/*` is not
  executed. `tests/lint.sh` passes over the widened set.
- Reviewer: READY. It independently forced a FAIL through a sourced check to
  confirm that `rc` propagates.

## Follow-ups
- The restartsig advisory question is unchanged, still open from slot C.
