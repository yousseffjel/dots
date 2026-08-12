#!/usr/bin/env bash
# Theming-engine deployment for the "restore" stage — split out once
# install-restore.sh crossed the 250-line cap (file-architecture.md).
# Sourced by install-restore.sh only, never standalone: every function
# here assumes the caller has already `set -euo pipefail`, sourced
# global_fn.sh (for manifest_has_path()/manifest_append_row()), and set
# DOTS_DIR/DRY_RUN.
#
# usage: source "$SCRIPT_DIR/install-restore-theme.sh"; restore_theme
#
# dunst and picom configs are COPIED, never symlinked: the theming engine
# rewrites both files in place on every wallpaper change (neither program
# supports an include directive, so the whole file is generated), and a
# symlink would make it write back into this git repo. Existing files are
# left alone — they may be the user's own, or a previously themed copy
# that is newer than this static fallback.
#
# The theme.conf renderers (settings.ini, xsettingsd.conf) live in the sibling
# install-restore-theme-identity.sh — this file kept crossing the 250-line cap
# as they grew. Resolved from BASH_SOURCE rather than the caller's SCRIPT_DIR,
# the same choice install-session.sh made and for the same reason: this file is
# SOURCED, and a test may source it with no SCRIPT_DIR set at all.
THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-restore-theme-identity.sh
source "$THEME_DIR/install-restore-theme-identity.sh"

# --- the two manifest categories this file writes -----------------------------
#
# `manifest_has_path THEME <path>` answers "did we create this file?" — see
# global_fn.sh for why it is a read loop and not a `grep -q` pipeline. A path
# already recorded as a THEME row is one we created on an earlier run, so
# re-running the installer must not "back it up" over and over.
#
# THEMEBACKUP is a second, separate category and not a redundant one: a
# pre-existing user config is deliberately never recorded as a THEME row
# (uninstall_theme deletes every THEME row outright, and must not delete
# config we promised to leave alone), so without its own marker every
# re-install would back that file up again — the second time capturing our
# own generated content rather than the user's original. THEMEBACKUP rows
# are informational; uninstall_theme only reads THEME.
#
# ------------------------------------------------------------------------------

deploy_theme_file() {
    local src="$1" dst="$2"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would deploy $dst"
        return 0
    fi
    if [[ -e "$dst" ]]; then
        if manifest_has_path THEME "$dst"; then
            green "ok      $dst already deployed by us"
        else
            green "ok      $dst exists (left untouched, not tracked for removal)"
            PREEXISTING_TARGETS+=("$dst")
        fi
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    manifest_append_row THEME theme "$dst"
    green "wrote   $dst"
}

# fastfetch has no static config in this repo at all — fastfetch.dcol is the
# only authored copy and writes ~/.config/fastfetch/config.jsonc directly. Two
# consequences the installer has to cover, both of which gtk.css already shows:
#
#   1. apply_one() skips any template whose target's PARENT directory is
#      missing, treating that as "app not installed". Nothing else creates
#      ~/.config/fastfetch, so without this mkdir the template is silently
#      skipped forever and fastfetch is simply never themed.
#   2. The file must still come back out on uninstall, so it needs a THEME row
#      even though the installer never writes its contents.
#
# Deliberately unconditional on whether fastfetch is installed: the directory
# is three bytes of inode and creating it means a fastfetch installed later
# picks up the theme on the next wallpaper change instead of needing a
# re-install. The no-clobber rule still applies to the file itself.
theme_claim_fastfetch() {
    [[ $DRY_RUN -eq 0 ]] || {
        blue "  (dry-run) would create $CONF_HOME/fastfetch and claim config.jsonc"
        return 0
    }
    local ff_conf="$CONF_HOME/fastfetch/config.jsonc"
    mkdir -p "$(dirname "$ff_conf")"
    if [[ -e "$ff_conf" ]]; then
        if manifest_has_path THEME "$ff_conf"; then
            green "ok      $ff_conf already deployed by us"
        else
            green "ok      $ff_conf exists (left untouched, not tracked for removal)"
            PREEXISTING_TARGETS+=("$ff_conf")
        fi
    else
        manifest_append_row THEME theme "$ff_conf"
    fi
}

