# running-build-stale
Date: 2026-10-20
Files: 10 | Lines: +215/-5

## What changed
- New `scripts/running-build.sh`, sourced and never run alone:
  - `running_build_stale <name>` scans `$DOTS_PROC` (default `/proc`, read at
    call time) for this user's processes with that name. It reports one as
    stale when the running binary differs (`cmp`) from the file now at its
    path.
  - A binary that was never replaced compares equal to itself. One removed
    outright is skipped.
  - `running_build_report` prints the restart command for each stale one:
    `pkill -HUP -x dwm` (restartsig re-exec in place) and
    `pkill -x dwmblocks; setsid -f dwmblocks`.
- `install-suckless.sh` and `install-void.sh` end with `running_build_report`,
  so it is the last thing a `dots update` prints.
- `dots doctor`: `check_running_builds` (doctor-session.sh, called from
  check_session) reports `ok session builds` or `warn session build-<name>`.
- Tests:
  - new `tests/running-build.sh`;
  - three new cases in `tests/doctor.sh`;
  - `tests/lib/doctor-sandbox.sh` passes `DOTS_PROC="$SB/proc"`, so doctor
    tests never scan the host's processes.
- Also updated: the CHANGELOG [Unreleased] Fixed line and the CLAUDE.md
  project-map entry.

## Why
Found on the Void VM during the 0.4.0 → 0.5.0 upgrade (2026-10-20). The user
was logged into dwm while `dots update` ran. `make install` replaced
`/usr/local/bin/dwm` and `dwmblocks`, but the running processes kept the old
code (`/proc/<pid>/exe` → `... (deleted)`). Nothing reported it, and new
patches took effect only after the next theme change or login. Reproduced
with a second `install-suckless.sh --skip-deps`.

## Assumptions
- Type B: "stale" means replaced and with different content, so a rebuild
  of unchanged sources stays quiet. That case was seen live on the VM: the
  morning's identical rebuild reported ok.
- Type B: the hint is printed by both installers, so a full run shows it
  twice: once in the suckless stage, and again at the end, where a
  `dots update` user actually reads. install-suckless.sh stays
  standalone-runnable and needs its own copy.
  - Alternative: an env flag from install-void.sh to silence the inner one.
    Rejected as coupling for one repeated line.
- Type B: st, dmenu and slock are left out: they are short-lived, and their
  next start uses the new build.

## Test coverage
- `tests/running-build.sh` covers:
  - stale;
  - identical;
  - never replaced;
  - removed outright;
  - another name;
  - a non-numeric entry;
  - the report's contents and its silence;
  - both installers ending with the call.
- `tests/doctor.sh`: 104 passed (the warn and ok paths, with the in-place hint).
- Mutants: 9 of 11 caught.
  - M2 (no `(deleted)` pre-check) was equivalent, so the line was removed.
  - M3 (no owner check) cannot be faked without a second user or root.
    Untested by the suite.
  - M11 (removed binary counted as stale) was caught by the case added for it.
- Full suite: 96 OK, exit 0. Lint passes. Audit READY; reviewer READY.
- On the VM, against a copy of `~/dots` with this slot's scripts laid on top:
  - Identical rebuild: `ok session builds`.
  - dwm built with `VERSION = 6.8-vmtest`, installed under the live session:
    - The installer ended with the dwm hint, and doctor warned `build-dwm`.
    - `pkill -HUP -x dwm` kept the same pid and `_NET_CLIENT_LIST`, and
      switched to the new exe. Doctor was ok afterwards.
  - `pkill -x dwmblocks; setsid -f dwmblocks` gave a new pid on the new
    binary, and the bar kept drawing.
  - The original build was then reinstalled from `~/dots` and dwm
    re-exec'd. Doctor: all checks passed.

## Follow-ups
- none
