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
check "Intel CPU: intel-ucode" has intel-ucode
check "...and the initramfs rebuilt for the installed kernel" grep -qx "xbps-reconfigure -f linux6.12" "$LOG"
check "bare metal: fwupd" has fwupd
check "the Wi-Fi card is not treated as a GPU" not_said "a0f0"
check "nothing failed" test "${#FAILED_EXTRA[@]}" -eq 0

blue "==> re-run is a no-op"
: >"$LOG"
run
check "no xbps-install" no_installs
check "no initramfs rebuild" no_rebuild

blue "==> chassis: laptop by firmware, by battery; desktop; unknown"
machine GenuineIntel none
chassis 10
run
check "chassis type 10 (Notebook) is a laptop" test "$(drivers_chassis)" = laptop
check "laptop.lst installed on a laptop" has brightnessctl
check "with a PACKAGE row, so uninstall removes it" row PACKAGE brightnessctl
check "and said why" said "laptop (chassis type 10)"
machine GenuineIntel none
chassis 1
battery BAT0
run
check "firmware says Other, but a system battery: laptop" test "$(drivers_chassis)" = laptop
check "...and gets laptop.lst" has brightnessctl
machine GenuineIntel none
chassis 3
battery hidpp_battery_0 Device
run
check "a desktop with a wireless mouse battery stays a desktop" test "$(drivers_chassis)" = desktop
check "...and gets no laptop packages" lacks brightnessctl
machine GenuineIntel kvm
chassis 1
run
check "a KVM guest (chassis 1, Other): vm" test "$(drivers_chassis)" = vm
check "a vm is treated as a desktop: nothing laptop-only" lacks brightnessctl
check "said so, naming the hypervisor" said "vm (kvm, chassis type 1) — no laptop packages"
machine GenuineIntel kvm
chassis 10
battery BAT0
run
check "a guest exposing a laptop chassis AND a battery is still a vm" test "$(drivers_chassis)" = vm
check "...and gets no laptop packages" lacks brightnessctl
machine GenuineIntel none
chassis 1
run
check "bare metal reporting chassis 1 (Other), no battery: unknown" test "$(drivers_chassis)" = unknown
check "unknown is treated as a desktop too" lacks brightnessctl
machine GenuineIntel none
run
check "no dmi at all: unknown, nothing installed" lacks brightnessctl
machine GenuineIntel none
chassis 9
# A child bash gets only the exported detection functions, never read_pkg_list.
(
    export -f drivers_laptop drivers_chassis drivers_chassis_type drivers_system_battery drivers_chassis_why drivers_sysfs drivers_is_vm drivers_virt red blue
    bash -c 'drivers_laptop' >"$SB/out" 2>&1 || true
)
check "laptop without the list parser: said, not a silent no-op" grep -q "read_pkg_list is not loaded" "$SB/out"

blue "==> VM detection without systemd: the hypervisor CPU flag, then DMI"
HYPERVISOR_FLAG=" hypervisor" machine GenuineIntel detect
mkdir -p "$SYSFS/class/dmi/id" && echo QEMU >"$SYSFS/class/dmi/id/sys_vendor"
check "flag + QEMU: kvm" test "$(drivers_virt)" = kvm
echo 'VMware, Inc.' >"$SYSFS/class/dmi/id/sys_vendor"
check "flag + VMware: vmware" test "$(drivers_virt)" = vmware
echo 'Some Vendor' >"$SYSFS/class/dmi/id/sys_vendor"
check "flag, unknown vendor: still a vm" test "$(drivers_virt)" = vm
machine GenuineIntel detect
mkdir -p "$SYSFS/class/dmi/id" && echo QEMU >"$SYSFS/class/dmi/id/sys_vendor"
check "no flag but a QEMU vendor (an aarch64 guest): kvm" test "$(drivers_virt)" = kvm
echo 'LENOVO' >"$SYSFS/class/dmi/id/sys_vendor"
check "no flag, a hardware vendor: bare metal" test "$(drivers_virt)" = none
check "...and not a vm" eval '! drivers_is_vm'
echo 'Microsoft Corporation' >"$SYSFS/class/dmi/id/sys_vendor"
check "no flag, Microsoft (a Surface): bare metal, not Hyper-V" test "$(drivers_virt)" = none

blue "==> Intel, pre-Broadwell (Ivy Bridge)"
machine GenuineIntel none
gpu 0000:00:02.0 0x030000 8086 0166 i915
run
check "libva-intel-driver installed" has libva-intel-driver
check "iHD, which cannot drive it, is not" lacks intel-media-driver

blue "==> AMD: mesa-vaapi, and the CPU's microcode from linux-firmware-amd"
machine AuthenticAMD none
gpu 0000:03:00.0 0x030000 1002 73bf amdgpu
run
check "mesa-vaapi installed" has mesa-vaapi
check "PACKAGE row" row PACKAGE mesa-vaapi
check "AMD CPU: linux-firmware-amd" has linux-firmware-amd
check "...and the initramfs rebuilt" grep -qx "xbps-reconfigure -f linux6.12" "$LOG"
NO_KERNEL=1 machine AuthenticAMD none
run
check "no kernel package (a container): said, and no rebuild attempted" \
    eval 'said "no kernel package installed here" && no_rebuild'

