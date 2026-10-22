# dwm-test-stale-build
Date: 2026-10-22
Files: 6 | Lines: +160/-0 (two new files, 131 lines; 29 lines in four edited)

## What changed
- New `tests/lib/dwm-build-fresh.sh`: `dwm_build_stale <binary>` prints the
  first reason the built dwm is stale, with the command that fixes it:
  - a `*.c`, `*.h`, `config.mk` or `Makefile` in its own directory (depth 1)
    is newer than the binary (`make -C <dir>`);
  - `config.def.h` is newer than an existing `config.h`, which make never
    regenerates (`rm <dir>/config.h && make -C <dir>`).
- `tests/dwm-runtime.sh` and `tests/dwm-multimon.sh` source it right after
  their "no binary" skip, and **fail** (exit 1, never skip) on a stale build.
- New `tests/dwm-build-fresh.sh`: 10 cases on a fake build directory with
  set mtimes (no compiler, no X).
- `TESTING.md` gets an entry for it, and `CHANGELOG.md` [Unreleased] → Fixed
  gets one line.

## Why
During the 2026-10-22 readiness check for the user's main machine, the full
suite failed five `dwm-multimon.sh` checks (status on both bars, replug)
on code that was correct. Main's `suckless/dwm/dwm` was built on
2026-10-19. The `statusallmons` and `replug` changes to `dwm.c` (2026-10-21)
had been built and tested in their own slot worktrees, and main's untracked
binary was never rebuilt. After `make -C suckless/dwm` the test passed and
the main suite was 106/106. The reverse is the worse case: a regression
made to `dwm.c` after the last local build would pass. CI builds first, so
it was never affected.

## Assumptions
- **Type B: fail, not skip.** A skip reads as green in the suite total, and
  a stale binary is exactly what hides there. Alternative: skip loudly, as
  for a missing binary. If wrong, change `exit 1` to `exit 0` in both
  guard blocks.
- **Type C: mtimes are the signal**, as `make` itself uses. A build in the
  same second as the change reads as fresh (`-newer` and `-nt` are strict).

## Test coverage
- Test first: with an empty helper, `tests/dwm-build-fresh.sh` failed (127).
- Mutants on a tar copy in the scratchpad, all caught after two fixes:
  - no config.def.h check;
  - no `-e config.h` guard;
  - no `*.h`, no `config.mk`, no `Makefile`;
  - no `-maxdepth` (the first version survived: its `patches/x.diff` matched
    no pattern, so the case became a `.c` in a subdirectory);
  - always stale.
  `-type f` survived with no realistic case to justify it and was removed.
- End to end on that copy, with dwm built:
  - both tests run past the guard; `dwm-runtime.sh` was all green;
  - after `touch dwm.c`, both fail, naming the `make -C` command.
- CI check: `build-suckless` runs `tests/build.sh` (`make clean && make` in
  place), then both tests in the same tree, so the binary is always newer.
- `bash tests/lint.sh`: passed.
- Suites:
  - Slot: `timeout 590 bash tests/run-tests.sh`, 107/107 OK. The slot has
    no built binary, so the two X tests skip there.
  - Main, after the rebuild: 106/106 OK.
- Reviewer: READY.

## Follow-ups
- The same blind spot can exist for any other test that runs a built
  suckless binary, but today only these two do (`grep` of `tests/*.sh` for
  `suckless/<prog>/<prog>"`; `migration-0.2.0.sh` builds nothing).
