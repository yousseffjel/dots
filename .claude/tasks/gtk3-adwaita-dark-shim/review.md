# Review — gtk3-adwaita-dark-shim

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1 fixed: fake() in tests/lib/sealed-path.sh wrote through the copied symlink toward /usr/bin/cp (stopped by permissions); now rm -f first; 15 sealed-path tests re-run OK |
| 2 | Size/Performance | ✅ | 0 — max file 238, max function ~30; install-restore-theme.sh 225 (+source/call only) |
| 3 | Types/Validation | ✅ | 1 fixed: failed cp -r left a partial unclaimed Adwaita-dark; now cleared + test + mutant caught |
| 4 | Dependencies | ✅ | 2 fixed: no guard for restore_gtk3_shim wiring (symmetry now checks the THEME row) or for the xdg-data/themes grant (derived counts are self-referential; shim test now asserts it) |

**Audit verdict:** ✅ READY — lint clean, suite 40 OK / 0 FAIL, 11/11 mutants caught on copies + the partial-copy mutant

## Reviewer Gate
**Verdict:** READY
**Notes:** No issues flagged. Tree fingerprinted before review and verified byte-identical after; index empty. Resolved earlier in the round: fake() symlink write-through (hardened in sealed-path.sh), partial-copy leftover, missing wiring/grant guards.

## Test Gate
**Command:** tests/run-tests.sh
**Result:** ✅ PASSED — 40 OK, 0 FAIL (lint.sh and build.sh run in their own CI jobs; tests/lint.sh passed locally)
