#!/usr/bin/env bash
# Runs scripts/install-services.sh end to end on a sealed PATH, with the
# runit dirs, ly's install root and ly's config all in a sandbox, to assert
# the one ordering rule nothing else covers: tty2's getty is handed to ly
# ONLY when a ly binary is really there. A failed or skipped build must leave
# tty2's login prompt alone, or the box boots with no login on tty2.
#
# What is asserted:
#   * ly not built (here: the arch probe fails, so the build is skipped):
#     agetty-tty2 stays linked, its down file is not created, ly not linked;
#   * a ly binary present (someone else's, so no build runs): the getty is
#     unlinked with a down file, then ly is linked;
#   * a ly binary with no /etc/sv/ly (a foreign ly): tty2 keeps its getty;
#   * ly's service cannot be linked: the getty is put straight back;
#   * the desktop services are enabled in every case.

# The predicates are only called through check's "$@". See tests/pkg-repos.sh.
# SC2016: the eval'd checks are single-quoted on purpose, so they expand when
# check runs them.
# shellcheck disable=SC2317,SC2329,SC2016

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
seal_path "$SB/real" bash dirname tr cut grep date mkdir touch mktemp awk mv cat ln rm \
    sed sort readlink basename id head tail wc

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}
linked() { [[ -L "$SB/$1/service/$2" ]]; }

# run_stage <name> — a fresh sandbox: getty on tty2 linked, the desktop
# services and ly installed (in /etc/sv) but not enabled.
run_stage() {
    local d="$SB/$1" s
    mkdir -p "$d/fake" "$d/home" "$d/state" "$d/sv" "$d/service" "$d/root"
    for s in dbus elogind NetworkManager bluetoothd agetty-tty2 ly; do mkdir -p "$d/sv/$s"; done
    [[ -z "${NO_LY_SV:-}" ]] || rm -rf "$d/sv/ly"
    ln -s "$d/sv/agetty-tty2" "$d/service/"
    # LN_FAIL=<name>: an `ln -s` of that service fails, as a full disk or a
    # read-only /var/service would make it.
    fake "$d/fake" sudo "[[ \"\$1 \${@: -2:1}\" == \"ln $d/sv/${LN_FAIL:-none}\" ]] && exit 1; exec \"\$@\""
    fake "$d/fake" usermod ':'
    fake "$d/fake" getent "echo \"\$2:x:1000:1000::/home/\$2:/bin/zsh\""
    # No xbps-uhelper: the arch probe reads empty, so ly_install skips.
    env -i HOME="$d/home" USER=tuser XDG_STATE_HOME="$d/state" \
        XDG_CONFIG_HOME="$d/home/.config" XDG_CACHE_HOME="$d/home/.cache" \
        XDG_DATA_HOME="$d/home/.local/share" DOTS_RUNIT_SV="$d/sv" \
        DOTS_RUNIT_SERVICE="$d/service" DOTS_LY_ROOT="$d/root" DOTS_VIRT=none \
        DOTS_LY_CONFIG="$d/root/etc/ly/config.ini" PATH="$d/fake:$SB/real" \
        "$(type -P bash)" "$DOTS_DIR/scripts/install-services.sh" >"$d/out" 2>&1 \
        || { red "install-services.sh exited non-zero in $1:" && cat "$d/out" && FAILS=$((FAILS + 1)); }
}

blue "==> ly not built"
run_stage nobuild
check "tty2's getty still linked" linked nobuild agetty-tty2
check "...no down file" test ! -e "$SB/nobuild/sv/agetty-tty2/down"
check "ly not linked" eval '! linked nobuild ly'
check "the desktop services are enabled anyway" eval 'linked nobuild dbus && linked nobuild NetworkManager'

blue "==> a ly binary is there"
mkdir -p "$SB/present/root/usr/bin"
printf '#!/bin/sh\n' >"$SB/present/root/usr/bin/ly"
chmod 755 "$SB/present/root/usr/bin/ly"
run_stage present
check "the getty is unlinked, with a down file" eval '! linked present agetty-tty2 && [[ -e $SB/present/sv/agetty-tty2/down ]]'
check "ly linked" linked present ly
check "...a SERVICE row for it" grep -qx $'SERVICE\tly' "$SB/present/state/dots/manifest"

blue "==> a ly binary with no runit service (a foreign ly)"
mkdir -p "$SB/nosv/root/usr/bin" "$SB/nosv/sv"
printf '#!/bin/sh\n' >"$SB/nosv/root/usr/bin/ly"
chmod 755 "$SB/nosv/root/usr/bin/ly"
NO_LY_SV=1 run_stage nosv
check "tty2's getty still linked" linked nosv agetty-tty2
check "...no down file" test ! -e "$SB/nosv/sv/agetty-tty2/down"
check "...and it says why" grep -q "no runit service at" "$SB/nosv/out"

blue "==> ly cannot be linked"
mkdir -p "$SB/lnfail/root/usr/bin"
printf '#!/bin/sh\n' >"$SB/lnfail/root/usr/bin/ly"
chmod 755 "$SB/lnfail/root/usr/bin/ly"
LN_FAIL=ly run_stage lnfail
check "the getty is put back" linked lnfail agetty-tty2
check "...without a down file dots made" test ! -e "$SB/lnfail/sv/agetty-tty2/down"
check "...saying so" grep -q "tty2's getty is back" "$SB/lnfail/out"

if [[ $FAILS -eq 0 ]]; then
    green "✓ services stage: tty2 is handed to ly only when ly is there"
else
    red "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
