#!/usr/bin/env bash
# The Super+s scratchpad set (scratchpadgroup) for tests/dwm-runtime.sh.
# SOURCED, never run on its own (tests/lib/ is outside run-tests.sh's
# depth-1 glob). Uses the caller's pass/fail and the helpers in
# dwm-runtime-x.sh and dwm-runtime-mouse.sh (outer_geom, near,
# mouse_floating_win). On tag 9, which no other section keeps windows on,
# with a visit to tag 8; closes every window it opens. Gathering from the other monitor is checked
# in tests/dwm-multimon.sh.

# Stashes the focused window (Super+Shift+s).
sp_stash() {
    xdotool key --clearmodifiers super+shift+s
    sleep 0.3
}

sp_toggle() {
    xdotool key --clearmodifiers super+s
    sleep 0.4
}

# How many of the given windows dwm is showing.
sp_shown() {
    local w n=0
    for w in "$@"; do
        is_shown "$w" && n=$((n + 1))
    done
    echo "$n"
}

# One stashed window comes back filling the area under the bar, wherever
# it was stashed from and at whatever size.
sp_check_one() {
    local s="$1" wy="$2" x y w h
    sp_toggle
    read -r x y w h <<<"$(outer_geom "$s")"
    # 13px: xterm's size increments still apply to a floating window.
    if ((x == 0 && y == wy)) && near "$w" 1280 13 && near "$h" $((1024 - wy)) 13; then
        pass "one scratchpad stashed at 404x304 comes back filling the screen (${w}x$h at $x,$y)"
    else
        fail "the shown scratchpad is ${w}x$h at $x,$y, not the area under the bar (1280x$((1024 - wy)) at 0,$wy)"
    fi
    sp_toggle
    if is_shown "$s"; then
        fail "the second Super+s left the scratchpad showing"
    else
        pass "the next Super+s hides it"
    fi
}

# Three members: one on the left half at full height, two stacked on the
# right half, the left one focused.
sp_check_three() {
    local wy="$1" w x y gw gh left=0 right=0 tops=""
    shift
    for w in "$@"; do
        read -r x y gw gh <<<"$(outer_geom "$w")"
        if ((x == 0)) && near "$gw" 640 8 && near "$gh" $((1024 - wy)) 13; then
            left=$((left + 1))
            [[ "$(xdotool getactivewindow)" == "$w" ]] || fail "the left-half scratchpad is not the focused one"
        elif ((x == 640)) && near "$gw" 640 8 && near "$gh" $(((1024 - wy) / 2)) 13; then
            right=$((right + 1)) tops="$tops $y"
        fi
    done
    if ((left == 1 && right == 2)) && [[ "$tops" == *" $wy"* ]]; then
        pass "three scratchpads show together: one on the left half, two stacked on the right"
    else
        fail "three scratchpads: $left on the left half, $right on the right (tops:$tops)"
    fi
}

check_scratchpad_group() {
    local t s1 s2 s3 wy n w
    blue "==> scratchpadgroup (Super+s shows and hides the whole set)"
    xdotool key --clearmodifiers super+9
    sleep 0.2
    t="$(spawn_win)"
    sleep 0.3
    read -r _ wy _ _ <<<"$(outer_geom "$t")"
    mouse_floating_win s1 300 300 400 300
    sp_stash
    sp_check_one "$s1" "$wy"
    s2="$(spawn_win)"
    sp_stash
    s3="$(spawn_win)"
    sp_stash
    # On the bar: dwm focuses the window under the pointer (focus follows
    # the mouse), which would override the focus Super+s gives the first.
    xdotool mousemove 5 5
    sleep 0.2
    sp_toggle
    n="$(sp_shown "$s1" "$s2" "$s3")"
    ((n == 3)) || fail "one Super+s showed $n of the three scratchpads"
    sp_check_three "$wy" "$s1" "$s2" "$s3"
    if is_shown "$(dropterm_wins | head -1)"; then
        fail "Super+s showed the stashed dropterm too"
    else
        pass "the stashed dropterm is not part of the set"
    fi
    # Shown on tag 9, then viewing tag 8: the set is showing nowhere here,
    # so Super+s brings it along instead of hiding it.
    xdotool key --clearmodifiers super+8
    sleep 0.3
    sp_toggle
    n="$(sp_shown "$s1" "$s2" "$s3")"
    if ((n == 3)); then
        pass "on another tag, Super+s brings the set shown on tag 9 along"
    else
        fail "on another tag, Super+s showed $n of the three scratchpads shown on tag 9"
    fi
    sp_toggle
    n="$(sp_shown "$s1" "$s2" "$s3")"
    if ((n == 0)); then
        pass "the next Super+s hides all three"
    else
        fail "$n scratchpads still showing after the hiding Super+s"
    fi
    sp_toggle
    restart_dwm || fail "dwm did not come back from SIGHUP in the scratchpad check"
    sleep 1
    sp_toggle
    n="$(sp_shown "$s1" "$s2" "$s3")"
    if ((n == 0)); then
        pass "after a restart, Super+s still hides the showing set"
    else
        fail "after a restart, Super+s left $n of the shown scratchpads up — the set was lost"
    fi
    for w in "$s1" "$s2" "$s3" "$t"; do xdotool windowkill "$w"; done
    xdotool key --clearmodifiers super+1
    sleep 0.2
}
