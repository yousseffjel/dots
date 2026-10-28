# Installation

dots installs a complete dwm desktop on **Void Linux**. There are two ways in, depending on where you start:

- **A blank disk and the Void live ISO.** `scripts/install-live.sh` installs Void itself, then the desktop, and
  reboots into the login screen.
- **A Void base install you already have.** `scripts/install-void.sh` installs the desktop on top of it.

Both accept `--dry-run`, which prints what would happen and changes nothing.

## Requirements

- **Void Linux, glibc, x86_64**, with runit (Void's default). The installer installs Xorg itself, so a base system
  with no graphical environment is the expected starting point.
- **A user account in the `wheel` group.** Every privileged step runs through `sudo`, and Void grants sudo to
  `wheel`. The first stage stops early if you are not in it, and tells you the `usermod` command to run as root.
- **A network connection** for the whole run: packages come from the Void mirror.

Void **musl** is not refused, but it is not supported either. The installer says so up front: the default editor
comes from the glibc-only nonfree repository, and nothing has been tested on musl. aarch64 is out of scope.

## From the live ISO

Boot the **x86_64 glibc base** live ISO, log in as `root` (password `voidlinux`), get online, then:

```sh
xbps-install -Syu xbps     # the ISO's xbps may be too old for the mirror
xbps-install -y git
git clone https://github.com/yousseffjel/dots && cd dots
scripts/install-live.sh
```

dialog menus ask for the hostname, your user, passwords, timezone, keymap and locale. Then it lists the disks it is
allowed to erase and has you **type the disk's name**, asks whether to encrypt `/`, and shows the plan for a final
Yes. Nothing is written before that Yes.

**It erases the whole disk you pick.** It needs one disk of 12 GiB or more and refuses to run anywhere but the live
ISO. Dual-boot, btrfs and ZFS are out of scope.

What you end up with, in short:

- GPT with a 1 GiB `/boot` and an ext4 root, booted by GRUB on UEFI or legacy BIOS (whichever the ISO started in).
- Optional LUKS2 encryption of `/`, with one passphrase prompt at boot.
- The `linux` kernel, plus `linux-lts` as a fallback under *Advanced options*.
- zram swap, and a swapfile behind it.
- Your user in `wheel`; root locked unless you gave it a password.
- The repo cloned into `~/dots`, and `install-void.sh` run as you inside the new system.

Useful flags: `--answers FILE` for an unattended install, `--target DIR` to install onto a root you partitioned and
mounted yourself, `--skip-dots` to stop at a bootable text console, `--reboot` to reboot without asking. A failed or
interrupted run is fixed by running the same command again: a disk it already laid out is resumed, not erased.

[docs/LIVE-INSTALL.md](https://github.com/YoussefFjel/dots/blob/main/docs/LIVE-INSTALL.md) is the full guide: every
flag, every answers-file key, the exact partition layout, encryption and known caveats. Read it before you run the
script. A commented answers file is in
[docs/live-answers.example](https://github.com/YoussefFjel/dots/blob/main/docs/live-answers.example).

## On an existing Void install

Log in as your user (not root), then:

```sh
sudo xbps-install -S git
git clone https://github.com/yousseffjel/dots ~/dots
~/dots/scripts/install-void.sh
```

The installer is a thin wrapper over four stages, each its own script, run in this order:

1. **pre** — sanity checks: xbps present, sudo available, you are in `wheel`.
1. **install** — a full system upgrade first (Void does not support partial upgrades), then the packages, the
   nonfree repository and the hardware drivers, then the suckless build: dwm, st, dmenu, dwmblocks and slock.
1. **restore** — config symlinks into `~/.config`, the theme, app configs, fonts and cursor, Flatpak's Flathub
   remote, the wallpaper collection, and the zsh and tmux plugin managers.
1. **services** — your login shell becomes zsh, the runit services are enabled (dbus, elogind, NetworkManager,
   bluetoothd), you are added to the `network`, `bluetooth`, `kvm` and `video` groups, and the ly login screen is
   built from source and takes over tty2.

### Flags

`install-void.sh --help` prints the full list.

| Flag | What it does |
| ---- | ------------ |
| `--dry-run` | Run every stage without installing, writing, cloning or building anything |
| `--only-pre`, `--only-install`, `--only-restore`, `--only-services` | Run just those stages; combine them freely |
| `--skip-suckless` | Skip building the suckless programs; run `scripts/install-suckless.sh` later |

Every run's output is also written to `install.log` at the repo root.

Two related scripts can be run on their own: `scripts/install-suckless.sh` rebuilds just the suckless programs, and
`scripts/symlinks.sh` re-links the configs without touching packages. Both take `--dry-run`.

Set `DOTS_WALLPAPER_REPO=` (empty) to skip the wallpaper download, which is about 400 MB. See
[Theming](Theming).

### Running it again

Every stage is idempotent. Re-running after a partial or full success converges to the same state, so the fix for
a failed or interrupted run is to run it again. Once installed, [`dots update`](Updating-and-Uninstalling) does
this for you after pulling.

## What gets installed

In broad strokes:

- **Display and session:** Xorg, the ly login screen, dwm with its status bar (dwmblocks), the dmenu launcher, the
  slock screen locker, and sxhkd for the hotkeys dwm does not own.
- **Terminals and shell:** alacritty (st is the fallback for machines with no working GL), zsh with starship,
  tmux.
- **Desktop services:** PipeWire audio, NetworkManager, Bluetooth, dunst notifications, the picom compositor, a
  clipboard manager, the gnome-keyring Secret Service and the GTK desktop portal.
- **Applications:** Firefox, Thunar, mpv, nsxiv and Sublime Text (from Void's nonfree repository), among others.
- **Theming:** the wallpaper-driven colour engine, four static themes, Cascadia Code NF, the Bibata cursor.
- **Hardware:** video decoding drivers, missing firmware and CPU microcode, plus laptop extras on a laptop. See
  [Laptops and Hardware](Laptops-and-Hardware).

The exact package names live in
[packages/](https://github.com/YoussefFjel/dots/tree/main/packages), split into tiers by what breaks when one fails.
See [Packages](Packages).

Node.js and lazygit are deliberately not installed. The installer's closing lines say how to add them.

## When it finishes

The installer ends with a short list of what to do next. On the next boot, log in through ly on tty2; tty1 keeps a
plain text login on purpose, as a rescue console. Continue with [First Steps](First-Steps).

Every file, package, service and repository the installer adds is recorded in an install manifest, so
[`dots uninstall`](Updating-and-Uninstalling) can reverse exactly that and nothing else.

## What is not proven

Be clear about what has been tested before you install on a machine you care about:

- **Nothing has been run end to end on bare metal.** Every real install so far has been in a virtual machine.
- `install-void.sh` has been run in a Void VM (login through ly, the session, audio, the portal, power actions and
  `dots doctor` all checked).
- `install-live.sh` has been run from the ISO on all four combinations of {UEFI, BIOS} × {plain, encrypted}, each
  booting to ly with `dots doctor` passing.
- CI runs the whole installer in a Void container on every relevant change. A container cannot prove that a runit
  service actually runs, or anything graphical.

Laptop-specific behaviour has been tested with fixtures only, as no laptop has been available to test on.
