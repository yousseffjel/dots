# Context — live-luks

## Background
Scope J sub-task J-4 (`.claude/tasks/scope-j-live-install.md`, table row J-4). J-1..J-3 done 2026-10-16.

## Prior Decisions
- Decision 6: LUKS2 argon2id on root only; /boot plain ext4; dracut unlocks, not GRUB (no GRUB_ENABLE_CRYPTODISK).
- Decision 8: dracut, crypt module in J-4. Decision 9: both kernels get their own dracut image.
- Decision 13 (2026-10-16): unattended passphrase via LUKS_PASSFILE, root-owned 0600; answers file stays hash-only.
- Decision 14 (2026-10-16): dialog defaults to no encryption.
- J-1: answers file holds password hashes only; `live_set_password` passes secrets on stdin.

## References
- install-live-part.sh: live_part_mkfs :77-83 (root mkfs :81), live_part_create :87-110 (umount -R :88), live_part_prepare :124-139 (resume check :127-128, mount :133), live_part_nodes :50-65 (skips mappings, :57).
- install-live-config.sh: xgenfstab -U :62-67; live_configure_boot :156-170 (xbps-reconfigure -fa :167, grub-mkconfig :168); live_write :29-40, live_set_rc :45-54, live_set_password :86-100.
- install-live.sh: plan_text :117-136; call order :165-176; EXIT trap live_dots_revoke :181; --skip-dots :197.
- install-live-dots.sh: live_dots_finish umount -R :135.
- install-live-base.sh: preflight tools :100-103; live_disk_of :64-68 (walks up through a mapping).
- install-live-answers.sh: keys :31-32, live_answer_valid :43-56, live_answer_set :61-74, live_ask_password :142-156.
- Tests: tests/lib/live-disk-env.sh, tests/lib/live-dry-run-env.sh, tests/lib/sealed-path.sh, tests/live-part-nodes.sh:31-32 (cryptroot fixture).
- cryptsetup is on the ISO (mkiso.sh:127; archive/live-core/context.md:32-34).
- VMs dots-live-j3 (UEFI) and dots-live-j3b (BIOS) kept for J-4.

## Notes
- Line counts at plan time: install-live.sh 199, answers 185, config 170, base 164, disk 162, dots 148, part 139.
