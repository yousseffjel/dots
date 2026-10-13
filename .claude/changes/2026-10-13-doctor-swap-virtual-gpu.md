# doctor-swap-virtual-gpu
Date: 2026-10-13
Files: 12 | Lines: +190/-88

## What changed
- `scripts/doctor-checks.sh`: a new `doctor_drop_satisfied` drops a
  "missing" package whose `SATISFIED_BY` stand-in (install-pkg-tiers.sh) is
  installed, and reports it as `ok … replaced by <stand-in>`.
  `check_packages` calls it before deciding fail or warn.
- `scripts/drivers-detect.sh`: `drivers_virtual_gpu <vendor>` replaces
  `drivers-gpu.sh`'s private `DRIVERS_VIRTUAL_GPU_VENDORS` string, so doctor
  can use it too. `scripts/doctor-drivers.sh` reports `ok` for a virtual GPU
  and `skip` for an unrecognised vendor (both used to be silent).
- `tests/lib/doctor-sandbox.sh`: `run_doctor` now passes
  `DOTS_SYSFS`/`DOTS_CPUINFO`/`DOTS_VIRT` (an empty PCI tree, an Intel
  cpuinfo, kvm). The `rpm` fake answers `rpm -q pkg` as well as
  `rpm -q --whatprovides …`.
- `tests/doctor.sh`: cases for a swapped ffmpeg (ok, exit 0), neither ffmpeg
  (fail), and a sealed drivers section. Its desktop sections (notifications,
  portal, GTK3, cursor, flatpak) were moved verbatim into
  `tests/lib/doctor-cases-desktop.sh`.
- `tests/lib/drivers-cases.sh`: doctor gives an ok row for a virtio GPU and a
  skip row for an unknown vendor.
- CHANGELOG [Unreleased] → Fixed: two lines.

## Why
Found on the Fedora 44 VM right after the hardware-drivers merge: the first
install there with RPM Fusion made `dots doctor` FAIL `ffmpeg-free` on every
machine where the swap happened. The installer already counted RPM Fusion's
`ffmpeg` as `ffmpeg-free` through `SATISFIED_BY`, but doctor loaded that
table and never used it. The drivers section also printed nothing for the
VM's virtio GPU, so it was unclear the GPU had been looked at.

## Key Technical Decisions
- Doctor reuses the installer's `SATISFIED_BY` instead of special-casing
  ffmpeg, so a future stand-in is covered in both places at once.
- A stand-in counts only while it is itself installed (`rpm -q`). With
  neither package installed it is still a FAIL.
- An unknown GPU vendor is a `skip`, not an `ok`: nothing was checked.

## Assumptions Made
- (C) `doctor_drop_satisfied` works on `check_packages`' locals through bash
  dynamic scope, as the comment says. A pure function returning a list would
  need a second `mapfile` round-trip for no gain.

## Test coverage
- Found while doing this: since the hardware-drivers merge (`8d7f4e4`),
  `tests/doctor.sh` read the dev host's real `/sys` and `/proc/cpuinfo`. It
  passed only because the `rpm` fake said every package was installed. Now
  sealed. A mutation that removes the seal is caught on this host, which has
  an Intel GPU.
- Mutations on a scratch copy, 5 of 5 caught: dropping the
  `doctor_drop_satisfied` call, not requiring the stand-in to be installed,
  removing the sandbox sysfs seal, removing the virtual-GPU ok row, and
  emptying the virtual vendor list.
- `tests/doctor.sh` gives 77 passed both before and after the split, so no
  check was lost. Full suite `tests/run-tests.sh` exit 0 (63 scripts).
  `tests/lint.sh` passed.
- On the f44 VM, read-only from a temp copy: `ok packages pkg-ffmpeg-free
  ffmpeg-free is replaced by ffmpeg` and `ok drivers video-0000:00:01.0 …
  is virtual`.
- Reviewer: WARN (my insert had separated `check_packages`' header comment
  from it). Fixed, and doctor + lint re-run.

## Follow-ups
- Plan deviation: `tests/lib/doctor-cases-desktop.sh` was not in the plan's
  Scope. It was created by the forced 250-line split.
- Still open from hardware-drivers: the installer prints "installed: X" for
  packages already present.
