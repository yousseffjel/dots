#!/usr/bin/env bash
# The cases of tests/drivers.sh — SOURCED by it, never run alone (tests/lib/
# is outside run-tests.sh's depth-1 glob). Uses that file's machine, gpu,
# run, check and predicate helpers; split off at the 250-line cap.

blue "==> Intel, Broadwell and newer"
machine GenuineIntel none
gpu 0000:00:02.0 0x030000 8086 9a49 i915
gpu 0000:00:14.3 0x028000 8086 a0f0 iwlwifi # Wi-Fi: not a display device
run
check "intel-media-driver installed" has intel-media-driver
check "not the legacy driver" lacks libva-intel-driver
check "PACKAGE row for it" row PACKAGE intel-media-driver
check "Intel CPU: microcode_ctl" has microcode_ctl
check "bare metal: fwupd" has fwupd
check "the Wi-Fi card is not treated as a GPU" not_said "a0f0"
check "nothing failed" test "${#FAILED_EXTRA[@]}" -eq 0

blue "==> re-run is a no-op"
: >"$LOG"
run
check "no dnf install or swap" no_dnf_writes

blue "==> Intel, pre-Broadwell (Ivy Bridge)"
machine GenuineIntel none
gpu 0000:00:02.0 0x030000 8086 0166 i915
run
check "libva-intel-driver installed" has libva-intel-driver
check "iHD, which cannot drive it, is not" lacks intel-media-driver

blue "==> AMD, f43: separate mesa-va-drivers is swapped"
machine AuthenticAMD none mesa-va-drivers
gpu 0000:03:00.0 0x030000 1002 73bf amdgpu
run
check "freeworld in" has mesa-va-drivers-freeworld
check "Fedora's out" lacks mesa-va-drivers
check "REPO swap row, so uninstall swaps it back" row REPO $'swap\tmesa-va-drivers\tmesa-va-drivers-freeworld'
check "AMD CPU: amd-ucode-firmware" has amd-ucode-firmware

blue "==> AMD, f44: VA drivers live in mesa-dri-drivers, so a plain install"
machine AuthenticAMD none mesa-dri-drivers
gpu 0000:03:00.0 0x030000 1002 73bf amdgpu
run
check "freeworld installed" has mesa-va-drivers-freeworld
check "mesa-dri-drivers untouched" has mesa-dri-drivers
check "no swap attempted" not grep -q '^dnf swap' "$LOG"
check "PACKAGE row instead" row PACKAGE mesa-va-drivers-freeworld

blue "==> NVIDIA on nouveau, Secure Boot on: reported, never installed"
machine GenuineIntel none
gpu 0000:01:00.0 0x030000 10de 1b80 nouveau
secure_boot_on
run
check "card named from the NVIDIA block of pci.ids" said "GP104 [GeForce GTX 1080]"
check "Pascal -> the 580xx branch" said "akmod-nvidia-580xx"
check "Secure Boot steps printed" said "mokutil --import"
check "no akmod installed" not grep -q 'dnf install -y akmod' "$LOG"
check "no NVIDIA package of any kind installed" not grep -q 'nvidia' "$DB"

blue "==> NVIDIA: Turing+ current branch, no Secure Boot, Fermi-older, unknown"
machine GenuineIntel none
gpu 0000:01:00.0 0x030000 10de 2484 nouveau
run
check "current branch has no suffix" said "sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda"
check "no MOK steps without Secure Boot" not_said "mokutil"
machine GenuineIntel none
gpu 0000:01:00.0 0x030000 10de 0a20 nouveau
run
check "Tesla-era card: nouveau only" said "nouveau is the only option"
check "and no install command" not_said "akmod-nvidia"
machine GenuineIntel none
gpu 0000:01:00.0 0x030000 10de 5000 nouveau
run
check "unknown codename: pointed at the guide, no guess" said "driver branch not recognised"
check "and no install command for it" not_said "akmod-nvidia"

blue "==> NVIDIA with the proprietary driver loaded, plus an Intel iGPU"
machine GenuineIntel none
gpu 0000:00:02.0 0x030000 8086 9a49 i915
gpu 0000:01:00.0 0x030000 10de 2484 nvidia
run
check "libva-nvidia-driver added" has libva-nvidia-driver
check "and the iGPU still handled" has intel-media-driver

blue "==> firmware: only what the kernel missed AND a package ships"
machine GenuineIntel none
gpu 0000:00:02.0 0x030000 8086 9a49 i915
cat >"$DOTS_KERNEL_LOG" <<'EOF'
iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-90.ucode failed with error -2
iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2
iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2
EOF
run
check "the shipped file's package installed" has iwlwifi-mvm-firmware
check "installed once, though logged twice" test "$(grep -c 'install -y iwlwifi' "$LOG")" -eq 1
check "the fallback attempt (-90) installs nothing" test "$(grep -c '^dnf install' "$LOG")" -eq 4

