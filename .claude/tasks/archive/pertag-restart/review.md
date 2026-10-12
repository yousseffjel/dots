# Review — pertag-restart

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1 fixed — dwm-runtime.sh header said "seven vendored patches" next to "no patch count"; now names preservepertag + wakeonsignal, no count |
| 2 | Size/Performance | ✅ | 2 fixed — dwm-runtime-restart.sh 275 ln and check_pertag_restart 80 ln → tests/lib/dwm-runtime-pertag.sh (148), functions ≤ 54 |
| 3 | Types/Validation | ✅ | 0 — every _DWM_PERTAG field bounded; layout by index; read once |
| 4 | Dependencies | ✅ | 0 |

**Audit verdict:** ✅ READY

Verification: suite 47/47, lint green, dwm-runtime 3+2 clean runs, diff
reproduces dwm.c. Mutations 6/6 (Q2 needed the new fresh-session check).

## Reviewer Gate
**Verdict:** READY
**Notes:** First round, no findings. Prompt forbade any writing git command;
unstaged diff empty and staged stat unchanged afterwards.

## Test Gate
**Command:** tests/run-tests.sh
**Result:** ✅ PASSED — 47/47 OK, 0 FAIL, 0 SKIP (dwm-runtime incl. both pertag restart checks)
