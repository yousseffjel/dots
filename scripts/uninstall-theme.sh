#!/usr/bin/env bash
# The two theme uninstall steps: removing what the installer deployed
# (uninstall_theme) and putting back what it backed up (uninstall_theme_backups).
#
# Moved out of uninstall_steps.sh on 2026-09-28, which sat at 235 of the
# 250-line cap when the second function was needed — the same reason
# uninstall-apps.sh exists. Sourced by uninstall.sh only: assumes `set -euo
# pipefail`, global_fn.sh, uninstall.sh's logging-aware red/green/yellow/blue,
# confirm() and DRY_RUN.

# Theme files are COPIES, not symlinks (config/dunst and config/picom are
# deliberately not symlinked — the theming engine rewrites those targets on
# every wallpaper change, and a symlink would make it write into the repo).
# So they cannot go through uninstall_configs, which verifies readlink and
# skips anything that is not our own symlink. Generated cache files under
# ~/.cache/dots are removed too: they are wholly derived, nothing there is
# user data.
uninstall_theme() {
    blue "=== theme files ==="
    mapfile -t theme_paths < <(manifest_rows THEME | cut -f3)
    if [[ ${#theme_paths[@]} -eq 0 ]]; then
        blue "  no THEME rows in manifest — nothing to remove"
    elif confirm "Remove ${#theme_paths[@]} deployed theme file(s) and the generated theme cache?"; then
        for path in "${theme_paths[@]}"; do
            if [[ $DRY_RUN -eq 1 ]]; then
                blue "  (dry-run) would remove $path"
                continue
            fi
            if [[ ! -e "$path" ]]; then
                yellow "  skip    $path (already gone)"
                continue
            fi
            if rm -rf "$path"; then
                green "  removed  $path"
            else
                red "  failed to remove $path"
            fi
        done
        theme_cache="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"
        # A ~/.fehbg naming a wallpaper wallpaper-default.sh generated would
        # dangle once the cache is gone. Removed only then — recognised by the
        # marker line that script writes (FEHBG_MARKER there; keep in step).
        # One naming an image the user picked is theirs and stays.
        fehbg="$HOME/.fehbg"
        fehbg_ours=0
        [[ -f "$fehbg" ]] && grep -qxF '# dots: generated wallpaper' "$fehbg" && fehbg_ours=1
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would remove generated cache $theme_cache"
            ((fehbg_ours == 0)) || blue "  (dry-run) would remove $fehbg (points at the generated wallpaper)"
        else
            if [[ -d "$theme_cache" ]]; then
                rm -rf "$theme_cache" && green "  removed  $theme_cache"
            fi
            if ((fehbg_ours == 1)); then
                rm -f "$fehbg" && green "  removed  $fehbg (pointed at the generated wallpaper)"
            fi
        fi
    else
        yellow "  skipped theme files"
    fi
}

# A theme config the user ALREADY had is deliberately left unclaimed by the
# installer (it must never be deleted), but the theming engine rewrites it
# wholesale on the first wallpaper apply. install-restore-theme.sh therefore
# copies the original to ~/.dotfiles-backup/<ts>/ first and records a
# THEMEBACKUP row: <pre-existing path> <backup path>. This moves each original
# back, so the file ends up as it was before the install rather than as the
# engine last wrote it — the same promise uninstall_configs keeps for symlinks.
#
# Rows written before 2026-09-28 carry no backup path. Those are reported,
# never guessed at: a timestamp directory could hold anything.
#
# The current file is replaced without a diff, on purpose: every THEMEBACKUP
# target is a theming-engine template target (dunstrc, picom.conf, gtk.css,
# the fastfetch config) that the engine rewrites wholesale on each wallpaper
# change, so an edit made there after install does not persist anyway. The
# prompt says so, rather than implying it is only ever "the generated version".
uninstall_theme_backups() {
    blue "=== theme configs you had before installing ==="
    local rows=() row pre bak
    mapfile -t rows < <(manifest_rows THEMEBACKUP)
    if [[ ${#rows[@]} -eq 0 ]]; then
        blue "  no THEMEBACKUP rows in manifest — nothing to restore"
        return 0
    fi
    if ! confirm "Restore ${#rows[@]} theme config(s) you had before installing? (The current copies are replaced; the theming engine rewrote them on every wallpaper change.)"; then
        yellow "  skipped — your originals stay under ~/.dotfiles-backup/"
        return 0
    fi
    for row in "${rows[@]}"; do
        IFS=$'\t' read -r _ _ pre bak <<<"$row"
        if [[ -z "${bak:-}" ]]; then
            yellow "  skip    $pre (installed before backups were recorded — find it under ~/.dotfiles-backup/)"
            continue
        fi
        if [[ ! -e "$bak" ]]; then
            yellow "  skip    $pre (backup $bak is gone)"
            continue
        fi
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would restore $pre from $bak"
            continue
        fi
        mkdir -p "$(dirname "$pre")"
        if mv -f "$bak" "$pre"; then
            green "  restored $pre (from $bak)"
            rmdir "$(dirname "$bak")" 2>/dev/null || true
        else
            red "  failed to restore $pre from $bak"
        fi
    done
}
