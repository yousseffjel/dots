#!/usr/bin/env bash
# Sandbox for tests/doctor.sh and tests/doctor-keyring.sh — SOURCED, never
# run on its own (tests/lib/ is outside run-tests.sh's depth-1 glob). Builds
# a HOME that looks like a healthy install and a sealed PATH of fakes whose
# answers are steered by FAKE_* variables. Reads the caller's SB and DOTS_DIR.

# shellcheck source=sealed-path.sh
source "$(dirname "${BASH_SOURCE[0]}")/sealed-path.sh"
# shellcheck source=fake-flatpak.sh
source "$(dirname "${BASH_SOURCE[0]}")/fake-flatpak.sh"

# The daemon names, read the way doctor-daemons.sh reads them: from the
# installer's report against a file that mentions nothing.
daemon_names() {
    (
        # shellcheck disable=SC2317,SC2329 # called from the sourced report
        green() { :; }
        # shellcheck disable=SC2317,SC2329
        yellow() { printf '%s\n' "$*"; }
        # shellcheck source=../../scripts/install-session-report.sh
        source "$DOTS_DIR/scripts/install-session-report.sh"
        session_autostart_report /dev/null
    ) | sed -n 's/.*does not mention \([A-Za-z0-9._-]*\).*/\1/p'
}

make_fakes() {
    BIN="$SB/bin"
    seal_path "$BIN" bash sed grep awk tr cut cat head readlink dirname basename \
        ls sort date mkdir touch mktemp mv cp cmp
    # shellcheck disable=SC2016 # the bodies expand when the fakes run
    {
        # `xbps-query <name>` (check_packages and the drivers checks): exit 0 when
        # installed, 2 when not, as the real one does (xbps 0.60.7, probed).
        fake "$BIN" xbps-query 'case " ${FAKE_MISSING:-} " in *" $1 "*) exit 2 ;; esac; echo "$1-1.0_1"'
        fake "$BIN" pgrep 'case "$1" in
-x) [[ ( "$2" == dwm && -z "${FAKE_NO_DWM:-}" ) || " ${FAKE_UP:-} " == *" $2 "* ]] ;;
-a) echo "42 picom ${FAKE_PICOM_ARGS:---backend xrender}" ;;
-f) for d in ${FAKE_DOWN:-}; do [[ "$2" == *"/)$d( "* ]] && exit 1; done; exit 0 ;;
*) exit 1 ;;
esac'
        fake "$BIN" xrdb 'echo "dwm.normbgcolor:	#1e1e2e"
[[ -z "${FAKE_XCURSOR:-}" ]] || echo "Xcursor.theme:	$FAKE_XCURSOR"'
        fake "$BIN" pamixer 'echo 40'
        fake "$BIN" nmcli 'echo connected'
        # ReadOne returns one variant: gdbus prints "(<uint32 1>,)". The error
        # text is what the Fedora VM printed when the portal could not start.
        # --dest org.freedesktop.secrets is the keyring (FAKE_KEYRING, texts
        # from gnome-keyring 51.1; tests/doctor-keyring.sh cross-checks them).
        fake "$BIN" gdbus '[[ " $* " == *" org.freedesktop.secrets "* ]] && case "${FAKE_KEYRING:-unlocked}" in
unlocked) echo "(<false>,)"; exit 0 ;;
locked) echo "(<true>,)"; exit 0 ;;
empty) echo "Error: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/freedesktop/secrets/collection/login”" >&2; exit 1 ;;
*) echo "Error: GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name org.freedesktop.secrets was not provided by any .service files" >&2; exit 1 ;;
esac
case "${FAKE_PORTAL:-dark}" in
dark) echo "(<uint32 1>,)" ;;
light) echo "(<uint32 0>,)" ;;
*) echo "Error: GDBus.Error:org.freedesktop.DBus.Error.NameHasNoOwner: Could not activate remote peer '"'"'org.freedesktop.portal.Desktop'"'"': startup job failed" >&2; exit 1 ;;
esac'
        # passwd for the login-shell check; group for the D4 group check
        # (FAKE_NOGROUP: groups that do not exist).
        fake "$BIN" getent 'case "$1" in
