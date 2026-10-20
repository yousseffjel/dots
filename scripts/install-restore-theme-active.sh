#!/usr/bin/env bash
# Which theme a re-run of the restore stage re-applies. Sourced by
# install-restore-theme.sh, never standalone: assumes DOTS_DIR. Defines one
# function and assigns nothing, so tests can source it on its own.
#
# usage: source "$THEME_DIR/install-restore-theme-active.sh"; theme_active
#
# theme_initial_apply runs on every restore with a DISPLAY — `dots update`
# from a session terminal included — and it used to apply `dark` every time,
# throwing away a wallpaper-derived palette or a static theme the user had
# switched to (seen on the Fedora VM, 2026-10-13). The two choices leave two
# records in the theme cache:
#   theme.set — written by every static apply (theme-apply.sh <name>);
#   wall.set  — written by every wallpaper change (wallpaper.sh), and
#               touched by `theme-apply.sh --wallbash` (Void VM, 2026-10-20:
#               without it, a static theme applied earlier won the re-run).
# Whichever was written last is the theme in use. A tie (both in the same
# instant) counts as static. An image that has since been deleted, or a
# theme.set naming a theme this checkout no longer ships, falls through.

# Prints the theme-apply.sh argument for the active theme: --wallbash, a
# static theme name, or `dark` when nothing has been applied yet.
theme_active() {
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme" name="" wall=""
    # cat || true, not $(<file): an unreadable file must fall through, not
    # end the caller's `theme="$(theme_active)"` under set -e without a word.
    [[ -f "$cache/theme.set" ]] && name="$(cat "$cache/theme.set" 2>/dev/null || true)"
    if [[ -f "$cache/wall.set" ]] \
        && [[ ! -f "$cache/theme.set" || "$cache/wall.set" -nt "$cache/theme.set" ]]; then
        wall="$(cat "$cache/wall.set" 2>/dev/null || true)"
        if [[ -n "$wall" && -f "$wall" ]]; then
            echo --wallbash
            return 0
        fi
    fi
    if [[ -n "$name" && -f "$DOTS_DIR/themes/$name/colors.dcol" ]]; then
        echo "$name"
        return 0
    fi
    echo dark
}
