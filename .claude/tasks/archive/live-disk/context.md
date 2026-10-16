# Context — live-disk

## Background
Scope J sub-task J-3 (`.claude/tasks/scope-j-live-install.md`). J-1 needs /mnt to be mounted already, and J-2 installs dots. This task adds the partitioning step that decision 1 deferred.

## Prior Decisions
- Scope J decisions 1-10 (layout table, GPT on both firmwares, ext4, separate /boot, zram + swapfile).
- User, 2026-10-16 (this session):
  - zram: ZRAM_SIZE=50 with zstd. zramen 1.0.1 defaults are 25% / lz4 / priority 32767 / no cap.
  - swapfile size = RAM, capped at 8 GiB and at 10% of the root partition.
  - Unattended wipe needs DISK= plus WIPE= naming the same device.
- Type B (this plan): the disk stage is the default and `--target DIR` is the pre-mounted path. A /mnt that is already mounted but was not passed with --target is refused, not reused silently.

## References
- install-live-base.sh:190 live_run, :219 live_firmware, :226 live_disk_of, :234 live_check_boot_layout, :260 live_preflight
- install-live-config.sh:62 xgenfstab, :158 dhcpcd link, :165 grub-install BIOS disk
- install-live-answers.sh:28 keys, :39 validators, :117 live_ask
- tests/live-dry-run.sh:28-53 fake lsblk/findmnt/mountpoint (the lsblk fake exits 2 on an option set it does not know)
- zramen 1.0.1_1 package: /etc/sv/zramen/{run,finish,conf}; run sources ./conf

## Notes
- sfdisk, mkfs and blkid are not used anywhere yet. The live ISO is not yet confirmed to ship sfdisk, wipefs or mkfs.vfat.
