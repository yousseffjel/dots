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
start_dwm() {
    "$DWM" >"$TMP/dwm.log" 2>&1 &
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
    blue "==> dwm running (pid $DWM_PID)"
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

# Width of the focused window. Falls back to 0 rather than an empty string on
# any failure, so a broken xdotool call surfaces as a clear FAIL comparison
# instead of an opaque arithmetic error aborting the whole script under set -e.
master_width() {
    local w
    w="$(xdotool getactivewindow getwindowgeometry --shell 2>/dev/null | awk -F= '/^WIDTH/{print $2}')"
    printf '%s' "${w:-0}"
}

# Upper-cased "#RRGGBB" -> "RRGGBB", the shape border_pixel prints.
hex_of() {
    local want="${1#\#}"
    printf '%s' "${want^^}"
}
