# complete-stamp-cleared
Date: 2026-10-20
Files: 3 | Lines: +32/-3

## What changed
- `scripts/install-void.sh`: a full run (no `--only-*`) that isn't
  `--dry-run` now sets the manifest's `complete` stamp to empty right after
  the pre stage. `manifest_get_meta` already reads an empty value as absent.
  The stamp is written again only at the run's end, as before.
- `tests/install-complete-stamp.sh`: a new section, "a run after a finished
  one, same commit", using one HOME across runs:
  - a failed re-run clears the stamp;
  - finishing it writes the stamp back;
  - a pre-stage refusal, `--only-restore` and `--dry-run` keep it.
- `CHANGELOG.md` [Unreleased] Fixed: one line.

## Why
Found on the Void VM with a real SIGINT to the installer's process group
during the suckless build. The run stopped correctly (exit 130, nothing left
running), but the `complete` stamp from the previous finished run of the
same commit (784d203) still equalled HEAD. `dots update` then said "already
up to date". That contradicts update.sh's documented contract that an
install stopped partway reads as stale and is re-run. The 2026-10-13 fix only
covered an interrupted run of a new commit.

## Assumptions
- Type B: the stamp is cleared after the pre stage, not at the very start.
  A run the pre stage refuses (not in wheel, no sudo) has changed nothing, so
  the earlier finished install still stands. The test pins this.
- Type B: a manifest write that fails while clearing aborts the run (set -e).
  This happens before any change, and every later stage writes the manifest
  too.

## Test coverage
- `tests/install-complete-stamp.sh` passes. 4/4 mutants caught: no clear;
  clear ignoring `--only`; clear ignoring `--dry-run`; clear before the pre
  stage.
- Full suite: 96 OK, exit 0. Lint passes. Reviewer READY.
- On the VM, against a copy of `~/dots` with the fixed install-void.sh:
  - SIGINT to the process group mid-build: exit 130, and the stamp empty.
  - `dots update --dry-run` then said "no finished install is recorded yet
    … would re-run the installer".
  - A real `dots update` converged: stamp 784d203, then "already up to date".
- Test-harness note: my first attempt launched the installer as a background
  job of a non-interactive shell, which starts with SIGINT ignored. The
  installer then "ignored" Ctrl-C and exited 0. That was a false finding,
  caught by checking `SigIgn` in `/proc/<pid>/status`. The real test resets
  SIGINT to default with a python3 `os.execvp` wrapper.

## Follow-ups
- none
