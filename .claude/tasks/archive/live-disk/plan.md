# Plan — live-disk

## Goal
Scope J, J-3: install-live.sh picks a disk, confirms it when the device name is typed, lays out GPT (UEFI: ESP 1G / boot 1G / root; BIOS: bios_grub 1M / boot 1G / root),
formats and mounts it at /mnt, creates the swapfile, and sets up zram. `--target DIR` keeps the old pre-mounted path. The run converges when re-run after a crash.

## Scope
- scripts/install-live*.sh
- packages/live/*.lst
- tests/live-*.sh
- tests/lib/*.sh
- CHANGELOG.md
- CLAUDE.md
- .claude/tasks/scope-j-live-install.md
- .claude/tasks/live-disk/**

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. Disk choice (new module): candidates from lsblk; refuse the live medium, a disk mounted outside the target, a non-disk, or one under 12 GiB; dialog --menu picker + type-the-name confirmation; answers keys DISK + WIPE (must equal DISK) with validators.
2. Partitioning (new module): wipefs + sfdisk script per firmware with dots-* PARTLABELs; resolve partition nodes via lsblk (not name concatenation; nvme pN); mkfs vfat/ext4/ext4; mount at target; resume when the target already holds this disk's dots layout; before a re-wipe, unmount anything from it under the target.
3. Swapfile: size = RAM (from /proc/meminfo, overridable), capped at 8 GiB and at 10% of root; created in the disk stage (fallocate + chmod 600 + mkswap); fstab line pri=10, added after xgenfstab.
4. zram: zramen in packages/live/base.lst; target /etc/sv/zramen/conf ZRAM_SIZE=50 ZRAM_COMP_ALGORITHM=zstd; service linked like dhcpcd.
5. Wire into install-live.sh: the disk stage runs unless --target is given; refuse a pre-mounted /mnt without --target and refuse DISK/WIPE alongside --target; the plan says WIPES <disk>; preflight tool list; header and usage; dry-run prints everything.
6. Tests: new tests/live-disk.sh (sfdisk + mkfs on a sparse image with no root, picker refusals with fake lsblk, swap sizing, partition-node resolution incl. nvme); extend live-answers.sh + live-dry-run.sh.
7. Records + VM: scope file (decisions 11-13, status), CHANGELOG, CLAUDE.md map; VM runs from the ISO on blank disks (UEFI with answers, BIOS with dialog), re-run after an abort converges.

## Out of scope
- LUKS (J-4), docs page / full matrix (J-5), hibernate resume=, MBR, dual boot

## Risks
- Wrong disk wiped — typed name; refuse live medium + foreign mounts; WIPE key; dry-run touches nothing
- sfdisk/mkfs.vfat/wipefs missing from the ISO — check on the VM first; add to preflight tools
- lsblk PARTN column unavailable / udev lag after sfdisk — `udevadm settle`; fall back to sysfs partition numbers
- Swapfile on ext4 needs no holes — fallocate is fine on ext4 (not btrfs); mkswap validates it
- Kill-loop / real-/proc hazards in tests — fake every enumeration root (memory)
