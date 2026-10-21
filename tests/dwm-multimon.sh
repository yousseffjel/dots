#!/usr/bin/env bash
# The built dwm on TWO monitors: one 3840x1080 Xvfb screen split into two
# RandR monitors with `xrandr --setmonitor`, which dwm reads through the
# server's Xinerama emulation exactly as it reads two real screens.
#
# What is asserted:
#   * dwm makes one bar per monitor;
#   * the status text is drawn on EVERY bar (statusallmons-local.diff), not
#     only on the selected monitor's — the user runs two screens and the
#     clock, volume and battery were on whichever one held the pointer;
#   * it stays on both when the selected monitor changes, and a status
#     update made while the other monitor is selected reaches both: the
#     two status regions must be pixel-identical, not merely non-empty;
#   * unplugging a monitor brings its windows to the one left, and plugging
#     it back RETURNS them, with the view (tag) they were on, while a window
#     that was on the remaining monitor stays (replug-local.diff). Stock dwm
#     left every window on the first monitor.
#
# Not covered: a window moved by hand while away (sendmon) must lose its
# home. With two monitors there is nowhere to move it while one is gone,
# and this Xvfb screen cannot be made wider for a third.
#
# An unplug is simulated the way a real one reaches dwm: the screen
# shrinks (a 1920-wide mode added to Xvfb's output, --fb), which is the
# root ConfigureNotify dwm re-reads its monitors on; a RandR monitor
# appearing or vanishing alone sends dwm nothing.
#
# The pixel identity also covers traywidth(): with the tray width taken off
# every bar, the bar without the tray draws its status shifted left by the
# (empty, 1 px) tray, and the two regions differ. Mutation-checked.
#
# Shares tests/lib/dwm-runtime-x.sh with tests/dwm-runtime.sh, so dwm runs
# in the same sandbox HOME (never the tester's autostart.sh). Skips loudly,
# like that test, when a tool or the built binary is missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DWM="$DOTS_DIR/suckless/dwm/dwm"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/dwm-runtime-x.sh
source "$SCRIPT_DIR/lib/dwm-runtime-x.sh"

skip() {
    yellow "SKIP: dwm-multimon.sh needs $1 and it is not available."
    exit 0
}
[[ -x "$DWM" ]] || skip "a built suckless/dwm/dwm binary (run tests/build.sh first)"
for t in Xvfb xdotool xrandr xsetroot xwininfo xdpyinfo import; do
    command -v "$t" >/dev/null 2>&1 || skip "$t"
done
if command -v magick >/dev/null 2>&1; then MAGICK=magick; elif command -v convert >/dev/null 2>&1; then MAGICK=convert; else skip "ImageMagick"; fi

TMP="$(mktemp -d)"
XVFB_PID=
DWM_PID=
WINCLASS="DwmMultimon$$"
cleanup() {
    local status=$?
    trap - EXIT
    set +e
    pkill -f "xterm -class $WINCLASS" 2>/dev/null
    [[ -n "$DWM_PID" ]] && kill "$DWM_PID" 2>/dev/null
    [[ -n "$XVFB_PID" ]] && kill "$XVFB_PID" 2>/dev/null
    wait 2>/dev/null
    rm -rf -- "$TMP"
    exit "$status"
}
trap cleanup EXIT
rc=0
check() {
    local name="$1"
    shift
    if "$@"; then green "  ok: $name"; else
        red "  FAIL: $name"
        rc=1
    fi
}

