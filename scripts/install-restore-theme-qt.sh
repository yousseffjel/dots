#!/usr/bin/env bash
# The Qt identity writer: theme.conf's icons and font, plus the path of the
# wallpaper colour scheme, rendered into qt5ct.conf and qt6ct.conf. Sourced by
# install-restore-theme-identity.sh (and so by both of its callers); its own
# file because that one would cross the 250-line cap. Same contract as the
# writers there: theme_identity_may_write decides, the manifest claims.
#
# The colours are not here. always/qt.dcol renders them into the theme cache
# on every wallpaper change; these confs only point at that file. What these
# files carry changes only with a theme switch, so they are identity, not
# palette (the reason xsettingsd.conf is not a template either).
#
# Probed on the dev host with compiled Qt5/Qt6 probes (qt5ct 1.9, qt6ct 0.11),
# 2026-10-23:
#   * both plugins answer QT_QPA_PLATFORMTHEME=qt5ct (config/zsh/.zshenv);
#   * the font string differs: Qt5's QFont has 10 fields (weight 50 = normal),
#     Qt6's has 16 (weight 400). Each file gets its own;
#   * no fixed font: Qt's fixed font follows fontconfig's monospace, which
#     config/fontconfig already maps to Cascadia Code NF;
#   * an open app re-reads its conf when the file is RENAMED into place, so
#     the write goes through a temp file and mv, and a theme switch re-themes
#     running Qt apps too.

QT_COLORS_REL=dots/theme/qt-colors.conf

# qt_conf_body <qt-major> — the conf, from the active theme.conf.
qt_conf_body() {
    local major="$1" font family size
    font="$(theme_conf_get font)"
    family="${font% *}"
    size="${font##* }"
    printf '# Written by dots (scripts/install-restore-theme-qt.sh); a theme switch\n'
    printf '# rewrites it. The qt%sct GUI may change it too: QSettings drops comments.\n' "$major"
    printf '[Appearance]\n'
    printf 'color_scheme_path=%s/%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}" "$QT_COLORS_REL"
    printf 'custom_palette=true\n'
    printf 'icon_theme=%s\n' "$(theme_conf_get icon_theme)"
    printf 'standard_dialogs=default\n'
    printf 'style=Fusion\n'
    # A font with no "<family> <size>" shape is left to fontconfig.
    [[ "$size" =~ ^[0-9]+$ && -n "$family" && "$family" != "$font" ]] || return 0
    printf '\n[Fonts]\n'
    if [[ $major -eq 5 ]]; then
        printf 'general="%s,%s,-1,5,50,0,0,0,0,0"\n' "$family" "$size"
    else
        printf 'general="%s,%s,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"\n' "$family" "$size"
    fi
}

theme_write_qt_conf() {
    local major conf
    [[ -f "$DOTS_DIR/$THEME_CONF_REL" ]] || return 0
    for major in 5 6; do
        conf="$CONF_HOME/qt${major}ct/qt${major}ct.conf"
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would write $conf"
            continue
        fi
        theme_identity_may_write "$conf" || continue
        mkdir -p "$(dirname "$conf")"
        qt_conf_body "$major" >"$conf.dots-tmp"
        mv -f "$conf.dots-tmp" "$conf"
        green "wrote   $conf"
        manifest_has_path THEME "$conf" || manifest_append_row THEME theme "$conf"
    done
}
