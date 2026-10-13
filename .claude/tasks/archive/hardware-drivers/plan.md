# Plan — hardware-drivers

## Goal
`dots drivers` (+ called by install-pkg.sh): read /sys, install what this machine
needs — GPU video accel (Intel new/old, AMD freeworld), firmware for every bound
driver, CPU microcode, fwupd — and REPORT-only for NVIDIA (branch + Secure Boot).
Re-runnable, --dry-run, manifest rows so uninstall reverts only what it added.

## Scope
- scripts/{drivers*,doctor*,install-pkg-repos}.sh, scripts/dots
- tests/{drivers*,pkg-repos}.sh, tests/fixtures/sysfs/**
- docs/{HARDWARE,THUNAR}.md, CHANGELOG.md, CLAUDE.md

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. drivers-detect.sh: pure sysfs readers (DOTS_SYSFS_ROOT override) — GPUs, bound drivers, CPU vendor.
2. drivers-gpu.sh: Intel new/old split, AMD freeworld (swap row), NVIDIA report.
3. drivers-firmware.sh: modinfo firmware -> dnf provides -> subpackage; microcode; fwupd.
4. drivers.sh CLI + SUBCOMMANDS row; install-pkg-repos.sh calls it (drop unconditional intel-media-driver).
5. doctor-drivers.sh: missing driver pkgs, NVIDIA on nouveau, pending fwupd updates.
6. tests/drivers.sh: fixture sysfs trees + fake dnf/rpm/modinfo; update tests/pkg-repos.sh.
7. docs/HARDWARE.md, THUNAR.md line, CHANGELOG, CLAUDE.md map; VM run (virtio GPU).

## Out of scope
- Installing NVIDIA drivers (decision: detect + report only)
- pciutils / lspci; hybrid-GPU switching (PRIME)

## Risks
- f44 folds mesa-va-drivers into mesa-dri-drivers: `dnf swap` may remove dri — verify on VM, fallback install --allowerasing
- Intel gen / NVIDIA branch need device-ID cutoffs (drift) — one table, cited source, unknown => report
- modinfo lists every firmware a module MAY load — resolve by package, not by file
