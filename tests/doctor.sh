#!/usr/bin/env bash
# `dots doctor` (scripts/doctor.sh) against a sandbox that looks like a
# healthy install, then with one thing broken at a time. Checked:
#   * healthy: exit 0, no warn or fail, in both formats;
#   * notifications: dunst asked over D-Bus; do-not-disturb left on and a
#     dunst that does not answer both warn; nothing is asked outside dwm;
#   * the two formats come from one code path: same statuses, same order;
#   * a missing desktop.lst package FAILS with that line's consequence text;
#     a missing extra.lst package only warns;
#   * a disabled manifest SERVICE fails; no manifest fails;
#   * daemons: the list is the installer's report, every DAEMON_PROCESS key
#     is in it, a daemon absent from autostart.sh and one that died get
#     different advice, a VM-only daemon off a VM is skipped, dwm-lock is
#     found as xss-lock;
#   * no X session, not Fedora: whole sections skip instead of failing;
#   * the desktop portal: a session D-Bus bus, then a real ReadOne of
#     color-scheme (dark ok; light, dead, no bus warn; no X skips);
#   * the GTK3 theme name: missing -> warn, a GTK built-in -> ok;
#   * flatpak: a missing grant or remote warns, a grant set the user's own
#     way is ok, no flatpak at all skips;
#   * it is read-only: the sandbox HOME is byte-identical afterwards.
# SEALED PATH: the fakes in tests/lib/doctor-sandbox.sh are all it can reach.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

PASS=0
FAIL=0
ok() {
    green "  ok: $*"
    PASS=$((PASS + 1))
}
bad() {
    red "  FAIL: $*"
    FAIL=$((FAIL + 1))
}
# check <description> <command...> — ok when the command succeeds.
check() {
    local what="$1"
    shift
    if "$@"; then ok "$what"; else bad "$what"; fi
}

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# shellcheck source=lib/doctor-sandbox.sh
source "$SCRIPT_DIR/lib/doctor-sandbox.sh"

mapfile -t DAEMONS < <(daemon_names)
make_fakes
make_home

tsv() { run_doctor --tsv >"$SB/out.tsv" 2>&1 && echo 0 >"$SB/rc" || echo $? >"$SB/rc"; }
rc_is() { [[ "$(cat "$SB/rc")" == "$1" ]]; }
row() { grep -qE "^$1	$2	$3	" "$SB/out.tsv"; }
no_row() { ! row "$@"; }
none_of() { ! grep -qE "^($1)	" "$SB/out.tsv"; }
detail() { grep -E "^[a-z]+	[a-z]+	$1	" "$SB/out.tsv" | cut -f4; }

blue "==> healthy install"
check "the installer's report names daemons (${#DAEMONS[@]})" test "${#DAEMONS[@]}" -gt 5
tsv
check "exit 0" rc_is 0
check "no warn or fail" none_of 'warn|fail'
check "packages checked per tier" row ok packages tier-desktop
check "the manifest's service is checked" row ok install service-ly
check "every linked config is checked" \
    test "$(grep -cE $'^ok\tinstall\tlink-' "$SB/out.tsv")" -eq "$(HOME="$H" bash "$DOTS_DIR/scripts/symlinks.sh" --list-links | grep -c .)"
check "every reported daemon is checked" \
    test "$(grep -cE $'^[a-z]+\tsession\tdaemon-' "$SB/out.tsv")" -eq "${#DAEMONS[@]}"
check "dwm-lock is found as xss-lock" row ok session daemon-dwm-lock
check "autorandr is one-shot, not a daemon" row skip session daemon-autorandr
check "the GTK3 theme name resolves (the shim)" row ok theme gtk3
check "Flatpak grants and Flathub are checked" row ok theme flatpak
check "...the Flathub remote too" row ok theme flathub
check "no running build is older than the installed one" row ok session builds
find "$H" -printf '%p %s %l\n' | sort >"$SB/before"

blue "==> one code path, two formats"
run_doctor >"$SB/out.human" 2>&1 || true
sed -n 's/^[^ ]* *\(ok\|warn\|FAIL\|skip\) .*/\1/p' "$SB/out.human" | tr '[:upper:]' '[:lower:]' >"$SB/h"
cut -f1 "$SB/out.tsv" >"$SB/t"
check "human and tsv list the same statuses in the same order" cmp -s "$SB/h" "$SB/t"
cmp -s "$SB/h" "$SB/t" || diff "$SB/h" "$SB/t" | head -5
check "human output ends with the verdict" grep -q 'all checks passed' "$SB/out.human"

blue "==> each DAEMON_PROCESS key is a daemon the installer reports"
keys="$(sed -n 's/^declare -A DAEMON_PROCESS=(\(.*\))$/\1/p' "$DOTS_DIR/scripts/doctor-daemons.sh" \
    | grep -o '\["[^"]*"\]' | tr -d '[]"')"
