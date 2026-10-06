#!/usr/bin/env bash
# The GTK3 Adwaita-dark shim: restore_gtk3_shim (install-restore-gtk3-shim.sh)
# deploys assets/themes/Adwaita-dark, uninstall_theme removes it. Checked:
#   * fresh HOME: deployed byte for byte, one THEME row; a re-run adds nothing;
#   * an Adwaita-dark the user already has is left alone and never claimed;
#   * --dry-run writes nothing; a missing asset warns instead of failing;
#   * a copy that fails partway is cleared, not left unclaimed;
#   * uninstall removes our copy and leaves the user's own;
#   * every themes/*/theme.conf gtk_theme is a GTK3 built-in or a shim under
#     assets/themes — read by the shipped theme_conf_get, so a rename that
#     brings back the light fallback fails here instead of on someone's desktop;
#   * FLATPAK_GRANTS still exposes xdg-data/themes, or sandboxed GTK3 is light;
#   * the stylesheet the shim @imports is still compiled into libgtk-3, where
#     `gresource` (or failing that, libgtk-3 itself) is available to ask.
# See assets/themes/README.md for why the shim exists.
#
# SEALED PATH (tests/lib/sealed-path.sh): only the tools the shipped functions
# need, and a sandbox HOME with all four XDG variables.

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
seal_path "$BIN" awk cut grep mkdir touch cat mv rm cp sed dirname

ASSET="$DOTS_DIR/assets/themes/Adwaita-dark"
# <case> <commands...>: the shipped functions in a sandbox; HOME is $SB/<case>.
run() {
    local name="$1"
    shift
    mkdir -p "$SB/$name"
    # shellcheck disable=SC2016 # the -c script expands in the sandbox shell
    env -i PATH="$BIN" HOME="$SB/$name" XDG_DATA_HOME="$SB/$name/.local/share" \
        XDG_CONFIG_HOME="$SB/$name/.config" XDG_CACHE_HOME="$SB/$name/.cache" \
        XDG_STATE_HOME="$SB/$name/.local/state" DRY_RUN="${DRY_RUN:-0}" \
        "$(type -P bash)" -c '
        set -euo pipefail
        ASSUME_YES=1
        source "$0/scripts/global_fn.sh"
        source "$0/scripts/install-restore-gtk3-shim.sh"
        source "$0/scripts/uninstall-theme.sh"
        '"$*" "$DOTS_DIR" >"$SB/$name.out" 2>&1 || echo "EXIT $?" >>"$SB/$name.out"
}
dst() { printf '%s\n' "$SB/$1/.local/share/themes/Adwaita-dark"; }
rows() {
    local m="$SB/$1/.local/state/dots/manifest"
    if [[ -f "$m" ]]; then grep -c "^THEME	theme	$(dst "$1")\$" "$m" || true; else echo 0; fi
}

blue "==> deploy"
run fresh "restore_gtk3_shim; restore_gtk3_shim"
if diff -r "$ASSET" "$(dst fresh)" >/dev/null && [[ "$(rows fresh)" == 1 ]] && grep -q 'already deployed by us' "$SB/fresh.out"; then
    ok "fresh HOME: deployed byte for byte, one THEME row, a re-run is a no-op"
else
    bad "fresh: $(cat "$SB/fresh.out")"
fi
mkdir -p "$(dst theirs)/gtk-3.0"
printf '/* the user own Adwaita-dark */\n' >"$(dst theirs)/gtk-3.0/gtk.css"
run theirs "restore_gtk3_shim; uninstall_theme"
if grep -q 'the user own' "$(dst theirs)/gtk-3.0/gtk.css" && [[ "$(rows theirs)" == 0 ]] && grep -q 'left untouched' "$SB/theirs.out"; then
    ok "an Adwaita-dark the user has is left alone, never claimed, survives uninstall"
else
    bad "user's theme: $(cat "$SB/theirs.out")"
fi
DRY_RUN=1 run dry restore_gtk3_shim
if [[ ! -e "$(dst dry)" && "$(rows dry)" == 0 ]]; then
    ok "--dry-run writes nothing"
else
    bad "--dry-run deployed it"
fi
run noasset "GTK3_SHIM_SRC=\"\$HOME/nowhere\"; restore_gtk3_shim"
if [[ ! -e "$(dst noasset)" ]] && grep -q 'GTK3 apps stay light' "$SB/noasset.out" && ! grep -q EXIT "$SB/noasset.out"; then
    ok "a missing asset warns and carries on"
