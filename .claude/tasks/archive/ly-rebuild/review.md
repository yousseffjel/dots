# Review — ly-rebuild

## Audit Loop
Tier: Medium+ (7 files, +183/-33).

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | rules 1-3; sourced-file pattern as install-pkg-repos.sh; CHANGELOG Fixed line; ly never restarted |
| 2 | Size/Performance | ✅ | place.sh 90, ly.sh 195, test 223; ly_install 50 |
| 3 | Types/Validation | ✅ | 1 fixed: a leftover .dots-new is removed before cp (cp writes through a link) |
| 4 | Dependencies | ✅ | none new; mv -T is GNU coreutils (Void's); test seals stat |

Mutations: 10/10 caught (scratch copies). Suite rc 0, 94 OK. Lint passed.

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY
**Notes:** first round.

## Test Gate
**Command:** bash tests/run-tests.sh
**Result:** ✅ PASSED (rc 0, 94 OK)