# The right end of the bar at screen x <x0> (STATUS_PX wide) holds text when
# it has more than a couple of colours; an empty bar is one flat colour.
STATUS_PX=300
# Prints the image signature of that region, or nothing when it is empty.
bar_status() {
    local x0="$1" w="$2" h="$3"
    import -window root -crop "${STATUS_PX}x${h}+$((x0 + w - STATUS_PX))+0" +repage "png:$TMP/bar.png" 2>/dev/null
    (($("$MAGICK" "$TMP/bar.png" -format '%k' info:) > 2)) || return 0
    "$MAGICK" "$TMP/bar.png" -format '%#' info:
}
# bars — "x width height" of each dwm bar window, left to right.
bars() {
    local w
    for w in $(xdotool search --class '^dwm$' 2>/dev/null); do
        xwininfo -id "$w" | awk -F: '/Absolute upper-left X/ { gsub(/ /, "", $2); x = $2 }
            /^  Width/ { gsub(/ /, "", $2); w = $2 } /^  Height/ { gsub(/ /, "", $2); h = $2 }
            END { if (h + 0 < 100) print x, w, h }'
    done | sort -n
}
# Both bars carry text, and the SAME pixels: a bar left with the previous
# status still has text, so text alone would pass a stale redraw. Each
# bar's right edge already excludes the tray (bar windows are resized).
status_on_every_bar() {
    local x w h sigs=()
    while read -r x w h; do
        sigs+=("$(bar_status "$x" "$w" "$h")")
    done < <(bars)
    ((${#sigs[@]} == 2)) && [[ -n "${sigs[0]}" && "${sigs[0]}" == "${sigs[1]}" ]]
}

XVFB_SCREEN=3840x1080x24 start_xvfb
xrandr --setmonitor L 1920/508x1080/286+0+0 screen >/dev/null
xrandr --setmonitor R 1920/508x1080/286+1920+0 none >/dev/null
start_dwm

blue "==> status on every bar"
check "two bars, one per monitor" test "$(bars | wc -l)" -eq 2
xdotool mousemove 2500 500
sleep 0.3
xsetroot -name "MULTIMON STATUS TEXT 12:34"
sleep 0.5
check "status drawn on both bars (right monitor selected)" status_on_every_bar
xdotool mousemove 300 500
sleep 0.5
check "...and still after selecting the left monitor" status_on_every_bar
xsetroot -name "UPDATED WHILE LEFT IS SELECTED 56:78"
sleep 0.5
check "a status update reaches both bars" status_on_every_bar

blue "==> unplug and replug"
win_x() { xwininfo -id "$1" 2>/dev/null | awk -F: '/Absolute upper-left X/ { gsub(/ /, "", $2); print $2 }'; }
viewable() { xwininfo -id "$1" 2>/dev/null | grep -q 'Map State: IsViewable'; }
on_left() { (($(win_x "$1") < 1920)) && viewable "$1"; }
on_right() { (($(win_x "$1") >= 1920)) && viewable "$1"; }
xdotool mousemove 300 500
sleep 0.3
WL="$(spawn_win)"
xdotool mousemove 2500 500
sleep 0.3
xdotool key super+2
sleep 0.3
WR="$(spawn_win)"
# A floating one too, at a known spot: the stock clamp would leave it
# wherever the unplug pushed it.
WF="$(spawn_win)"
# Focus follows the mouse: point at the new window before floating it.
eval "$(xdotool getwindowgeometry --shell "$WF")"
xdotool mousemove "$((X + WIDTH / 2))" "$((Y + HEIGHT / 2))"
sleep 0.3
xdotool key super+shift+space
sleep 0.3
# configurerequest() adds the monitor's origin to a floating window's x:
# 700 lands it at 2620.
xdotool windowmove "$WF" 700 400
sleep 0.5
FX="$(win_x "$WF")"
all_spawned() { [[ -n "$WL" && -n "$WR" && -n "$WF" ]]; }
check "a window on each monitor (the right one on tag 2)" all_spawned
check "...the floating one where it was put" test "$FX" -ge 2600
check "...left on the left" on_left "$WL"
check "...right on the right" on_right "$WR"
xrandr --newmode dotshalf 148.50 1920 2008 2052 2200 1080 1084 1089 1125 >/dev/null
xrandr --addmode screen dotshalf
xrandr --delmonitor R >/dev/null
xrandr --output screen --mode dotshalf --fb 1920x1080
sleep 1
check "unplugged: one bar" test "$(bars | wc -l)" -eq 1
left_of_1920() { (($(win_x "$1") < 1920)); }
check "...the right monitor's window came to the left one" left_of_1920 "$WR"
# View tag 2 here so the floating window is shown, and clamped onto this
# monitor; only its saved position can bring it back to its spot.
xdotool key super+2
sleep 0.5
check "...the floating one shown on the left while away" on_left "$WF"
xdotool key super+1
sleep 0.3
xrandr --setmonitor R 1920/508x1080/286+1920+0 none >/dev/null
xrandr --output screen --mode 3840x1080 --fb 3840x1080
sleep 1
check "replugged: two bars" test "$(bars | wc -l)" -eq 2
check "the window went back to the right monitor, its tag in view" on_right "$WR"
check "the left monitor's window stayed on the left" on_left "$WL"
check "the floating window came back to its spot ($FX)" test "$(win_x "$WF")" -eq "$FX"

# A second cycle with the window moved to tag 3 (and viewed there): a home
# left over from the first cycle would bring back tag 2's view instead.
# A restart sits in the middle of it.
# Its bottom-right corner: the floating window covers its middle.
eval "$(xdotool getwindowgeometry --shell "$WR")"
xdotool mousemove "$((X + WIDTH - 40))" "$((Y + HEIGHT - 40))"
sleep 0.3
xdotool key super+shift+3 super+3
sleep 0.5
xrandr --delmonitor R >/dev/null
xrandr --output screen --mode dotshalf --fb 1920x1080
sleep 1
# And a restart while away, as every wallpaper change sends: the home
# travels in preserveonrestart's _DWM_CLIENT_INFO.
check "dwm restarted while the monitor was gone" restart_dwm
xrandr --setmonitor R 1920/508x1080/286+1920+0 none >/dev/null
xrandr --output screen --mode 3840x1080 --fb 3840x1080
sleep 1
check "second replug, after a restart: back on the right, on tag 3's view" on_right "$WR"

if ((rc != 0)); then
    red "✗ dwm on two monitors"
    exit 1
fi
green "✓ dwm-multimon: a bar per monitor, the status on every one, windows return on replug"
