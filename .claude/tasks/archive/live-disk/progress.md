# Progress — live-disk

## Status
`in-progress`

## Steps
- [x] 1. Disk choice module + DISK/WIPE answers keys
- [x] 2. Partitioning module (wipefs, sfdisk, node resolution, mkfs, mount, resume)
- [x] 3. Swapfile (sizing, creation, fstab line)
- [x] 4. zram (zramen package, conf, service)
- [x] 5. Wire into install-live.sh
- [x] 6. Tests
- [x] 7. Records + VM runs

## Deviations
- Step 5: plan said "refuse a pre-mounted /mnt without --target". Refined: in
  disk mode a target mounted from the CHOSEN disk is allowed, since it is an
  earlier run, resumed or re-laid. One mounted from any other disk is
  refused, naming --target. Without this, rule 1 (re-run converges) could
  not hold after a crash.
- Step 3: the swapfile is made only in disk mode; --target gets zram only
  (the user's layout, the user's swap). Recorded in scope decision 12.
- Step 6: two test files went over the 250-line cap, so they were split.
  Shared sandboxes are in tests/lib/live-disk-env.sh and
  tests/lib/live-dry-run-env.sh. New tests: live-disk, live-part-nodes,
  live-part-swap, live-dry-run-disk.
- Plan risk check: wipefs was planned, and dropped. sfdisk's --wipe always
  and --wipe-partitions always do that job. The ISO (20250202) was checked
  by reading its squashfs: sfdisk, wipefs, mkfs.ext4/vfat, mkswap,
  fallocate, udevadm, blkid, findmnt and lsblk 2.40.2 (PARTN, PARTLABEL)
  are present, partprobe is not (not needed).
- Mutation testing: 28 mutants on copies, all caught. Two gaps found and
  closed: the tenth-of-root cap, and sfdisk missing from the preflight tool
  list.

## VM runs (2026-10-16, ISO 20250202)
- dots-live-j3 (UEFI, answers): Ctrl-C mid-bootstrap, the re-run printed
  "resuming it, not erasing" (no sfdisk), then installed and unmounted. First
  boot reached ly. zram0 zstd 2.02 GB (pri 32767); /swapfile 1843 MiB (pri 10).
- dots-live-j3b (BIOS, dialog): menu offered only vda (the read-only repo
  disk is RO=1, never listed); 'vda' was re-asked, '/dev/vda' accepted. First
  boot reached ly; vda1 dots-bios / vda2 /boot / vda3 /; 1945 MiB swapfile +
  zram active; sudo needs a password (the NOPASSWD rule is gone).
- The background console watcher was killed once by host memory pressure.
  The VM finished regardless; its state was read from tty1.

## Blockers
