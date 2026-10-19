# Installing from the live ISO

`scripts/install-live.sh` installs Void Linux and this desktop onto a blank
disk in one run, from the Void live ISO. It asks its questions, erases the
disk you name, lays it out, bootstraps the base system, installs GRUB, runs
`install-void.sh` as your user inside the new system, and offers the reboot.
The first boot lands on the ly login screen, with your user chosen and the
cursor on the password field. `--dry-run` checks everything and prints
every command without writing anything.

If Void is already installed, you do not need this page: log in, clone the
repo and run `scripts/install-void.sh` (see the README).

## Quick start

Boot the **x86_64 glibc base** live ISO from
[voidlinux.org](https://voidlinux.org/download/) and log in as `root`
(password `voidlinux`). Get online first (wired works out of the box; for
Wi-Fi, see the Void Handbook), then:

```sh
xbps-install -Syu xbps     # the ISO's xbps may be too old for the mirror
xbps-install -y git
git clone https://github.com/yousseffjel/dots && cd dots
scripts/install-live.sh
```

dialog menus ask for the hostname, user, passwords, timezone, keymap and
locale, then list the disks that may be erased and have you **type the
disk's name**. Next comes the choice of encrypting `/`. Last, a summary of
the plan waits for a final Yes. Cancel at any point before that Yes and
nothing has been written.

## What it needs

| | |
| - | - |
| Machine | x86_64, UEFI or legacy BIOS (it uses whichever the ISO booted with) |
| Disk | one whole disk, 12 GiB or larger; **everything on it is erased** |
| Network | for the whole run: packages come from the Void mirror |
| Where | the Void live ISO only. It refuses to run without `root=live:` on the kernel command line, because it writes a bootloader |

A disk is not offered when it is read-only, a zram device, under 12 GiB,
holds the live medium, or has anything mounted (swap included).
Dual-boot next to another OS, musl, aarch64, btrfs and ZFS are out of scope.

## Flags

`scripts/install-live.sh --help` prints the same list.

| Flag | What it does |
| ---- | ------------ |
| `--answers FILE` | Read every answer from a file instead of dialog menus: an unattended install. See below. |
| `--target DIR` | Install onto a root **you** partitioned and mounted at `DIR` (UEFI: the ESP at `DIR/boot/efi` too). No disk is erased and no swapfile is made. |
| `--skip-dots` | Stop at a bootable text-console system: no dots, nothing unmounted. Log in and run `install-void.sh` yourself. |
| `--reboot` | Reboot when done without asking. |
| `--dry-run` | Check everything and print every command, writing nothing. It needs the live ISO but not root. |

## Answers file

`docs/live-answers.example` is a commented answers file. Copy it, fill it
in, `chmod 600` it, and run `scripts/install-live.sh --answers /root/answers`.

The file holds one `KEY=VALUE` per line, with `#` comments and optional
quotes around a value. It is parsed, never sourced, so a value is never run.
Every line is checked before anything is written, and a bad line is reported
by its number, never by its value. Passwords are crypt hashes only: run
`openssl passwd -6`, then paste the whole `$6$...` line. A plain password
is refused, so the file never holds a usable one.

| Key | Required | Value |
| --- | -------- | ----- |
| `HOSTNAME` | yes | lower-case letters, digits and inner hyphens, up to 63 |
| `USERNAME` | yes | lower case, up to 32; `root` and system accounts refused. Joins `wheel`, which means sudo |
| `USER_PASSWORD_HASH` | yes | `openssl passwd -6` output (SHA-512; SHA-256 `$5$` also accepted) |
| `TIMEZONE` | yes | a file under `/usr/share/zoneinfo`, e.g. `Europe/Berlin` |
| `KEYMAP` | yes | a console keymap under `/usr/share/kbd/keymaps`, e.g. `de-latin1` |
| `LOCALE` | yes | a locale in `/etc/default/libc-locales`, e.g. `en_US.UTF-8` |
| `ROOT_PASSWORD_HASH` | no | as above; empty or absent **locks** root |
| `REPO` | no | the xbps mirror, default `https://repo-default.voidlinux.org/current` |
| `DISK` | without `--target` | the disk to erase, e.g. `/dev/vda` |
| `WIPE` | without `--target` | the same disk again, so one typo cannot pick another disk |
| `LUKS_PASSFILE` | no | encrypt `/`: an absolute path to a root-owned, mode-600 file holding only the passphrase |

`DISK`, `WIPE` and `LUKS_PASSFILE` are refused with `--target`, whose disk
layout is your own.

## What ends up on the disk

GPT, the same three partitions with or without encryption:

| # | UEFI | BIOS | Filesystem | Mount |
| - | ---- | ---- | ---------- | ----- |
| 1 | ESP, 1 GiB | `bios_grub`, 1 MiB | vfat / none | `/boot/efi` / — |
| 2 | 1 GiB | 1 GiB | ext4 | `/boot` |
| 3 | the rest | the rest | ext4, optionally inside LUKS2 | `/` |

The partitions are named `dots-esp` (or `dots-bios`), `dots-boot` and
`dots-root`. On top of that:

- **Kernels:** `linux`, the default GRUB entry, and `linux-lts` under
  *Advanced options*, as a fallback when a new kernel will not boot.
- **Swap:** zram at half of RAM with zstd, used first, then `/swapfile`,
  the size of RAM capped at 8 GiB and at a tenth of `/`.
- **GRUB:** an EFI entry named "Void" plus the removable-media path
  `EFI/BOOT/BOOTX64.EFI` on UEFI; the disk's boot code on BIOS.
- **Accounts:** your user in `wheel` with sudo; root locked unless you gave
  it a password.
- **dots:** the repo you ran from, cloned locally into `~/dots` (its origin
  is your clone's origin, so `dots update` works), then `install-void.sh` run
  as you. It needs sudo with no one to type a password, so it gets a
  temporary password-free rule that is removed when it ends, even after a
  failure or Ctrl-C.

It writes no rows to the dots install manifest: it creates the operating
system, which `dots uninstall` never removes. The manifest belongs to the
`install-void.sh` run inside it.

## Encryption

Choose it in the menu (off by default, passphrase typed twice) or with
`LUKS_PASSFILE`. Only `/` is encrypted: LUKS2 with argon2id, opened at
boot by the initramfs (dracut) with **one passphrase prompt**. `/boot`
stays plain ext4, so GRUB needs no cryptodisk support and you are not
asked twice. The swapfile lives on `/`, so it is encrypted with it, and
zram never touches a disk.

The passphrase reaches `cryptsetup` on stdin, never in a command line, a log
or the dry-run output. Nothing is added to `/etc/crypttab`: dracut opens `/`
from `rd.luks.uuid=` on the kernel command line, which every GRUB entry
carries, recovery entries included. The prompt uses your `KEYMAP`.

Losing the passphrase means losing the data; there is no recovery key.

## Running it again

Every step converges, so a failed or interrupted run (power cut, Ctrl-C, a
mirror timing out) is fixed by running the same command again:

- A target that an earlier run already mounted from this disk is
  **resumed, not erased**. When encrypted, the mapping must open with this
  run's passphrase.
- Anything else mounted under the target is unmounted, and the disk is laid
  out again.
- The user is created once, files are rewritten, and the GRUB and initramfs
  steps are idempotent. An existing `~/dots` clone is left as it is.
- A Ctrl-C while `install-void.sh` runs inside the target stops every
  process still running there, then removes the temporary sudo rule.
  Nothing carries on in the background.

## Known caveats

- **With `--skip-dots`, the router shows no hostname** for the machine:
  the base system's dhcpcd does not send one. It is cosmetic, and dots
  replaces dhcpcd with NetworkManager, which does.
- **`dots doctor` warns about spice-vdagent** in a VM displayed over VNC.
  That daemon needs a SPICE channel. The warning goes away with a SPICE
  display, and does not appear on bare metal.
- **A stuck run inside install-void.sh** can leave a gpg-agent (from the
  Flathub key import) holding the target busy. The installer stops
  processes rooted in the target before unmounting. If an unmount still
  fails, re-run: it converges.

## Testing it safely

`--dry-run` on the live ISO walks every check, including the disk choice,
and prints every command. Everything it does is covered by the
`tests/live-*.sh` suite without a live ISO. An end-to-end run belongs in a
VM with a blank virtual disk. When this page was written, the installer
was run from the ISO on all four combinations of {UEFI, BIOS} × {plain,
encrypted}, and each one booted to ly with `dots doctor` passing.
`TESTING.md` covers the suite.
