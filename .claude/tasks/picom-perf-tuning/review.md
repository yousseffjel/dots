# Review — picom-perf-tuning

## Audit Loop

Tier: **Medium+** (10 files, +475/-66 — `git add -N` first, since `--shortstat`
does not count untracked files). Sweeps run strictly 1 → 2 → 3 → 4.

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0. Lockstep invariant holds; no Forbidden path touched; template keeps its `target\|post-command` header. `grep picom scripts/symlinks.sh` did hit — but only the explanatory comment at line 32; the `LINKS` array has zero picom entries, so the copy-not-symlink rule is intact. |
| 2 | Size/Performance | ✅ | **1 found, 1 fixed.** `detect-transient` removed from both files. It groups windows via `WM_TRANSIENT_FOR` so a group counts as focused together, which only changes rendering if focus does — and here it cannot: `inactive-opacity` equals `active-opacity`, with no `inactive-dim` or `focus-exclude`. It was reading a property per window to feed a decision with no output. Same reasoning that had already removed `detect-rounded-corners`. All files within caps (largest 133/250); functions 3 and 16 lines. |
| 3 | Types/Validation | ✅ | **2 found, 2 fixed.** (a) `set -uo pipefail` → `set -euo pipefail`, matching the other three tests and CLAUDE.md rule 1. (b) `check_balance` compared brace counts as strings; `wc` emits leading whitespace on some platforms, which would make `12` and ` 12` compare unequal — now numeric. Deliberately re-ran the full mutation suite after the `-e` change, since `set -e` can abort early and mask an intended failure path. |
| 4 | Dependencies | ✅ | 0. The test needs only base tools (bash/sed/grep/diff/tr/wc/coreutils), does not require picom to be installed, and reads nothing outside the repo. |

**Audit verdict:** ✅ READY

## Test Gate
**Command:** `bash tests/lint.sh && bash tests/pkglist.sh && bash tests/picom-lockstep.sh && bash tests/build.sh`
(repo convention — no config.yml, package.json or Makefile at the root)
**Result:** ✅ PASSED — all four exit 0. lint clean; package lists valid; lockstep
verified with no stray placeholders and balanced braces; all five suckless
programs still build (regression only — no C touched).

The new CI `tests` job was exercised too, by extracting its `run` block from
`.github/workflows/ci.yml` and executing it: green path skips `build.sh` and
`lint.sh` with the reason printed and runs the other two (rc=0); against a
deliberately drifted `picom.conf` it exits 1. So the job is wired to actually
fail, not merely to run.

Plus 6 mutants against `tests/picom-lockstep.sh`, all caught — re-run after the
`set -uo` → `set -euo` change, since `-e` can abort early and mask a failure
path. One mutant went stale when `detect-transient` was removed in audit
iteration 2 and was retargeted; the harness's own no-op detector caught that.

## Reviewer Gate
**Verdict:** READY
**Notes:** Clean first round, no issues raised. Pointed specifically at the four
things most worth doubting: whether the two files are genuinely in lockstep
including anything the comment-stripping could hide, whether the test's
isolation really prevents the template engine from touching the live session,
whether the new CI job actually goes red on failure, and whether any picom v13
option is now dead or contradictory with shadows off.
