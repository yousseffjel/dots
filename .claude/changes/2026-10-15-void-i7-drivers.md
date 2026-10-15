# void-i7-drivers — I-7: drivers and VM detection on Void

## What changed
- `scripts/drivers-detect.sh`: `drivers_virt` treats a machine as a VM when
  the kernel's `hypervisor` CPU flag is set OR the DMI vendor is a
  hypervisor's (QEMU/KVM, VMware, VirtualBox, Xen; Microsoft only with the
  flag). systemd-detect-virt is gone. `drivers_is_vm` derives from it.
  NVIDIA branches use Void's nonfree names (nvidia, nvidia580, nvidia470,
  nvidia390).
- `scripts/drivers-gpu.sh`: intel-media-driver, libva-intel-driver and
  mesa-vaapi from main, with no repository gate and no swap. NVIDIA is
  report-only, now with xbps commands and nvidia-vaapi-driver.
- `scripts/drivers-firmware.sh`:
  - the kernel log comes from `dmesg` (via sudo);
  - the firmware index (`xbps-query -Rs linux-firmware`, then `-Rf` per
    package) is built once and matched on the path end, .zst/.xz optional;
  - microcode is intel-ucode (nonfree, guarded) or linux-firmware-amd,
    followed by `xbps-reconfigure -f linuxX.Y`.
- `scripts/drivers-laptop.sh`: the power-profiles-daemon runit service
  replaces tuned/tuned-ppd (with a dry-run guard).
- `scripts/drivers-lib.sh`: drivers_pkg, drivers_swap and
  drivers_have_rpmfusion are removed; pkg_ensure is used throughout.
  uninstall_repo_swaps and its call are removed. drivers.sh checks for xbps.
- `scripts/doctor-drivers.sh`: xbps-query, the ppd runit link, and Void's
  package names.
- `config/dwm/bin/dwm-picom`: sources drivers-detect.sh through
  `readlink -f` of itself (one detector); falls back to the cpuinfo flag.
- spice-vdagent: the autostart template, the report line and doctor-daemons
  use the flag / drivers_is_vm. The services stage links the
  `spice-vdagentd` runit service in a VM.
- Tests:
  - drivers.sh and both case files rewritten with xbps fakes;
  - picom-backend-probe uses cpuinfo/DMI fixtures;
  - doctor-sandbox drops its rpm, systemctl and systemd-detect-virt fakes;
  - services-runit gains a VM spice case;
  - DOTS_VIRT is pinned in the services tests.
- Docs: HARDWARE.md rewritten; CLAUDE.md, CHANGELOG and scope updated.

## Key Technical Decisions
- **No driver -> package table for firmware.** The packages' own file lists
  answer which package ships a file (about 1 s per package, probed), as dnf
  did on Fedora.
- **The initramfs is rebuilt only when this run installed microcode**,
  following the handbook (intel-ucode sets dracut early_microcode).
- **spice-vdagentd enabled in VMs:** Void ships it as a runit service that
  nothing starts (read in the .xbps). On Fedora the package activated it.
- **One VM detector:** dwm-picom sources drivers-detect.sh, so the
  compositor and the drivers cannot disagree.

## Assumptions Made
- (B) The kernel package is `linux$(uname -r | cut -d. -f1,2)`; this is
  Void's naming. An LTS kernel such as linux6.6 fits too.
- (B) dmesg's ring buffer still holds the firmware lines when `dots drivers`
  runs; a long-running machine may have rotated them. Fedora's journal kept
  the whole boot.

## Test coverage
- Probed for real:
  - `xbps-query -Rf` speed and format;
  - the `-Rs` format;
  - .xbps contents of spice-vdagent, sublime-text4 and the firmware
    packages;
  - Void templates for mesa, intel-ucode and power-profiles-daemon;
  - dwm-picom's readlink through a symlinked directory.
- Mutations on a tree copy, 9/9 caught:
  - the hypervisor flag ignored;
  - the firmware match blind to .zst;
  - no initramfs rebuild;
  - no nonfree guard on intel-ucode;
  - AMD given the wrong package;
  - dwm-picom bypassing the detector;
  - no spice-vdagentd in a VM;
  - the ppd dry-run guard removed;
  - doctor's ppd check always ok.
- `tests/run-tests.sh` 81 OK, 1 SKIP. `tests/lint.sh --strict` passes.
  Reviewer: WARN (a non-x86 guest read as bare metal), fixed with DMI, then
  READY.

## Follow-ups
- I-8: runtime scripts (dwm-powermenu's systemctl, dwm-updates' dnf,
  dwm-lock), plus the remaining doctor checks.
