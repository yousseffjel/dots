#!/usr/bin/env bash
# The "app configs" uninstall steps — removes what install-restore-apps.sh
# deployed (Thunar's thunarrc/uca.xml, the Xfce helper defaults, the xdg
# mime defaults, and the Neovim desktop entry), and resets the dconf keys it
# set (uninstall_dconf).
#
# Its own file rather than another function in uninstall_steps.sh, which
# is already at 230 of the 250-line cap (file-architecture.md) — the same
# reason install-restore-theme.sh was split out of install-restore.sh.
# (2026-09-28: uninstall_theme left for uninstall-theme.sh, the same way, and
# uninstall_steps.sh is now ~200 lines — the figure above is historical.)
#
# Sourced by uninstall.sh only: assumes `set -euo pipefail`, global_fn.sh,
# and uninstall.sh's own logging-aware red/green/yellow/blue plus
# confirm() and DRY_RUN.
#
# Mirrors uninstall_theme: APP rows are files this installer CREATED, so
# removing them is safe. A config that already existed was deliberately
# never given a manifest row (see deploy_app_file), so it is not listed
# here and survives the uninstall untouched.
#
# The xfconf preferences install-restore-apps.sh sets are deliberately NOT
# reverted. They live in the user's own xfconf channel alongside settings
# Thunar itself wrote, there is no record of what the values were before,
# and resetting them would be indistinguishable from clobbering choices
# the user made in Thunar's preferences dialog afterwards. Removing config
# we wrote is reversible; guessing at prior state is not.
uninstall_apps() {
    blue "=== app configs ==="
    mapfile -t app_paths < <(manifest_rows APP | cut -f3)
    if [[ ${#app_paths[@]} -eq 0 ]]; then
        blue "  no APP rows in manifest — nothing to remove"
        return 0
    fi
    if ! confirm "Remove ${#app_paths[@]} deployed app config file(s) (Thunar, Xfce helpers, mime defaults)?"; then
        yellow "  skipped app configs"
        return 0
    fi

    local path removed=0
    for path in "${app_paths[@]}"; do
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would remove $path"
            continue
        fi
        if [[ ! -e "$path" ]]; then
            yellow "  skip    $path (already gone)"
            continue
        fi
        if rm -f "$path"; then
            green "  removed  $path"
            removed=$((removed + 1))
        else
            red "  failed to remove $path"
        fi
    done

    # Only worth refreshing when a desktop entry actually went away — and not
    # when the loop above just removed a cache the installer created and no
    # .desktop file is left to index: the refresh would only write that same
    # cache back, leaving behind the one file this uninstall was meant to
    # remove. A cache that is still there was not ours, so it is refreshed.
    local app_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    local remaining=()
    [[ -d "$app_dir" ]] && mapfile -t remaining < <(find "$app_dir" -maxdepth 1 -name '*.desktop')
    if [[ ${#remaining[@]} -eq 0 && ! -e "$app_dir/mimeinfo.cache" ]]; then
        removed=0
    fi
    if [[ $removed -gt 0 && -d "$app_dir" ]] && command -v update-desktop-database >/dev/null 2>&1; then
        if update-desktop-database "$app_dir" 2>/dev/null; then
            green "  refreshed desktop database"
        else
            yellow "  update-desktop-database failed — non-fatal"
        fi
    fi

    blue "  note: Thunar preferences in the xfconf \"thunar\" channel are left as they are."
}

# DCONF row: <key> <value written>. install-restore-apps.sh wrote the key only
# while it was unset, so resetting it restores exactly what was there before.
# It is reset only while it still holds that value: a value changed since is
# the user's choice, made after the install, and stays.
uninstall_dconf() {
    blue "=== dconf settings ==="
    local rows=()
    mapfile -t rows < <(manifest_rows DCONF)
    if [[ ${#rows[@]} -eq 0 ]]; then
        blue "  no DCONF rows in manifest — nothing to reset"
        return 0
    fi
    if ! command -v dconf >/dev/null 2>&1; then
        yellow "  dconf not found — ${#rows[@]} setting(s) left as they are"
        return 0
    fi
    if ! confirm "Reset ${#rows[@]} dconf setting(s) dots set (the dark colour-scheme preference)?"; then
        yellow "  skipped dconf settings"
        return 0
    fi
    local row key value current
    for row in "${rows[@]}"; do
        key="$(cut -f3 <<<"$row")"
        value="$(cut -f4 <<<"$row")"
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would reset $key if it is still $value"
            continue
        fi
        current="$(dconf read "$key" 2>/dev/null || true)"
        if [[ "$current" != "$value" ]]; then
            yellow "  kept     $key = ${current:-unset} (changed since install)"
        elif dconf_cmd reset "$key"; then
            green "  reset    $key"
        else
            red "  could not reset $key (no session bus and no dbus-run-session)"
        fi
    done
}
