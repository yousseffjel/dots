#!/usr/bin/env bash
# The dark colour-scheme preference: apps_dconf_prefs (install-restore-apps.sh)
# and uninstall_dconf (uninstall-apps.sh), run for real against a fake dconf
# whose database is a file. The round trip itself is in
# tests/install-uninstall-symmetry.sh; this covers the branches it cannot:
#   * a session bus (direct write) vs. none (dbus-run-session) vs. neither;
#   * no dconf at all;
#   * a key the user already set is never written, and a re-run never
#     writes twice;
#   * uninstall resets only a key that still holds what was written;
#   * --dry-run changes nothing;
#   * portals.conf is linked by symlinks.sh and names the gtk backend.
#
# SEALED PATH (tests/lib/sealed-path.sh): the dev host may have a real dconf
# and dbus-run-session, and a real `dconf write` would change the desktop of
# whoever runs this test.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

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

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

KEY=/org/gnome/desktop/interface/color-scheme
BIN="$SB/bin"
seal_path "$BIN" awk cut grep mkdir touch cat mv
# The store holds "key<TAB>value" lines. write/reset succeed only with a
# "session bus": FAKE_BUS=1 in the environment, which dbus-run-session sets.
# shellcheck disable=SC2016 # expands inside the fake
fake "$BIN" dconf 'store="$SB/store"; echo "dconf $*" >>"$SB/calls"
case "$1" in
read) awk -F"\t" -v k="$2" "\$1==k {print \$2}" "$store" ;;
write | reset)
    [[ -n "${FAKE_BUS:-}" ]] || exit 1
    awk -F"\t" -v k="$2" "\$1!=k" "$store" >"$store.new" && mv "$store.new" "$store"
    [[ "$1" == reset ]] || printf "%s\t%s\n" "$2" "$3" >>"$store" ;;
esac'
# shellcheck disable=SC2016 # expands inside the fake
fake "$BIN" dbus-run-session 'echo "dbus-run-session" >>"$SB/calls"; shift; FAKE_BUS=1 exec "$@"'

# <case> <setup> <commands...>: one sandboxed shell with the shipped functions
# sourced. setup runs first: bus | nobus | noroute | nodconf, plus an
# optional initial store value. Output goes to $SB/<case>.out.
run() {
    local name="$1" mode="$2" initial="$3"
    shift 3
    rm -f "$SB/store" "$SB/calls"
    : >"$SB/store"
    [[ -z "$initial" ]] || printf '%s\t%s\n' "$KEY" "$initial" >"$SB/store"
    mkdir -p "$SB/$name/bin"
    cp -a "$BIN/." "$SB/$name/bin/"
    case "$mode" in
        noroute) rm -f "$SB/$name/bin/dbus-run-session" ;;
        nodconf) rm -f "$SB/$name/bin/dconf" ;;
    esac
    # shellcheck disable=SC2016 # the -c script expands in the sandbox shell
    env -i SB="$SB" PATH="$SB/$name/bin" HOME="$SB/$name/home" \
        XDG_STATE_HOME="$SB/$name/state" FAKE_BUS="$([[ $mode == bus ]] && echo 1)" \
        DRY_RUN="${DRY_RUN:-0}" \
        "$(type -P bash)" -c '
        set -euo pipefail
        ASSUME_YES=1
        source "$0/scripts/global_fn.sh"
        source "$0/scripts/install-restore-apps.sh"
        source "$0/scripts/uninstall-apps.sh"
        '"$*" "$DOTS_DIR" >"$SB/$name.out" 2>&1 || echo "EXIT $?" >>"$SB/$name.out"
}
value() { awk -F'\t' -v k="$KEY" '$1==k {print $2}' "$SB/store"; }
rows() {
    local m="$SB/$1/state/dots/manifest"
    if [[ -f "$m" ]]; then grep -c '^DCONF	' "$m" || true; else echo 0; fi
}

blue "==> install"
run bus bus "" apps_dconf_prefs
if [[ "$(value)" == "'prefer-dark'" && "$(rows bus)" == 1 ]] && ! grep -q dbus-run-session "$SB/calls"; then
    ok "session bus: written directly, one DCONF row"
