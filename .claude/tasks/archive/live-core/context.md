# Context — live-core

## Background
User idea (2026-10-15): install Void plus dots from the live ISO, then
reboot to a finished system. Scope J, sub-task J-1 (`live-core`).

## Prior Decisions
`.claude/tasks/scope-j-live-install.md`, locked decisions 1-10. The ones
J-1 uses: 2 (UEFI+BIOS, GPT), 5 (GRUB), 8 (dracut), 9 (`linux` +
`linux-lts`), 10 (dialog, plus an answers file that bypasses it).

## References
- Void Handbook, chroot install: https://docs.voidlinux.org/installation/guides/chroot.html
  (keys copy, `XBPS_ARCH=… xbps-install -S -r /mnt -R "$REPO" base-system`,
  `xgenfstab -U /mnt`, `xchroot /mnt`, libc-locales, grub-install
  `--efi-directory=/boot/efi --bootloader-id=Void`, `--removable` fallback)
- `scripts/install-services-runit.sh:21-34` and `drivers-firmware.sh:135`
  (already work in a chroot)
- Memory: void-vm-test-box (VM at 192.168.122.242 via ~/.ssh/agent/dots.sock)

## Notes
- Answers-file passwords are a hash only (`openssl passwd -6`). This is a
  Type B assumption, made for the risk in plan.md. If wrong, accept plain
  text from a 0600 file.

## Step 1 findings (2026-10-16)

Method: void-mklive `mkiso.sh` (master) for the ISO's package set; the main
x86_64 repodata `index.plist` for dependencies; the `xtools-minimal-0.70_1`
`.xbps` file list and its `xchroot`/`xgenfstab` sources. No ISO was booted.
Booting one is step 6.
- The ISO adds `dialog cryptsetup lvm2 mdadm xtools-minimal xmirror chrony
  tmux` on top of base-system (mkiso.sh:127). So **dialog, xchroot and
  xgenfstab are all present**. cryptsetup is too (for J-4).
- The ISO kernel cmdline is `root=live:CDLABEL=VOID_LIVE …` (mklive.sh:298,
  and the same for isolinux), so **`root=live:` in /proc/cmdline marks the
  live ISO**.
- `base-system-0.114_2` already depends on `linux`, `sudo`, `glibc-locales`,
  `dhcpcd`, `e2fsprogs` and `dosfstools`. `linux` → `linux6.18` +
  `linux-base`, and **`linux-base` → `dracut`** plus firmware. So the
  packages to name are `base-system linux-lts grub`, plus `grub-x86_64-efi`
  on UEFI (which pulls in efibootmgr).
- There is no `grub-i386-pc`: the BIOS modules are in `grub`.
- `xchroot` rbinds /dev /proc /sys (so efivars too) and binds resolv.conf.
  It does not bind /run. It is `sh -e` and passes the inner exit status
  through.
- `findmnt -no SOURCE` adds `[/subvol]` on btrfs; **use `findmnt -nvo
  SOURCE`**. `lsblk -nrspo NAME,TYPE <part>` lists the part first, then the
  disk (`/dev/nvme0n1p2 part` / `/dev/nvme0n1 disk`); this was captured on
  the dev host for the shims. `lsblk -ndrpo PTTYPE <disk>` → `gpt`.
  BIOS-on-GPT needs a partition with PARTTYPE
  `21686148-6449-6e6f-744e-656564454649` (bios_grub).

## Step 6 — real VM run (2026-10-16)

ISO `void-live-x86_64-20250202-base.iso` (old xbps, so the self-update
step ran for real). The ISO's kernel and initrd were booted directly with
`console=ttyS0` and driven over `virsh console` (a pty script, since there
is no expect). Two new VMs, `dots-live-uefi` (OVMF) and `dots-live-bios`,
each with a 20 GiB disk partitioned by hand into the J-3 layout. The code
was delivered as a tarball over http from 192.168.122.1, since git is not
on the ISO.
- **UEFI, answers file:** exit 0. Both kernels have an initramfs and a GRUB
  entry. The NVRAM entry `Boot0002* Void` plus `EFI/BOOT/BOOTX64.EFI`;
  fstab by UUID (/, /boot, /boot/efi); root locked; ysf in wheel with the
  hash; sudoers.d/10-wheel 0440; dhcpcd linked. Booted from disk: tty
  login `dotsuefi`, kernel 6.18.57_1. Logged in as ysf (virsh send-key),
  and `sudo id -un` → root.
- **BIOS (GPT + bios_grub), dialog menus:** exit 0, GRUB in the MBR, keymap
  `de`. **The bug:** plain `chpasswd` exited 0 but left `ysf:!` (the
  hash path, `-e`, is fine). `chpasswd -c SHA512` verified by hand, then
  fixed. A **re-run** over the finished install (password reset to `!`)
  converged: "user ysf already exists", "ysf password set" (read back),
  exit 0. Booted from disk to the `dotsbios` login on 6.18. Then GRUB
  "Advanced options" → 6.12.113_1 (linux-lts) → login.
- Harmless install-time warnings: the PAM 1.5 notice, and os-prober not
  run. dhcpcd sends no hostname, so leases show `-`. The leases were renewed
  after the from-disk boot.
- Left defined, powered off, for the user to delete:
  `virsh undefine --nvram dots-live-uefi; virsh undefine dots-live-bios`, then
  `virsh vol-delete --pool default` for dots-live-{uefi,bios}.qcow2 and
  dots-live-{vmlinuz,initrd}.
