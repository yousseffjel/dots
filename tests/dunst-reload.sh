#!/usr/bin/env bash
# A theme apply must reload dunst in place, never restart it: a restarted
# dunst has an empty history and is unpaused, so every wallpaper change used
# to empty the notification centre and silently end focus mode.
#
# What is asserted:
#   * scripts/theme/reload.sh (and the reload-dunst.sh it sources), run for real on a sealed PATH of fakes:
#     a running dunst gets `dunstctl reload`, with the pause level read
#     before and put back after (reload drops it to 0, like dunst 1.13.2);
#     an unpaused one gets no set-pause-level; a dunst that is not running,
#     or not installed, is not touched; a failed reload falls back to the
#     old kill; a failed restore says so in red;
#   * dunst.dcol's post-command kills nothing (reload.sh owns the step);
#   * the [dots_osd] rule (OSD pop-ups kept out of the history) is in both
#     dunst.dcol and the static config/dunst/dunstrc, identical;
#   * with dunst, dbus-run-session and Xvfb on the host: the same reload.sh
#     against a REAL dunst on a private bus keeps the history and the pause
#     level, and the shipped dunstrc keeps a dwm-osd pop-up out of history;
#   * the [dots_sound] rule (notification sounds) is in both files, identical,
#     and that real dunst runs its script for each notification it SHOWS,
#     never for one focus mode holds back (a critical one included).
#
# SAFETY: the fake run never sees a real dunst. The real run uses its own
# D-Bus session and Xvfb with WAYLAND_DISPLAY unset (inherited, a Wayland
# host would draw the test pop-ups on the tester's screen), and pkill is a
# fake there too: reload.sh's fallback `pkill -x dunst` would otherwise hit
# the tester's own dunst.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

RELOAD="$DOTS_DIR/scripts/theme/reload.sh"
DCOL="$DOTS_DIR/config/theme/templates/always/dunst.dcol"
STATIC="$DOTS_DIR/config/dunst/dunstrc"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/calls.log"
BIN="$TMP/bin"
ST="$TMP/state"
mkdir -p "$ST" "$TMP/home"

rc=0
check() { # <description> <actual> <expected>
    if [[ "$2" == "$3" ]]; then green "  ok: $1"; else
        red "  FAIL: $1 — got [$2], want [$3]"
        rc=1
    fi
}

seal_path "$BIN" bash mkdir cat dirname
fake "$BIN" dunst 'exit 0'
fake "$BIN" timeout 'shift; exec "$@"'
# pgrep finds dunst only while $ST/running exists; nothing else runs.
fake "$BIN" pgrep "[[ \"\$*\" == '-x dunst' && -e '$ST/running' ]]"
fake "$BIN" pkill "echo \"pkill \$*\" >>'$LOG'"
# dunstctl keeps the pause level in $ST/level. reload drops it to 0, as the
# real one does; $ST/fail-<cmd> makes that subcommand fail.
fake "$BIN" dunstctl "echo \"dunstctl \$*\" >>'$LOG'
[[ -e \"$ST/fail-\$1\" ]] && exit 1
case \"\$1\" in
get-pause-level) cat '$ST/level' ;;
set-pause-level) echo \"\$2\" >'$ST/level' ;;
reload) echo 0 >'$ST/level' ;;
esac"

# run <level> [running] [fail-cmd]; RC, OUT, and the dunst lines of the log.
run() {
    rm -f "$ST"/fail-* "$ST/running"
    echo "$1" >"$ST/level"
    [[ "${2:-}" == running ]] && : >"$ST/running"
    [[ -n "${3:-}" ]] && : >"$ST/fail-$3"
    : >"$LOG"
    RC=0
    OUT="$(env -i PATH="$BIN" HOME="$TMP/home" XDG_CACHE_HOME="$TMP/home/.cache" \
        DISPLAY=:99 bash "$RELOAD" 2>&1)" || RC=$?
    OUT="$(grep '^.\[[0-9]*mdunst ' <<<"$OUT" | sed 's/\x1b\[[0-9;]*m//g' || true)"
}
calls() { tr '\n' ';' <"$LOG"; }

blue "==> reload.sh, fakes"
run 1 running
check "paused: level read, reload, level put back" "$(calls)" \
    "dunstctl get-pause-level;dunstctl reload;dunstctl set-pause-level 1;"
check "...and focus mode survives" "$(cat "$ST/level")" "1"
check "...reported as kept" "$OUT" "dunst   reloaded (history and focus mode kept)"
run 3 running
check "any pause level is put back, not just 1" "$(cat "$ST/level")" "3"
run 0 running
check "unpaused: reload only, no kill" "$(calls)" "dunstctl get-pause-level;dunstctl reload;"
run garbage running
check "an unreadable level counts as unpaused" "$(calls)" "dunstctl get-pause-level;dunstctl reload;"
run 1
check "not running: dunst is not touched (D-Bus starts it later)" "$(calls)|$OUT" \
    "|dunst   not running — skipped"
run 1 running reload
check "reload fails: falls back to the old kill" "$(calls)" \
    "dunstctl get-pause-level;dunstctl reload;pkill -x dunst;"
check "...and says what was lost" "$OUT" \
    "dunst   reload failed — restarted instead (history and focus mode lost)"
