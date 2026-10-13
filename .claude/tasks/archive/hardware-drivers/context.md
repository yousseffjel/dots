# Context — hardware-drivers

## Background
User asked (2026-10-13) for a hardware checker that installs every needed driver,
after reviewing mmbesar's Fedora-39 post-install guide (AMD freeworld, old-Intel
libva, fwupd were the gaps found).

## Prior Decisions
- NVIDIA: detect + report only (user, 2026-10-13).
- Scope adds fwupd, CPU microcode, Wi-Fi/BT firmware (user, 2026-10-13).
- Entry point: `dots drivers`, also run by the installer (user, 2026-10-13).
- RPM Fusion free+nonfree already enabled by install-pkg-repos.sh (rule 4, 3rd/4th exception).
- RAR stays on unar (scope B locked decision 8).

## References
- scripts/install-pkg-repos.sh (repos_install_pkg, REPO swap rows), scripts/uninstall-repos.sh
- scripts/doctor.sh report(); scripts/dots SUBCOMMANDS
- RPM Fusion f44 free: mesa-va-drivers-freeworld 26.x, libva-intel-driver; no vdpau-freeworld
- RPM Fusion f44 nonfree: akmod-nvidia{,-open} 595, -580xx, -470xx, -390xx
- mdapi f43/f44 200: fwupd microcode_ctl amd-ucode-firmware hwdata kmod linux-firmware
  iwlwifi-mvm-firmware amd-gpu-firmware intel-gpu-firmware
- f44 mesa-dri-drivers Provides+Obsoletes mesa-va-drivers

## Notes
- PCI class 0x03xxxx = display; vendor 8086 Intel, 1002 AMD, 10de NVIDIA, 1af4/1234 virtual.
