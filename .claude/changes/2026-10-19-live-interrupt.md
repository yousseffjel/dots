# live-interrupt — Ctrl-C stops an install, direct and from the live ISO
Date: 2026-10-19
Files: 17 (+ this log, the archived task folder, state) | Lines: +346/-50

## What changed
- **`stop_on_interrupt`** (new, `scripts/global_fn.sh`): `trap 'exit 130' INT` and
  `trap 'exit 143' TERM`. It is called on the line after `source global_fn.sh` in
  `install-void.sh` and in every script it runs: install-pre, migrate, install-pkg,
  install-suckless, install-restore and install-services.
  - `install-pre.sh` now sources global_fn.sh only for this call. Its own messages
    are unchanged, and it gained rule 3's `SCRIPT_DIR` line.
- **`scripts/install-live-dots.sh`**:
  - `live_dots_rooted` lists live pids whose `/proc/<pid>/root` is the target. It
    reads `LIVE_PROC` in tests and drops dead pids with `kill -0`.
  - `live_dots_release` sends TERM first (so each script's trap ends it), then up
    to four KILL rounds, each rescanning, since a loop can start a new child
    between a scan and the kill. It says so when something would not stop.
  - `live_dots_cleanup` = release, then revoke.
- **`scripts/install-live.sh`**: the dots stage's EXIT trap is now
  `live_dots_cleanup` (it was `live_dots_revoke`), armed before the grant. The
  INT/TERM traps are unchanged.
- **Tests**:
  - `tests/install-interrupt.sh` (new): a real SIGINT to a setsid group around a
    fake xbps that exits 0 on INT. With the call the script stops at 130; without
    it the script carries on (the bug, reproduced). It also checks that every
    script install-void.sh runs (read from its own lines) calls
    `stop_on_interrupt` right after the source line.
  - `tests/live-dots.sh`: a new J-4 case. The fake xchroot leaves an orphan in the
    fake /proc and TERMs the stage. Expected: exit 143, the orphan stopped while
    the rule still exists, then the rule removed.
  - `tests/live-release.sh` (new, split from live-dots.sh at the 250-line cap):
    only the target-rooted process is stopped, and a TERM-proof loop is stopped
    along with every child it started.
  - `tests/install-pre.sh`: its `env -i` sandbox now has `dirname` and `HOME`,
    which the stage needs since it sources global_fn.sh.
- **Docs**:
  - CHANGELOG [Unreleased] Fixed: "Ctrl-C stops an install."
  - `docs/LIVE-INSTALL.md` "Running it again": what a Ctrl-C does now.
  - The CLAUDE.md map line for install-live-dots.sh.

## Why
Two separate failures, both reproduced on the VM before fixing (step 1, dots-live-j3b):
- **Direct run.** A Ctrl-C landing while xbps-install verified RSA signatures was
  swallowed. xbps exits 0 after that SIGINT, and bash's wait-and-cooperative-exit
  treats a child that exits normally as having handled the signal. So
  install-pkg.sh, install-void.sh and even the interactive shell carried on: the
  suckless build ran and the run ended `EXIT=0`.
  - A script with its own INT trap runs it once the child returns, whatever the
    child's status. That is why every script in the chain needs the call, not
    only install-void.sh: a stage without it would finish its remaining tiers
    first.
- **Live ISO (the J-4 queue item).** `su -c` runs install-void.sh in a new
  session, so the terminal's SIGINT never reaches it. `su` TERMs install-void.sh
  alone, which orphans the stage it was waiting on. The old EXIT trap then
  revoked the NOPASSWD rule while that stage kept running ("sudo: a password is
  required" in J-4's log). Now everything rooted in the target is stopped
  before the rule goes.

## Assumptions
- Type B: exit codes 130/143 (128+signal), the shell convention. Callers only
  test for non-zero.
- Type B: no extra "interrupted" message (plan step 2 named one). The release
  step already says what it stops, and the exit status carries the rest.

## Test coverage
- `tests/run-tests.sh`: rc 0, 93 OK. `tests/lint.sh`: passed (shellcheck, shfmt,
  markdownlint).
- Mutation check on scratch copies (never the worktree), 5/5 caught: revoke
  before release, cleanup without release, single-pass release, an empty
  `stop_on_interrupt`, and a stage missing the call.
  - The cleanup-without-release mutant first HUNG live-dots.sh: the fake orphan
    held the stage's output pipe. The orphan's stdio is now detached, and
    survivors are KILLed by the test, so a regression fails instead of hanging.
- VM, dots-live-j3b (Void live ISO, BIOS, plain, answers file; snapshot of this
  slot), with `install-live.sh` in the foreground on ttyS0:
  - A real Ctrl-C landed 20 s into the desktop-critical tier inside the target.
  - xchroot's umount of /mnt/dev said "busy", then "note stopping 8 process(es)
    still running in /mnt", then `EXIT=130`.
  - 20 s later: 0 processes rooted in /mnt, the rule gone, nothing but /mnt and
    /mnt/boot mounted, no xbps running, and no "password is required" or FAILED
    in install.log.
  - A re-run with the same answers resumed the target ("resuming it, not
    erasing") and stopped the known gpg-agent leftover. It ended "dots installed;
    the temporary sudo rule is removed", rc 0.
- Audit loop Medium+: READY. Reviewer: READY.

## Follow-ups
- `scripts/theme/apply-templates.sh` traps INT/TERM for cleanup without exiting,
  so its own loop goes on after a Ctrl-C until it returns. Its caller now stops
  right after, so this is cosmetic, not queued.
- Not verified: a Ctrl-C during the live-side bootstrap (xbps-install -r).
  install-live.sh's pre-existing INT trap covers it, but this slot did not test it.
