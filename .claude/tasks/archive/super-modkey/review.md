# Review — super-modkey

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | Reuse: header-refresh rule duplicates the 0.1.0->0.2.0 migration's matches_history; kept separate on purpose (released migration is frozen, its test copies the file alone). CHANGELOG [Unreleased] present. |
| 2 | Size/Performance | ✅ | All new files < 160 lines, functions < 60. KEYBINDINGS.md is a doc (568, pre-existing size). |
| 3 | Types/Validation | ✅ | 1 fixed: norm_chord's `grep -v '^$'` aborted silently under set -e with no modifiers; parsers moved out of `||` context so a failure can no longer read as "no chords". |
| 4 | Dependencies | ✅ | git (core.lst), coreutils comm/paste/sort only. |

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** WARN round 1 (stale dwm.1 man page + dwm.c Alt+minus comment) — fixed; round 2 below
**Notes:** READY on round 3 (round 1 WARN dwm.1 + dwm.c comment; round 2 WARN PATCHES.md ownership note; both fixed)
