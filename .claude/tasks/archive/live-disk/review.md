# Review — live-disk

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 2 fixed: `$'\n'` inside a quoted `${:+}` (menu text); a pre-mounted target from the chosen disk must resume, not be refused (deviation) |
| 2 | Size/Performance | ✅ | 2 fixed: live-disk.sh 269 and live-dry-run.sh 282 lines, split with tests/lib/*-env.sh; tenth-of-root computed once |
| 3 | Types/Validation | ✅ | 3 fixed in tests: `( ) \|\| true` turned set -e off (production calls are plain); base.sh resets LIVE_FIRMWARE on source; fake umount left a stale mount table. 28/28 mutants caught |
| 4 | Dependencies | ✅ | 2 fixed: lib `source=` hints need ../../; `local rc` in a sourced module shadowed the test's rc (SC2031). New tools all on the 20250202 ISO and in preflight |

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY
**Notes:** No issues raised. Before the reviewer ran: full suite 89 OK, lint --strict passed, 28/28 mutants caught, VM runs from the ISO on UEFI (answers file, interrupted and resumed) and BIOS (dialog menus), both booted to ly with zram and the swapfile active.

## Test Gate
**Command:** tests/run-tests.sh
**Result:** ✅ PASSED (89 OK)
