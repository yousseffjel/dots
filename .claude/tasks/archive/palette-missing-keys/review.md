# Review — palette-missing-keys

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | One gate in the engine (every run + --check); theme-apply calls --check rather than re-implementing it. Placeholders read from the templates, keys from the parser's own sed script — no list. THEMING.md + CHANGELOG updated. |
| 2 | Size/Performance | ✅ | apply-templates.sh 246 (< 250), theme-apply.sh 198, palette_gaps 8 lines; one grep over ~11 templates per run. |
| 3 | Types/Validation | ✅ | Placeholder regex = parser key charset (all shipped placeholders conform, checked). comm/grep inside process substitutions cannot trip set -e/pipefail. First test run showed the empty .theme.lock as a write: excluded with a comment (taken before validation, by design). SC2016 directive added. |
| 4 | Dependencies | ✅ | comm/grep/sed/sort: coreutils + grep already used. Test runs in the CI tests job (glob). |

Mutants (tar copy): gate only under --check; theme-apply pre-check removed; comm sides swapped; placeholder regex without digits — all caught.
VM (headless, session down): theme-apply and apply-templates both exit 1 naming pry1 txt1, cache/config hashes unchanged; four shipped palettes and the live wallbash cache pass --check.

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY (with warning)
**Notes:** WARN — the always/theme group distinction was untested (theme/ ships no template). Resolved: the test now adds a theme/ template in the copy using a key no palette has; `all` refuses it, `always` does not read it.

## Test Gate
**Command:** bash tests/run-tests.sh
**Result:** ✅ PASSED (101 OK)