# gtk.css is written by the gtk.dcol template rather than deployed here,
# but it still lands in ~/.config and must come back out on uninstall.
# Registering it now (rather than at apply time) keeps all manifest writes
# in the installer, which is the only thing that runs with the manifest in
# scope. Same no-clobber rule: if the user already has their own gtk.css,
# do not claim it — the template will overwrite its contents on the first
# apply, but deleting the file on uninstall goes a step further than that.
theme_claim_gtk_css() {
    [[ $DRY_RUN -eq 0 ]] || return 0
    local gtk_css="$CONF_HOME/gtk-3.0/gtk.css"
    if [[ -e "$gtk_css" ]]; then
        manifest_has_path THEME "$gtk_css" \
            || PREEXISTING_TARGETS+=("$gtk_css")
    else
        manifest_append_row THEME theme "$gtk_css"
    fi
}

# The template engine rewrites its targets wholesale, so a file we
# deliberately left "untouched" above is going to be overwritten by the
# first apply. Back those up now, using the same ~/.dotfiles-backup/<ts>/
# convention symlinks.sh uses (CLAUDE.md rule 7) — otherwise the
# no-clobber guarantee above is true only until the apply runs.
#
# Runs on EVERY install, not only when an apply happens in this run. On a
# headless box the apply is deferred to a hand-run theme-apply.sh, and
# neither theme-apply.sh nor apply-templates.sh backs anything up — so
# gating the backup on $DISPLAY would leave exactly the documented
# fresh-server path with no backup at all.
#
# Returns non-zero when a backup failed, so the caller skips the apply
# rather than overwriting something it could not preserve.
theme_backup_preexisting() {
    [[ $DRY_RUN -eq 0 ]] || return 0
    [[ ${#PREEXISTING_TARGETS[@]} -gt 0 ]] || return 0
    local theme_backup pre
    theme_backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$theme_backup"
    for pre in "${PREEXISTING_TARGETS[@]}"; do
        manifest_has_path THEMEBACKUP "$pre" && continue
        if cp -a "$pre" "$theme_backup/$(basename "$pre")" 2>/dev/null; then
            manifest_append_row THEMEBACKUP theme "$pre"
            yellow "backup  $pre -> $theme_backup/$(basename "$pre")"
        else
            red "could not back up $pre"
            rmdir "$theme_backup" 2>/dev/null || true
            return 1
        fi
    done
    # Empty only when every target was already backed up on a prior run.
    rmdir "$theme_backup" 2>/dev/null || true
}

# Initial theme apply, only when an X session is actually running. On a
# fresh server install there is no display yet; the colours land on the
# first wallpaper.sh/theme-apply.sh run instead.
theme_initial_apply() {
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would apply themes/dark if X is running"
        return 0
    fi
    if [[ -z "${DISPLAY:-}" ]] || [[ ! -f "$DOTS_DIR/themes/dark/colors.dcol" ]]; then
        yellow "skip    initial theme apply (no DISPLAY — run theme-apply.sh dark after startx)"
        return 0
    fi
    blue "==> applying the dark theme"
    if "$DOTS_DIR/scripts/theme/theme-apply.sh" dark; then
        green "applied themes/dark"
    else
        yellow "theme apply failed — run scripts/theme/theme-apply.sh dark by hand"
    fi
}

restore_theme() {
    blue "==> deploying theme base configs"
    CONF_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    PREEXISTING_TARGETS=()
    deploy_theme_file "$DOTS_DIR/config/dunst/dunstrc" "$CONF_HOME/dunst/dunstrc"
    deploy_theme_file "$DOTS_DIR/config/picom/picom.conf" "$CONF_HOME/picom/picom.conf"
    theme_write_gtk_ini
    theme_write_xsettingsd_conf
    theme_claim_gtk_css
    theme_claim_fastfetch
    # Must precede the apply, and must run even when no apply happens —
    # see theme_backup_preexisting's header. A failure here means we could
    # not preserve a file the engine is about to rewrite, so no apply runs
    # now and the deferred hand-run is called out explicitly.
    if theme_backup_preexisting; then
        theme_initial_apply
    else
        yellow "skip    theme apply — could not preserve the file above."
        yellow "        Save it yourself, then run scripts/theme/theme-apply.sh dark."
        yellow "        Until then the theme is NOT applied and that file is untouched."
    fi
}
