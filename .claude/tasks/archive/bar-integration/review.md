# Review — bar-integration

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 2 fixed — new tests were 644 (suite convention 755); Makefile installed dwm-blockutil 755, now 644 like dwm-colors |
| 2 | Size/Performance | ✅ | 1 fixed — polled cpu/mem/temp sourced dwm-blockutil every run; now only on a click. Max file 146, max function 12 |
| 3 | Types/Validation | ✅ | 1 fixed — GAMMA's backgrounded night-light group kept the block's stdout open; whole group now redirected |
| 4 | Dependencies | ✅ | 0 — htop already in extra.lst; scripts scanned POSIX-clean, but dash (CI's /bin/sh) not run locally |

**Audit verdict:** ✅ READY

Verification: suite 46/46 OK, lint green. Mutations 15/15 caught (on copies).
A real bug surfaced: dnf5's "Upgrades" header leaked into the left-click list.

## Reviewer Gate
**Verdict:** READY
**Notes:** Round 1 WARN — GAMMA resolved dwm-brightness via block_bin, so a
missing dwm-blockutil made it render n/a, breaking the helper's own "only
clicks stop" promise. Fixed: inline lookup restored for rendering; new test
runs a solo copy with no helper (mutation B16 caught). Round 2: READY.
Both rounds forbade worktree edits; unstaged diff empty afterwards.

## Test Gate
**Command:** tests/run-tests.sh
**Result:** ✅ PASSED — 46/46 OK, 0 FAIL, 0 SKIP (blocks-audio/info/system, dwm-net and dwm-runtime all ran)
