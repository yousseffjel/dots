#!/usr/bin/env bash
# X-side helpers for tests/dwm-runtime.sh — SOURCED, never run on its own.
# Lives under tests/lib/ so tests/run-tests.sh's `tests/*.sh` glob (depth 1)
# never mistakes it for a test. Split out of dwm-runtime.sh at the 250-line
# cap; every helper here reads the caller's globals (TMP, DWM, WINCLASS,
# MAGICK) and writes XVFB_PID / DWM_PID back for its cleanup trap.

# Finds a free display number, starts Xvfb on it and exports DISPLAY.
#
# -noreset IS LOAD-BEARING. Without it, the X server resets all state
# (properties, RESOURCE_MANAGER) the instant zero clients are momentarily
# connected — discovered the hard way while developing this test: a
# short-lived `xrdb -merge` or `xsetroot` would report success and then
# vanish before the next client read it back, because the writer
# disconnected before dwm's own long-lived connection was established.
start_xvfb() {
    local n dispnum=
    for n in $(seq 90 199); do
        [[ -S "/tmp/.X11-unix/X$n" ]] || {
            dispnum="$n"
            break
        }
    done
    [[ -n "$dispnum" ]] || {
        red "no free X display number found in 90-199"
        exit 1
    }
    export DISPLAY=":$dispnum"

    Xvfb "$DISPLAY" -screen 0 1280x1024x24 -noreset >"$TMP/xvfb.log" 2>&1 &
    XVFB_PID=$!
    for _ in $(seq 1 50); do
        xdpyinfo >/dev/null 2>&1 && break
        sleep 0.1
    done
    xdpyinfo >/dev/null 2>&1 || {
        red "Xvfb on $DISPLAY never became ready"
        cat "$TMP/xvfb.log" >&2
        exit 1
    }
    blue "==> Xvfb ready on $DISPLAY (pid $XVFB_PID)"
}

# Starts the built dwm and waits until it has finished setup().
#
# HOME and XDG_DATA_HOME are a sandbox. The autostart patch runs
# $XDG_DATA_HOME/dwm/autostart.sh (else ~/.local/share/dwm/), and on a
# tester's desktop that is their real one: it would start their daemons
# against this display, dwm-audiowatch among them, which talks to their real
# PipeWire and signals their real dwmblocks. The stand-in only leaves a
# marker, and the wait below proves it was this one that ran. Restarts keep
# the environment (execvp), so they run the stand-in too.
start_dwm() {
    mkdir -p "$TMP/home/.local/share/dwm"
    printf '#!/bin/sh\ntouch "%s/autostart.ran"\n' "$TMP" >"$TMP/home/.local/share/dwm/autostart.sh"
    chmod 755 "$TMP/home/.local/share/dwm/autostart.sh"
    HOME="$TMP/home" XDG_DATA_HOME="$TMP/home/.local/share" "$DWM" >"$TMP/dwm.log" 2>&1 &
    DWM_PID=$!
    # _NET_SUPPORTED is set one XChangeProperty call AFTER
    # _NET_SUPPORTING_WM_CHECK in dwm.c's setup() — wait for the LATER one, or
    # a query landing between the two races the first property into existing
    # while the second still reads "not found".
    for _ in $(seq 1 50); do
        xprop -root _NET_SUPPORTED 2>/dev/null | grep -q _NET_WM_STATE_FULLSCREEN && break
        sleep 0.1
    done
    xprop -root _NET_SUPPORTED 2>/dev/null | grep -q _NET_WM_STATE_FULLSCREEN || {
        red "dwm never finished advertising _NET_SUPPORTED — did not start"
        cat "$TMP/dwm.log" >&2
        exit 1
    }
    for _ in $(seq 1 50); do
        [[ -e "$TMP/autostart.ran" ]] && break
        sleep 0.1
    done
    [[ -e "$TMP/autostart.ran" ]] || {
        red "dwm did not run the sandbox autostart.sh — it may have run the tester's real one"
        exit 1
    }
    blue "==> dwm running (pid $DWM_PID), sandbox autostart ran"
}

# Opens one test xterm and prints its window id (empty if none appeared).
spawn_win() {
    local before after new
    before="$(xdotool search --class "$WINCLASS" 2>/dev/null || true)"
    setsid xterm -class "$WINCLASS" -bg black -e "sleep 300" >>"$TMP/xterm.log" 2>&1 &
    for _ in $(seq 1 50); do
        after="$(xdotool search --class "$WINCLASS" 2>/dev/null || true)"
        new="$(comm -13 <(sort <<<"$before") <(sort <<<"$after") | head -1)"
        [[ -n "$new" ]] && break
        sleep 0.1
    done
    printf '%s\n' "$new"
}