run 2 running set-pause-level
check "restore fails: says so in red, never claims it was kept" "$OUT" \
    "dunst   reloaded, but focus mode could not be restored — Super+Shift+n turns it back on"
check "reload.sh still exits 0 (best-effort contract)" "$RC" "0"
rm "$BIN/dunst"
run 1 running
check "dunst not installed: skipped" "$(calls)|$OUT" "|dunst   not installed — skipped"

blue "==> the dunst configs"
check "dunst.dcol's post-command kills nothing" \
    "$(head -n1 "$DCOL" | grep -c 'pkill' || true)" "0"
osd_block() { sed -n '/^# The volume \/ mic \/ brightness pop-up/,/^    history_ignore = yes$/p' "$1"; }
check "the [dots_osd] rule is in dunst.dcol" "$(osd_block "$DCOL" | grep -c '^\[dots_osd\]$')" "1"
check "...and identical in the static dunstrc" "$(osd_block "$STATIC")" "$(osd_block "$DCOL")"
sound_block() { sed -n '/^# Notification sounds/,/^    script = dwm-sound-notify$/p' "$1"; }
check "the [dots_sound] rule is in dunst.dcol" "$(sound_block "$DCOL" | grep -c '^\[dots_sound\]$')" "1"
check "...and identical in the static dunstrc" "$(sound_block "$STATIC")" "$(sound_block "$DCOL")"
check "rule scripts run only for a shown notification, in both" \
    "$(grep -h '^    always_run_script' "$DCOL" "$STATIC" | sort -u)" "    always_run_script = false"

blue "==> reload.sh against a real dunst (private D-Bus + Xvfb)"
# dunstctl is a POSIX shell script over dbus-send, busctl and jq.
need=(dunst dunstctl dunstify notify-send dbus-run-session Xvfb xdpyinfo pgrep timeout dbus-send busctl jq)
missing=()
for t in "${need[@]}"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
if ((${#missing[@]})); then
    yellow "  skip: needs ${missing[*]}"
else
    REAL="$TMP/real"
    seal_path "$REAL" bash mkdir cat dirname dunst dunstctl pgrep timeout dbus-send busctl jq
    fake "$REAL" pkill "echo \"pkill \$*\" >>'$LOG'"
    # The rule's script, found on dunst's PATH: a logging fake ahead of the
    # real one (on the tester's PATH after an install), which would PLAY.
    mkdir -p "$TMP/snd"
    fake "$TMP/snd" dwm-sound-notify "echo \"\$5\" >>'$TMP/snd.log'"
    cat >"$TMP/real.sh" <<EOF
set -u
export DISPLAY=:97
Xvfb :97 -screen 0 800x600x24 >/dev/null 2>&1 & xp=\$!
for _ in \$(seq 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.1; done
PATH='$TMP/snd':\$PATH dunst -config '$STATIC' >/dev/null 2>&1 & dp=\$!
# Wait until OUR dunst owns the name. Asking dunstctl sooner would make D-Bus
# activate a second dunst with the default config, and ours would exit.
owned() { dbus-send --session --print-reply --dest=org.freedesktop.DBus / \\
    org.freedesktop.DBus.NameHasOwner string:org.freedesktop.Notifications 2>/dev/null | grep -q 'boolean true'; }
for _ in \$(seq 50); do owned && break; sleep 0.1; done
notify-send one; notify-send two
# The OSD expires on its own, as dwm-osd's does (1.5 s there).
dunstify -a dwm-osd -u low -t 300 -h string:x-dunst-stack-tag:dwm-osd-volume "Volume  50%"
sleep 0.8; dunstctl close-all; sleep 0.2
dunstctl set-pause-level 2
before="\$(dunstctl count history)"
env -i PATH='$REAL' HOME='$TMP/home' XDG_CACHE_HOME='$TMP/home/.cache' DISPLAY=:97 \
    DBUS_SESSION_BUS_ADDRESS="\$DBUS_SESSION_BUS_ADDRESS" bash '$RELOAD' >/dev/null 2>&1
echo "\$before|\$(dunstctl count history)|\$(dunstctl get-pause-level)|\$(kill -0 \$dp 2>/dev/null && echo alive)"
notify-send held; notify-send -u critical held-too; sleep 0.5
echo "sounds:\$(paste -sd, '$TMP/snd.log')"
kill \$dp \$xp 2>/dev/null
EOF
    : >"$LOG"
    out="$(timeout 60 env -u WAYLAND_DISPLAY dbus-run-session -- bash "$TMP/real.sh" 2>/dev/null || true)"
    res="$(grep -v '^sounds:' <<<"$out" | tail -n1)"
    check "history (OSD excluded), kept history, pause level, same dunst" "$res" "2|2|2|alive"
    # one, two and the low OSD (dwm-sound-notify drops it); then focus mode
    # is on, and neither the normal nor the critical one shows.
    check "the sound rule runs per shown notification, never in focus mode" \
        "$(grep '^sounds:' <<<"$out")" "sounds:NORMAL,NORMAL,LOW"
    check "...and nothing was killed" "$(calls)" ""
fi

if ((rc == 0)); then green "dunst-reload: all checks passed"; else red "dunst-reload: FAILED"; fi
exit "$rc"