blue "==> intel-ucode out of reach (nonfree not enabled)"
machine GenuineIntel none
FAKE_UNAVAIL=intel-ucode run
check "not installed" lacks intel-ucode
check "said why, naming the repo" said "intel-ucode needs void-repo-nonfree"
check "in the summary" grep -qx intel-ucode <<<"$(printf '%s\n' "${FAILED_EXTRA[@]}")"
check "no initramfs rebuild" no_rebuild

blue "==> NVIDIA on nouveau, Secure Boot on: reported, never installed"
machine GenuineIntel none
gpu 0000:01:00.0 0x030000 10de 1b80 nouveau
secure_boot_on
run
check "card named from the NVIDIA block of pci.ids" said "GP104 [GeForce GTX 1080]"
check "Pascal -> nvidia580" said "sudo xbps-install -S nvidia580"
check "Secure Boot warning printed" said "Secure Boot is ON"
check "no NVIDIA package of any kind installed" not grep -q 'nvidia' "$DB"

blue "==> NVIDIA: Turing+ current branch, no Secure Boot, Fermi-older, unknown"
machine GenuineIntel none
gpu 0000:01:00.0 0x030000 10de 2484 nouveau
run
check "current branch: plain nvidia" grep -qE -- 'xbps-install -S nvidia$' <<<"$OUT"
check "no Secure Boot warning without it" not_said "Secure Boot"
machine GenuineIntel none
gpu 0000:01:00.0 0x030000 10de 0a20 nouveau
run
check "Tesla-era card: nouveau only" said "nouveau is the only option"
check "and no install command" not_said "xbps-install -S nvidia"
machine GenuineIntel none
gpu 0000:01:00.0 0x030000 10de 5000 nouveau
run
check "unknown codename: pointed at the guide, no guess" said "driver branch not recognised"
check "and no install command for it" not_said "xbps-install -S nvidia"

blue "==> NVIDIA with the proprietary driver loaded, plus an Intel iGPU"
machine GenuineIntel none
gpu 0000:00:02.0 0x030000 8086 9a49 i915
gpu 0000:01:00.0 0x030000 10de 2484 nvidia
run
check "nvidia-vaapi-driver added" has nvidia-vaapi-driver
check "and the iGPU still handled" has intel-media-driver

blue "==> firmware: only what the kernel missed AND a package ships"
machine GenuineIntel none
gpu 0000:00:02.0 0x030000 8086 9a49 i915
cat >"$DOTS_KERNEL_LOG" <<'EOF'
iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-90.ucode failed with error -2
iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2
iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2
i915 0000:00:02.0: Direct firmware load for i915/adlp_dmc.bin failed with error -2
EOF
run
check "the shipped file's package installed (.zst, under intel/iwlwifi/)" has linux-firmware-network
check "a file asked for with its directory (i915/...) too" has linux-firmware-intel
check "installed once, though logged twice" test "$(grep -c 'install -y linux-firmware-network' "$LOG")" -eq 1
check "the fallback attempt (-90) installs nothing more" \
    test "$(grep -c '^xbps-install -y linux-firmware' "$LOG")" -eq 2

machine GenuineIntel none
printf '%s\n' 'iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2' >"$DOTS_KERNEL_LOG"
FAKE_FAIL=fwquery run
check "xbps failing is said, not passed off as a driver fallback" said "xbps-query -Rf failed"
check "and not as 'none shipped by any package'" not_said "none shipped"
check "nothing installed for it" lacks linux-firmware-network

blue "==> an unreadable kernel log is not a clean one"
machine GenuineIntel kvm
DOTS_KERNEL_LOG="$SB/no-such-log" run
check "said it could not check" said "firmware not checked"
check "did not claim a clean boot" not_said "no failed firmware loads"

blue "==> virtual machine"
machine GenuineIntel kvm
gpu 0000:00:01.0 0x030000 1af4 1050 virtio-pci
run
check "virtio GPU: nothing installed" no_installs
check "said it was virtual" said "virtual GPU"
check "microcode and fwupd skipped" said "belongs to its host"

blue "==> --dry-run and failures"
machine AuthenticAMD none
gpu 0000:03:00.0 0x030000 1002 73bf amdgpu
DRY_RUN=1 run
check "dry run: no xbps writes" no_installs
check "dry run: no initramfs rebuild" no_rebuild
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
machine AuthenticAMD none
gpu 0000:03:00.0 0x030000 1002 73bf amdgpu
fake "$SB/bin" sudo '"$@"'
check "exits 0" bash "$DOTS_DIR/scripts/drivers.sh" --dry-run >"$SB/out" 2>&1
check "reports what it would install" grep -qF "(dry-run) would install mesa-vaapi" "$SB/out"
check "changes nothing" no_installs
check "rejects an unknown flag" not bash "$DOTS_DIR/scripts/drivers.sh" --bogus >/dev/null 2>&1
