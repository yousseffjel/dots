# Plan — live-dots (scope J, J-2)

## Goal
After J-1's bootstrap, install-live.sh installs dots into the new system before
the reboot: clone the repo into the new user's home, grant a temporary NOPASSWD
sudo rule (removed on every exit path), run install-void.sh as that user inside
xchroot, then unmount and offer the reboot. The VM boots straight into ly and
`dots doctor` passes.

## Scope
- scripts/install-live*.sh
- tests/live-*.sh
- CHANGELOG.md
- CLAUDE.md
- .claude/tasks/scope-j-live-install.md

## Allowed
## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. New `scripts/install-live-dots.sh`: `git clone --local` of the live clone into `~/dots` from the live side (origin reset to the live clone's), chown to the target uid; write `/etc/sudoers.d/99-dots-live-install` (NOPASSWD, visudo -cf), removed by an EXIT/INT/TERM trap from the live side and re-checked at the end.
2. Run `install-void.sh` via `xchroot "$T" su - "$user" -c …` (login env: USER, HOME right — never root's), then `install-void.sh --only-restore` under `dbus-run-session` so the flatpak `--user` remote and the dconf key land; dry-run prints both.
3. Wire into `install-live.sh`: stage after `live_configure_boot`; `--only-dots` (re-run after a failed dots stage, J-1 steps skipped), `--skip-dots` (J-1 behaviour), `--reboot`; on success `umount -R` + dialog reboot prompt (answers mode: reboot only with `--reboot`); closing text updated; header usage.
4. Tests: `tests/live-dots.sh` with fakes (xchroot, su, visudo, git): dry-run calls nothing; the sudoers file is gone after a failing install-void (trap) and after success; `su -` is used with the answers' user. Extend `tests/live-dry-run.sh` for the new stage.
5. Lint (`tests/lint.sh --strict`), full suite, size caps (250/60).
6. Real VM run from the live ISO (UEFI, answers file): boots to ly, log in, `dots doctor` passes; check no 99-dots-live-install left; note any chroot-only failures and fix.
7. Records: CHANGELOG [Unreleased], CLAUDE.md map line for install-live-dots.sh, scope-j status + answered open questions.

## Out of scope
- Partitioning (J-3), LUKS (J-4), docs page (J-5).
- Making install-void.sh itself chroot-aware beyond what step 6 proves broken.

## Risks
- USER=root leaks into install-services (usermod on root) — `su -` login env; test asserts it.
- NOPASSWD left behind on crash — trap removes it from the live side; final check fails loudly.
- Network needed in chroot (xbps -Su, zig, clones) — xchroot binds resolv.conf (J-1 context.md:44).
- dbus-run-session pass doubles restore time — restore is idempotent; drop it if step 6 shows plain run already sets both.
