#!/usr/bin/env bash
# `dots doctor`: the scope K desktop-integration checks (docs/DESKTOP.md) that
# have no older file to live in. Sourced by doctor.sh; same report() contract.
# The keyring has its own file, doctor-keyring.sh.

# session_env_get <VAR> — VAR as the running dwm session has it, read from
# dwm's /proc/<pid>/environ (DOTS_PROC fakes /proc in tests). Not this
# process's environment: the doctor runs in a terminal whose zsh read
# .zshenv itself, so its own copy proves nothing about the session's. Exit 1
# when no dwm of ours is found.
session_env_get() {
    local want="$1" proc="${DOTS_PROC:-/proc}" dir comm entry
    for dir in "$proc"/[0-9]*; do
        [[ -O $dir ]] || continue
        { read -r comm <"$dir/comm"; } 2>/dev/null || continue
        [[ $comm == dwm && -r $dir/environ ]] || continue
        # read -d '', not tr | grep -m1: under pipefail the early grep exit
        # turns a match into a 141.
        while IFS= read -r -d '' entry; do
            [[ $entry == "$want="* ]] && printf '%s\n' "${entry#*=}" && return 0
        done <"$dir/environ"
        return 0
    done
    return 1
}

# Qt theming is a chain, and each link fails silently: the session must carry
# QT_QPA_PLATFORMTHEME (from config/zsh/.zshenv), and each qt*ct.conf must
# name a colour scheme that the theme engine has rendered.
check_qt() {
    local s=theme value major conf csp
    [[ -n "${DISPLAY:-}" ]] && pgrep -x dwm >/dev/null 2>&1 || return 0
    if ! value="$(session_env_get QT_QPA_PLATFORMTHEME)"; then
        report skip "$s" qt "Qt theme: no dwm process of this user to read the session environment from"
        return 0
    fi
    case "$value" in
        "")
            report warn "$s" qt "the dwm session has no QT_QPA_PLATFORMTHEME, so Qt apps ignore qt5ct/qt6ct — config/zsh/.zshenv sets it: log out and back in"
            return 0
            ;;
        qt5ct | qt6ct) ;;
        *)
            report skip "$s" qt "QT_QPA_PLATFORMTHEME is $value, set outside dots — Qt apps are not themed from the wallpaper"
            return 0
            ;;
    esac
    for major in 5 6; do
        conf="${XDG_CONFIG_HOME:-$HOME/.config}/qt${major}ct/qt${major}ct.conf"
        if [[ ! -f "$conf" ]]; then
            report warn "$s" qt "no $conf, so Qt$major apps get no colours — re-run the installer: scripts/install-void.sh --only-restore"
            return 0
        fi
        csp="$(sed -n 's/^color_scheme_path=//p' "$conf")"
        csp="${csp/#\~/$HOME}"
        if [[ -z "$csp" || ! -f "$csp" ]]; then
            report warn "$s" qt "$conf names no colour scheme that exists (${csp:-none}) — dots wallpaper --random, or dots theme dark, renders it"
            return 0
        fi
    done
    report ok "$s" qt "Qt apps are themed: QT_QPA_PLATFORMTHEME=$value, and qt5ct and qt6ct both name an existing colour scheme"
}
