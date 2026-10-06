#!/usr/bin/env bash
# Deploys the GTK3 Adwaita-dark shim. Sourced by install-restore-theme.sh,
# never standalone: assumes the caller has `set -euo pipefail`, sourced
# global_fn.sh (manifest_has_path/manifest_append_row), set DRY_RUN, and
# defined the red/green/yellow/blue helpers.
#
# usage: source "$THEME_DIR/install-restore-gtk3-shim.sh"; restore_gtk3_shim
#
# themes/*/theme.conf name `Adwaita-dark`, which GTK 3.24 does not have built
# in: on Fedora 44, with gnome-themes-extra retired, GTK3 falls back to LIGHT
# Adwaita and discards prefer-dark with it. The shim is the one-line theme
# that package used to ship. See assets/themes/README.md for the source, the
# GTK code path and why the name was kept (GTK4 aliases it).
#
# Resolved from BASH_SOURCE, like install-restore-cursor.sh: this file is
# SOURCED, and a test may source it with no DOTS_DIR set at all.
GTK3_SHIM_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/assets/themes/Adwaita-dark"

# Same no-clobber rule as the cursor: a THEME row authorises uninstall to
# rm -rf the path, so a directory we did not create is never claimed. A real
# Adwaita-dark the user installed (or an older copy of their own) wins.
restore_gtk3_shim() {
    local themes_dir="${XDG_DATA_HOME:-$HOME/.local/share}/themes"
    local dst="$themes_dir/Adwaita-dark"

    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        blue "  (dry-run) would deploy the GTK3 Adwaita-dark shim -> $dst"
        return 0
    fi
    if [[ -e "$dst" ]]; then
        if manifest_has_path THEME "$dst"; then
            green "ok      Adwaita-dark (GTK3 shim) already deployed by us"
        else
            green "ok      $dst exists (left untouched, not tracked for removal)"
        fi
        return 0
    fi
    if [[ ! -f "$GTK3_SHIM_SRC/gtk-3.0/gtk.css" ]]; then
        yellow "warn    $GTK3_SHIM_SRC/gtk-3.0/gtk.css missing — GTK3 apps stay light"
        return 0
    fi
    mkdir -p "$themes_dir"
    if cp -r "$GTK3_SHIM_SRC" "$dst"; then
        manifest_append_row THEME theme "$dst"
        green "wrote   $dst (GTK3 dark Adwaita)"
    else
        # A half-written copy would be unclaimed, so every later run would
        # call it "the user's" and uninstall would never remove it. It did not
        # exist a moment ago (checked above), so it is ours to clear.
        rm -rf "$dst"
        red "failed to copy the GTK3 Adwaita-dark shim to $dst"
    fi
}