# Prints the RRGGBB (upper-case) of a pixel inside <win>'s right border.
border_pixel() {
    local win="$1" info x y w h bw bx by
    info="$(xwininfo -id "$win")"
    x="$(awk -F: '/Absolute upper-left X/{gsub(/ /,"",$2); print $2}' <<<"$info")"
    y="$(awk -F: '/Absolute upper-left Y/{gsub(/ /,"",$2); print $2}' <<<"$info")"
    w="$(awk -F: '/^  Width/{gsub(/ /,"",$2); print $2}' <<<"$info")"
    h="$(awk -F: '/^  Height/{gsub(/ /,"",$2); print $2}' <<<"$info")"
    bw="$(awk -F: '/Border width/{gsub(/ /,"",$2); print $2}' <<<"$info")"
    ((bw > 0)) || bw=1
    # Empirically (not "x + w"): the right border's visible pixels sit at
    # [x+w+bw, x+w+2*bw), one full border-width past the client's own
    # declared right edge — verified against a live Xvfb+dwm instance by
    # scanning column-by-column rather than assumed from X11 border theory.
    bx=$((x + w + bw))
    by=$((y + h / 2))
    import -window root -crop "${bw}x${bw}+${bx}+${by}" +repage "png:$TMP/px.png" 2>/dev/null
    "$MAGICK" "$TMP/px.png" -format '%[hex:p{0,0}]' info: 2>/dev/null | tr 'a-f' 'A-F'
}

# Width of the focused window (see win_width for the 0 fallback).
master_width() {
    win_width "$(xdotool getactivewindow 2>/dev/null || true)"
}

# Upper-cased "#RRGGBB" -> "RRGGBB", the shape border_pixel prints.
hex_of() {
    local want="${1#\#}"
    printf '%s' "${want^^}"
}

# SIGHUPs dwm the way scripts/theme/reload.sh does and waits until the
# re-exec'd instance has run setup(). Returns 1 if it never came back.
#
# How a restart is detected: delete root's _NET_SUPPORTING_WM_CHECK BEFORE
# the kill, and wait for the check property to come back. Only setup() sets it, so it reappears only
# once a fresh instance has re-initialised. The order matters: deleting after
# the kill would race any stray event that restarts dwm first — the delete
# would then remove the NEW instance's property and fail a good run.
# Comparing the check window's ID before and after does NOT work: execvp()
# keeps the PID, the old X connection closes on exec, and the new one usually
# gets the same client slot — so the new check window often has the very
# same ID (2 of 3 container runs, 2026-10-06).
#
# NO X event is sent to wake dwm, deliberately. Until 2026-10-12 this helper
# set a throwaway root property after the kill, because dwm acted on SIGHUP
# only at its next X event — and that workaround hid the same stall from every
# user: a power-menu logout took 20-25 s on the Fedora VM. dwm now wakes itself
# (the wakeonsignal diff), and an idle Xvfb sends nothing, so a regression
# shows up here as a restart that never comes. setup() runs BEFORE scan(), so
# a caller that inspects recovered windows must still poll for them to settle.
restart_dwm() {
    xprop -root -remove _NET_SUPPORTING_WM_CHECK
    kill -HUP "$DWM_PID"
    for _ in $(seq 1 50); do
        xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -qE '0x[0-9a-fA-F]+' && return 0
        sleep 0.1
    done
    return 1
}

# True when dwm is showing <win>: mapped, and not parked off-screen. dwm hides
# a window that is not on the current view by moving it to x = -2 * width
# (showhide()), it never unmaps it — so map state alone says nothing.
is_shown() {
    local info x
    info="$(xwininfo -id "$1" 2>/dev/null)" || return 1
    grep -q 'Map State: IsViewable' <<<"$info" || return 1
    x="$(awk -F: '/Absolute upper-left X/{gsub(/ /,"",$2); print $2}' <<<"$info")"
    ((${x:--1} >= 0))
}

# Width of <win> in pixels. Falls back to 0 rather than an empty string on
# any failure, so a broken xdotool call surfaces as a clear FAIL comparison
# instead of an opaque arithmetic error aborting the whole script under set -e.
win_width() {
    local w
    w="$(xdotool getwindowgeometry --shell "$1" 2>/dev/null | awk -F= '/^WIDTH/{print $2}')"
    printf '%s' "${w:-0}"
}
