#!/usr/bin/env bash
# Restart-survival section of tests/dwm-runtime.sh — SOURCED, never run on
# its own (tests/lib/ is outside run-tests.sh's depth-1 glob). Split from
# dwm-runtime-checks.sh at the 250-line cap. Uses the caller's pass/fail and
# the helpers in dwm-runtime-x.sh.

# 8. preserveonrestart: a SIGHUP restart must leave the desktop as it was.
#
# scripts/theme/reload.sh SIGHUPs dwm on EVERY wallpaper change and theme
# switch. Before this check existed, the re-exec'd dwm recovered each window
# through scan() -> manage() -> applyrules(), which knows nothing about the
# previous instance: every window landed on the view dwm starts on, stashed
# scratchpads came back out, floating windows were tiled and focus was lost.
# The 2026-10-06 note in dwm-runtime.sh's header saw only the last symptom.
#
# Layout built here, all by keyboard so dwm (not xdotool) owns every state:
#   tag 3: A                       tag 4: B (focused), C, F (floating, 200px)
#   stashed in the scratchpad: S   view before the restart: tag 4
# Nothing is pressed after the restart until the view and focus are checked.
check_preserve() {
    local fw active settled=0
    blue "==> preserveonrestart (restart keeps tags, view, stash, floating, focus)"
    preserve_layout || return 0
    if ! restart_dwm; then
        fail "SIGHUP never triggered a restart (_NET_SUPPORTING_WM_CHECK never came back)"
        return 0
    fi
    # setup() advertises the check window before scan() recovers anything.
    for _ in $(seq 1 30); do
        is_shown "$P_B" && ! is_shown "$P_A" && settled=1 && break
        sleep 0.1
    done
    sleep 0.3

    if ((settled)) && is_shown "$P_C"; then
        pass "the view (tag 4) and its windows came back"
    else
        fail "tag 4's windows are not what dwm shows after the restart — the view or their tags were lost"
    fi
    if is_shown "$P_A"; then
        fail "A (tag 3) is showing on the restored view — its tag was reset"
    else
        pass "A stayed on tag 3"
    fi
    if is_shown "$P_S"; then
        fail "the stashed scratchpad S came back out on restart"
    else
        pass "the stashed scratchpad stayed stashed"
    fi
    fw="$(win_width "$P_F")"
    if ((fw > 0 && fw < 300)); then
        pass "F is still floating at its own size (${fw}px)"
    else
        fail "F is ${fw}px wide — it was re-tiled, so its floating state was lost"
    fi
    active="$(xdotool getactivewindow 2>/dev/null || true)"
    if [[ "$active" == "$P_B" ]]; then
        pass "focus is back on B"
    else
        fail "focus after the restart is on '$active', not on B ($P_B)"
    fi
    preserve_still_usable
}

# Builds the layout above and sets P_A P_B P_C P_F P_S to the window ids.
# Returns 1 (after a fail) when the layout could not be built — a test
# setup problem, reported as one rather than as seven dwm failures.
preserve_layout() {
    local a b c f s
    xdotool key --clearmodifiers super+3
    sleep 0.2
    a="$(spawn_win)"
    xdotool key --clearmodifiers super+5
    sleep 0.2
    s="$(spawn_win)"
    sleep 0.2
    xdotool key --clearmodifiers super+shift+s
    xdotool key --clearmodifiers super+4
    sleep 0.2
    f="$(spawn_win)"
    sleep 0.2
    xdotool key --clearmodifiers super+shift+space
    sleep 0.2
    xdotool windowsize "$f" 200 150
    b="$(spawn_win)"
    c="$(spawn_win)"
    sleep 0.2
    # C is newest, so it is master and focused; one step down the stack is B.
    xdotool key --clearmodifiers super+j
    sleep 0.3
    if [[ -z "$a" || -z "$b" || -z "$c" || -z "$f" || -z "$s" ]] || [[ "$(xdotool getactivewindow)" != "$b" ]]; then
        fail "could not build the pre-restart layout (focus is not on B) — test setup, not dwm"
        return 1
    fi
    P_A="$a" P_B="$b" P_C="$c" P_F="$f" P_S="$s"
}

# After the restart, the tags and the stash still WORK, not just look right.
preserve_still_usable() {
    xdotool key --clearmodifiers super+3
    sleep 0.3
    if is_shown "$P_A"; then
        pass "A shows when tag 3 is viewed"
    else
        fail "A does not show on tag 3 after the restart"
    fi
    # Super+s cycles every stashed window, and an earlier section may have
    # left another one (the dropterm) ahead of S: a press shows the next one,
    # the press after re-stashes it. Four presses reach S from any position.
    for _ in 1 2 3 4; do
        xdotool key --clearmodifiers super+s
        sleep 0.3
        is_shown "$P_S" && break
    done
    if is_shown "$P_S"; then
        pass "the stash still works: Super+s brings S back"
    else
        fail "Super+s did not bring the stashed S back after the restart"
    fi
}

# 9. wakeonsignal: SIGTERM (what dwm-powermenu's logout sends) ends dwm at once
#    on an idle display. Before the fix dwm sat in XNextEvent() until some X
#    event arrived — a 20-25 s logout on the Fedora VM. Runs LAST: it ends dwm.
check_sigterm() {
    local start elapsed
    blue "==> wakeonsignal (SIGTERM ends dwm with no X event)"
    start="$(date +%s%N)"
    kill -TERM "$DWM_PID"
    for _ in $(seq 1 30); do
        kill -0 "$DWM_PID" 2>/dev/null || break
        sleep 0.05
    done
    elapsed=$((($(date +%s%N) - start) / 1000000))
    if kill -0 "$DWM_PID" 2>/dev/null; then
        fail "dwm still running ${elapsed} ms after SIGTERM on an idle display — it waits for an X event again"
    else
        pass "dwm exited ${elapsed} ms after SIGTERM, with no X event to wake it"
        DWM_PID=
    fi
}
