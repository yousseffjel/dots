#!/usr/bin/env bash
# wallpaper.sh --login-random on|off|status — SOURCED by wallpaper.sh, never
# run on its own; it uses wallpaper.sh's LOGIN_RANDOM_FLAG and colour helpers.
# Split out when wallpaper.sh reached the 250-line cap (file-architecture.md).

# --login-random on|off|status. The flag is a file, not a setting inside one,
# so the /bin/sh ~/.xinitrc can test it with [ -e ].
login_random() {
    case "$1" in
        on)
            mkdir -p "$(dirname "$LOGIN_RANDOM_FLAG")"
            : >"$LOGIN_RANDOM_FLAG"
            green "on      a random wallpaper at every login"
            login_random_hint
            ;;
        off)
            rm -f "$LOGIN_RANDOM_FLAG"
            green "off     the last wallpaper is kept at login"
            ;;
        status)
            if [[ -e "$LOGIN_RANDOM_FLAG" ]]; then echo on; else echo off; fi
            ;;
        *)
            red "--login-random takes on, off or status, not: $1"
            exit 1
            ;;
    esac
}

# An ~/.xinitrc from before 2026-10-13 never reads the flag, and the
# installer never rewrites one that exists. Same lines as the template.
# shellcheck disable=SC2016
login_random_hint() {
    grep -qs 'dots/random-wallpaper' "$HOME/.xinitrc" && return 0
    yellow "        ~/.xinitrc does not read it yet. Replace its ~/.fehbg line with:"
    yellow '          if [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/dots/random-wallpaper" ] &&'
    yellow '            timeout 120 "$HOME/.local/bin/dots" wallpaper --random; then :'
    yellow '          elif [ -x "$HOME/.fehbg" ]; then "$HOME/.fehbg"; fi'
}
