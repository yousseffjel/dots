# Review — live-interrupt

## Audit Loop
Tier Medium+ (17 files incl. 2 new tests, +~240/-50).

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | Rules 1-3 hold. stop_on_interrupt is defined once in global_fn.sh. install-live.sh keeps its own pre-existing traps (it never sources global_fn.sh). No INT/TERM trap elsewhere in the chain clashes (apply-templates.sh is a child with an EXIT cleanup). CHANGELOG Fixed line, LIVE-INSTALL.md and the CLAUDE.md map are updated. 0 open. |
| 2 | Size/Performance | ✅ | tests/live-dots.sh hit 291 lines: the release-only cases were split into tests/live-release.sh (223 + 106). Every function ≤60 lines. On the normal path release costs nothing (no rooted pids, so it breaks at once). 1 found, fixed. |
| 3 | Types/Validation | ✅ | Kill by exact /proc root match. A target of `/` is refused by preflight before the trap is armed. Every test kill path uses LIVE_PROC, never the real /proc. A cleanup-without-release regression used to HANG the test (the orphan held the output pipe): stdio is now detached and survivors are KILLed. install-pre.sh's sealed-env test was given dirname and HOME. Lint: SC2034, SC2016 (justified directive), SC2030/2031 (FAKE_XCHROOT_KILL). 4 found, fixed. |
| 4 | Dependencies | ✅ | `env --default-signal` (coreutils ≥8.31; CI has 9.x) and setsid (util-linux), both in tests only. No new packages; no sourcing cycle. 0 found. |

Mutation check (scratch copies): 5/5 caught (revoke before release, cleanup without release, single-pass release, empty stop_on_interrupt, a stage missing the call).
VM (dots-live-j3b, live ISO): a real Ctrl-C mid-package ends EXIT=130, with 0 processes left in /mnt and the rule gone; the re-run converges.
Suite: run-tests rc=0 (93 OK); lint ✓.

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY
**Notes:** No issues raised in the first round. The reviewer was told the worktree is read-only; the diff stat is unchanged after it ran.

## Test Gate
**Command:** tests/run-tests.sh
**Result:** ✅ PASSED (93 OK, rc 0)
