# theme-change-lock
Date: 2026-10-20
Files: 6 | Lines: +161/-0

## What changed
- New `scripts/theme/theme-lock.sh`, sourced first thing by `wallpaper.sh`
  and `theme-apply.sh` with their own path and arguments.
  - The first pass re-runs the script under
    `flock -o -w ${DOTS_THEME_LOCK_WAIT:-60} -E 75`, on
    `<cache>/dots/theme/.theme.lock`, and exits with its status.
  - The re-run sees `DOTS_THEME_LOCKED`, unsets it and carries on.
  - A change still waiting at the timeout exits 75 and says so.
  - It runs unlocked when flock is missing or the lock file cannot be made.
- `wallpaper.sh` (2 lines, now exactly 250) and `theme-apply.sh` source it.
- Tests: new `tests/theme-lock.sh`.
- Also updated: the CHANGELOG [Unreleased] Fixed line and the CLAUDE.md
  project-map line.

## Why
On the Void VM, two concurrent `dots wallpaper --random` runs interleaved.
`~/.fehbg` ended on game-relaxed-mario.png (run 2), but `colors.dcol` came
from nature-dunes-sunset.jpg (run 1: pry1 #0C2244, written 2 s after run 2
set its wallpaper). The desktop showed one wallpaper with another's colours.
Only reload.sh held a lock; feh → colorgen → apply-templates ran unguarded.
A double press of Super+w, or autorandr's hook during a manual change, gets
there.

## Assumptions
- Type B: serialise (queue) rather than cancel the older change. The last
  change started is the one that remains, and each is a complete run.
  Alternative: a "superseded" check before writing the palette, which still
  leaves a check-to-write window.
- Type B: use `flock -o` instead of an fd held in the script. util-linux's
  `flock FILE CMD` hands the lock fd to CMD (checked: `/proc/$$/fd` lists it,
  2.41.4 on the VM and 2.42.4 on the host). `-o` keeps it with flock alone, so
  the dwmblocks a change starts cannot hold it. That is the leak reload.sh's
  header records.
- Type C: reload.sh keeps its own lock, since it is also run alone.

## Test coverage
- `tests/theme-lock.sh` covers:
  - no interleave;
  - the exit status passed through;
  - the marker not inherited;
  - a detached child not holding the lock;
  - the timeout giving 75 plus a message;
  - no flock on PATH, which runs unlocked;
  - both entry points sourcing it.
- 6/6 mutants, each caught by its own check. The first harness run reported
  M1 (no `-o`) as CAUGHT only because the test aborted silently under
  `set -e`. The check now captures the status and reports it.
- The existing wallpaper and theme tests (10) pass. Full suite: 97 OK,
  exit 0. Lint passes. Audit READY; reviewer READY.
- On the VM, against a copy of `~/dots` with this slot's three scripts, three
  rounds of two concurrent `wallpaper.sh --random` runs:
  - every round's wallpaper and `dcol_pry1` match the run that finished last;
  - dunst kept the same pid;
  - dwmblocks holds no `.theme.lock` fd;
  - dwmblocks settled to one instance (a count of 2 right after round 3 was
    reload's kill-and-start overlap).

## Follow-ups
- `scripts/theme/wallpaper.sh` is exactly at the 250-line cap. The next
  addition there must run split-oversized-file first.
