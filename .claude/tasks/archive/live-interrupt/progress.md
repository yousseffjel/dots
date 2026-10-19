# Progress — live-interrupt

## Status
`done`

## Steps
- [x] 1. Reproduce: a direct install-void.sh run on the VM, Ctrl-C mid-transaction; record what carries on.
- [x] 2. install-live.sh: the dots-stage exit path stops everything rooted in the target (live_dots_release), THEN revokes; INT/TERM say "interrupted".
- [x] 3. install-void.sh + stages: an interrupt ends the run (exit 130/143), never "retry one at a time" — fix where step 1 shows it continues.
- [x] 4. Tests: release-before-revoke on an interrupt (fake /proc only), and the stage stop (fake xbps killed by INT).
- [x] 5. Docs: LIVE-INSTALL.md "Running it again", CHANGELOG Fixed line, CLAUDE.md map line if it changes.
- [x] 6. VM: live run interrupted with a real Ctrl-C on the serial console during install-void.sh; nothing left in the target, rule gone, re-run converges.
- [x] 7. Lint, the live tests, run-tests.

## Findings (step 1, VM dots-live-j3b, 2026-10-19; serial getty enabled on the installed system, console.py `keys2` sends Ctrl-C on the same connection the moment a regex appears)
Direct run `./scripts/install-void.sh --only-install` with rust + cargo removed (10-package transaction):
| Ctrl-C lands during | Result |
| --- | --- |
| download (send-key on tty1) | run stops at once: `^C`, trap line, no `EXIT=` |
| xbps unpack | xbps finishes its transaction, then the run stops (no `EXIT=`) |
| `make st` | `make: *** Interrupt`, run stops |
| **xbps "verifying RSA signature"** | **swallowed: transaction completes, `installed: rust/cargo`, drivers, the whole suckless build, `EXIT=0`** (also my first, unexplained tty1 attempt) |
Mechanism: xbps exits 0 after that SIGINT, and bash's wait-and-cooperative-exit treats a child that exits normally as having handled it, so every bash in the chain (install-pkg.sh, install-void.sh, even the interactive `; echo`) carries on. A script with its own INT trap runs it once the child returns, whatever the child's status: that is the fix for the direct run — in every script of the chain, not only install-void.sh (a stage without one finishes its remaining tiers first).
Live case: the inner install runs under `su -c` inside xchroot and never saw the terminal's SIGINT reliably; the outer side must stop it by /proc root (step 2).


## Deviations
- Step 2: no separate "interrupted" message. The trap exits 130/143, and live_dots_release already names what it stops ("stopping N process(es) still running in /mnt"). release rescans and KILLs up to 4 more rounds, since a loop can start a new child between a scan and the kill. live_dots_rooted drops dead pids (`kill -0`).
- Step 3: the fix is a shared `stop_on_interrupt` in global_fn.sh, called by install-void.sh and every script it runs. install-pre.sh now sources global_fn.sh for that alone.
- Step 4: mutation-checked on scratch copies (never the worktree). All 5 mutants were caught: revoke-before-release, cleanup without release, single-pass release, an empty stop_on_interrupt, and one stage missing the call. The cleanup-without-release mutant first HUNG the test, because the fake orphan held the stage's output pipe. Fixed: the orphan's stdio goes to /dev/null, and a surviving orphan or spawner is KILLed by the test.
- Step 6 (VM dots-live-j3b, live ISO, BIOS, plain, snapshot fa13028 = this slot): `install-live.sh --answers` in the foreground on ttyS0, with a real Ctrl-C 20 s into the "desktop-critical" tier inside the target. Result: xchroot's umount of /mnt/dev hit "busy" (the orphan still held it), then "note stopping 8 process(es) still running in /mnt", `EXIT=130`. 20 s later: 0 processes rooted in /mnt, the rule gone, only /mnt and /mnt/boot mounted, no xbps running, and no "password is required" or FAILED in install.log. Re-run: "resuming it, not erasing", "stopping 1 process(es)" (the known gpg-agent), "dots installed; the temporary sudo rule is removed", rc 0.
- Step 7: tests/install-pre.sh ran the stage under `env -i` on a sealed PATH. The stage now sources global_fn.sh, which needs dirname (rule 3's SCRIPT_DIR) and HOME (the manifest path), so the test now gives it both; a real run always has them. live-dots.sh reached 291 lines (cap 250), so the two live_dots_release-only cases moved to the new tests/live-release.sh (223 + 104 lines). Lint: SC2030/2031 resolved by passing the pid in its own variable, FAKE_XCHROOT_KILL.

## Blockers
