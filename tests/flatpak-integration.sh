#!/usr/bin/env bash
# Flatpak integration: restore_flatpak (install-restore-flatpak.sh) and
# uninstall_flatpak (uninstall-flatpak.sh), run for real against a fake
# flatpak. The install -> uninstall round trip of a whole HOME is in
# tests/install-uninstall-symmetry.sh; this covers the branches it cannot:
#   * no flatpak, no network, a remote or grant the user already has;
#   * a re-run writes nothing twice;
#   * uninstall drops only entries still as written, keeps a remote that
#     installed refs come from, and gives a user's own groups back byte for byte;
#   * --dry-run changes nothing, either way.
# When a REAL flatpak is installed, the same round trip also runs against it,
# in a sandboxed HOME with a local remote URL (no network) — that is what keeps
# the fake's keyfile format honest.
#
# SEALED PATH (tests/lib/sealed-path.sh) for the fake cases: the dev host may
# have a real flatpak, and a real `flatpak override --user` would change every
# sandboxed app of whoever runs this test.

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

BIN="$SB/bin"
seal_path "$BIN" awk cut grep mkdir touch cat mv rm cp chmod dirname
# shellcheck source=lib/fake-flatpak.sh
source "$SCRIPT_DIR/lib/fake-flatpak.sh"
fake_flatpak "$BIN/flatpak" "$SB/fp"

# <case> <mode> <commands...>: one sandboxed shell with the shipped functions
# sourced. mode: fake | noflatpak | offline. The case's HOME is $SB/<case>;
# seed files there first with seed(). Output goes to $SB/<case>.out.
run() {
    local name="$1" mode="$2"
    shift 2
    mkdir -p "$SB/$name/bin" "$SB/fp"
    cp -a "$BIN/." "$SB/$name/bin/"
    [[ $mode != noflatpak ]] || rm -f "$SB/$name/bin/flatpak"
    # shellcheck disable=SC2016 # the -c script expands in the sandbox shell
    env -i SB="$SB" PATH="$SB/$name/bin" HOME="$SB/$name" \
        XDG_DATA_HOME="$SB/$name/.local/share" XDG_STATE_HOME="$SB/$name/.local/state" \
        FAKE_OFFLINE="$([[ $mode == offline ]] && echo 1)" DRY_RUN="${DRY_RUN:-0}" \
        "$(type -P bash)" -c '
        set -euo pipefail
        ASSUME_YES=1
        source "$0/scripts/global_fn.sh"
        source "$0/scripts/install-restore-flatpak.sh"
        source "$0/scripts/uninstall-flatpak.sh"
        '"$*" "$DOTS_DIR" >"$SB/$name.out" 2>&1 || echo "EXIT $?" >>"$SB/$name.out"
}
gfile() { printf '%s\n' "$SB/$1/.local/share/flatpak/overrides/global"; }
# A seeded override file, written as flatpak 1.18 writes one.
seed() {
    mkdir -p "$(dirname "$(gfile "$1")")"
    printf '%b' "$2" >"$(gfile "$1")"
    cp "$(gfile "$1")" "$SB/$1.before"
}
rows() {
    local m="$SB/$1/.local/state/dots/manifest"
    if [[ -f "$m" ]]; then grep -c "^FLATPAK	$2" "$m" || true; else echo 0; fi
}
entries() { sed -n 's/^filesystems=//p' "$(gfile "$1")" 2>/dev/null | tr ';' '\n' | sed '/^$/d' | LC_ALL=C sort | tr '\n' ' '; }
remotes() { cat "$SB/fp/remotes" 2>/dev/null; }
reset_fp() {
    : >"$SB/fp/remotes"
    : >"$SB/fp/origins"
    : >"$SB/fp/calls"
}
mkdir -p "$SB/fp"

