#!/usr/bin/env bash
# Runs the real config/dwm/bin/dwm-calendar (the clock's popup) on a private
# Xvfb with a private session bus, and asserts:
#
#   * its window's WM_CLASS is one a rules[] entry in config.def.h floats
#     (read with xprop, matched by strstr the way dwm's applyrules does);
#   * it is a dialog-type window with no decorations asked of dwm;
#   * a second launch closes the first and exits (the clock's toggle);
#   * with no session bus it still opens;
#   * it closes when another window takes the focus (needs xterm).
#
# The clock block's side (which binary it starts, the notify-send fallback)
# is tests/blocks-info.sh. SKIPS without Xvfb, xdotool, xprop,
# dbus-run-session or a python3 that imports GTK 3: those are the things
# under test, and faking them would test the fakes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/dwm-runtime-floating.sh
source "$SCRIPT_DIR/lib/dwm-runtime-floating.sh"

SUT="$DOTS_DIR/config/dwm/bin/dwm-calendar"

skip() {
    yellow "SKIP: dwm-calendar.sh needs $1 and it is not available."
    exit 0
}
for t in Xvfb xdotool xprop dbus-run-session python3; do
    command -v "$t" >/dev/null 2>&1 || skip "$t"
done
python3 -c 'import gi; gi.require_version("Gtk", "3.0"); from gi.repository import Gtk' \
    >/dev/null 2>&1 || skip "python3-gobject with GTK 3"

TMP="$(mktemp -d)"
XPID=""
cleanup() {
    [[ -z "$XPID" ]] || kill "$XPID" 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

# -displayfd: Xvfb picks a free display and writes its number once it is up.
Xvfb -displayfd 3 -screen 0 1280x800x24 -nolisten tcp 3>"$TMP/display" >/dev/null 2>&1 &
XPID=$!
for _ in $(seq 1 50); do
    [[ -s "$TMP/display" ]] && break
    sleep 0.1
done
[[ -s "$TMP/display" ]] || {
    red "FAIL: Xvfb did not start"
    exit 1
}
DISPLAY=":$(cat "$TMP/display")"
export DISPLAY

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

# window_id — the calendar's window, waiting up to 4 s for it to map.
window_id() {
    local id=""
    for _ in $(seq 1 40); do
        id="$(xdotool search --classname dots-float-calendar 2>/dev/null | head -n 1)" || true
        [[ -n "$id" ]] && break
        sleep 0.1
    done
    printf '%s' "$id"
}

# Everything under one session bus, as ~/.xinitrc runs the desktop. The body
# prints `key=value` lines read back below; stderr (the bus's own chatter)
# goes to a log.
dbus-run-session -- bash -s "$SUT" >"$TMP/out" 2>"$TMP/bus.log" <<'EOF'
set -u
SUT="$1"
"$SUT" &
first=$!
for _ in $(seq 1 40); do
    id="$(xdotool search --classname dots-float-calendar 2>/dev/null | head -n 1)" && [ -n "$id" ] && break
    sleep 0.1
done
echo "id=${id:-}"
[ -n "${id:-}" ] || exit 0
echo "class=$(xprop -id "$id" WM_CLASS | sed 's/^[^=]*= //')"
echo "type=$(xprop -id "$id" _NET_WM_WINDOW_TYPE | sed 's/^[^=]*= //')"
timeout 5 "$SUT"
echo "second_rc=$?"
for _ in $(seq 1 30); do
    kill -0 "$first" 2>/dev/null || break
    sleep 0.1
done
if kill -0 "$first" 2>/dev/null; then echo "first=running"; kill "$first"; else echo "first=closed"; fi
EOF
val() { sed -n "s/^$1=//p" "$TMP/out"; }

blue "dwm-calendar"
check "opens a window" test -n "$(val id)"
class="$(val class)"
check "WM_CLASS is dots-float-calendar (got: $class)" test "$class" = '"dots-float-calendar", "dots-float-calendar"'
floated=0
while read -r rule; do [[ -n "$rule" && "$class" == *"$rule"* ]] && floated=1; done < <(float_rule_classes)
check "a rules[] entry floats that class" test "$floated" = 1
check "a dialog-type window" test "$(val type)" = "_NET_WM_WINDOW_TYPE_DIALOG"
check "a second launch exits at once" test "$(val second_rc)" = 0
check "...and closes the open one (the clock's toggle)" test "$(val first)" = closed

blue "no session bus"
# An address that cannot connect, not merely an unset one: with none set,
# GLib may autolaunch a bus over X11 and this would test the bus case again.
DBUS_SESSION_BUS_ADDRESS="unix:path=$TMP/no-bus" "$SUT" >/dev/null 2>&1 &
nobus=$!
id="$(window_id)"
check "still opens a window" test -n "$id"
kill "$nobus" 2>/dev/null || true
wait "$nobus" 2>/dev/null || true

blue "focus"
if command -v xterm >/dev/null 2>&1; then
    xterm -class dwm-calendar-other -e sleep 30 >/dev/null 2>&1 &
    other_pid=$!
    # A dead bus address, like the section above: never the caller's own bus.
    DBUS_SESSION_BUS_ADDRESS="unix:path=$TMP/no-bus" "$SUT" >/dev/null 2>&1 &
    cal=$!
    id="$(window_id)"
    other=""
    for _ in $(seq 1 40); do
        other="$(xdotool search --class dwm-calendar-other 2>/dev/null | head -n 1)" || true
        [[ -n "$other" ]] && break
        sleep 0.1
    done
    sleep 0.3
    [[ -z "$id" ]] || xdotool windowfocus --sync "$id" 2>/dev/null || true
    sleep 0.3
    check "focused, it stays open" kill -0 "$cal"
    [[ -z "$other" ]] || xdotool windowfocus "$other" 2>/dev/null || true
    sleep 0.6
    check "another window takes the focus: it closes" bash -c "! kill -0 $cal 2>/dev/null"
    kill "$cal" "$other_pid" 2>/dev/null || true
else
    yellow "  skipped (no xterm to take the focus)"
fi

if [[ $FAILS -gt 0 ]]; then
    red "$FAILS check(s) failed"
    exit 1
fi
green "✓ dwm-calendar: the clock's popup floats and toggles"
