# Progress — queue-sweep-1-5

## Status
`in-progress`

## Steps
- [x] 1. Split `install-session.sh` -> `install-session-report.sh` (250 -> 192)
- [x] 2. `tests/lint.sh --strict`; CI `lint` + `build-suckless` call the scripts
- [x] 3. Read-loop replaces `cut | grep -qxF` in `install-restore-theme.sh`
      (repro: old shape 0/5 found, new 5/5, on 200k rows with target first)
- [x] 4. Bound `xresources.dcol`'s `xrdb -merge` with `timeout 10`
      (both branches shimmed: rc=124 at 10s wedged; rc=0 without timeout)
- [x] 5. `$XDG_DATA_HOME` for TPM — installer + `30-plugins.conf`, verified
      against a real tmux 3.7b server (custom + unset XDG_DATA_HOME, and a
      re-run that does not re-clone); + `tests/tmux-tpm-lockstep.sh`
- [x] 6. Docs: `HANDOFF.md`, `TESTING.md`, `CLAUDE.md`

## Deviations
- **Step 5 gained `tests/tmux-tpm-lockstep.sh`** (not in plan.md's 6 steps).
  The step creates a new two-file coupling; the plan mitigated that only with
  "change both in one commit", which protects this commit and nothing after.
  The repo answers this shape with a consistency test four times already, and
  HANDOFF.md names that shape the highest-yield test here. Four mutants, all
  caught — including one that keeps the correct *spelling* but points at a
  different directory, which the grep checks alone would have missed.
- **Step 2 gained an empty-file-list guard in `tests/lint.sh`.** Found while
  mutation-testing `--strict` on a sealed PATH: with `find` unavailable,
  `SH_FILES` came back empty and both shell linters would have been handed
  zero paths. Now a hard failure rather than a quiet pass.

## Blockers
_(none)_
