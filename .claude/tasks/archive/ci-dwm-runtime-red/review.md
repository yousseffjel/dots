# Review — ci-dwm-runtime-red

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0 — fix stays inside the existing test/lib split; procps-ng stays CI-only, out of build.lst (same reasoning as the other test tools) |
| 2 | Size/Performance | ✅ | 0 — dwm-runtime.sh 132, checks 186 lines; check_restartsig 28 lines |
| 3 | Types/Validation | ✅ | 1 fixed — "red since 2026-09-03" was the test's write date; CI API shows the first red run is 2026-09-08 (no pushes in between). Corrected in 3 places |
| 4 | Dependencies | ✅ | 0 — procps-ng is a real Fedora package (already in desktop.lst); pgrep requirement removed with its only use |

**Audit verdict:** ✅ READY

Verification (fedora containers, CI steps on a copy): unfixed tree exit=127
(reproduced); final tree 3/3 exit 0 on fedora:latest AND fedora:43, restartsig
ok each time; mutant dwm with a no-op sighup() → FAIL "never came back",
exit 1. Mutant without the root-property delete still passes (spawn_win's
MapRequest wakes dwm; the border-colour assertion is what proves the reload).

## Reviewer Gate
**Verdict:** READY
**Notes:** Round 1 WARN: (1) race — deleting _NET_SUPPORTING_WM_CHECK after
the HUP could remove the NEW dwm's property if a stray event restarted it
first; fixed by deleting before the HUP and waking dwm with a separate
_DOTS_TEST_WAKE root property. (2) header's "5/5" read as the final
verification; reworded to 5/5 on fedora:latest, then 3/3 on each image.
Re-verified both images 3/3 + no-op-sighup mutant FAIL on both. Round 2: READY.

## Test Gate
**Command:** tests/run-tests.sh
**Result:** ✅ PASSED (41 OK, 0 FAIL; dwm-runtime.sh skips on the dev host —
no built dwm — and was verified in fedora:latest + fedora:43 containers instead)
