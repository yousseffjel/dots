#!/usr/bin/env bash
# The theme IDENTITY writers — everything that renders themes/dark/theme.conf
# into a format some toolkit reads. Split out of install-restore-theme.sh once
# that file crossed the 250-line cap (file-architecture.md) on the addition of
# the xsettingsd writer.
#
# The seam is deliberate rather than mechanical: the parent file's remaining job
# is *placement* — deploy a static config, claim a path in the manifest, back up
# what the engine is about to overwrite. This file's job is *rendering*: one
# source (theme.conf, the non-colour half of the theme) into two outputs whose
# only difference is syntax. Adding a third toolkit format belongs here.
#
# Not palette work. Nothing here re-renders on a wallpaper change — that is what
# config/theme/templates/always/ is for. See theme_write_xsettingsd_conf's
# header for why an XSETTINGS config is deliberately not a .dcol template.
#
# Sourced by install-restore-theme.sh and by scripts/theme/theme-apply.sh.
# Assumes the caller has already `set -euo pipefail`, sourced global_fn.sh, and
# set DOTS_DIR / DRY_RUN / CONF_HOME plus the red/green/yellow/blue helpers.
# Two more caller-set globals select *which* theme and *whether* an existing
# file may be replaced — see THEME_CONF_REL and THEME_IDENTITY_CLOBBER below.

# The active theme's theme.conf holds the non-colour half of the theme — GTK
# theme name, icons, cursor and font. Two writers below render those same values
# into two different formats (settings.ini and xsettingsd.conf), so the reader is
# hoisted here instead of nested inside one of them.
#
# `grep -m1` rather than `sed … | head -1`: head exits on the first line and
# SIGPIPEs its producer, which under the `set -o pipefail` this file inherits
# reports 141 even when the key was found. Same trap manifest_has_path exists
# to avoid — see global_fn.sh. A missing key yields empty output and status 0,
# exactly as the sed form did.
# Repo-relative on purpose: DOTS_DIR is set by the caller and is not guaranteed
# to be in scope at the moment this file is sourced, so the absolute path is
# composed at call time. Three sites below need it — the reader and both
# writers' "is there a theme at all?" guards.
#
# Defaulted rather than fixed: the installer wants themes/dark (it runs before
# any theme has been chosen), while theme-apply.sh points it at whichever theme
# is being switched to. Assign it before sourcing this file, or between calls.
THEME_CONF_REL="${THEME_CONF_REL:-themes/dark/theme.conf}"

# May an already-existing settings.ini / xsettingsd.conf be replaced?
#
#   0 (installer) — no. A re-run must not clobber a file the user has since
#                   edited, and on the first run there is nothing to replace.
#   1 (switch)    — yes, but only for files the manifest says we wrote. That
#                   exception is the whole point: without it a theme switch
#                   would change the palette and leave the GTK theme, icons and
#                   font frozen at whatever the install wrote.
#
# A file we did not write is never replaced in either mode — same guarantee
# rule 6 gives autostart.sh and .xinitrc.
THEME_IDENTITY_CLOBBER="${THEME_IDENTITY_CLOBBER:-0}"

# Decide whether the caller may write $1, printing the reason when it may not.
# Three cases, and the third is why this is not just `[[ -e ]]`:
#   absent            -> write
#   ours (manifest)   -> write only in clobber mode
#   present, not ours -> never write, and say so loudly in clobber mode, because
#                        there the user asked for a change that is not happening
theme_identity_may_write() {
    local target="$1"
    [[ -e "$target" ]] || return 0
    if manifest_has_path THEME "$target"; then
        if [[ $THEME_IDENTITY_CLOBBER -eq 1 ]]; then
            return 0
        fi
        green "ok      $target already deployed by us"
        return 1
    fi
    if [[ $THEME_IDENTITY_CLOBBER -eq 1 ]]; then
        yellow "skipped $target — not ours, theme identity not applied there"
    else
        green "ok      $target exists (left untouched, not tracked for removal)"
    fi
    return 1
}

theme_conf_get() {
    local line
    line="$(grep -m1 "^$1=" "$DOTS_DIR/$THEME_CONF_REL" 2>/dev/null)" || return 0
    printf '%s\n' "${line#*=}"
}

# GTK settings.ini from the active theme's theme.conf, so the GTK theme and
# icons the palette assumes are actually selected. gtk.dcol only supplies
# accent colours; it cannot pick a theme name.
theme_write_gtk_ini() {
    local gtk_ini="$CONF_HOME/gtk-3.0/settings.ini"
    [[ -f "$DOTS_DIR/$THEME_CONF_REL" ]] || return 0

    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would write $gtk_ini"
        return 0
    fi
    # Same rule as deploy_theme_file: untouched means untracked. Ask the
    # manifest rather than assuming — on every re-run this file is one we
    # wrote ourselves on the first run, and reporting that as "not tracked
    # for removal" would contradict the manifest.
    theme_identity_may_write "$gtk_ini" || return 0
    mkdir -p "$(dirname "$gtk_ini")"
    cat >"$gtk_ini" <<EOF
[Settings]
gtk-theme-name=$(theme_conf_get gtk_theme)
gtk-icon-theme-name=$(theme_conf_get icon_theme)
gtk-cursor-theme-name=$(theme_conf_get cursor_theme)
gtk-cursor-theme-size=$(theme_conf_get cursor_size)
gtk-font-name=$(theme_conf_get font)
gtk-application-prefer-dark-theme=1
EOF
    green "wrote   $gtk_ini"
    manifest_append_row THEME theme "$gtk_ini"
}

# xsettingsd.conf — the same theme identity settings.ini carries, in the format
# an XSETTINGS daemon serves to GTK apps, plus the Xft font-rendering keys that
# live nowhere else in this repo (xresources.dcol carries colours only).
#
# NOT a .dcol template, and that is deliberate. Every template under
# config/theme/templates/always/ re-renders on each wallpaper change because its
# content is palette-derived. Nothing here is: all of it comes from the active
# theme's theme.conf, which one wallpaper change does not touch. A template
# would rewrite an identical file every time and buy nothing. theme_write_gtk_ini
# is the precedent — same source, same no-clobber rule, different output format.
#
# Xft/DPI is deliberately absent. XSETTINGS wants 1024ths of an inch, and
# hardcoding 96*1024 would override X's own autodetection and render wrong on
# any HiDPI panel. Leaving the key out lets each toolkit keep autodetecting.
# Add it only when a theme.conf grows a dpi= key to read it from.
theme_write_xsettingsd_conf() {
    local xs_conf="$CONF_HOME/xsettingsd/xsettingsd.conf"
    [[ -f "$DOTS_DIR/$THEME_CONF_REL" ]] || return 0

    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would write $xs_conf"
        return 0
    fi
    theme_identity_may_write "$xs_conf" || return 0
    mkdir -p "$(dirname "$xs_conf")"
    # Strings quoted, integers bare — verified against xsettingsd 1.0.2, which
    # rejects an unquoted string outright rather than ignoring the line.
    cat >"$xs_conf" <<EOF
Net/ThemeName "$(theme_conf_get gtk_theme)"
Net/IconThemeName "$(theme_conf_get icon_theme)"
Gtk/CursorThemeName "$(theme_conf_get cursor_theme)"
Gtk/CursorThemeSize $(theme_conf_get cursor_size)
Gtk/FontName "$(theme_conf_get font)"
Xft/Antialias 1
Xft/Hinting 1
Xft/HintStyle "hintslight"
Xft/RGBA "rgb"
EOF
    green "wrote   $xs_conf"
    manifest_append_row THEME theme "$xs_conf"
}