group) [[ " ${FAKE_NOGROUP:-} " == *" $2 "* ]] && exit 2; echo "$2:x:1:probe" ;;
*) echo "probe:x:1000:1000::/home/probe:/usr/bin/zsh" ;;
esac'
        # id: the group database (-nG <user>) and this session's groups (-nG)
        # differ when a group was added after login (FAKE_DB_GROUPS /
        # FAKE_SESSION_GROUPS).
        fake "$BIN" id 'all="probe wheel network bluetooth kvm"
case "$*" in
-un) [[ -n "${FAKE_NOID:-}" ]] || echo probe ;;
-u) echo 1000 ;;
"-nG probe") echo "${FAKE_DB_GROUPS:-$all}" ;;
-nG) echo "${FAKE_SESSION_GROUPS:-${FAKE_DB_GROUPS:-$all}}" ;;
esac'
        fake "$BIN" dconf "echo \"'prefer-dark'\""
        # is-paused: false / true (do not disturb), or "dead" = no answer.
        fake "$BIN" dunstctl 'case "${FAKE_DUNST:-false}" in dead) exit 1 ;; *) echo "${FAKE_DUNST:-false}" ;; esac'
    }
    fake_flatpak "$BIN/flatpak" "$SB/fp"
    local d
    for d in "${DAEMONS[@]}"; do
        [[ -e "$BIN/$d" ]] || fake "$BIN" "$d" 'exit 0'
    done
}

# A HOME the installer would leave behind, plus everything a login adds.
make_home() {
    H="$SB/home"
    mkdir -p "$H/.local/state/dots" "$H/.local/bin" "$H/.cache/dots/theme" \
        "$H/.local/share/dwm" "$H/.config" "$SB/bt/hci0" "$SB/sys/bus/pci/devices"
    printf 'vendor_id\t: GenuineIntel\n' >"$SB/cpuinfo"
    # Written by the installer's own manifest functions, never by hand: a
    # hand-written SERVICE row once had a field the real one lacks, and the
    # service check passed here while it could never run on a real install.
    (
        XDG_STATE_HOME="$H/.local/state"
        # shellcheck source=../../scripts/global_fn.sh
        source "$DOTS_DIR/scripts/global_fn.sh"
        manifest_set_meta version "$(tr -d '[:space:]' <"$DOTS_DIR/VERSION")"
        manifest_append_row SERVICE ly
    )
    # The Flatpak grants and remote, the GTK3 settings.ini, the Adwaita-dark
    # shim and the XDG default cursor theme — each written by the installer's own function.
    # shellcheck disable=SC2016 # the -c script expands in the sandbox shell
    env -i PATH="$BIN" HOME="$H" XDG_DATA_HOME="$H/.local/share" XDG_STATE_HOME="$H/.local/state" \
        XDG_CONFIG_HOME="$H/.config" DOTS_DIR="$DOTS_DIR" DRY_RUN=0 "$(type -P bash)" -c 'set -euo pipefail
        green() { :; }; yellow() { echo "$*" >&2; }; blue() { :; }
        source "$0/scripts/global_fn.sh"; source "$0/scripts/install-restore-flatpak.sh"
        source "$0/scripts/install-restore-theme.sh"; CONF_HOME="$XDG_CONFIG_HOME"
        restore_flatpak; theme_write_gtk_ini; restore_gtk3_shim; theme_write_cursor_default' "$DOTS_DIR" >/dev/null
    ln -s "$DOTS_DIR/scripts/dots" "$H/.local/bin/dots"
    local src dst
    while IFS=$'\t' read -r src dst; do
        ln -s "$src" "$dst"
    done < <(HOME="$H" bash "$DOTS_DIR/scripts/symlinks.sh" --list-links)
    : >"$H/.cache/dots/theme/xresources"
    printf '#!/bin/sh\n' >"$H/.fehbg" && chmod +x "$H/.fehbg"
    printf '# Generated by scripts/theme/apply-templates.sh — DO NOT EDIT.\n' >"$H/.gtkrc-2.0"
    printf '%s &\n' "${DAEMONS[@]}" >"$H/.local/share/dwm/autostart.sh"
    printf 'NAME="Void"\nID="void"\n' >"$SB/os-release"
}