# The grant list is the installer's own FLATPAK_GRANTS, read back rather than
# restated: a fourth grant once broke four hard-coded counts here. The file
# only assigns at the top level, so sourcing it alone is safe.
# shellcheck disable=SC2016 # expands in the child shell
mapfile -t GRANTS < <(bash -c 'source "$1/scripts/install-restore-flatpak.sh"; printf "%s\n" "${FLATPAK_GRANTS[@]}"' _ "$DOTS_DIR")
N=${#GRANTS[@]}
sorted() { LC_ALL=C sort | tr '\n' ' '; }
ALL="$(printf '%s\n' "${GRANTS[@]}" | sorted)"
# shellcheck disable=SC2088 # literal entries: "~" is flatpak's syntax for HOME
ICONS_RW='~/.local/share/icons' ICONS_RO='~/.local/share/icons:ro'
# Between install and uninstall: proves the install wrote, so a round trip that
# "restores" a file nothing ever touched cannot pass.
WROTE='restore_flatpak; flatpak_grant_for xdg-config/gtk-3.0:ro >/dev/null && echo WROTE'
wrote() { grep -qx WROTE "$SB/$1.out"; }

blue "==> install"
reset_fp
run fresh fake restore_flatpak
if [[ "$(entries fresh)" == "$ALL" && "$(rows fresh override)" == "$N" && "$(remotes)" == flathub ]] \
    && grep -qF "remote	flathub	https://dl.flathub.org/repo/flathub.flatpakrepo" "$SB/fresh/.local/state/dots/manifest"; then
    ok "fresh HOME: all $N read-only grants, Flathub added, $((N + 1)) rows"
else
    bad "fresh: $(entries fresh) / $(rows fresh override) / $(remotes) / $(cat "$SB/fresh.out")"
fi
reset_fp
run rerun fake "restore_flatpak; restore_flatpak"
if [[ "$(grep -c '^flatpak override' "$SB/fp/calls")" == "$N" && "$(grep -c '^flatpak remote-add' "$SB/fp/calls")" == 1 && "$(rows rerun "")" == $((N + 1)) ]]; then
    ok "a re-run writes nothing more"
else
    bad "re-run: $(cat "$SB/fp/calls")"
fi
reset_fp
seed theirs '[Context]\nfilesystems=!home;~/.local/share/icons;\n'
echo flathub >"$SB/fp/remotes"
run theirs fake restore_flatpak
want="$(printf '%s\n' '!home' "$ICONS_RW" "${GRANTS[@]}" | grep -vxF "$ICONS_RO" | sorted)"
if [[ "$(rows theirs override)" == $((N - 1)) && "$(rows theirs remote)" == 0 ]] \
    && grep -qF "$ICONS_RW already set" "$SB/theirs.out" && [[ "$(entries theirs)" == "$want" ]]; then
    ok "the user's own grant (another mode) and remote are left alone, with no row"
else
    bad "user's settings: $(entries theirs) / $(cat "$SB/theirs.out")"
fi
reset_fp
seed negated '[Context]\nfilesystems=!xdg-config/gtk-3.0;\n'
run negated fake restore_flatpak
if [[ "$(rows negated override)" == $((N - 1)) ]] && grep -qF '!xdg-config/gtk-3.0;' "$(gfile negated)"; then
    ok "a path the user negated stays negated"
else
    bad "negation: $(entries negated)"
fi
reset_fp
# An env var that happens to be called "filesystems" is not a grant.
seed envvar '[Environment]\nfilesystems=xdg-config/gtk-3.0:ro;\n'
run envvar fake "restore_flatpak; uninstall_flatpak"
if [[ "$(grep -c 'set     flatpak override' "$SB/envvar.out")" == "$N" ]] && cmp -s "$SB/envvar.before" "$(gfile envvar)"; then
    ok "only [Context] holds grants: a look-alike key elsewhere is neither read nor edited"
else
    bad "look-alike key: $(cat -A "$(gfile envvar)") / $(cat "$SB/envvar.out")"
fi
reset_fp
run nofp noflatpak restore_flatpak
if [[ "$(rows nofp "")" == 0 ]] && grep -q 'flatpak not found' "$SB/nofp.out" && ! grep -q EXIT "$SB/nofp.out"; then
    ok "no flatpak: skipped with a note"
else
    bad "no flatpak: $(cat "$SB/nofp.out")"
fi
reset_fp
run offline offline restore_flatpak
if [[ "$(rows offline remote)" == 0 && "$(rows offline override)" == "$N" ]] && grep -q 'Re-run .*--only-restore' "$SB/offline.out"; then
    ok "offline: no remote and no row, a re-run hint, grants still set"
else
    bad "offline: $(cat "$SB/offline.out")"
fi
reset_fp
DRY_RUN=1 run dry fake restore_flatpak
if [[ ! -e "$(gfile dry)" && -z "$(remotes)" && ! -s "$SB/fp/calls" ]]; then
    ok "--dry-run writes nothing"
else
    bad "--dry-run: $(cat "$SB/fp/calls")"
fi

blue "==> uninstall"
reset_fp
run undo fake "$WROTE; uninstall_flatpak"
if wrote undo && [[ ! -e "$(gfile undo)" && -z "$(remotes)" ]]; then
    ok "fresh round trip: override file and remote both gone"
else
    bad "round trip: $(entries undo) / $(remotes) / $(cat "$SB/undo.out")"
fi
for g in '[Environment]\nFOO=bar\n' '[Context]\nfilesystems=!home;\n\n[Environment]\nFOO=bar\n' '[Session Bus Policy]\norg.x.Y=talk\n'; do
    reset_fp
    seed groups "$g"
    run groups fake "$WROTE; uninstall_flatpak"
    if wrote groups && cmp -s "$SB/groups.before" "$(gfile groups)"; then
        ok "the user's own groups come back byte for byte: ${g%%\\n*}"
    else
        bad "groups ${g%%\\n*}: $(cat -A "$(gfile groups)")"
    fi
done
reset_fp
run changed fake "restore_flatpak; flatpak override --user --filesystem=xdg-config/gtk-3.0; uninstall_flatpak"
if [[ "$(entries changed)" == 'xdg-config/gtk-3.0 ' ]] && grep -q 'kept .*gtk-3.0:ro (changed' "$SB/changed.out"; then
    ok "a grant changed after the install is kept"
else
    bad "changed grant: $(entries changed) / $(cat "$SB/changed.out")"
fi
reset_fp
run inuse fake "restore_flatpak; echo flathub >\"\$SB/fp/origins\"; uninstall_flatpak"
if [[ "$(remotes)" == flathub ]] && grep -q 'kept .*1 installed ref' "$SB/inuse.out"; then
    ok "a remote installed refs still come from is kept"
else
    bad "in-use remote: $(remotes) / $(cat "$SB/inuse.out")"
fi
reset_fp
if [[ $EUID -ne 0 ]]; then
    run ro fake "restore_flatpak; chmod 555 \"\$(dirname \"\$(flatpak_override_file)\")\"; uninstall_flatpak; echo REACHED_END"
    chmod 755 "$(dirname "$(gfile ro)")"
    if grep -q 'could not edit' "$SB/ro.out" && grep -qx REACHED_END "$SB/ro.out" && [[ "$(entries ro)" == "$ALL" ]]; then
        ok "an override file it cannot edit is reported, and uninstall carries on"
    else
        bad "unwritable: $(cat "$SB/ro.out")"
    fi
else
    yellow "  skip: unwritable-directory case (root can write anywhere)"
fi
reset_fp
run undodry fake "restore_flatpak; DRY_RUN=1 uninstall_flatpak"
if [[ "$(entries undodry)" == "$ALL" && "$(remotes)" == flathub ]]; then
    ok "uninstall --dry-run reverts nothing"
else
    bad "dry-run uninstall: $(entries undodry) / $(remotes)"
fi

# shellcheck source=lib/flatpak-real.sh
source "$SCRIPT_DIR/lib/flatpak-real.sh"
real_flatpak_round_trip

echo
if [[ $FAIL -eq 0 ]]; then
    green "flatpak-integration: $PASS passed"
else
    red "flatpak-integration: $FAIL failed, $PASS passed"
    exit 1
fi
