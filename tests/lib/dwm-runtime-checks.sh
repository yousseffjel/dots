#!/usr/bin/env bash
# The assertion sections of tests/dwm-runtime.sh — SOURCED, never run on its
# own (tests/lib/ is outside run-tests.sh's depth-1 glob). One function per
# section; the caller runs them in the order its header explains. Each reads
# and writes the caller's globals (WIN1, CHECKWIN_HEX, COLOR_A, DWM_PID, rc
# via pass/fail), and relies on the helpers in dwm-runtime-x.sh.

# 1. EWMH root-window state. Sets CHECKWIN_HEX and WIN1 for later sections.
check_ewmh() {
    local supported atom win1_hex
    blue "==> EWMH root properties"
    supported="$(xprop -root _NET_SUPPORTED)"
    for atom in _NET_SUPPORTED _NET_CLIENT_LIST _NET_ACTIVE_WINDOW \
        _NET_SUPPORTING_WM_CHECK _NET_WM_STATE_FULLSCREEN; do
        if grep -q "$atom" <<<"$supported"; then
            pass "_NET_SUPPORTED advertises $atom"
        else
            fail "_NET_SUPPORTED is missing $atom"
        fi
    done

    CHECKWIN_HEX="$(xprop -root _NET_SUPPORTING_WM_CHECK | grep -oE '0x[0-9a-fA-F]+')"
    if [[ -n "$CHECKWIN_HEX" ]] && xprop -id "$CHECKWIN_HEX" _NET_SUPPORTING_WM_CHECK | grep -qF "$CHECKWIN_HEX"; then
        pass "_NET_SUPPORTING_WM_CHECK window points back at itself"
    else
        fail "_NET_SUPPORTING_WM_CHECK is not self-consistent"
    fi
    if xprop -id "$CHECKWIN_HEX" _NET_WM_NAME 2>/dev/null | grep -q '"dwm"'; then
        pass "_NET_SUPPORTING_WM_CHECK window's _NET_WM_NAME is \"dwm\""
    else
        fail "_NET_SUPPORTING_WM_CHECK window does not advertise _NET_WM_NAME=dwm"
    fi

    WIN1="$(spawn_win)"
    if [[ -z "$WIN1" ]]; then
        red "test xterm window never appeared — cannot continue"
        exit 1
    fi
    xdotool windowfocus "$WIN1"
    sleep 0.3
    win1_hex="$(printf '0x%x' "$WIN1")"
    if xprop -root _NET_CLIENT_LIST | grep -qi "$win1_hex"; then
        pass "_NET_CLIENT_LIST includes the managed test window"
    else
        fail "_NET_CLIENT_LIST does not include the managed test window"
    fi
}

# 2. xresources: colour loaded from the X resource database at startup.
check_xresources() {
    local got want
    blue "==> xresources colour path"
    got="$(border_pixel "$WIN1")"
    want="$(hex_of "$COLOR_A")"
    if [[ "$got" == "$want" ]]; then
        pass "focused window's border reads $COLOR_A from dwm.selbordercolor"
    else
        fail "border pixel is #$got, expected $COLOR_A (dwm.selbordercolor not applied)"
    fi
}

# 3. actualfullscreen: a real _NET_WM_STATE_FULLSCREEN toggle.
#
# Runs BEFORE restartsig, deliberately: a SIGHUP restart's scan()-recovered
# pre-existing windows were observed, while developing this test, to lose
# dwm's internal "selected client" (togglefullscr() no-ops when
# !selmon->sel, and _NET_ACTIVE_WINDOW appeared to go stale) even though the
# restart itself succeeds. Whether that is a real dwm/restartsig gap or an
# artifact of this specific test's window-recovery path is exactly the kind
# of thing this test exists to surface — filed as a follow-up rather than
# investigated further here — but either way, every focus-dependent check
# must run against a dwm instance that has never been restarted.
check_fullscreen() {
    blue "==> actualfullscreen"
    xdotool windowfocus "$WIN1"
    sleep 0.2
    xdotool key --clearmodifiers alt+shift+f
    sleep 0.4
    if xprop -id "$WIN1" _NET_WM_STATE | grep -q _NET_WM_STATE_FULLSCREEN; then
        pass "alt+shift+f sets _NET_WM_STATE_FULLSCREEN on the focused window"
    else
        fail "_NET_WM_STATE_FULLSCREEN was not set after the fullscreen keybind"
    fi
    xdotool key --clearmodifiers alt+shift+f
    sleep 0.4
    if xprop -id "$WIN1" _NET_WM_STATE | grep -q _NET_WM_STATE_FULLSCREEN; then
        fail "_NET_WM_STATE_FULLSCREEN was not cleared by toggling again"
    else
        pass "toggling again clears _NET_WM_STATE_FULLSCREEN"
    fi
}

