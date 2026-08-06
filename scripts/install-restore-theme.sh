#!/usr/bin/env bash
# Theming-engine deployment for the "restore" stage — split out once
# install-restore.sh crossed the 250-line cap (file-architecture.md).
# Sourced by install-restore.sh only, never standalone: every function
# here assumes the caller has already `set -euo pipefail`, sourced
# global_fn.sh (for manifest_rows()/manifest_append_row()), and set
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

# Only files this installer actually CREATES get a manifest row.
# uninstall_theme deletes every THEME row outright, so registering a
# pre-existing file we deliberately left untouched would turn "we did not
# clobber your config" into "we deleted your config on uninstall". A stray
# file left behind is recoverable; someone else's config removed is not.
# A path already recorded as a THEME row is one we created on an earlier
# run, so re-running the installer must not "back it up" over and over.
theme_is_ours() {
    manifest_rows THEME 2>/dev/null | cut -f3 | grep -qxF "$1"
}

# A path we have already preserved once. Needed because a pre-existing
# user config is deliberately never recorded as a THEME row (uninstall
# must not delete it), so without a separate marker every re-install would
# back it up again — the second time capturing our own generated content,
# not theirs. THEMEBACKUP rows are informational; uninstall_theme only
# reads THEME.
theme_backed_up() {
    manifest_rows THEMEBACKUP 2>/dev/null | cut -f3 | grep -qxF "$1"
}

deploy_theme_file() {
    local src="$1" dst="$2"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would deploy $dst"
        return 0
    fi
    if [[ -e "$dst" ]]; then
        if theme_is_ours "$dst"; then
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

# GTK settings.ini from themes/dark/theme.conf, so the dark GTK theme and
# Papirus-Dark icons the palette assumes are actually selected. gtk.dcol
# only supplies accent colours; it cannot pick a theme name.
theme_write_gtk_ini() {
    local theme_conf="$DOTS_DIR/themes/dark/theme.conf"
    local gtk_ini="$CONF_HOME/gtk-3.0/settings.ini"
    [[ -f "$theme_conf" ]] || return 0

    conf_get() { sed -n "s/^$1=//p" "$theme_conf" | head -1; }

    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would write $gtk_ini"
        return 0
    fi
    if [[ -e "$gtk_ini" ]]; then
        # Same rule as deploy_theme_file: untouched means untracked. Ask
        # the manifest rather than assuming — on every re-run this file is
        # one we wrote ourselves on the first run, and reporting that as
        # "not tracked for removal" would contradict the manifest.
        if theme_is_ours "$gtk_ini"; then
            green "ok      $gtk_ini already deployed by us"
        else
            green "ok      $gtk_ini exists (left untouched, not tracked for removal)"
        fi
        return 0
    fi
    mkdir -p "$(dirname "$gtk_ini")"
    cat >"$gtk_ini" <<EOF
[Settings]
gtk-theme-name=$(conf_get gtk_theme)
gtk-icon-theme-name=$(conf_get icon_theme)
gtk-cursor-theme-name=$(conf_get cursor_theme)
gtk-cursor-theme-size=$(conf_get cursor_size)
gtk-font-name=$(conf_get font)
gtk-application-prefer-dark-theme=1
EOF
    green "wrote   $gtk_ini"
    manifest_append_row THEME theme "$gtk_ini"
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
        theme_is_ours "$gtk_css" \
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
        theme_backed_up "$pre" && continue
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
    theme_claim_gtk_css
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
