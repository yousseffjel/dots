#!/usr/bin/env bash
# Sourced by dwm-screenshot, never run (no exec bit, so dmenu_path never lists
# it): the theming and capture half, split out at the 250-line cap
# (2026-10-12). Uses the caller's red/notify, its maim/slop flags and
# monitor_geometry (dwm-lib-monitor.sh, or the caller's stand-in).

# --- theming -----------------------------------------------------------
# slop's --color wants float RGBA, so the palette hex needs converting.
# $((16#..)) is plain bash arithmetic; awk's strtonum() would have been
# shorter but it is a gawk extension and nothing else here assumes gawk.
hex2rgba() {
    local hex="${1#\#}" r g b
    [[ "$hex" =~ ^[0-9A-Fa-f]{6}$ ]] || return 1
    r=$((16#${hex:0:2}))
    g=$((16#${hex:2:2}))
    b=$((16#${hex:4:2}))
    awk -v r="$r" -v g="$g" -v b="$b" \
        'BEGIN { printf "%.3f,%.3f,%.3f,1\n", r / 255, g / 255, b / 255 }'
}

# dwm.selbordercolor is the border dwm draws around the focused window, so
# reusing it means the region selector matches what "selected" already looks
# like on this desktop. It comes from the live X resource database — the same
# source every suckless tool here reads — so it re-themes with the wallpaper
# for free. Prints nothing when unthemed; the caller falls back to slop's
# own grey. No awk `exit`: that SIGPIPEs xrdb and trips pipefail.
selector_color() {
    local hex
    command -v xrdb >/dev/null 2>&1 || return 0
    hex="$(xrdb -query 2>/dev/null \
        | awk '!f && $1 == "dwm.selbordercolor:" { print $2; f = 1 }' || true)"
    [[ -n "$hex" ]] || return 0
    hex2rgba "$hex" || return 0
}

# --- capture -----------------------------------------------------------
# ImageMagick 7 is `magick`; 6 has only `convert` (colorgen.sh's fallback).
magick_bin() {
    command -v magick 2>/dev/null || command -v convert 2>/dev/null || {
        red "dwm-screenshot: ImageMagick is not installed (needed only for --region)"
        return 1
    }
}

# The active window id, as the 0x-prefixed string maim -i accepts verbatim.
# dwm maintains _NET_ACTIVE_WINDOW, and sets it to 0x0 when nothing is
# focused — which matches the hex pattern, so it needs rejecting by name.
active_window() {
    local id
    id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{ print $NF }' || true)"
    if [[ ! "$id" =~ ^0x[0-9A-Fa-f]+$ ]] || [[ "$id" == "0x0" ]]; then
        red "dwm-screenshot: no active window (_NET_ACTIVE_WINDOW is unset or 0x0)"
        return 1
    fi
    printf '%s\n' "$id"
}

# Writes a PNG to $2. Returns 1 on failure, 2 when the user cancelled a
# selection — the caller treats those very differently.
#
# $1 is assumed valid: the sole call site validates it, and repeating the
# mode list here would be a second place to forget when one is added. An
# unknown mode falls through to the empty-capture check downstream.
capture() {
    local mode="$1" out="$2" id geom rgba magick slop_opts=()

    case "$mode" in
        full)
            maim "${CAPTURE_OPTS[@]}" "$out"
            ;;
        monitor)
            # The key's stderr goes nowhere, so the reason is notified too.
            geom="$(monitor_geometry)" || {
                notify -u critical "Screenshot failed" "could not find the monitor under the pointer"
                return 1
            }
            maim "${CAPTURE_OPTS[@]}" --geometry "$geom" "$out"
            ;;
        window)
            require xprop "needed only for --window; --full and --region still work" || return 1
            id="$(active_window)" || return 1
            # Captures the window's rectangle off the screen, so anything
            # stacked on top of it appears in the shot. That is how X
            # compositing works, not something this script can paper over.
            maim "${CAPTURE_OPTS[@]}" --window "$id" "$out"
            ;;
        region)
            require slop "region selection" || return 1
            magick="$(magick_bin)" || return 1
            # Freeze first (2026-10-22): the whole screen is captured BEFORE
            # slop runs, and the selection is cropped out of that frame.
            # slop grabs the keyboard, and the focus loss closes whatever
            # popup was open — a browser dropdown, a GTK menu — so capturing
            # after the drag could never contain one.
            maim "${CAPTURE_OPTS[@]}" "$out"
            # slop is run directly rather than through maim --select, so the
            # themed colour applies and the geometry is ours to inspect.
            #
            # An empty result is treated as a cancel because slop cannot tell
            # the two apart: pressing Escape and failing to grab the pointer
            # both exit 1 with nothing on stdout. Its stderr is deliberately
            # NOT discarded — that is the only thing separating "the user
            # changed their mind" from "another client holds a grab".
            rgba="$(selector_color)"
            slop_opts=(--bordersize "$SLOP_BORDER")
            if [[ -n "$rgba" ]]; then slop_opts+=(--color "$rgba"); fi
            # --no-grab: slop's keyboard grab would close an open dropdown.
            if [[ -n "${NO_GRAB:-}" ]]; then slop_opts+=(--nokeyboard); fi
            geom="$(slop "${slop_opts[@]}" || true)"
            if [[ -z "$geom" ]]; then return 2; fi
            # slop and maim both use root coordinates, so on several
            # monitors the rectangle lands in the same place in the frame.
            "$magick" "$out" -crop "$geom" +repage "$out"
            ;;
    esac
}
