# Review — manifest-has-path

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1 found / 1 fixed — the relocated manifest-category comment sat directly above `deploy_theme_file` and read as its doc block; given an explicit section banner. |
| 2 | Size/Performance | ✅ | 0 — 223 / 156 / 148 / 164 lines, all under 250; every function under 60; the new test costs 0.64s per CI run. |
| 3 | Types/Validation | ✅ | 2 found / 2 fixed — SC2329 (local `red`/`green`/`blue` were dead code, overwritten by the sourced `global_fn.sh`) and SC2015 (`cmd && pass \|\| fail` could run both). Both fixed at source; **zero suppressions added**. |
| 4 | Dependencies | ✅ | 0 — only `cut` is invoked and it was already a dependency; `global_fn.sh` sources nothing, so no cycle; the test exports `XDG_STATE_HOME` **before** sourcing the file that derives `MANIFEST_DIR` from it. |

**Audit verdict:** ✅ READY

Tier: Medium+ (10 files, +348/-72) — full 4 sequential sweeps.

Evidence beyond reading:
- `manifest_has_path` 5/5 vs. the replaced pipeline 0/5 on a 200k-row manifest.
- `uninstall.sh --dry-run` in a four-variable XDG sandbox: correct rows read, both
  fixture files still present afterwards, real manifest untouched.
- Full suite 8/8 runnable + `tests/lint.sh --strict` clean; dunst held PID 6788
  throughout, so no template post-command escaped its sandbox.

## Test Gate
**Command:** `for t in tests/*.sh; do bash "$t"; done` (TESTING.md:13)
**Result:** ✅ PASSED — 10/10, exit 0

Full suite this time, including the two `/code` deliberately excluded:
`build.sh` compiled all five suckless programs (2s) and `lint.sh` passed.
Note `lint.sh` ran here **without** `--strict`, the spelling the documented
runner uses; the `--strict` form CI passes was run separately during `/code`
and also passed, so both paths are covered.

dunst held PID 6788 across the whole run — no template post-command escaped
its sandbox.

## Reviewer Gate
**Verdict:** READY
**Notes:** Clean first round, no issues raised. Brief was pointed at the six
rewired call sites (category semantics vs. `git show HEAD`), surviving
references to the three deleted names, whether the deleted comment knowledge
was relocated or lost, whether the test exercises the shipped function rather
than a copy, and `set -e`/`set -u` behaviour of the helper and its callers.