# 4. pertag: per-tag mfact is independent AND persists across tag switches.
check_pertag() {
    local tag1_base tag1_adjusted tag2_default tag1_recheck threshold=40
    blue "==> pertag (per-tag mfact)"
    xdotool key --clearmodifiers alt+1
    sleep 0.2
    spawn_win >/dev/null
    sleep 0.2
    tag1_base="$(master_width)"

    xdotool key --clearmodifiers alt+l
    xdotool key --clearmodifiers alt+l
    xdotool key --clearmodifiers alt+l
    sleep 0.2
    tag1_adjusted="$(master_width)"

    xdotool key --clearmodifiers alt+2
    sleep 0.2
    spawn_win >/dev/null
    sleep 0.2
    spawn_win >/dev/null
    sleep 0.2
    tag2_default="$(master_width)"

    xdotool key --clearmodifiers alt+1
    sleep 0.2
    tag1_recheck="$(master_width)"

    if ((tag1_adjusted - tag1_base > threshold)); then
        pass "alt+l on tag1 widens the master column ($tag1_base -> $tag1_adjusted px)"
    else
        fail "master column did not widen on tag1 ($tag1_base -> $tag1_adjusted px)"
    fi
    if ((tag2_default < tag1_adjusted - threshold)); then
        pass "tag2's mfact is independent of tag1's ($tag2_default px, not $tag1_adjusted px)"
    else
        fail "tag2 inherited tag1's adjusted mfact ($tag2_default px) — pertag not isolating tags"
    fi
    if ((tag1_recheck >= tag1_adjusted - threshold / 2)); then
        pass "tag1's mfact persisted across the round trip ($tag1_recheck px)"
    else
        fail "tag1's mfact reset after switching away and back ($tag1_adjusted -> $tag1_recheck px)"
    fi
}

# 5. restartsig: change the resource, HUP dwm, expect a NEW window
#    to pick up the NEW colour.
#
# Runs LAST, after every focus-dependent check, and verifies against a FRESH
# window rather than one that predates the restart — see check_fullscreen.
#
# dwm acts on SIGHUP only at its NEXT X event: sighup() just clears
# `running`, and run() sits blocked in XNextEvent() until something arrives.
# A live desktop produces events constantly (every status-bar update is a
# root PropertyNotify), so a reload is near-instant there; this test produced
# none, so the restart never happened and the section always warned — which
# was wrongly blamed on signal delivery in the sandbox.
#
# How a restart is detected: delete root's _NET_SUPPORTING_WM_CHECK BEFORE
# the kill, then wake dwm with a throwaway root property, and wait for the
# check property to come back. Only setup() sets it, so it reappears only
# once a fresh instance has re-initialised. The order matters: deleting after
# the kill would race any stray event that restarts dwm first — the delete
# would then remove the NEW instance's property and fail a good run. Comparing the check window's ID
# before and after does NOT work: execvp() keeps the PID, the old X
# connection closes on exec, and the new one usually gets the same client
# slot — so the new check window often has the very same ID (2 of 3
# container runs, 2026-10-06).
check_restartsig() {
    local color_b="#654321" win2 got
    blue "==> restartsig (SIGHUP reload)"
    printf 'dwm.selbordercolor: %s\n' "$color_b" | xrdb -merge -
    xprop -root -remove _NET_SUPPORTING_WM_CHECK
    kill -HUP "$DWM_PID"
    xprop -root -f _DOTS_TEST_WAKE 8s -set _DOTS_TEST_WAKE 1
    for _ in $(seq 1 50); do
        xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -qE '0x[0-9a-fA-F]+' && break
        sleep 0.1
    done
    if ! xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -qE '0x[0-9a-fA-F]+'; then
        fail "SIGHUP never triggered a restart (_NET_SUPPORTING_WM_CHECK never came back)"
        return 0
    fi
    win2="$(spawn_win)"
    if [[ -z "$win2" ]]; then
        fail "no window appeared after restart — cannot verify reload"
        return 0
    fi
    xdotool windowfocus "$win2"
    sleep 0.3
    got="$(border_pixel "$win2")"
    if [[ "$got" == "$(hex_of "$color_b")" ]]; then
        pass "SIGHUP reload (restartsig) re-reads dwm.selbordercolor as $color_b"
    else
        fail "border pixel after SIGHUP is #$got, expected $color_b (restartsig reload)"
    fi
}
