#!/usr/bin/env bash
# One wallpaper or theme change at a time. Sourced, first thing, by
# wallpaper.sh and theme-apply.sh with their own path and arguments:
#
#   source "$SCRIPT_DIR/theme-lock.sh" "${BASH_SOURCE[0]}" "$@"
#
# WHY. A change runs feh -> colorgen.sh -> apply-templates.sh -> reload.sh,
# and only reload.sh was locked. Two at once (Super+w pressed twice; the
# Void VM, 2026-10-20) interleaved: the second wallpaper stayed on screen
# while the first one's palette, finishing later, was written over its own.
#
# HOW. The first pass re-runs the script under `flock -o` and exits with its
# status; the re-run sees DOTS_THEME_LOCKED, unsets it (so nothing a change
# starts inherits it) and carries on. `-o` closes the lock fd in the script:
# the lock stays with the waiting flock, so a daemon the change starts
# (dwmblocks) never holds it — the leak reload.sh's header describes.
# Runs unlocked when flock is missing or the lock file cannot be made: a
# theme change must not depend on it. DOTS_THEME_LOCK_WAIT (seconds, default
# 60) is how long a change waits for the one before it.
#
# Arguments that change nothing take no lock (2026-10-21): --list (the
# Super+Shift+t menu builds its list from it), help, --login-random (a flag
# file only) and --select, whose dmenu picker held the lock for as long as it
# stayed open. wallpaper.sh re-runs itself with the chosen path, and that
# run is locked like any other.

if [[ -n ${DOTS_THEME_LOCKED:-} ]]; then
    unset DOTS_THEME_LOCKED
elif [[ ${2:-} == @(-h|--help|--list|--login-random|--select) ]]; then
    :
else
    theme_lock_file="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme/.theme.lock"
    if command -v flock >/dev/null 2>&1 && mkdir -p "${theme_lock_file%/*}" 2>/dev/null \
        && : 2>/dev/null >>"$theme_lock_file"; then
        theme_lock_rc=0
        DOTS_THEME_LOCKED=1 flock -o -w "${DOTS_THEME_LOCK_WAIT:-60}" -E 75 \
            "$theme_lock_file" "$BASH" "$@" || theme_lock_rc=$?
        if ((theme_lock_rc == 75)); then
            red "another wallpaper or theme change is still running — this one was not started"
        fi
        exit "$theme_lock_rc"
    fi
fi