else
    bad "missing asset: $(cat "$SB/noasset.out")"
fi

# cp fails partway (a full disk): the partial copy must not be left behind
# unclaimed, where it would read as "the user's" forever after.
mkdir -p "$SB/cpfail-bin"
cp -a "$BIN/." "$SB/cpfail-bin/"
# shellcheck disable=SC2016 # expands when the fake runs
fake "$SB/cpfail-bin" cp 'mkdir -p "${*: -1}"; exit 1'
BIN_SAVED="$BIN" BIN="$SB/cpfail-bin"
run cpfail restore_gtk3_shim
BIN="$BIN_SAVED"
if [[ ! -e "$(dst cpfail)" && "$(rows cpfail)" == 0 ]] && grep -q 'failed to copy' "$SB/cpfail.out"; then
    ok "a failed copy leaves nothing behind and claims nothing"
else
    bad "failed copy: $(find "$SB/cpfail" | head -5) / $(cat "$SB/cpfail.out")"
fi

blue "==> uninstall"
run undo "restore_gtk3_shim; [[ -d $(dst undo) ]] && echo WROTE; uninstall_theme"
if grep -qx WROTE "$SB/undo.out" && [[ ! -e "$(dst undo)" ]]; then
    ok "uninstall removes the copy it deployed"
else
    bad "uninstall: $(cat "$SB/undo.out")"
fi

blue "==> every theme.conf names a GTK3 theme that resolves"
for conf in "$DOTS_DIR"/themes/*/theme.conf; do
    rel="${conf#"$DOTS_DIR"/}"
    # shellcheck disable=SC2016 # expands in the child shell
    name="$(THEME_CONF_REL="$rel" bash -c 'red() { :; }; green() { :; }; yellow() { :; }; blue() { :; }
        DOTS_DIR="$1"; source "$1/scripts/install-restore-theme-identity.sh"; theme_conf_get gtk_theme' _ "$DOTS_DIR")"
    case "$name" in
        Adwaita | HighContrast | HighContrastInverse) ok "$rel: $name is built into GTK3" ;;
        *)
            if [[ -f "$DOTS_DIR/assets/themes/$name/gtk-3.0/gtk.css" ]]; then
                ok "$rel: $name is shipped under assets/themes"
            else
                bad "$rel: gtk_theme=$name is neither a GTK3 built-in nor under assets/themes — GTK3 would fall back to LIGHT Adwaita"
            fi
            ;;
    esac
done

blue "==> Flatpak GTK3 apps can see it"
# shellcheck disable=SC2016 # expands in the child shell
if bash -c 'source "$1/scripts/install-restore-flatpak.sh"; printf "%s\n" "${FLATPAK_GRANTS[@]}"' _ "$DOTS_DIR" | grep -qx 'xdg-data/themes:ro'; then
    ok "FLATPAK_GRANTS exposes xdg-data/themes read-only"
else
    bad "FLATPAK_GRANTS lacks xdg-data/themes:ro — sandboxed GTK3 falls back to light Adwaita"
fi

blue "==> the @import target is compiled into libgtk-3"
res="$(sed -n 's|.*resource://\([^")]*\).*|\1|p' "$ASSET/gtk-3.0/gtk.css")"
lib=""
for f in /usr/lib64/libgtk-3.so.0 /usr/lib/libgtk-3.so.0 /usr/lib/x86_64-linux-gnu/libgtk-3.so.0; do
    if [[ -e "$f" ]]; then
        lib="$f"
        break
    fi
done
if [[ -z "$res" ]]; then
    bad "no resource:// URL in the shim"
elif [[ -z "$lib" ]]; then
    yellow "  skip: no libgtk-3 on this host to look $res up in"
elif command -v gresource >/dev/null 2>&1; then
    if gresource list "$lib" | grep -qxF "$res"; then ok "gresource lists $res"; else bad "$res is not in $lib"; fi
elif grep -qaF "${res##*/}" "$lib"; then
    # Weaker: the name appears, not necessarily under this exact path. gresource
    # is in glib2-devel on Fedora and not installed everywhere.
    ok "${res##*/} appears in $lib (no gresource here to check the full path)"
else
    bad "${res##*/} does not appear in $lib"
fi

echo
if [[ $FAIL -eq 0 ]]; then
    green "gtk3-adwaita-dark-shim: $PASS passed"
else
    red "gtk3-adwaita-dark-shim: $FAIL failed, $PASS passed"
    exit 1
fi
