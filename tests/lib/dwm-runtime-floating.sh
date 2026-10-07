#!/usr/bin/env bash
# Floating-window sections of tests/dwm-runtime.sh: the float rules and the
# drop-down terminal. SOURCED, never run on its own (tests/lib/ is outside
# run-tests.sh's depth-1 glob). Uses the caller's pass/fail, TMP, DOTS_DIR
# and the helpers in dwm-runtime-x.sh. Every window opened here carries the
# title prefix "dwm-runtime-$$-", which the caller's cleanup pkills.

# Puts a fake `alacritty` first on the PATH dwm will inherit. dwm spawns
# droptermcmd with execvp(), so the fake is what runs: it records its argv,
# which proves the class dwm asks for, and opens an xterm with that class,
# which proves dwm recognises the window by it. The real alacritty is never
# launched — it needs GL, and CI's container has none.
# Must run BEFORE start_dwm.
install_fake_alacritty() {
    mkdir -p "$TMP/fakebin"
    cat >"$TMP/fakebin/alacritty" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$TMP/alacritty.args"
exec xterm -class dots-dropterm -title "dwm-runtime-$$-dropterm" -e sleep 300
EOF
    chmod +x "$TMP/fakebin/alacritty"
    export PATH="$TMP/fakebin:$PATH"
}

dropterm_wins() {
    xdotool search --class '^dots-dropterm$' 2>/dev/null || true
}

# The classes rules[] marks floating, read from config.def.h — never a copy
# here, or a rule added later would silently go untested.
float_rule_classes() {
    sed -n '/^static const Rule rules\[\] = {/,/^};/p' "$DOTS_DIR/suckless/dwm/config.def.h" \
        | awk -F, '/^[[:space:]]*\{ "/ { gsub(/[[:space:]]/, "", $5); if ($5 == "1") { split($1, c, "\""); print c[2] } }'
}

# 6. float rules: a window of each ruled class opens floating. On an empty
#    tag a lone tiled window spans the screen; a floating xterm keeps its own
#    ~500px request.
check_float_rules() {
    local cls classes w win n=0
    blue "==> float rules (rules[] in config.def.h)"
    classes="$(float_rule_classes)"
    if [[ -z "$classes" ]]; then
        fail "read no floating classes out of rules[] — the parser no longer matches config.def.h"
        return 0
    fi
    xdotool key --clearmodifiers alt+6
    sleep 0.2
    while read -r cls; do
        n=$((n + 1))
        setsid xterm -class "$cls" -title "dwm-runtime-$$-rule" -e sleep 300 >>"$TMP/xterm.log" 2>&1 &
        win=
        for _ in $(seq 1 50); do
            win="$(xdotool search --class "^$cls\$" 2>/dev/null | tail -1 || true)"
            [[ -n "$win" ]] && break
            sleep 0.1
        done
        sleep 0.3
        w="$(win_width "${win:-0}")"
        if [[ -n "$win" ]] && ((w > 0 && w < 900)); then
            pass "$cls floats (${w}px)"
        else
            fail "$cls is ${w}px wide on an empty tag — tiled, so its rule does not match"
        fi
        [[ -z "$win" ]] || xdotool windowkill "$win" 2>/dev/null || true
        sleep 0.2
    done <<<"$classes"
    ((n >= 6)) || fail "only $n floating rules found; expected at least the six in config.def.h"
    xdotool key --clearmodifiers alt+1
    sleep 0.2
}

# 7. dropterm: Super+grave spawns once, then hides/shows the same window.
check_dropterm() {
    blue "==> dropterm (Super+grave)"
    dropterm_first_press || return 0
    dropterm_toggle "$DROPTERM"
}

# The first press, with none running: spawn, placement, focus. Sets DROPTERM
# to the window id; returns 1 (after a fail) when nothing appeared.
dropterm_first_press() {
    local d w y spawned
    xdotool key --clearmodifiers alt+1
    sleep 0.2
    xdotool key --clearmodifiers super+grave
    d=
    for _ in $(seq 1 50); do
        d="$(dropterm_wins | head -1)"
        [[ -n "$d" ]] && break
        sleep 0.1
    done
    if [[ -z "$d" ]]; then
        fail "Super+grave with no dropterm running spawned nothing"
        return 1
    fi
    sleep 0.3
    spawned="$(cat "$TMP/alacritty.args" 2>/dev/null || true)"
    if [[ "$spawned" == "--class dots-dropterm" ]]; then
        pass "the first press runs droptermcmd (alacritty --class dots-dropterm)"
    else
        fail "droptermcmd ran with args '$spawned', expected '--class dots-dropterm'"
    fi
    w="$(win_width "$d")"
    y="$(xwininfo -id "$d" | awk -F: '/Absolute upper-left Y/{gsub(/ /,"",$2); print $2}')"
    # 0.6 of a 1280px-wide Xvfb is 768 minus the borders; the bar is ~20px.
    if is_shown "$d" && ((w > 700 && w < 780 && y < 60)); then
        pass "it opens floating, top-centre, 0.6 wide (${w}px at y=$y)"
    else
        fail "dropterm geometry is ${w}px wide at y=$y — not the drop-down placement"
    fi
    if [[ "$(xdotool getactivewindow)" == "$d" ]]; then
        pass "it has focus"
    else
        fail "the new dropterm did not get focus"
    fi
    DROPTERM="$d"
}

# Later presses on the same window: stash, re-show on another tag (no second
# spawn), focus and re-placement. Leaves it stashed, and the view on tag 1.
dropterm_toggle() {
    local d="$1" n y

    # Drag it away first, so the re-show below must put it back on its own.
    xdotool windowmove "$d" 300 400
    sleep 0.2
    xdotool key --clearmodifiers super+grave
    sleep 0.3
    if is_shown "$d"; then
        fail "a second press did not hide the focused dropterm"
    else
        pass "the second press stashes it"
    fi

    xdotool key --clearmodifiers alt+2
    sleep 0.2
    xdotool key --clearmodifiers super+grave
    sleep 0.3
    n="$(dropterm_wins | wc -l)"
    if is_shown "$d" && ((n == 1)) && [[ "$(wc -l <"$TMP/alacritty.args")" -eq 1 ]]; then
        pass "the third press, on another tag, shows the SAME window there (no second spawn)"
    else
        fail "third press: shown=$(is_shown "$d" && echo y || echo n), windows=$n, spawns=$(wc -l <"$TMP/alacritty.args")"
    fi
    if [[ "$(xdotool getactivewindow)" == "$d" ]]; then
        pass "it is focused when shown"
    else
        fail "the re-shown dropterm is not focused"
    fi
    y="$(xwininfo -id "$d" | awk -F: '/Absolute upper-left Y/{gsub(/ /,"",$2); print $2}')"
    if ((y < 60)); then
        pass "it is re-placed at the top when shown, wherever it was moved (y=$y)"
    else
        fail "the re-shown dropterm stayed where it was dragged (y=$y), not at the top"
    fi

    xdotool key --clearmodifiers super+grave
    sleep 0.3
    xdotool key --clearmodifiers alt+1
    sleep 0.2
}
