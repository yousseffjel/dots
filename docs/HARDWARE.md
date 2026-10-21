# Hardware drivers

`dots drivers` looks at this machine and installs what its hardware needs.
The installer runs the same code right after it enables Void's nonfree
repository, so a fresh install is already covered; run it yourself after
swapping a GPU or moving the install to new hardware. `dots drivers
--dry-run` prints what it would do and changes nothing. `dots doctor` reports
the same things under **drivers**.

## What it installs

| Hardware | Package | From |
| -------- | ------- | ---- |
| Intel GPU, Broadwell (2014) and newer | `intel-media-driver` | Void main |
| Intel GPU, older | `libva-intel-driver` | Void main |
| AMD GPU | `mesa-vaapi` | Void main |
| NVIDIA GPU with the NVIDIA driver loaded | `nvidia-vaapi-driver` | Void main |
| Firmware a driver failed to load this boot | the `linux-firmware-*` package that ships the file | Void main |
| Intel CPU (bare metal) | `intel-ucode` | Void nonfree |
| AMD CPU (bare metal) | `linux-firmware-amd` | Void main |
| Any bare-metal machine | `fwupd` | Void main |
| A laptop | everything in `packages/laptop.lst` (`brightnessctl`, `power-profiles-daemon`) | Void main |

The GPU packages are the VA-API drivers: without them mpv decodes HEVC and
H.264 on the CPU. Void builds mesa with every codec (its template sets
`-Dvideo-codecs=all`), so unlike on Fedora there is no third-party repository
and nothing to swap.

Microcode loads early, from the initramfs, so after installing it `dots
drivers` rebuilds the initramfs of every installed kernel package
(`xbps-reconfigure -f linuxX.Y`); it takes effect at the next boot. `intel-ucode` is in the
nonfree repository, which the installer enables; if nonfree is off, dots says
so and installs nothing.

A virtual machine gets none of the CPU and firmware rows: its microcode and
firmware belong to the host. An emulated GPU (virtio, QXL, VMware, ...) needs
no video driver.

Two things in a VM are settings of that VM, not of dots:

- **The screen size.** A fresh VM's X session starts at 1024x768. Pick a mode
  with `Super+Shift+d` (or `xrandr`), then its "save this layout as a profile"
  entry (or `autorandr --save <name>`);
  `autostart.sh` re-applies it at every login. Or enable the viewer's "auto
  resize VM with window", which `spice-vdagent` follows.
