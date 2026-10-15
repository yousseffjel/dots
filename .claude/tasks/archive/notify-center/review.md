# Review — notify-center

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | jq failure masked as empty history (fixed: records var + message); sxhkdrc path split |
| 2 | Size/Performance | ✅ | MD013 line in KEYBINDINGS.md; dwm-notify 180 lines, max fn 37 |
| 3 | Types/Validation | ✅ | dmenu -z MAX(argv[++i]) double-eval crash; jq null on empty urls |
| 4 | Dependencies | ✅ | `cmd` not local; xdg-utils undeclared (pre-existing, open question) |

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY (with warning)
**Notes:** WARN — stray untracked suckless/dmenu/d.pid (leftover from the first, hung zsh geometry run). Removed before commit; nothing else flagged, tests/notify-center.sh passed for the reviewer.

## Test Gate
**Command:** tests/run-tests.sh
**Result:** ✅ PASSED — 73/73 (dwm-runtime included); tests/lint.sh --strict and tests/build.sh run separately, both pass
