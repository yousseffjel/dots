#!/usr/bin/env bash
# Mouse sections of tests/dwm-runtime.sh: the Hyprland-style move/resize
# patches (resizepoint, placemouse, cfacts + dragtile, snapwindows,
# preservecfact). SOURCED, never run on its own (tests/lib/ is outside
# run-tests.sh's depth-1 glob). Uses the caller's pass/fail and the helpers in
# dwm-runtime-x.sh. Everything runs on tag 9, which no other section uses, and
# closes its windows before it returns.
#
# The drags are real pointer events through xdotool, held Super included:
# dwm's own button grab is what is under test, so nothing is synthesised
# inside the window. Geometry is read back with xwininfo and compared with a
# tolerance where tile() rounds through an xterm's size increments.

# Outer geometry of <win>, border included: "x y w h", dwm's c->x/y and
# WIDTH()/HEIGHT(). xwininfo's absolute position is already the border's
# outer corner (a master tiled at x = 0 reads 0); its size is the inside.
outer_geom() {
    local info x y w h bw
    info="$(xwininfo -id "$1" 2>/dev/null)" || {
        echo "0 0 0 0"
        return 0
    }
    x="$(awk -F: '/Absolute upper-left X/{gsub(/ /,"",$2); print $2}' <<<"$info")"
    y="$(awk -F: '/Absolute upper-left Y/{gsub(/ /,"",$2); print $2}' <<<"$info")"
    w="$(awk -F: '/^  Width/{gsub(/ /,"",$2); print $2}' <<<"$info")"
    h="$(awk -F: '/^  Height/{gsub(/ /,"",$2); print $2}' <<<"$info")"
    bw="$(awk -F: '/Border width/{gsub(/ /,"",$2); print $2}' <<<"$info")"
    echo "$x $y $((w + 2 * bw)) $((h + 2 * bw))"
}

# drag <button> <x0> <y0> <x1> <y1>: Super held, in ten steps, so dwm's
# refreshrate throttle sees motion rather than one jump.
mouse_drag() {
    local b="$1" x0="$2" y0="$3" x1="$4" y1="$5" i
    xdotool mousemove "$x0" "$y0"
    sleep 0.2
    xdotool keydown super mousedown "$b"
    sleep 0.1
    for i in $(seq 1 10); do
        xdotool mousemove "$((x0 + (x1 - x0) * i / 10))" "$((y0 + (y1 - y0) * i / 10))"
        sleep 0.03
    done
    sleep 0.1
    xdotool mouseup "$b" keyup super
    sleep 0.4
}

# The pointer's "x y" now.
pointer_at() {
    xdotool getmouselocation --shell | awk -F= '/^X=/{x=$2} /^Y=/{y=$2} END{print x, y}'
}

