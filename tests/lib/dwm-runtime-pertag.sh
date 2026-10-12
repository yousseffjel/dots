#!/usr/bin/env bash
# Pertag-across-a-restart sections of tests/dwm-runtime.sh — SOURCED, never
# run on its own (tests/lib/ is outside run-tests.sh's depth-1 glob). Split
# from dwm-runtime-restart.sh at the 250-line cap (2026-10-12). Uses the
# caller's pass/fail, WINCLASS and the helpers in dwm-runtime-x.sh.

# Width of the test window that sits at x=0 (the tiled master, or the monocle
# window) on the current view; 0 when there is none. Ignores windows parked
# off-screen by showhide().
leftmost_width() {
    local id
    for id in $(xdotool search --onlyvisible --class "$WINCLASS" 2>/dev/null); do
        eval "$(xdotool getwindowgeometry --shell "$id" 2>/dev/null)"
        [[ "${X:-}" == 0 ]] && {
            printf '%s' "${WIDTH:-0}"
            return 0
        }
    done
    printf '0'
}

# 9. pertag survives a restart: each tag's master size, layout and bar.
#
# Restarts while viewing tag 1 on purpose: a fresh dwm STARTS on tag 1, so
# restoring the view is a no-op there (view() returns early for the tag
# already shown) — the per-tag values must reach the screen anyway.
# Tag 1 is widened HERE: the earlier restarts in this run reset what
# check_pertag set (a first draft relied on that and compared 700 to 700).
# Builds the layout check_pertag_restart restarts on, and sets PT_W1 PT_W7
# PT_E. Returns 1 (after a fail) when tag 1 could not be widened.
pertag_build_layout() {
    local w1 w7 e
    xdotool key --clearmodifiers super+7
    sleep 0.2
    spawn_win >/dev/null
    spawn_win >/dev/null
    sleep 0.2
    for _ in 1 2 3; do xdotool key --clearmodifiers super+l; done
    sleep 0.3
    w7="$(leftmost_width)"
    xdotool key --clearmodifiers super+8
    sleep 0.2
    spawn_win >/dev/null
    spawn_win >/dev/null
    sleep 0.2
    xdotool key --clearmodifiers super+m
    xdotool key --clearmodifiers super+6
    sleep 0.2
    e="$(spawn_win)"
    sleep 0.2
    xdotool key --clearmodifiers super+b
    xdotool key --clearmodifiers super+1
    sleep 0.3
    for _ in 1 2 3; do xdotool key --clearmodifiers super+l; done
    sleep 0.4
    w1="$(leftmost_width)"
    if ((w1 < 760)); then
        fail "could not widen tag 1's master before the restart (${w1}px) — test setup, not dwm"
        return 1
    fi
    PT_W1="$w1" PT_W7="$w7" PT_E="$e"
}

check_pertag_restart() {
    local w1 w1b w7 w7b w8b e y6
    blue "==> pertag across a restart (mfact, layout, bar per tag)"
    pertag_build_layout || return 0
    w1="$PT_W1" w7="$PT_W7" e="$PT_E"

    if ! restart_dwm; then
        fail "SIGHUP never triggered a restart"
        return 0
    fi
    sleep 1

    w1b="$(leftmost_width)"
    if ((w1 > 0 && w1b >= w1 - 5 && w1b <= w1 + 5)); then
        pass "tag 1 (the view dwm starts on) keeps its master size ($w1 -> $w1b px)"
    else
        fail "tag 1's master went $w1 -> $w1b px — the start view's pertag state was not applied"
    fi
    # Before the restart: tag 6, then tag 1. Mod+Tab must still go back to 6.
    xdotool key --clearmodifiers super+Tab
    sleep 0.4
    if is_shown "$e"; then
        pass "Mod+Tab still returns to the tag viewed before (6)"
    else
        fail "Mod+Tab after the restart did not return to tag 6 — prevtag was lost"
    fi
    xdotool key --clearmodifiers super+7
    sleep 0.4
    w7b="$(leftmost_width)"
    if ((w7 > 0 && w7b >= w7 - 5 && w7b <= w7 + 5)); then
        pass "tag 7 keeps its widened master ($w7 -> $w7b px)"
    else
        fail "tag 7's master went $w7 -> $w7b px — its mfact was reset"
    fi
    xdotool key --clearmodifiers super+8
    sleep 0.4
    w8b="$(leftmost_width)"
    if ((w8b > 1200)); then
        pass "tag 8 is still monocle (${w8b}px)"
    else
        fail "tag 8 is ${w8b}px wide — its monocle layout was reset to tile"
    fi
    xdotool key --clearmodifiers super+6
    sleep 0.4
    eval "$(xdotool getwindowgeometry --shell "$e" 2>/dev/null)"
    y6="${Y:-?}"
    if [[ "$y6" == 0 ]]; then
        pass "tag 6 still has its bar hidden (window at y=0)"
    else
        fail "tag 6's window is at y=$y6 — its hidden bar came back"
    fi
    xdotool key --clearmodifiers super+1
    sleep 0.2
}

# 0. Runs FIRST, on the fresh dwm: both tagset slots still hold tag 1 (no tag
#    switch since start), so restorestate() replays no history and view(1) is
#    a no-op — only applycurtag() can put tag 1's saved master size back.
#    This is "log in, change tag 1's layout, press Super+w". Cleans up after
#    itself so the later sections start from defaults.
check_pertag_fresh_restart() {
    local a b w wb
    blue "==> pertag across a restart with no tag switched since start"
    a="$(spawn_win)"
    b="$(spawn_win)"
    sleep 0.3
    for _ in 1 2 3; do xdotool key --clearmodifiers super+l; done
    sleep 0.3
    w="$(leftmost_width)"
    if ! restart_dwm; then
        fail "SIGHUP never triggered a restart"
        return 0
    fi
    sleep 1
    wb="$(leftmost_width)"
    if ((w > 760 && wb >= w - 5 && wb <= w + 5)); then
        pass "tag 1's master size survives a restart before any tag switch ($w -> $wb px)"
    else
        fail "tag 1's master went $w -> $wb px on a fresh session's restart"
    fi
    for _ in 1 2 3; do xdotool key --clearmodifiers super+h; done
    xdotool windowkill "$a" 2>/dev/null || true
    xdotool windowkill "$b" 2>/dev/null || true
    sleep 0.5
}
