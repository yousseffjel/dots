# Review — dwm-hyprland-mouse

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | placemouse grab/beingmoved leak on failed getrootptr fixed (deviation 3 in PATCHES.md); TESTING.md entry appended |
| 2 | Size/Performance | ✅ | shfmt fixed; test lib 236 lines, longest function 39 |
| 3 | Types/Validation | ✅ | SC2034 x2 fixed; restored cfact range-checked; no new -Wextra warnings |
| 4 | Dependencies | ✅ | none added |

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY (with warning)
**Notes:** WARN — (1) "tag/toggletag tag-bar bindings dropped": false positive; only the duplicate pair was removed (plan step 6), the bindings remain at config.def.h:242-243. (2) floating resize ignores size hints: intended, resizepoint upstream behaviour, recorded in PATCHES.md.

## Test Gate
**Command:** tests/run-tests.sh
**Result:** ✅ PASSED (107 scripts OK, 0 failed; dwm-runtime.sh incl. the new mouse checks)