# near <a> <b> <tolerance>
near() {
    local d=$(($1 - $2))
    ((${d#-} <= $3))
}

# mouse_floating_win <var> <x> <y> <w> <h>: a new window, floated, at that
# geometry; its id goes into <var>.
mouse_floating_win() {
    local _mfw
    _mfw="$(spawn_win)"
    xdotool key --clearmodifiers super+shift+space
    sleep 0.2
    # Size first: a just-floated window is still screen-sized, and dwm
    # re-centres a floating window moved partly off the monitor.
    xdotool windowsize "$_mfw" "$4" "$5"
    sleep 0.2
    xdotool windowmove "$_mfw" "$2" "$3"
    sleep 0.3
    printf -v "$1" '%s' "$_mfw"
}

# resizepoint: grab near the top-left corner and drag up-left; the bottom-right
# corner must stay put and the pointer must stay where it was released.
check_resizepoint() {
    local w x y gw gh x2 y2 gw2 gh2 p
    mouse_floating_win w 300 300 400 300
    read -r x y gw gh <<<"$(outer_geom "$w")"
    mouse_drag 3 "$((x + 15))" "$((y + 15))" "$((x - 45))" "$((y - 25))"
    read -r x2 y2 gw2 gh2 <<<"$(outer_geom "$w")"
    if near $((x2 + gw2)) $((x + gw)) 2 && near $((y2 + gh2)) $((y + gh)) 2 \
        && near "$x2" $((x - 60)) 3 && near "$y2" $((y - 40)) 3; then
        pass "resizepoint: a top-left grab resizes from that corner (${gw}x$gh -> ${gw2}x$gh2), the opposite corner fixed"
    else
        fail "resizepoint: $x,$y ${gw}x$gh became $x2,$y2 ${gw2}x$gh2 after a top-left drag of -60,-40"
    fi
    p="$(pointer_at)"
    if [[ "$p" == "$((x - 45)) $((y - 25))" ]]; then
        pass "resizepoint: the pointer is not warped to a corner"
    else
        fail "resizepoint: the pointer ended at $p, not where it was released ($((x - 45)) $((y - 25)))"
    fi
    xdotool windowkill "$w"
}

# snapwindows: B's left edge is 8px right of where A's right edge is dragged
# to (under windowsnap); A must end flush against B.
check_snapwindows() {
    local a b ax ay aw bx
    mouse_floating_win a 100 300 300 200
    mouse_floating_win b 700 300 300 200
    read -r ax ay aw _ <<<"$(outer_geom "$a")"
    read -r bx _ _ _ <<<"$(outer_geom "$b")"
    mouse_drag 1 "$((ax + 50))" "$((ay + 50))" "$((ax + 50 + bx - 8 - ax - aw))" "$((ay + 70))"
    read -r ax ay aw _ <<<"$(outer_geom "$a")"
    if ((ax + aw == bx)); then
        pass "snapwindows: a floating window dragged 8px short of another snaps flush to it"
    else
        fail "snapwindows: A's right edge is at $((ax + aw)), B's left at $bx — no snap"
    fi
    if near "$ay" 320 3; then
        pass "a floating window moves freely on the other axis (y=$ay)"
    else
        fail "the floating window's y is $ay after a +20 drag from 300"
    fi
    xdotool windowkill "$a"
    xdotool windowkill "$b"
}

# Three tiled windows: m is master, s1 above s2 in the stack.
mouse_tiled_three() {
    local w1 w2 w3
    w1="$(spawn_win)"
    w2="$(spawn_win)"
    w3="$(spawn_win)"
    sleep 0.3
    TILE_M="$w3" TILE_S1="$w2" TILE_S2="$w1"
}

# dragtile: a vertical drag in s1's bottom half moves only the s1/s2 edge; a
# horizontal one moves the split. The pointer never warps.
check_dragtile() {
    local mx my mw mh s1x s1y s1w s1h s2h mh2 mw2 s1h2 s2h2 x y
    read -r mx my mw mh <<<"$(outer_geom "$TILE_M")"
    read -r s1x s1y s1w s1h <<<"$(outer_geom "$TILE_S1")"
    read -r _ _ _ s2h <<<"$(outer_geom "$TILE_S2")"
    x=$((s1x + s1w / 2)) y=$((s1y + s1h * 3 / 4))
    mouse_drag 3 "$x" "$y" "$x" "$((y + 100))"
    read -r _ _ mw2 mh2 <<<"$(outer_geom "$TILE_M")"
    read -r _ _ _ s1h2 <<<"$(outer_geom "$TILE_S1")"
    read -r _ _ _ s2h2 <<<"$(outer_geom "$TILE_S2")"
    if near $((s1h2 - s1h)) 100 20 && near $((s2h - s2h2)) 100 20 && ((mw2 == mw && mh2 == mh)); then
        pass "dragtile: down 100px grows the stack window ${s1h} -> ${s1h2}, its neighbour gives it up, master untouched"
    else
        fail "dragtile vertical: s1 $s1h -> $s1h2, s2 $s2h -> $s2h2, master ${mw}x$mh -> ${mw2}x$mh2"
    fi
    [[ "$(pointer_at)" == "$x $((y + 100))" ]] || fail "dragtile: the pointer was warped, now at $(pointer_at)"
    mouse_drag 3 "$((mx + mw / 2))" "$((my + mh / 2))" "$((mx + mw / 2 + 128))" "$((my + mh / 2))"
    read -r _ _ mw2 _ <<<"$(outer_geom "$TILE_M")"
    read -r s1x _ _ _ <<<"$(outer_geom "$TILE_S1")"
    # The stack must start where the master now ends: the split moved, the
    # master was not merely resized over it.
    if near $((mw2 - mw)) 128 16 && near "$s1x" $((mx + mw2)) 8; then
        pass "dragtile: right 128px moves the master split (${mw} -> ${mw2}px, stack at x=$s1x)"
    else
        fail "dragtile horizontal: master width $mw -> $mw2, stack at x=$s1x, after a 128px drag"
    fi
}

# placemouse: master dragged onto the bottom stack window lands in the stack
# and stays tiled (flush with the screen's right edge, the stack's width).
check_placemouse() {
    local mx my mw mh sx sy sw sh x w ow
    read -r mx my mw mh <<<"$(outer_geom "$TILE_M")"
    read -r sx sy sw sh <<<"$(outer_geom "$TILE_S2")"
    mouse_drag 1 "$((mx + mw / 2))" "$((my + mh / 2))" "$((sx + sw / 2))" "$((sy + sh / 2))"
    read -r x _ w _ <<<"$(outer_geom "$TILE_M")"
    read -r _ _ ow _ <<<"$(outer_geom "$TILE_S2")"
    if ((x > mx + mw / 2)) && near $((x + w)) 1280 2 && near "$w" "$ow" 12; then
        pass "placemouse: the dragged master is now in the stack, still tiled (x=$x, ${w}px)"
    else
        fail "placemouse: after the drop the window is at x=$x, ${w}px wide (stack window ${ow}px)"
    fi
}

# cfacts keys, then preservecfact: one column (nmaster 2), so each height
# depends on its own cfact alone and not on the order a restart scans in.
check_cfact_restart() {
    local a b ha hb ha2 hb2
    a="$(spawn_win)"
    b="$(spawn_win)"
    xdotool key --clearmodifiers super+i
    xdotool key --clearmodifiers super+shift+k super+shift+k
    sleep 0.4
    read -r _ _ _ hb <<<"$(outer_geom "$b")"
    read -r _ _ _ ha <<<"$(outer_geom "$a")"
    if ((hb > ha + 100)); then
        pass "cfacts: Super+Shift+k makes the focused window taller (${hb} vs ${ha}px)"
    else
        fail "cfacts: two Super+Shift+k left heights at $hb (focused) and $ha"
    fi
    restart_dwm || fail "dwm did not come back from SIGHUP in the cfact check"
    sleep 1
    xdotool key --clearmodifiers super+9
    sleep 0.4
    read -r _ _ _ hb2 <<<"$(outer_geom "$b")"
    read -r _ _ _ ha2 <<<"$(outer_geom "$a")"
    if near "$hb2" "$hb" 15 && near "$ha2" "$ha" 15; then
        pass "preservecfact: the heights survive a restart ($hb/$ha -> $hb2/$ha2)"
    else
        fail "preservecfact: heights $hb/$ha became $hb2/$ha2 after a restart"
    fi
    # Focus came back with the restart (preserveonrestart), so this is b's.
    xdotool key --clearmodifiers super+shift+o
    sleep 0.4
    read -r _ _ _ hb2 <<<"$(outer_geom "$b")"
    read -r _ _ _ ha2 <<<"$(outer_geom "$a")"
    if near "$hb2" "$ha2" 15; then
        pass "cfacts: Super+Shift+o evens them out again ($hb2/$ha2)"
    else
        fail "cfacts: after Super+Shift+o the heights are $hb2 and $ha2"
    fi
    xdotool key --clearmodifiers super+d
    xdotool windowkill "$a"
    xdotool windowkill "$b"
}

check_mouse() {
    blue "==> Hyprland-style mouse (resizepoint, snapwindows, dragtile, placemouse, cfacts)"
    xdotool key --clearmodifiers super+9
    sleep 0.2
    check_resizepoint
    check_snapwindows
    mouse_tiled_three
    check_dragtile
    check_placemouse
    xdotool windowkill "$TILE_M"
    xdotool windowkill "$TILE_S1"
    xdotool windowkill "$TILE_S2"
    sleep 0.3
    check_cfact_restart
    xdotool key --clearmodifiers super+1
    sleep 0.2
}
