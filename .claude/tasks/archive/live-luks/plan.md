# Plan — live-luks

## Goal
Scope J, J-4: optional LUKS2 (argon2id) on partition 3 (`dots-root`). /boot stays plain ext4 and dracut unlocks root (decision 6), so there is one password prompt at boot for both kernels. Dialog asks (default off, decision 14). An unattended run gives `LUKS_PASSFILE` (root-owned, mode 600, decision 13). A re-run resumes an open mapping, and every exit path closes it.

## Scope
- scripts/install-live*.sh
- packages/live/*.lst
- tests/live-*.sh
- tests/lib/*.sh
- CHANGELOG.md
- CLAUDE.md
- .claude/tasks/scope-j-live-install.md
- .claude/tasks/live-luks/**

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. Choice + secret (new module install-live-luks.sh): answers key LUKS_PASSFILE with a validator (exists, root-owned, mode 600, non-empty, one line, trailing newline stripped); dialog yes/no (default No) + passphrase asked twice, non-empty; the summary and plan print "encrypted", never the secret.
2. Format + open: `cryptsetup luksFormat --type luks2 --pbkdf argon2id` and `open`, with the passphrase on stdin only (live_set_password pattern, never argv or dry-run output); mkfs.ext4 and mount on the mapper device; a variable for the root device replaces the raw $LIVE_PART3 where the filesystem is meant.
3. Resume + close: the resume check accepts a mapper source backed by this disk's dots-root; before a re-layout, close any mapping on the disk after `umount -R`; close it after the final unmount (install-live-dots.sh) and on the --skip-dots path; arm no new trap that could close a mapping still mounted.
4. Target config (before `xbps-reconfigure -fa`): cryptsetup in the target (base.lst, unless base-system already pulls it — read repodata); `/etc/crypttab`; dracut conf adding the crypt module (hostonly in a chroot cannot be trusted); `rd.luks.uuid=` appended to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub; check xgenfstab's root line is the inner ext4 UUID; preflight gets cryptsetup.
5. Tests: cryptsetup fake in tests/lib/live-disk-env.sh (records calls; asserts the secret is never in argv/called); new tests/live-luks.sh (validator refusals, format/open/close order, resume through a mapper, config files); extend live-answers.sh + live-dry-run*.sh; full suite, lint --strict, mutation testing on copies.
6. Records + VM: scope file (status, decisions 13-14 recorded at plan time), CHANGELOG, CLAUDE.md map; VM runs from the ISO: UEFI+LUKS with an answers file + passfile, BIOS+LUKS with dialog; one prompt at boot, the linux-lts entry boots too, swapfile + zram active, an aborted run resumes.

## Out of scope
- Full {UEFI,BIOS}x{plain,LUKS} matrix + docs (J-5), encrypted /boot, TPM/keyfile auto-unlock, hibernate, LVM

## Risks
- Trailing newline in passfile ≠ typed passphrase at boot — strip it; VM boots by typing it
- Secret leaks via argv, `set -x`, dry-run or log — stdin only; a test greps every recorded call and output for it
- Hostonly dracut in chroot omits crypt — explicit add_dracutmodules; VM proves the prompt
- Resume check erases an already-encrypted disk — map mapper→backing via lsblk -s; test it
- Mapping left open after a crash blocks sfdisk — close before wipefs; test it
- install-live.sh (199) / answers (185) near 250 — new module, not growth there
