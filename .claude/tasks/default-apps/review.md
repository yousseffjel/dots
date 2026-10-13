# Review — default-apps

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 5 fixed: history helper moved to global_fn.sh; tests/build.sh reads PROGRAMS; rule-4 vendoring conflict surfaced + recorded in CLAUDE.md; THEMING/ROADMAP/script-header drift |
| 2 | Size/Performance | ✅ | 1 fixed: --help header overflow. All files ≤250, functions ≤60 |
| 3 | Types/Validation | ✅ | 5 fixed: repo_in_use fail-open → fail-closed (+test); --queryformat; pipefail grep -q in test; set -e abort in test; 2 false-passing fixtures (tier crash, swap repo) |
| 4 | Dependencies | ✅ | 2 fixed: cmp → bash compare (diffutils undeclared); shfmt-mangled assoc keys quoted |

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY
**Notes:** No issues raised. Worktree verified unchanged after the review (same diffstat, nothing staged).

## Test Gate
**Command:** tests/run-tests.sh (plus tests/lint.sh and tests/build.sh, which the runner skips because their own CI jobs run them)
**Result:** ✅ PASSED (exit 0, 60 test scripts OK)