check "found the DAEMON_PROCESS table" test -n "$keys"
for k in $keys; do
    check "DAEMON_PROCESS[$k] is reported" grep -qx "$k" <(printf '%s\n' "${DAEMONS[@]}")
done
# daemon_applies' case labels, read from the function rather than listed here:
# a hand-written copy went stale the first time a daemon was added to it.
applies="$(sed -n '/^daemon_applies()/,/^}/p' "$DOTS_DIR/scripts/doctor-daemons.sh" \
    | sed -n 's/^ *\([a-z][a-z-]*\)).*/\1/p')"
check "found daemon_applies' cases" test -n "$applies"
for k in $applies; do
    check "daemon_applies' $k is reported" grep -qx "$k" <(printf '%s\n' "${DAEMONS[@]}")
    # shellcheck disable=SC2016 # $1 $2 are the inner bash's arguments
    check "daemon_applies' $k has its own skip reason" bash -c '
        source "$1"; [[ "$(daemon_skip_reason "$2")" != "not needed on this machine" ]]' _ "$DOTS_DIR/scripts/doctor-daemons.sh" "$k"
done

blue "==> packages"
FAKE_MISSING="sxhkd pavucontrol" tsv
check "a missing desktop package fails, exit 1" row fail packages pkg-sxhkd
check "...with desktop.lst's consequence text" grep -q 'EVERY non-dwm keybind' <(detail pkg-sxhkd)
check "a missing extra package only warns" row warn packages tier-extra
check "exit 1" rc_is 1
FAKE_MISSING=pavucontrol tsv
check "extra only: exit 0" rc_is 0
RELEASE="" tsv
check "not Void: the package section skips" row skip packages xbps
# The ffmpeg-free/RPM Fusion SATISFIED_BY cases went with the Fedora package
# names (scope I, I-2); I-4 deletes the swap and the mechanism together.

blue "==> picom backend"
tsv
check "VM running xrender: ok, with the reason" grep -qE $'^ok\tsession\tpicom-backend\tpicom uses xrender: virtual machine \\(kvm\\)' "$SB/out.tsv"
FAKE_PICOM_ARGS="--backend glx" tsv
check "VM running glx (an old autostart.sh): warns, says what to paste" row warn session picom-backend
check "...naming dwm-picom" grep -q "dwm-picom &" <<<"$(detail picom-backend)"
FAKE_PICOM_ARGS="--config x" tsv
check "picom with no --backend (picom.conf's glx) in a VM: warns too" row warn session picom-backend

blue "==> drivers"
tsv
check "sandbox is a VM: host-firmware skip" row skip drivers firmware-host
check "and no GPU row — the host's real /sys is not read" none_of 'ok	drivers	video|warn	drivers'
check "chassis reported (the sandbox is a KVM guest: vm)" grep -qE $'^ok\tdrivers\tchassis\tvm \(kvm' "$SB/out.tsv"
check "laptop.lst is skipped on a non-laptop" row skip packages tier-laptop
mkdir -p "$SB/sys/class/dmi/id"
echo 9 >"$SB/sys/class/dmi/id/chassis_type"
# Bare metal from here: in a VM the same chassis type would read as vm.
export FAKE_VIRT=none
FAKE_MISSING=brightnessctl tsv
check "on a laptop: laptop.lst is checked, and a missing package warns" row warn packages tier-laptop
check "...only warns: exit 0" rc_is 0
check "chassis says laptop" grep -qE $'^ok\tdrivers\tchassis\tlaptop ' "$SB/out.tsv"
check "laptop without the touchpad snippet warns" row warn drivers touchpad
check "laptop with power-profiles-daemon enabled: power ok" row ok drivers power
FAKE_SERVICE=disabled tsv
check "power-profiles-daemon not enabled: power warns" row warn drivers power
tsv
mkdir -p "$SB/xorg.conf.d"
cp "$DOTS_DIR/config/xorg/40-dots-touchpad.conf" "$SB/xorg.conf.d/"
tsv
check "...and is ok once installed" row ok drivers touchpad
check "...as dots' own copy, not as an edited one" \
    test "$(detail touchpad)" = "touchpad settings installed ($SB/xorg.conf.d/40-dots-touchpad.conf)"
echo '# edited' >>"$SB/xorg.conf.d/40-dots-touchpad.conf"
tsv
check "an edited snippet is the user's: still ok" row ok drivers touchpad
check "...and says it is edited" grep -q "edited by you" <<<"$(detail touchpad)"
rm -r "$SB/xorg.conf.d"
rm -r "$SB/sys/class/dmi"
unset FAKE_VIRT

