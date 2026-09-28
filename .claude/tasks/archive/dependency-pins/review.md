# Review — dependency-pins

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1 fixed: Fedora schedule deep link unverifiable (Anubis bot wall on both candidate pages) -> docs root. |
| 2 | Size/Performance | ✅ | 0. linter-pins.sh ~95 lines; check_pin 20. |
| 3 | Types/Validation | ✅ | 0. Empty extraction fails per-linter; packaging-rev bump is a passing negative control. |
| 4 | Dependencies | ✅ | 0. git mv keeps history; no live refs to the old name. |

Verification: 5/5 sandboxed mutations CAUGHT (bot bump of each of the 3 hooks, ci key renamed, hook repo renamed) + 1 negative control (packaging-only rev bump) correctly passes. dependabot.yml parses; lint + run-tests green.

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY (with warning) -> fixed
**Notes:** WARN — a YAML-quoted `rev: 'v…'` would false-fail pc_pin. Fixed before commit: both extractors strip quotes; verified a quoted-but-equal control passes (rc=0) and a quoted bump fails (rc=1). Reviewer also noted fedora:43 is doubly out of Dependabot's reach: the container image is `${{ matrix.fedora }}`, not a literal.
