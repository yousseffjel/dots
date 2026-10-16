# Plan — live-core

## Goal
Scope J, sub-task J-1. `scripts/install-live.sh` runs as root on the Void
live ISO against an already-mounted `/mnt`. It installs the base system
(`linux` + `linux-lts`, dracut, GRUB for UEFI or BIOS), configures it
(hostname, timezone, keymap, locale, a user in wheel, passwords, sudoers),
and leaves a disk that boots to a tty login. Questions: dialog or an answers file.

## Scope
- scripts/install-live*.sh
- tests/live-*.sh
- packages/live/*.lst
- tests/void-pkgnames.sh
- tests/pkglist.sh
- CLAUDE.md
- CHANGELOG.md
- .claude/tasks/live-core/**

## Allowed
## Forbidden
- scripts/install-void.sh
- HyDE/**

## Steps
1. Research on the VM's live ISO: xtools (xgenfstab/xchroot), dialog, base-system's kernel deps, efivars; record in context.md
2. `install-live-answers.sh`: dialog prompts + KEY=VALUE answers file (parsed, never sourced; password as a hash only) + `tests/live-answers.sh`
3. (+ packages/live/*.lst, user 2026-10-16) `install-live-base.sh`: preflight (root, live env, /mnt is a mountpoint, not /, network, UEFI/BIOS), xbps keys, `xbps-install -r` bootstrap
4. `install-live-config.sh`: chroot config, user + wheel + chpasswd -e, wheel sudoers, fstab, grub-install (target disk from lsblk PKNAME) + grub-mkconfig, `xbps-reconfigure -fa`
5. `install-live.sh` orchestrator (`--dry-run`, `--target`, `--answers`) + `tests/live-dry-run.sh` with shims on PATH
6. VM run from the ISO on a hand-partitioned disk, UEFI and BIOS: boots to a tty login, both kernels in GRUB
7. CLAUDE.md map + entry points, CHANGELOG [Unreleased] line

## Out of scope
- dots in the chroot, reboot (J-2); partitioning (J-3); LUKS (J-4); docs page (J-5)

## Risks
- grub-install on the wrong disk — derive it from /mnt's source; dry-run shows it; confirm in dialog
- A password in argv, a log or the answers file — stdin only; answers file accepts a hash only
- Run on the dev host by accident — refuse unless /run/rootfsbase or the live marker exists (step 1)
