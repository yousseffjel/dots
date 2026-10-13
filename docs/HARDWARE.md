# Hardware drivers

`dots drivers` looks at this machine and installs what its hardware needs.
The installer runs the same code right after it enables RPM Fusion, so a
fresh install is already covered; run it yourself after swapping a GPU or
moving the install to new hardware. `dots drivers --dry-run` prints what it
would do and changes nothing. `dots doctor` reports the same things under
**drivers**.

## What it installs

| Hardware | Package | From |
| -------- | ------- | ---- |
| Intel GPU, Broadwell (2014) and newer | `intel-media-driver` | RPM Fusion nonfree |
| Intel GPU, older | `libva-intel-driver` | RPM Fusion free |
| AMD GPU | `mesa-va-drivers-freeworld` | RPM Fusion free |
| NVIDIA GPU with the NVIDIA driver loaded | `libva-nvidia-driver` | Fedora |
| Firmware a driver failed to load this boot | the package that ships the file | Fedora |
| Intel CPU (bare metal) | `microcode_ctl` | Fedora |
| AMD CPU (bare metal) | `amd-ucode-firmware` | Fedora |
| Any bare-metal machine | `fwupd` | Fedora |
| A laptop | everything in `packages/laptop.lst` (`brightnessctl`) | Fedora |

The GPU packages are the VA-API drivers: without them mpv decodes HEVC and
H.264 on the CPU, because Fedora's own builds leave those codecs out. On an
AMD GPU, Fedora 43 and older ship a separate `mesa-va-drivers` that is
swapped for the freeworld build. From Fedora 44 the VA drivers are part of
`mesa-dri-drivers`, and the freeworld package installs alongside it.

A virtual machine gets none of the CPU and firmware rows: its microcode and
firmware belong to the host. An emulated GPU (virtio, QXL, VMware, ...) needs
no video driver.

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

`dots drivers` reads this boot's kernel log (`journalctl -k -b`, through
sudo), asks dnf which package ships each file, and installs that package.
Drivers often try several firmware versions and log a failure for every
newer one they do not find. No package ships those, so nothing is installed
for them. Reboot afterwards so the driver picks the firmware up.

## Laptop or desktop

dots runs on both. `dots drivers` and `dots doctor` start by saying which one
this machine is, and why:

```text
laptop (chassis type 10, battery BAT0) — packages/laptop.lst:
```

A machine is a **laptop** when its firmware says so (SMBIOS chassis type 8
Portable, 9 Laptop, 10 Notebook, 14 Sub Notebook, 31 Convertible or 32
Detachable) **or** when it has a system battery, because some firmware
reports a laptop as "Other". A battery the kernel marks `scope=Device`
belongs to a wireless mouse or headset, so it does not count. Types like
3 Desktop and 7 Tower make it a **desktop**. Anything else is **unknown** and
treated as a desktop: nothing laptop-only is installed on a guess. A QEMU
virtual machine reports "Other", so it lands here.

A desktop behaves exactly as it always did. On a laptop:

- `packages/laptop.lst` is installed, and only there. Each package gets a
  manifest row, so `dots uninstall` removes it. `dots doctor` checks that
  list only on a laptop.
- **The brightness keys dim the backlight**, through `brightnessctl`, and the
  status-bar block says `BL`. On a desktop they scale the picture with
  xrandr gamma, which saves no power, so the block says `GAMMA`. Fedora's
  `brightnessctl` goes through logind, so it works for whoever is logged in
  at the machine with no udev rule. Over ssh it is refused, and
  `dwm-brightness` says so rather than quietly using gamma.

- **The bar shows the battery**: `BAT 84%`, with `+` while charging. On
  battery it turns the warning colour at 15 % and the urgent colour at 5 %,
  and each threshold sends one notification (critical urgency at 5 %).
  Charging re-arms them. Left-click shows the time left or to full. A
  desktop's bar has no `BAT` block at all. A wireless mouse's battery
  doesn't count, because the kernel marks it `scope=Device`.

Still to come (`.claude/tasks/scope-h-laptop-support.md`): touchpad
tap-to-click, and power profiles. dots does not suspend or hibernate at a
critical level itself; that remains logind's and your choice.

## NVIDIA: reported, never installed

The NVIDIA driver is a kernel module that akmods builds against every new
kernel. If the build fails, or the branch is wrong for the card, the machine
boots with no graphical session. On a Secure Boot machine the module must
also be signed with a key you enrol by hand at the next boot. So `dots
drivers` identifies the card and prints what to run, and does not run it:

```text
NVIDIA GPU 0000:01:00.0: GP104 [GeForce GTX 1080] (kernel driver: nouveau)
  sudo dnf install akmod-nvidia-580xx xorg-x11-drv-nvidia-580xx-cuda
```

The branch comes from the chip codename in `/usr/share/hwdata/pci.ids`:

| Chip | Generation | Branch |
| ---- | ---------- | ------ |
| `TU`, `GA`, `AD`, `GB`, `GH` | Turing and newer | `akmod-nvidia` (current) |
| `GM`, `GP`, `GV` | Maxwell, Pascal, Volta | `akmod-nvidia-580xx` |
| `GK` | Kepler | `akmod-nvidia-470xx` |
| `GF` | Fermi | `akmod-nvidia-390xx` |
| older | Tesla and before | none — nouveau only |

A codename not in this table gets no guess: it points at
[RPM Fusion's NVIDIA guide](https://rpmfusion.org/Howto/NVIDIA). Once the
driver is loaded, run `dots drivers` again to add `libva-nvidia-driver`.

## Firmware updates

`fwupd` is installed but never run for you, because flashing firmware can
brick a device if the power fails. `dots doctor` warns when updates are
pending, going by the last `fwupdmgr refresh`. To apply them:

```sh
fwupdmgr refresh && fwupdmgr update
```

## Undoing it

Every package `dots drivers` installed and every swap it made is recorded in
the install manifest. `dots uninstall` removes those packages and swaps
`mesa-va-drivers` back. Anything that was already installed is left alone.
It never adds a repository. Without RPM Fusion it skips the GPU rows and
tells you to run the installer.