FAKE_FAIL=repoquery run
check "dnf failing is said, not passed off as a driver fallback" said "dnf repoquery failed"
check "and not as 'none shipped by any package'" not_said "none shipped"

blue "==> an unreadable kernel log is not a clean one"
machine GenuineIntel kvm
DOTS_KERNEL_LOG="$SB/no-such-log" run
check "said it could not check" said "firmware not checked"
check "did not claim a clean boot" not_said "no failed firmware loads"

blue "==> virtual machine"
machine GenuineIntel kvm
gpu 0000:00:01.0 0x030000 1af4 1050 virtio-pci
run
check "virtio GPU: nothing installed" no_dnf_writes
check "said it was virtual" said "virtual GPU"
check "microcode and fwupd skipped" said "belongs to its host"

blue "==> no RPM Fusion: video skipped, no repo added"
machine GenuineIntel kvm
grep -v rpmfusion "$DB" >"$DB.new" || true # empty result: grep exits 1
mv "$DB.new" "$DB"
gpu 0000:00:02.0 0x030000 8086 9a49 i915
run
check "skipped with the reason" said "RPM Fusion nonfree is not enabled"
check "nothing installed" no_dnf_writes
DRIVERS_ASSUME_RPMFUSION=1 DRY_RUN=1 run
check "the installer's dry run assumes it" said "(dry-run) would install intel-media-driver"

blue "==> --dry-run and failures"
machine AuthenticAMD none mesa-va-drivers
gpu 0000:03:00.0 0x030000 1002 73bf amdgpu
DRY_RUN=1 run
check "dry run: no dnf writes" no_dnf_writes
check "dry run: no manifest" test ! -e "$MANIFEST_FILE"
FAKE_FAIL=fwupd run
check "a failed install is reported" grep -qx fwupd <<<"$(printf '%s\n' "${FAILED_EXTRA[@]}")"
check "with no PACKAGE row" not row PACKAGE fwupd

blue "==> doctor agrees"
DOCTOR=""
report() { DOCTOR+="$1 $3"$'\n'; }
# shellcheck source=../../scripts/doctor-drivers.sh
source "$DOTS_DIR/scripts/doctor-drivers.sh"
machine GenuineIntel none
gpu 0000:00:02.0 0x030000 8086 9a49 i915
gpu 0000:01:00.0 0x030000 10de 2484 nouveau
check_drivers
check "missing intel-media-driver warns" grep -qx "warn video-0000:00:02.0" <<<"$DOCTOR"
check "nouveau warns" grep -qx "warn nvidia-0000:01:00.0" <<<"$DOCTOR"
check "missing microcode warns" grep -qx "warn microcode" <<<"$DOCTOR"
check "missing fwupd warns" grep -qx "warn fwupd" <<<"$DOCTOR"
run
DOCTOR=""
FAKE_FWUPD_RC=0 check_drivers
check "after dots drivers: video ok" grep -qx "ok video-0000:00:02.0" <<<"$DOCTOR"
check "microcode ok" grep -qx "ok microcode" <<<"$DOCTOR"
check "pending firmware updates warn" grep -qx "warn fwupd" <<<"$DOCTOR"
DOCTOR=""
check_drivers
check "fwupdmgr exit 2 (nothing to do) is ok" grep -qx "ok fwupd" <<<"$DOCTOR"
machine GenuineIntel kvm
gpu 0000:00:01.0 0x030000 1af4 1050 virtio-pci
gpu 0000:00:02.0 0x030000 abcd 0001 mystery
DOCTOR=""
check_drivers
check "virtual GPU: an ok row, not silence" grep -qx "ok video-0000:00:01.0" <<<"$DOCTOR"
check "unknown vendor: skipped, not passed" grep -qx "skip video-0000:00:02.0" <<<"$DOCTOR"

blue "==> the command itself: scripts/drivers.sh --dry-run"
machine AuthenticAMD none mesa-va-drivers
gpu 0000:03:00.0 0x030000 1002 73bf amdgpu
fake "$SB/bin" sudo '"$@"'
check "exits 0" bash "$DOTS_DIR/scripts/drivers.sh" --dry-run >"$SB/out" 2>&1
check "reports the swap it would make" grep -qF "would run: dnf swap mesa-va-drivers mesa-va-drivers-freeworld" "$SB/out"
check "changes nothing" no_dnf_writes
check "rejects an unknown flag" not bash "$DOTS_DIR/scripts/drivers.sh" --bogus >/dev/null 2>&1
