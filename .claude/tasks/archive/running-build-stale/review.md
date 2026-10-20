# Review — running-build-stale

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | Helper shared by 3 callers in its own sourced file (global_fn.sh at 242/250); caller's yellow() like reload-dunst.sh; CHANGELOG + CLAUDE.md map line; doctor sandbox fakes DOTS_PROC so tests never read the host's /proc |
| 2 | Size/Performance | ✅ (1 fixed) | `$(cat comm)` forked per process ×2 → `read` builtin (11 ms on the host); all files < 250 (doctor.sh test 244) |
| 3 | Types/Validation | ✅ (2 fixed) | SC2015 A&&B\|\|C split; a binary removed outright read as stale and its hint (HUP dwm) would exec nothing and end the session → skipped + test (M11 caught) |
| 4 | Dependencies | ✅ | cmp (diffutils, a base-system dep; already used by sysfile-lib.sh), readlink, setsid (util-linux), pkill (procps-ng) |

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY
**Notes:** first round, no issues raised.

## Test Gate
**Command:** bash tests/run-tests.sh
**Result:** ✅ PASSED (96 OK)
