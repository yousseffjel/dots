# update-arg-check
Date: 2026-10-21
Files: 3 | Lines: +~70/-5

## What changed
- `scripts/update.sh`: new `installer_takes` refuses a pass-through flag install-void.sh does not take, before preflight and the fetch. The accepted set is read from install-void.sh's own `--x)` case labels (sed), not listed. Header's "Refuses — before touching anything" list names it.
- `tests/dots-update.sh`: the stub installer now carries the real installer's case labels and rejects anything else, as the real one does; new section: `--skip-sucless` and `--only` (a prefix) are refused with HEAD and origin/main unmoved and no installer run; every real flag but --dry-run is passed through.
- CHANGELOG [Unreleased] Fixed line.

## Why
Edge-case pass over `dots <sub> --help`/unknown args on the Void VM: update.sh forwarded unknown args after `git fetch` + fast-forward, so a typo left the checkout updated and nothing installed, contradicting its own header.

## Assumptions
- Type B: the CURRENT checkout's installer defines the accepted flags; a flag the incoming commits add is refused until the next update (documented in the function comment).

## Test coverage
- New checks failed before the fix (HEAD moved). Mutants on a tar copy: call removed, `-x` dropped from grep (caught by the `--only` prefix case), empty-set early return forced: all caught.
- Reviewer WARN: (1) "install-void.sh has no --help": false, it exits 0 (handled before its flag loop); (2) the function had split preflight's comment from preflight: fixed by moving it above.
- lint passed; full suite 100 OK.

## Follow-ups
- none
