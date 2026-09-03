# Review — dwm-runtime-xvfb

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0 |
| 2 | Size/Performance | ✅ | 372-line file noted (largest test in repo) — not split; single cohesive integration test with expensive shared Xvfb+dwm setup, same "note not act" precedent as CLAUDE.md's own growth |
| 3 | Types/Validation | ✅ | 1 fixed — `master_width()` now falls back to "0" instead of risking an empty-string arithmetic abort under `set -e` |
| 4 | Dependencies | ✅ | 0 |

**Audit verdict:** ✅ READY

## Mutation testing (locked decision 4: "deliberate mutations... caught")
- **xresources**: neutered `xresupdate()`'s resource-loading loop (early
  `return`) → border showed the compiled-in default (`#5294E2`) instead of
  `#123456` → **caught**.
- **pertag**: first attempt neutered the mfact restore in `toggleview()`
  (wrong function — the keybinds used call plain `view()`) → test stayed
  green, proving nothing. Re-targeted `view()`'s own restore line → tag2
  showed tag1's adjusted mfact (892px, not the isolated 700px default) →
  **caught**. Both mutations reverted; `git status` on `suckless/dwm/dwm.c`
  confirmed clean before commit.

## Reviewer Gate
**Verdict:** READY
**Notes:** Confirmed `suckless/` byte-identical to HEAD (clean mutation
revert), the empirically-measured border offset is well-flagged and applied
consistently, the restartsig advisory design is documented and doesn't
undermine the suite's credibility, CI dependency names are plausible and
clearly CI-only-scoped, and the skip-loudly prerequisite checks exit before
any trap/tempdir setup.

## Test Gate
**Command:** tests/run-tests.sh (via .claude/config.yml)
**Result:** ✅ PASSED (full suite, includes dwm-runtime.sh)