- **The login screen size.** ly draws on the kernel console, which keeps the
  VM's boot mode (1024x768 on QXL) whatever X uses. A viewer stretching that
  to a large window makes ly blurry and the frozen pointer huge, right over
  the login box (nothing moves the pointer before the session's agent runs).
  Give the kernel the mode: add `video=Virtual-1:1920x1080` (the output name
  is in `ls /sys/class/drm`) to `GRUB_CMDLINE_LINUX_DEFAULT` in
  `/etc/default/grub`, then run `sudo update-grub` and reboot.

## How it decides

Everything is read from `/sys` and `/proc` — no `lspci`. Each PCI display
controller's vendor and device id picks the GPU row. Telling old Intel GPUs
from new uses the device-id blocks in the kernel's
`include/drm/intel/pciids.h`. Any id it does not know counts as new.

Firmware is not matched from a list. When a driver cannot load its firmware,
the kernel logs the exact file it wanted:

```text
Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2
```

`dots drivers` reads the kernel log (`dmesg`, through sudo), lists the files
of every `linux-firmware*` package (`xbps-query -Rf`, about a second each),
and installs the one that ships each file. Void stores firmware compressed
and sometimes under a vendor directory (`intel/iwlwifi/...ucode.zst`), so the
match is on the end of the path. Drivers often try several firmware versions
and log a failure for every newer one they do not find. No package ships
those, so nothing is installed for them. Reboot afterwards so the driver
picks the firmware up.

## Laptop or desktop

dots runs on both. `dots drivers` and `dots doctor` start by saying which one
this machine is, and why:

```text
laptop (chassis type 10, battery BAT0) — packages/laptop.lst:
```

A **virtual machine** is recognised first. Void has no
`systemd-detect-virt`, so dots reads the kernel's `hypervisor` CPU flag in
`/proc/cpuinfo` (set in every x86 guest) and the DMI vendor, which also
catches guests whose CPU has no such flag. The vendor names the hypervisor
(QEMU/KVM, VMware, VirtualBox, Hyper-V, Xen). A container shares the host's
cpuinfo and `/sys`, so it is not a VM. A VM reads as **vm**, whatever chassis
type or battery the hypervisor exposes, and is treated as a desktop. It also
gets picom's `xrender` backend, never `glx` (see `docs/THEMING.md`), and the
SPICE guest agent (`spice-vdagentd`, enabled by the services stage).

On real hardware, a machine is a **laptop** when its firmware says so (SMBIOS chassis type 8
Portable, 9 Laptop, 10 Notebook, 14 Sub Notebook, 31 Convertible or 32
Detachable) **or** when it has a system battery, because some firmware
reports a laptop as "Other". A battery the kernel marks `scope=Device`
belongs to a wireless mouse or headset, so it does not count. Types like
3 Desktop and 7 Tower make it a **desktop**. Anything else is **unknown** and
treated as a desktop: nothing laptop-only is installed on a guess.

A desktop behaves exactly as it always did. On a laptop:

- `packages/laptop.lst` is installed, and only there. Each package gets a
  manifest row, so `dots uninstall` removes it. `dots doctor` checks that
  list only on a laptop.
- **The brightness keys dim the backlight**, through `brightnessctl`, and the
  status-bar block says `BL`. On a desktop they scale the picture with
  xrandr gamma, which saves no power, so the block says `GAMMA`. Void builds
  `brightnessctl` without logind: it writes `/sys` through the udev rule it
  ships, which grants the `video` group. The Void installer puts you in
  `video` by default.

- **The bar shows the battery**: `BAT 84%`, with `+` while charging. On
  battery it turns the warning colour at 15 % and the urgent colour at 5 %,
  and each threshold sends one notification (critical urgency at 5 %).
  Charging re-arms them. Left-click shows the time left or to full. A
  desktop's bar has no `BAT` block at all. A wireless mouse's battery
  doesn't count, because the kernel marks it `scope=Device`.

- **The touchpad taps to click.** dots writes
  `/etc/X11/xorg.conf.d/40-dots-touchpad.conf`, turning on tap-to-click
  (one finger left, two right, three middle), natural scrolling, palm
  rejection while typing, and a two-finger click as a right-click anywhere
  on the pad. It matches touchpads only, so a mouse is never affected. Xorg
  reads it at start, so **log out and back in** once after `dots drivers`.
  To change a setting, edit that file: dots never overwrites an edited copy,
  and `dots uninstall` keeps it. `dots doctor` reports whether it is there.

- **Power profiles.** `power-profiles-daemon` is installed and its runit
  service enabled, so the profile you choose survives a reboot.
  `Super+Shift+p`, or `profile` in the power menu, switches between
  power-saver, balanced and performance. Switching needs no password for
  whoever is logged in at the machine (its polkit rule, with elogind's
  active session); from ssh it is refused, and the menu says so. `dots
  uninstall` disables the service only if dots enabled it.

dots does not suspend or hibernate at a critical battery level itself; that
remains elogind's and your choice.

## NVIDIA: reported, never installed

The NVIDIA driver is a kernel module that DKMS builds against every new
kernel. If the build fails, or the branch is wrong for the card, the machine
boots with no graphical session. On a Secure Boot machine an unsigned module
does not load at all. So `dots drivers` identifies the card and prints what
to run, and does not run it:

```text
NVIDIA GPU 0000:01:00.0: GP104 [GeForce GTX 1080] (kernel driver: nouveau)
  sudo xbps-install -S void-repo-nonfree && sudo xbps-install -S nvidia580
```

The branch comes from the chip codename in `/usr/share/hwdata/pci.ids`; the
packages are in Void's nonfree repository:

| Chip | Generation | Package |
| ---- | ---------- | ------- |
| `TU`, `GA`, `AD`, `GB`, `GH` | Turing and newer | `nvidia` (current) |
| `GM`, `GP`, `GV` | Maxwell, Pascal, Volta | `nvidia580` |
| `GK` | Kepler | `nvidia470` |
| `GF` | Fermi | `nvidia390` |
| older | Tesla and before | none — nouveau only |

A codename not in this table gets no guess: it points at
[the Void handbook's NVIDIA page](https://docs.voidlinux.org/config/graphical-session/graphics-drivers/nvidia.html).
Once the driver is loaded, run `dots drivers` again to add
`nvidia-vaapi-driver`.

## Firmware updates

`fwupd` is installed but never run for you, because flashing firmware can
brick a device if the power fails. `dots doctor` warns when updates are
pending, going by the last `fwupdmgr refresh`. To apply them:

```sh
fwupdmgr refresh && fwupdmgr update
```

## Undoing it

Every package `dots drivers` installed and every runit service it enabled is
recorded in the install manifest. `dots uninstall` removes those packages and
unlinks those services. Anything that was already installed or enabled is
left alone. `dots drivers` never adds a repository itself.
