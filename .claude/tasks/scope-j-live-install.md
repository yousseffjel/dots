# Scope J — Install Void + dots from the live ISO, then reboot

Opened 2026-10-15 (user idea: "run the project from the live boot void and
script install void and then install the dotfiles and reboot to ready to go
system"). Size: **Epic**, with one sub-task per session.

## Goal

Boot the official Void glibc live ISO, clone this repo, run one command,
answer a few questions, and reboot into the finished desktop with the ly
login screen. Today you install Void first (with `void-installer` or by
hand), then run `install-void.sh` on the booted system. This scope removes
that first step.

## Locked decisions (user, 2026-10-15)

1. **Option C, staged.** Fully automatic: disk picker, partitioning, base
   system, user, dots, reboot. Built in this order: the core (a mounted
   `/mnt` → base system → chroot → dots → reboot), then partitioning, then
   LUKS. Rejected: A (a post-hook after `void-installer`) and B (a
   pre-mounted `/mnt` only). B's core is still J-1, so the
   "bring your own `/mnt`" path is kept as a flag rather than thrown away.
2. **UEFI and BIOS.** Detected from `/sys/firmware/efi`. GPT on both: an ESP
   on UEFI, a 1 MiB `bios_grub` partition on BIOS.
3. **ext4, with optional encryption.** Asked during the install. How the
   encryption works is decision 6.
4. **The repo comes from `git clone` in the live environment**
   (`xbps-install -S git` first). Not chosen: a custom `void-mklive` ISO
   (option D). It is still a possible later scope.

### Boot and disk decisions (user, 2026-10-15, second round)

The options were compared in chat before this was locked. Every package
name was checked against `tests/fixtures/void-x86_64-pkgs.tsv`.

5. **Bootloader: GRUB** (`grub`, plus `grub-x86_64-efi` on UEFI). It is the
   only option that handles both UEFI and BIOS and has a kernel hook Void
   ships, so kernel upgrades need nothing from us. Limine (no Void hook
   confirmed), EFISTUB, systemd-boot and rEFInd (all UEFI-only) were turned
   down. BIOS GRUB is in plain `grub`; there is no `grub-i386-pc` package.
6. **Encryption: option B, and optional.** `/boot` is a plain ext4
   partition and only root is encrypted: LUKS2 with argon2id, one password
   prompt, unlocked by dracut, not GRUB. So GRUB never needs
   `GRUB_ENABLE_CRYPTODISK`, and the weaker LUKS1/PBKDF2 that GRUB would
   need is avoided. Turned down: the handbook's encrypted `/boot` with GRUB
   unlocking it (two prompts, a weaker key setting), LVM inside the
   encryption (no use with one root and a swapfile), and TPM unlock
   (possible later).
7. **Swap: zram first, swapfile behind it.** The user asked for the faster
   option. `zramen` gives compressed swap in RAM at a high priority. A
   swapfile on root at a lower priority catches overflow and keeps
   hibernate possible later (it would need `resume=` plus
   `resume_offset=`, not set up in this scope). *Type B assumption: the
   user said "swapfile (or go with the faster one)". If they wanted
   zram only, drop the swapfile in J-3.*
8. **Initramfs: dracut**, Void's default, with its crypt module in J-4.
   Turned down: mkinitcpio, booster.
9. **Kernel: `linux`, with `linux-lts` as a backup.** Both are installed;
   GRUB's kernel hook lists both, with `linux` as the default entry and the
   LTS kernel under "Advanced options" to fall back to when an update breaks
   boot. Each kernel gets its own dracut image (encryption included), so
   with the 1 GiB `/boot` there is room for both plus one old version of
   each. Turned down: `linux` alone, `linux-mainline`.
10. **Installer screens: `dialog`**, the same menus Void's own
    installer uses. The answers file (open question, J-1) bypasses every
    `dialog` call, so an unattended run needs no terminal. Turned down: plain
    `read` prompts, `newt`/whiptail. Whether `dialog` is already on the live
    ISO or must be installed alongside `git` is a J-1 check.

### Disk layout (follows from 5 and 6)

The same shape with or without encryption, so there is one code path. The
installer only adds encryption on top.

| Partition | UEFI | BIOS | Filesystem | Mount |
|---|---|---|---|---|
| 1 | ESP, 1 GiB | `bios_grub`, 1 MiB | vfat / none | `/boot/efi` / — |
| 2 | 1 GiB | 1 GiB | ext4, never encrypted | `/boot` |
| 3 | rest | rest | ext4, optionally inside LUKS2 | `/` |

*Type B assumption: `/boot` stays a separate partition even without
encryption. It costs 1 GiB and spares a second layout and a second test
matrix. If wrong, J-3 adds an unencrypted single-root branch.*

## What already works in a chroot (checked 2026-10-15)

- `install-services-runit.sh:21-34` links services into
  `/etc/runit/runsvdir/default` when no runsvdir is running.
- `drivers-firmware.sh:135` avoids `uname -r`, which would report the live
  kernel inside a chroot.
- Hardware detection reads `/sys`, so with `/sys` bind-mounted it sees the
  real machine.
- `install-void.sh` runs as a user in wheel and escalates with sudo
  (`install-pre.sh`).

## Sub-tasks

| # | Slot | What | Verified by |
|---|---|---|---|
| J-1 | `live-core` | `install-live.sh` (root, live ISO), given an already-mounted `/mnt`: base-system + grub via `xbps-install -r`, xbps keys, fstab, hostname/timezone/keymap/locale, a user in wheel with a password, the wheel sudoers rule, grub-install, `xbps-reconfigure -fa`. `--dry-run` prints the plan. | VM booted from the ISO, disk partitioned by hand |
| J-2 | `live-dots` | Clone into the new user's home, add a **temporary** `NOPASSWD` sudoers file (removed by a trap on every exit path, and checked again at the end), then run `install-void.sh` as that user inside the chroot. Find and fix whatever cannot run there (e.g. flatpak `--user` without a bus). Unmount and reboot. | Same VM boots straight into ly; `dots doctor` passes |
| J-3 | `live-disk` | Disk picker (`lsblk`; refuses the live medium itself), confirmation by **typing the device name**, the three-partition sfdisk layout above, mkfs, mount, then the swap from decision 7 (zramen service plus a lower-priority swapfile in fstab). | sfdisk and mkfs on a **sparse image file** (no root needed), plus a VM run under each firmware |
| J-4 | `live-luks` | Optional LUKS2 (argon2id) on partition 3, `/etc/crypttab`, dracut crypt module, `rd.luks.uuid=` in `GRUB_CMDLINE_LINUX_DEFAULT`, `xbps-reconfigure -f` of the kernel so dracut rebuilds. | VM: UEFI+LUKS and BIOS+LUKS; one password prompt at boot |
| J-5 | `live-docs` | README/INSTALL section, `docs/` page, CLAUDE.md map + entry points, CHANGELOG. A full matrix VM run. | 4 combinations: {UEFI, BIOS} × {plain, LUKS} |

**Status:** J-1 ✅ done 2026-10-16 (`0bec1f5`, log `2026-10-16-live-core.md`). It was verified on two VMs from the live ISO: UEFI with an answers file, BIOS with the dialog menus, plus the `linux-lts` boot. Next is J-2.

## Open questions — research before the sub-task that needs them

- **J-1:** is `xgenfstab` (xtools) on the live ISO, or must fstab be written
  from `blkid`? Is `xchroot` there, or do the bind mounts have to be done by
  hand? Check against the Void Handbook's "chroot install" (Context7
  `/websites/voidlinux`).
- **J-1:** an answers file / environment variables for every prompt, so a
  VM re-test can run unattended. This is probably needed: J-5 alone means
  four runs.
- *Answered 2026-10-16 (J-1):* both J-1 questions above. `xgenfstab` and
  `xchroot` ship on the ISO (`xtools-minimal`), and so does `dialog`; git
  does not. `--answers FILE` exists (KEY=VALUE, password hashes only).
  Details: `.claude/tasks/archive/live-core/context.md`.
- **J-2:** which steps of `install-void.sh` need a running system rather
  than a chroot: `sv` calls, the flatpak remote, `fc-cache`, the
  `xdg-user-dirs` run. Each one either gets a chroot path or waits until
  first boot.
- **J-3:** zram size (`zramen`'s default is a fraction of RAM) and swapfile
  size. Check zramen's runit service and how it is configured.
- **Safety:** what a crash halfway through leaves behind (mounts, open LUKS
  mapping, the NOPASSWD file). Re-running must converge to the same result
  (rule 1) or refuse with a clear message.

## Out of scope

- A custom ISO (option D, `void-mklive`). Revisit after J-5.
- musl, aarch64, dual-boot next to an existing OS, btrfs/ZFS.