blue "==> install"
FAKE_SERVICE=disabled tsv
check "a disabled service fails" row fail install service-ly
check "...saying the login screen will not start" grep -q "login screen will not start" <<<"$(detail service-ly)"
tsv
check "every D4 group: ok" row ok install group-network
FAKE_DB_GROUPS="probe wheel bluetooth kvm video" tsv
check "not in network: warns, naming the fix" grep -q -- '--only-services' <<<"$(detail group-network)"
FAKE_DB_GROUPS="probe wheel network bluetooth kvm video" FAKE_SESSION_GROUPS="probe wheel" tsv
check "added but not logged in again: says so" grep -q 'log out and back in' <<<"$(detail group-kvm)"
FAKE_NOGROUP=bluetooth tsv
check "bluez not installed: the bluetooth group skips" row skip install group-bluetooth
FAKE_NOID=1 tsv
check "id -un fails: one skip" row skip install groups
check "...and no false warning per group" no_row '[a-z]+' install group-network
mv "$H/.local/state/dots/manifest" "$SB/manifest.bak"
tsv
check "no manifest fails" row fail install manifest
mv "$SB/manifest.bak" "$H/.local/state/dots/manifest"

blue "==> session"
FAKE_DOWN=sxhkd tsv
check "a daemon in autostart.sh that is not running warns" row warn session daemon-sxhkd
check "...and says it exited" grep -q 'not running' <(detail daemon-sxhkd)
cp "$H/.local/share/dwm/autostart.sh" "$SB/autostart.bak"
grep -v '^sxhkd ' "$SB/autostart.bak" >"$H/.local/share/dwm/autostart.sh"
FAKE_DOWN=sxhkd tsv
check "a daemon autostart.sh never starts says so" grep -q 'does not mention' <(detail daemon-sxhkd)
grep -v 'xdg-user-dirs-update' "$SB/autostart.bak" >"$H/.local/share/dwm/autostart.sh"
tsv
check "a one-shot autostart.sh never runs warns, not 'runs once'" \
    grep -q 'never runs: .* does not mention' <(detail daemon-xdg-user-dirs-update)
cp "$SB/autostart.bak" "$H/.local/share/dwm/autostart.sh"
FAKE_DOWN=xss-lock tsv
check "dwm-lock without xss-lock warns" row warn session daemon-dwm-lock
FAKE_DOWN=spice-vdagent FAKE_VIRT=none tsv
check "spice-vdagent off a VM is skipped" row skip session daemon-spice-vdagent
FAKE_DOWN=nm-applet tsv
check "nm-applet without NetworkManager is skipped" row skip session daemon-nm-applet
# shellcheck disable=SC2016 # $1 is the inner bash's argument
check "...naming that reason, and only that one" bash -c '[[ "$1" == *"(NetworkManager is not running)" ]]' _ "$(detail daemon-nm-applet)"
FAKE_UP=NetworkManager FAKE_DOWN=nm-applet tsv
check "nm-applet down while NetworkManager runs warns" row warn session daemon-nm-applet
# A dwm whose binary an install replaced: /proc/<pid>/exe reads "... (deleted)".
mkdir -p "$SB/proc/4242" "$SB/inst"
echo dwm >"$SB/proc/4242/comm"
echo new >"$SB/inst/dwm" && echo old >"$SB/inst/dwm (deleted)"
ln -s "$SB/inst/dwm (deleted)" "$SB/proc/4242/exe"
tsv
check "dwm on a replaced, different build warns" row warn session build-dwm
check "...naming the in-place restart" grep -q 'pkill -HUP -x dwm' <(detail build-dwm)
echo new >"$SB/inst/dwm (deleted)"
tsv
check "an identical rebuild is not stale" row ok session builds
rm -rf "$SB/proc/4242"
DISPLAY_SET="" tsv
check "no X: one skip for the whole session section" \
    test "$(grep -c $'\tsession\t' "$SB/out.tsv")" -eq 1
check "no X: still exit 0" rc_is 0

# shellcheck source=lib/doctor-cases-desktop.sh
source "$SCRIPT_DIR/lib/doctor-cases-desktop.sh"

blue "==> read-only"
find "$H" -printf '%p %s %l\n' | sort >"$SB/after"
check "the sandbox HOME is unchanged" cmp -s "$SB/before" "$SB/after"

blue "==> arguments"
check "--help exits 0" run_doctor --help
if run_doctor --bogus >/dev/null 2>&1; then bad "an unknown argument exits 1"; else ok "an unknown argument exits 1"; fi

echo
if [[ $FAIL -eq 0 ]]; then
    green "doctor: $PASS passed"
else
    red "doctor: $FAIL failed, $PASS passed"
    exit 1
fi
