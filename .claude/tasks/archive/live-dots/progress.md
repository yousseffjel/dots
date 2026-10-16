# Progress — live-dots

## Status
`in-progress`

## Steps
- [x] 1. install-live-dots.sh: clone into ~/dots + temporary NOPASSWD with trap
- [x] 2. install-void.sh via xchroot su -, then --only-restore under dbus-run-session
- [x] 3. Wire into install-live.sh: --only-dots, --skip-dots, --reboot, umount + reboot prompt
- [x] 4. tests/live-dots.sh + live-dry-run.sh extension
- [x] 5. Lint, suite, size caps
- [x] 6. Real VM run: boots to ly, dots doctor passes, no sudoers leftover
- [x] 7. Records: CHANGELOG, CLAUDE.md map, scope-j status

## Deviations
- Step 2: the dbus-run-session `--only-restore` pass was dropped before coding. `dconf_cmd`
  (global_fn.sh:179) already falls back to dbus-run-session, and `flatpak remote-add --user`
  writes files without a bus. Step 6 checks both on the VM; re-add the pass only if doctor warns.
- Step 3: `--only-dots` was dropped. Re-running install-live.sh converges (J-1 + this stage), and
  `--only-dots` would need its own subset of the answers. The flags are `--skip-dots` and `--reboot`.
- Step 6 found three bugs, all fixed in this slot (UEFI VM `dots-live-j2`, live ISO 20250202):
  (1) **No DNS on first boot.** Every xchroot call `touch`es the target's /etc/resolv.conf to
  bind the ISO's over it, and the empty file stays. NetworkManager handed openresolv the
  nameserver (`resolvconf -l` showed it) but the file stayed empty. Reproduced by truncating
  and rebooting; absent at boot, it is written. Fix: `live_drop_empty_resolv` (install-live-
  config.sh) after the last xchroot call, on both paths (J-1's `--skip-dots` had it too).
  (2) **A lingering gpg-agent aborted the run.** flatpak's Flathub key import (ostree,
  `--homedir /tmp/ostree-gpg-*`) left it running in the target; xchroot's cleanup umount of
  /mnt/dev failed and so did xchroot's status, after a good install (run 2; run 1 won the
  race). Fix: a success marker written inside the target decides; `live_dots_release` stops
  processes whose /proc/<pid>/root is the target (never by uid: uid 1000 is the ISO's anon)
  and unmounts what xchroot left. The VM re-run had no leftover, so the stop path is
  fixture-tested only (a real process, fake /proc).
  (3) `--reboot` printed "Next: … reboot" after rebooting (runit's reboot returns): returns now.
- **Incident (2026-10-16):** a mutation of `live_dots_release`'s filter, run while other test
  cases reached it with the REAL /proc, signalled every process of the user's and ended the
  session (the host was rebooted afterwards). Every test call now passes a fake LIVE_PROC.
  Memory: kill-loop-tests-never-scan-real-proc.
- Verified: run 1 booted straight into ly; login; `dots doctor` rc=0, no failures, 1 warning
  (spice-vdagent: the VM has VNC, no SPICE channel). Run 3 (re-run over run 2's aborted
  target, `--reboot`) converged and rebooted; first boot from disk: resolv.conf written at
  boot, github.com resolves, zinit cloned, only 10-wheel in sudoers.d.

## Blockers
