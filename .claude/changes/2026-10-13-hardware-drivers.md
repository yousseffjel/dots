# hardware-drivers
Date: 2026-10-13
Files: 25 | Lines: +1230/-22

## What changed
- New `dots drivers` (`scripts/drivers.sh`, logic in `drivers-lib.sh` +
  `drivers-{detect,gpu,firmware}.sh`). It reads `/sys` and `/proc` (no lspci)
  and installs:
  - **GPU VA-API driver**: Intel Broadwell+ `intel-media-driver`, older Intel
    `libva-intel-driver` (id blocks from the kernel's `pciids.h`), AMD
    `mesa-va-drivers-freeworld` (a `dnf swap` + REPO swap row where a
    separate `mesa-va-drivers` exists, f43; a plain install on f44).
    Virtual GPUs get nothing.
  - **NVIDIA: REPORT-ONLY.** Card name and branch come from the pci.ids
    codename (TU/GA/AD/GB/GH current, GM/GP/GV 580xx, GK 470xx, GF 390xx,
    older: none; an unknown codename is not guessed). It prints the akmod
    commands and, when Secure Boot is on (from efivars), the MOK steps.
    `libva-nvidia-driver` is added only once the NVIDIA driver is loaded.
  - **Firmware**: files in this boot's kernel log ("Direct firmware load for
    X failed") are resolved with `dnf repoquery --whatprovides` and the
    owning package is installed. No hand-kept table.
  - **Microcode** (`microcode_ctl` / `amd-ucode-firmware`) and **fwupd** on
    bare metal only.
- The installer now calls `drivers_install` from `install-pkg-repos.sh` after
  RPM Fusion. `intel-media-driver` is no longer installed on machines with no
  Intel GPU.
- New `scripts/doctor-drivers.sh`: a `dots doctor` drivers section covering a
  missing VA driver, NVIDIA on nouveau, missing microcode and fwupd, and
  pending firmware updates (`fwupdmgr get-updates` exit code 0 or 2,
  offline).
- `scripts/dots` gains a `drivers` row in SUBCOMMANDS, so help and completion
  pick it up automatically.
- Tests: new `tests/drivers.sh` + `tests/lib/drivers-cases.sh`, which
  generate a fake sysfs tree per machine. `tests/pkg-repos.sh` gets a fixture
  Intel GPU in a VM.
- Docs: new `docs/HARDWARE.md`. README, THUNAR.md and UNINSTALL.md (5d:
  second swap) updated, plus the `uninstall-repos.sh` header, CHANGELOG
  [Unreleased] and the CLAUDE.md project map.

## Why
The user reviewed mmbesar's Fedora 39 post-install guide. Of its steps, only
the AMD freeworld mesa, the old-Intel VA driver and fwupd were real gaps.
The user then asked for a hardware checker that installs every driver this
machine needs, instead of hard-coding Intel.

## Key Technical Decisions
- **NVIDIA detect + report only** (user, 2026-10-13). A wrong branch or a
  failed akmod build leaves no graphical session, and Secure Boot needs an
  interactive MOK enrolment.
- **Scope includes fwupd, microcode and Wi-Fi/BT firmware** (user,
  2026-10-13). Firmware is handled generically through the kernel log, so
  it covers GPU firmware too.
- **Entry point: `dots drivers`, also run by the installer** (user,
  2026-10-13), in-process so failures land in the stage's closing summary.
- `dots drivers` never adds a repository. Without RPM Fusion it skips the GPU
  rows (CLAUDE.md rule 4 keeps repository changes in the installer). The
  installer's dry run sets `DRIVERS_ASSUME_RPMFUSION=1`.
- `drivers_pkg` exists alongside `repos_install_pkg` because the standalone
  command must not load the repo-adding file, and it needs `--dry-run` plus
  a skip for installed packages.
- An unreadable kernel log, or a failing `dnf repoquery`, is reported as
  "not checked", never as clean.

## Assumptions Made
- (B) Per-hardware package names sit inline in `drivers-gpu.sh` /
  `drivers-firmware.sh`, following `install-pkg-repos.sh`'s precedent. Rule
  10 targets package *lists*; these are hardware conditionals.
- (B) An Intel device id outside the pre-Broadwell blocks is treated as new
  (iHD). Those generations are finished, so the table cannot drift.
- (B) The NVIDIA codename-to-branch mapping follows the RPM Fusion branches
  published for f44: 595 current, 580xx, 470xx, 390xx.
- (B) In a VM, microcode and fwupd are skipped as host concerns.
  `systemd-detect-virt` missing ("unknown") is treated as bare metal.
- Package names verified (rule 8): mdapi f43+f44 200 for fwupd,
  microcode_ctl, amd-ucode-firmware, hwdata, kmod, linux-firmware,
  iwlwifi-mvm-firmware, amd-gpu-firmware, intel-gpu-firmware,
  libva-nvidia-driver and mokutil. RPM Fusion directory listings f43+f44 for
  mesa-va-drivers-freeworld, libva-intel-driver, akmod-nvidia{,-580xx,-470xx,
  -390xx} and xorg-x11-drv-nvidia*-cuda. `nvidia-vaapi-driver` (the guide's
  name) does not exist on f44.

## Test coverage
- `tests/drivers.sh`: ~70 checks across Intel new and old, AMD f43 swap and
  f44 install, NVIDIA (Pascal on Secure Boot, Turing, Tesla, unknown
  codename, proprietary loaded + iGPU), firmware (de-dup, fallbacks, dnf
  failure, unreadable log), VM, no RPM Fusion, dry run, a failed install,
  doctor agreement, and the CLI itself.
- Mutation testing on a scratch copy: 14 of 15 mutations caught. The miss is
  the firmware de-dup, which is redundant because `drivers_pkg` skips
  installed packages. The doctor `rc 2` mutation was initially missed; a
  test was added and it is now caught.
- Full suite `tests/run-tests.sh` exit 0 (63 scripts). `tests/lint.sh`
  passed.
- **Fedora 44 VM (kvm, virtio GPU)**: `dnf install --assumeno
  mesa-va-drivers-freeworld` (RPM Fusion via `--repofrompath`, nothing
  added) installs beside `mesa-dri-drivers` and only upgrades it, with no
  removal. The dnf5 `--whatprovides` glob resolves iwlwifi/amdgpu files and
  returns nothing for an unshipped one. `dots drivers --dry-run`, the doctor
  check and the installer dry run were all correct. The VM run found that an
  unreadable kernel log read as clean; fixed.
- Not verified: real Intel, AMD or NVIDIA hardware (fixtures only), and the
  f43 swap against real dnf.

## Follow-ups
- Run `dots drivers` on real AMD or NVIDIA hardware when available. The f43
  swap path also needs a real-dnf check.
- Per-file `dnf repoquery` is slow when many firmware loads fail. It could be
  batched if dnf5 accepts several `--whatprovides` values.
- Pre-existing, not from this slot: in `install-pkg.sh --dry-run`, the tier
  loop prints "installed: X" after "(dry-run) would install: X".
