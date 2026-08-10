#!/usr/bin/env bash
# App-config deployment for the "restore" stage — Thunar, the Xfce helper
# defaults, and the xdg mime defaults. Sourced by install-restore.sh only,
# never standalone: every function here assumes the caller has already
# `set -euo pipefail`, sourced global_fn.sh (for manifest_has_path() /
# manifest_append_row()), and set DOTS_DIR/DRY_RUN plus the red/green/
# yellow/blue helpers.
#
# usage: source "$SCRIPT_DIR/install-restore-apps.sh"; restore_apps
#
# Everything here is COPIED, never symlinked, for the same reason
# config/dunst and config/picom are (see install-restore-theme.sh): the
# programs rewrite these files in place. Thunar rewrites uca.xml when
# custom actions are edited in the GUI, xfce4-mime-settings rewrites
# helpers.rc, and GIO/`xdg-mime default`/Thunar's "Set Default" all rewrite
# mimeapps.list. A symlink would send every one of those writes into this
# git repo. config/thunar and config/xfce4 must therefore stay out of
# scripts/symlinks.sh.
#
# Note the capital T: Thunar reads $XDG_CONFIG_HOME/Thunar/, not thunar/.
# The repo directory is lowercase to match every other config/ entry.

# `manifest_has_path APP <path>` answers "did we create this file?" — only
# files this installer actually CREATES get a manifest row, so a pre-existing
# file we deliberately left alone is never registered and uninstall never
# deletes config we promised not to touch. See global_fn.sh for why the
# lookup is a read loop and not a `grep -q` pipeline.

# Unlike the theme files, nothing regenerates these later, so a
# pre-existing target that we skip stays the user's own indefinitely — no
# backup is needed here, where install-restore-theme.sh needs one.
deploy_app_file() {
    local src="$1" dst="$2"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would deploy $dst"
        return 0
    fi
    if [[ -e "$dst" ]]; then
        if manifest_has_path APP "$dst"; then
            green "ok      $dst already deployed by us"
        else
            green "ok      $dst exists (left untouched, not tracked for removal)"
        fi
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    manifest_append_row APP app "$dst"
    green "wrote   $dst"
}

# Rebuilds the mimeinfo cache so Thunar's "Open With" list picks up
# dots-nvim.desktop. Defaults in mimeapps.list are read directly by GIO and
# work without this; only the menu listing needs the cache. Best-effort:
# desktop-file-utils arrives as a Thunar dependency, but this must not be
# the thing that fails an install if it ever stops being one.
apps_update_desktop_db() {
    local app_dir="$1"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would refresh the desktop database in $app_dir"
        return 0
    fi
    if ! command -v update-desktop-database >/dev/null 2>&1; then
        yellow "skip    update-desktop-database not found — Thunar's \"Open With\" list may not show Neovim until it is run"
        return 0
    fi
    if update-desktop-database "$app_dir" 2>/dev/null; then
        green "ok      refreshed desktop database"
    else
        yellow "warn    update-desktop-database failed on $app_dir — non-fatal"
    fi
}

# Thunar 4.20 keeps preferences in the xfconf "thunar" channel, NOT in
# thunarrc — that file is only read once, when xfconf has no /last-view,
# and is skipped entirely thereafter (upstream thunar-preferences.c). So
# the shipped config/thunar/thunarrc alone would be inert on any machine
# where Thunar has already run. This pass is what actually applies them.
#
# Format: property|type|value. Enum values are the C identifier, which is
# what xfconf stores — confirmed against a live thunar.xml, which holds
# e.g. THUNAR_ZOOM_LEVEL_100_PERCENT rather than the "100%" nick.
# Keep in sync with config/thunar/thunarrc, whose keys are the CamelCase
# GParamSpec nick of these same properties.
THUNAR_PREFS=(
    "/last-view|string|ThunarDetailsView"
    "/last-side-pane|string|THUNAR_SIDEPANE_TYPE_SHORTCUTS"
    "/misc-single-click|bool|false"
    "/misc-folders-first|bool|true"
    "/misc-date-style|string|THUNAR_DATE_STYLE_YYYYMMDD"
    "/misc-thumbnail-mode|string|THUNAR_THUMBNAIL_MODE_ONLY_LOCAL"
    "/misc-volume-management|bool|true"
    "/misc-exec-shell-scripts-by-default|string|THUNAR_EXECUTE_SHELL_SCRIPT_NEVER"
    "/misc-file-size-binary|bool|true"
    "/misc-confirm-move-to-trash|bool|true"
    "/misc-confirm-close-multiple-tabs|bool|true"
)

# Only sets a property that is not already present. A value the user chose
# in Thunar's own preferences dialog is theirs, and an installer re-run
# must not silently revert it — the same no-clobber rule deploy_app_file
# applies to whole files, applied here per property. The practical effect
# on a machine where Thunar has run before is that /last-view (which
# Thunar writes on its own, recording the view you left it in) is kept,
# while the preferences nothing has ever set are applied.
apps_xfconf_prefs() {
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would apply ${#THUNAR_PREFS[@]} Thunar preferences via xfconf-query"
        return 0
    fi
    if ! command -v xfconf-query >/dev/null 2>&1; then
        yellow "skip    xfconf-query not found — Thunar preferences left to thunarrc's one-time migration"
        return 0
    fi
    # xfconf-query needs a session bus to reach xfconfd. On a headless
    # server install there is none, and every call below would fail one at
    # a time with the same error; check once instead.
    if ! xfconf-query -c thunar -l >/dev/null 2>&1; then
        yellow "skip    no session D-Bus (headless install?) — Thunar preferences not applied."
        yellow "        They will apply from thunarrc the first time Thunar runs, or re-run"
        yellow "        scripts/install-fedora.sh --only-restore from inside an X session."
        return 0
    fi

    local entry prop ptype value set_count=0 kept_count=0
    for entry in "${THUNAR_PREFS[@]}"; do
        IFS='|' read -r prop ptype value <<<"$entry"
        if xfconf-query -c thunar -p "$prop" >/dev/null 2>&1; then
            kept_count=$((kept_count + 1))
            continue
        fi
        if xfconf-query -c thunar -p "$prop" -n -t "$ptype" -s "$value" 2>/dev/null; then
            set_count=$((set_count + 1))
        else
            yellow "warn    could not set $prop"
        fi
    done
    green "ok      Thunar preferences: $set_count set, $kept_count already had a value (left alone)"
}

restore_apps() {
    blue "==> deploying app configs"
    local conf_home data_home
    conf_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    data_home="${XDG_DATA_HOME:-$HOME/.local/share}"

    deploy_app_file "$DOTS_DIR/config/thunar/thunarrc" "$conf_home/Thunar/thunarrc"
    deploy_app_file "$DOTS_DIR/config/thunar/uca.xml" "$conf_home/Thunar/uca.xml"
    deploy_app_file "$DOTS_DIR/config/xfce4/helpers.rc" "$conf_home/xfce4/helpers.rc"
    deploy_app_file "$DOTS_DIR/config/mimeapps.list" "$conf_home/mimeapps.list"
    deploy_app_file "$DOTS_DIR/config/applications/dots-nvim.desktop" \
        "$data_home/applications/dots-nvim.desktop"

    apps_update_desktop_db "$data_home/applications"
    apps_xfconf_prefs
}
