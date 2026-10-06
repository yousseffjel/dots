#!/usr/bin/env bash
# Flatpak integration for the "restore" stage: the Flathub remote and four
# read-only global overrides. Sourced by install-restore.sh, never
# standalone: assumes `set -euo pipefail`, global_fn.sh (manifest_append_row,
# flatpak_grant_for), DRY_RUN and the red/green/yellow/blue helpers.
# doctor-session.sh sources it too, for FLATPAK_GRANTS alone — so nothing at
# the top level here may do more than assign.
#
# usage: source "$SCRIPT_DIR/install-restore-flatpak.sh"; restore_flatpak
#
# Everything here is --user: the restore stage runs as the user, and a user
# remote or override needs neither sudo nor the system helper.
#
# Same contract as apps_dconf_prefs (install-restore-apps.sh): a setting is
# written only when it is absent, a FLATPAK manifest row records exactly what
# was written, and uninstall-flatpak.sh reverts it only while it still holds
# that value. Anything already there is the user's and is never touched.
#
# What is deliberately NOT here:
#   * GTK_THEME — a GTK debugging variable; set globally it breaks the layout
#     of every GTK4/libadwaita Flatpak (gitlab.gnome.org/GNOME/gtk/-/issues/5661).
#     GTK3 apps already get the theme name from xsettingsd, over the X socket
#     they share with the host, and GTK4 apps get dark mode from the portal's
#     colour scheme (apps_dconf_prefs).
#   * fonts — Flatpak itself binds the host's system and user font directories
#     into every sandbox (/run/host/fonts, /run/host/user-fonts).

# Rule 4 exception, explicitly authorised by the user (2026-10-06) — the second
# after the clipmenu COPR in install-pkg.sh. Flathub is where nearly every
# desktop Flatpak lives; Fedora's own remote carries a small subset.
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

# The literal "~" is flatpak's own syntax for $HOME, not a shell path.
# shellcheck disable=SC2088
FLATPAK_GRANTS=(
    # Vendored Bibata cursor (install-restore-cursor.sh) and any user icon
    # theme. Flatpak does bind this directory, at /run/host/user-share/icons,
    # but only newer runtimes search there for cursors; at its real path it is
    # on libXcursor's default search path on every runtime.
    "~/.local/share/icons:ro"
    # settings.ini (theme identity) and the wallpaper-derived gtk.css, so
    # Flatpak GTK3 apps pick up the accent colours like native ones.
    "xdg-config/gtk-3.0:ro"
    # dots ships no fontconfig today; this makes a user's own rendering
    # tweaks reach sandboxed apps too.
    "xdg-config/fontconfig:ro"
    # The GTK3 Adwaita-dark shim (install-restore-gtk3-shim.sh). The runtime
    # has no theme by that name either, so without it sandboxed GTK3 apps
    # fall back to light Adwaita exactly as native ones did.
    "xdg-data/themes:ro"
)

restore_flatpak() {
    blue "==> flatpak integration"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would add the Flathub remote (--user) and ${#FLATPAK_GRANTS[@]} read-only override(s) still absent"
        return 0
    fi
    if ! command -v flatpak >/dev/null 2>&1; then
        yellow "skip    flatpak not found — no Flathub remote, no overrides"
        return 0
    fi
    flatpak_add_flathub
    flatpak_add_grants
}

# A remote that already exists — added by hand, by an earlier install, or by
# anything else — gets no row, so uninstall never deletes a remote it did not
# add. Captured into a variable before grep: `remotes | grep -q` under
# pipefail can report 141 on a match (see manifest_has_path).
flatpak_add_flathub() {
    local names
    names="$(flatpak remotes --user --columns=name 2>/dev/null || true)"
    if grep -qx flathub <<<"$names"; then
        green "ok      Flathub remote already configured (left alone)"
        return 0
    fi
    if flatpak remote-add --user --if-not-exists flathub "$FLATHUB_URL" >/dev/null 2>&1; then
        manifest_append_row FLATPAK remote flathub "$FLATHUB_URL"
        green "set     Flathub remote (--user)"
    else
        yellow "skip    could not add the Flathub remote (no network?)."
        yellow "        Re-run scripts/install-fedora.sh --only-restore once online."
    fi
}

# A grant whose PATH is already in the global override — with any mode, or
# negated with "!" — is the user's decision and is left alone. The row records
# the entry as flatpak actually wrote it, read back from the file, so
# uninstall compares against the real spelling rather than our request.
flatpak_add_grants() {
    local grant have written
    for grant in "${FLATPAK_GRANTS[@]}"; do
        if have="$(flatpak_grant_for "$grant")"; then
            green "ok      flatpak override $have already set (left alone)"
            continue
        fi
        if ! flatpak override --user --filesystem="$grant" 2>/dev/null; then
            yellow "warn    could not set flatpak override $grant"
            continue
        fi
        if written="$(flatpak_grant_for "$grant")"; then
            manifest_append_row FLATPAK override "$written"
            green "set     flatpak override $written"
        else
            yellow "warn    flatpak override $grant set, but not found in $(flatpak_override_file)"
            yellow "        — uninstall will not be able to revert it."
        fi
    done
}