else
    bad "session bus: $(value) / $(rows bus) / $(cat "$SB/bus.out")"
fi
run nobus nobus "" apps_dconf_prefs
if [[ "$(value)" == "'prefer-dark'" && "$(rows nobus)" == 1 ]] && grep -q dbus-run-session "$SB/calls"; then
    ok "no session bus: written through dbus-run-session"
else
    bad "no bus: $(value) / $(cat "$SB/nobus.out")"
fi
run noroute noroute "" apps_dconf_prefs
if [[ -z "$(value)" && "$(rows noroute)" == 0 ]] && grep -q 'Re-run .*--only-restore' "$SB/noroute.out"; then
    ok "neither route: nothing written, no row, re-run hint"
else
    bad "neither route: $(cat "$SB/noroute.out")"
fi
run nodconf nodconf "" apps_dconf_prefs
if [[ "$(rows nodconf)" == 0 ]] && grep -q 'dconf not found' "$SB/nodconf.out" && ! grep -q EXIT "$SB/nodconf.out"; then
    ok "no dconf: skipped with a note"
else
    bad "no dconf: $(cat "$SB/nodconf.out")"
fi
run theirs bus "'default'" apps_dconf_prefs
if [[ "$(value)" == "'default'" && "$(rows theirs)" == 0 ]]; then
    ok "a key the user set (even to 'default') is left alone"
else
    bad "user's key: $(value) / $(rows theirs)"
fi
run rerun bus "" "apps_dconf_prefs; apps_dconf_prefs"
if [[ "$(grep -c '^dconf write' "$SB/calls")" == 1 && "$(rows rerun)" == 1 ]]; then
    ok "a re-run writes nothing more"
else
    bad "re-run: $(grep -c '^dconf write' "$SB/calls") writes"
fi
DRY_RUN=1 run dry bus "" "apps_dconf_prefs"
if [[ -z "$(value)" ]]; then
    ok "--dry-run writes nothing"
else
    bad "--dry-run wrote $(value)"
fi

blue "==> uninstall"
run undo nobus "" "apps_dconf_prefs; uninstall_dconf"
if [[ -z "$(value)" ]] && grep -q "reset    $KEY" "$SB/undo.out"; then
    ok "an unchanged key is reset (no session bus needed)"
else
    bad "reset: $(value) / $(cat "$SB/undo.out")"
fi
run changed bus "" "apps_dconf_prefs; dconf write $KEY \"'prefer-light'\"; uninstall_dconf"
if [[ "$(value)" == "'prefer-light'" ]] && grep -q 'changed since install' "$SB/changed.out"; then
    ok "a key changed after the install is kept"
else
    bad "changed key: $(value) / $(cat "$SB/changed.out")"
fi
DRY_RUN=1 run undodry bus "" "DRY_RUN=0 apps_dconf_prefs; DRY_RUN=1 uninstall_dconf"
if [[ "$(value)" == "'prefer-dark'" ]]; then
    ok "uninstall --dry-run resets nothing"
else
    bad "dry-run uninstall: $(value)"
fi

blue "==> portals.conf"
conf="$DOTS_DIR/config/xdg-desktop-portal/portals.conf"
if grep -qx '\[preferred\]' "$conf" && grep -qx 'default=gtk' "$conf"; then
    ok "portals.conf prefers the gtk backend"
else
    bad "portals.conf does not say [preferred] default=gtk"
fi
# shellcheck disable=SC2016 # a literal line of symlinks.sh
if grep -qF '"$CONFIG_DIR/xdg-desktop-portal:$HOME/.config/xdg-desktop-portal"' "$DOTS_DIR/scripts/symlinks.sh"; then
    ok "symlinks.sh links config/xdg-desktop-portal"
else
    bad "symlinks.sh does not link it"
fi

echo
if [[ $FAIL -eq 0 ]]; then
    green "color-scheme: $PASS passed"
else
    red "color-scheme: $FAIL failed, $PASS passed"
    exit 1
fi