# run_doctor [args...] — FAKE_* and DISPLAY pass through from the caller.
# The drivers section reads $SB/sys and $SB/cpuinfo, never the host's: an
# empty PCI tree and a VM, so it only reports the host-firmware skip.
run_doctor() {
    # The runit service dir: ly and power-profiles-daemon linked unless
    # FAKE_SERVICE=disabled.
    rm -rf "$SB/service" && mkdir -p "$SB/sv/ly" "$SB/sv/power-profiles-daemon" "$SB/service"
    if [[ "${FAKE_SERVICE:-enabled}" != disabled ]]; then
        ln -s "$SB/sv/ly" "$SB/service/ly"
        ln -s "$SB/sv/power-profiles-daemon" "$SB/service/power-profiles-daemon"
    fi
    # A session bus address unless FAKE_NOBUS; empty reads as "no bus".
    local bus="unix:path=$SB/bus"
    [[ -z "${FAKE_NOBUS:-}" ]] || bus=""
    # DOTS_PROC: running-build.sh scans $SB/proc, never the host's processes
    # (empty unless a case puts a fake one there).
    # XDG_DATA_DIRS is the system half of check_gtk3_theme's lookup. Unset
    # (env -i), it defaults to /usr/share, so a host with gnome-themes-extra
    # made "an Adwaita-dark nothing provides" find one and pass as ok.
    mkdir -p "$SB/share" "$SB/proc"
    env -i PATH="$BIN" HOME="$H" USER=probe DISPLAY="${DISPLAY_SET-:9}" \
        XDG_CONFIG_HOME="$H/.config" XDG_CACHE_HOME="$H/.cache" \
        XDG_STATE_HOME="$H/.local/state" XDG_DATA_HOME="$H/.local/share" \
        XDG_DATA_DIRS="$SB/share" \
        DBUS_SESSION_BUS_ADDRESS="$bus" \
        DOTS_DOCTOR_RELEASE="${RELEASE-$SB/os-release}" DOTS_DOCTOR_BT_SYSFS="$SB/bt" DOTS_RUNIT_SERVICE="$SB/service" \
        DOTS_SYSFS="$SB/sys" DOTS_CPUINFO="$SB/cpuinfo" DOTS_VIRT="${FAKE_VIRT:-kvm}" \
        DOTS_XORG_CONF_DIR="$SB/xorg.conf.d" DOTS_PROC="$SB/proc" FAKE_PICOM_ARGS="${FAKE_PICOM_ARGS:-}" \
        FAKE_MISSING="${FAKE_MISSING:-}" FAKE_DOWN="${FAKE_DOWN:-}" \
        FAKE_NO_DWM="${FAKE_NO_DWM:-}" FAKE_SERVICE="${FAKE_SERVICE:-}" \
        FAKE_NOGROUP="${FAKE_NOGROUP:-}" FAKE_DB_GROUPS="${FAKE_DB_GROUPS:-}" FAKE_SESSION_GROUPS="${FAKE_SESSION_GROUPS:-}" FAKE_NOID="${FAKE_NOID:-}" \
        FAKE_PORTAL="${FAKE_PORTAL:-}" FAKE_KEYRING="${FAKE_KEYRING:-}" FAKE_XCURSOR="${FAKE_XCURSOR:-}" FAKE_DUNST="${FAKE_DUNST:-}" FAKE_UP="${FAKE_UP:-}" \
        "$(type -P bash)" "$DOTS_DIR/scripts/doctor.sh" "$@"
}
