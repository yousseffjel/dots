# Review — release-0.5.0

## Audit Loop
Tier: Medium+ (6 files, +274/-10).

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | rules 1-3 hold (set -euo, colours, SCRIPT_DIR); manifest edited only for nsxiv rows; migrate.sh records the version |
| 2 | Size/Performance | ✅ | migration 104 lines, test 156; longest function remove_build 16 |
| 3 | Types/Validation | ✅ | 2 fixed: eval in checks → named predicates (SC2016); SC2329 directives justified. Prefix only from a row ending /bin/nsxiv |
| 4 | Dependencies | ✅ | none new; fake sudo first on PATH, env -i, four XDG vars sandboxed |

Mutations: 7/7 caught (scratch copies). Suite: rc 0, 94 OK. Lint: passed.

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY
**Notes:** first round. After it, CLAUDE.md rule 4's "migration (queued)" sentence was updated to name the shipped migration (docs only).

## Test Gate
**Command:** bash tests/run-tests.sh
**Result:** ✅ PASSED (rc 0, 94 OK)
