#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-notify, the notification centre.
#
# What is asserted:
#   * the list is dunst's history newest first, one line per notification
#     with markup stripped, entities decoded once (&amp;lt; stays "&lt;") and
#     newlines/tabs folded, below a focus-mode entry and "Clear all (N)";
#   * dmenu is placed by the xyw flags (-x negative = from the right edge)
#     and gets NO colour flags, which would override the X-resource theme;
#   * open = history-pop of THAT id plus xdg-open of its first link, decoded;
#     in focus mode it resumes dunst first; no link, or a link that is not
#     http(s)/ftp/mailto, opens nothing;
#   * delete = history-rm of that id, then the list comes back re-read;
#   * clear all, focus toggle, Escape, empty history, a typed non-entry and
#     a dunst that does not answer each do exactly what they say;
#   * every change re-renders the bell block (signal 12).
#
# The history is tests/fixtures/dunst-history-1.13.2.json, captured from a
# real dunst 1.13.2 (private D-Bus session + Xvfb, three gdbus Notify calls,
# close-all, `dunstctl history`), so the jq filter runs on the real format.
#
# SAFETY: dunstctl, dmenu, pkill, xdg-open and setsid are fakes on a sealed
# PATH — a real dunstctl would clear the tester's own notification history.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SUT="$DOTS_DIR/config/dwm/bin/dwm-notify"
FIXTURE="$SCRIPT_DIR/fixtures/dunst-history-1.13.2.json"
if ! command -v jq >/dev/null 2>&1; then
    yellow "  skip: jq not installed (dwm-notify needs it; packages/desktop.lst)"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/calls.log"
BIN="$TMP/bin"
ST="$TMP/state"
mkdir -p "$ST"

rc=0
check() { # <description> <actual> <expected>
    if [[ "$2" == "$3" ]]; then green "  ok: $1"; else
        red "  FAIL: $1 — got [$2], want [$3]"
        rc=1
    fi
}

seal_path "$BIN" bash cat tr jq
# dunstctl: history from $ST/history.json (history-rm really removes, so a
# re-shown list proves it was re-read); is-paused from $ST/paused; "down"
# in $ST/paused makes every call fail like a dunst that does not answer.
fake "$BIN" dunstctl "echo \"dunstctl \$*\" >>'$LOG'
[[ \"\$(cat '$ST/paused')\" == down ]] && exit 1
case \"\$1\" in
history) cat '$ST/history.json' ;;
is-paused) cat '$ST/paused' ;;
set-paused) [[ \"\$2\" == toggle ]] && { [[ \"\$(cat '$ST/paused')\" == true ]] && v=false || v=true; } || v=\"\$2\"; echo \"\$v\" >'$ST/paused' ;;
history-rm) jq --argjson id \"\$2\" '.data[0] |= map(select(.id.data != \$id))' '$ST/history.json' >'$ST/h.new'; cat '$ST/h.new' >'$ST/history.json' ;;
esac"
# dmenu logs its flags and the entries it was offered (one call per line),
# then answers successive prompts from FAKE_MENU ("a|b"); ESC = Escape.
fake "$BIN" dmenu "echo \"dmenu \$* <\$(tr '\n' ',' </dev/stdin)>\" >>'$LOG'
n=\$(cat '$TMP/menu.n' 2>/dev/null || echo 0); echo \$((n + 1)) >'$TMP/menu.n'
IFS='|' read -ra a <<<\"\${FAKE_MENU:-}\"; ans=\"\${a[\$n]:-ESC}\"; [[ \"\$ans\" == ESC ]] && exit 1; echo \"\$ans\""
# shellcheck disable=SC2016 # the fake bodies expand when the fake runs
fake "$BIN" timeout 'shift; exec "$@"'
# shellcheck disable=SC2016
fake "$BIN" setsid '[[ "$1" == -f ]] && shift; exec "$@"'
for t in pkill xdg-open; do
    fake "$BIN" "$t" "echo \"$t \$*\" >>'$LOG'"
done

# run <paused> [FAKE_MENU=...] [-- args]; fresh history, log and counter.
run() {
    local paused="$1" menu="${2:-}"
    shift 2 || shift
    [[ "${1:-}" == -- ]] && shift
    cp "$FIXTURE" "$ST/history.json"
    echo "$paused" >"$ST/paused"
    : >"$LOG"
    rm -f "$TMP/menu.n"
    RC=0
    env -i PATH="$BIN" FAKE_MENU="$menu" bash "$SUT" "$@" >/dev/null 2>"$TMP/err" || RC=$?
}
# Everything but the dmenu lines and the read-only dunstctl queries.
actions() { grep -v -e '^dmenu ' -e '^dunstctl history$' -e '^dunstctl is-paused' "$LOG" | tr '\n' ';'; }
menu_n() { grep '^dmenu ' "$LOG" | sed -n "${1}p"; }

L_FIREFOX="Firefox: Download complete — report.pdf saved — open or https://example."
L_PLAIN="notify-send: Plain summary"
L_MAIL="Mail: Re: tabs and lines — first line second &lt;kept&gt; line"
SIG="pkill -RTMIN+12 dwmblocks;"

blue "==> the list"
run false ""
check "Escape: changes nothing" "$(actions)" ""
check "entries: focus, clear all, history newest first" "$(menu_n 1 | sed 's/^.*<//')" \
    "󰂛  Turn on focus mode,󰎟  Clear all (3),$L_FIREFOX,$L_PLAIN,$L_MAIL,>"
flags="$(menu_n 1 | sed 's/ <.*//')"
check "placed top-right by the xyw flags" "$(grep -o -- '-x -12 -y 36 -z 560' <<<"$flags")" "-x -12 -y 36 -z 560"
check "no colour flags (the X-resource theme wins)" "$(grep -cE -- ' -(nb|nf|sb|sf) ' <<<"$flags")" "0"
check "the prompt carries the count" "$(grep -o -- '-p 󰂚 3' <<<"$flags")" "-p 󰂚 3"
run true ""
check "paused: the first entry turns focus mode off" "$(menu_n 1 | sed 's/^.*<//; s/,.*//')" "󰂚  Turn off focus mode"

blue "==> open"
run false "$L_FIREFOX|open"
check "pops that id, opens its first link decoded" "$(actions)" \
    "dunstctl history-pop 4;xdg-open https://example.org/files?id=1&v=2;"
check "the item menu offers open/delete/back" "$(menu_n 2 | sed 's/^.*<//')" "open,delete,back,>"
run true "$L_FIREFOX|open"
check "focus mode: resumes dunst first" "$(actions)" \
    "dunstctl set-paused false;${SIG}dunstctl history-pop 4;xdg-open https://example.org/files?id=1&v=2;"
run false "$L_MAIL|open"
check "no link: only the pop" "$(actions)" "dunstctl history-pop 2;"
jq '.data[0][0].urls.data = "[x] javascript:alert(1)\nhttps://ok.example/"' "$FIXTURE" >"$TMP/fixture.json"
FIXTURE="$TMP/fixture.json" run false "$L_FIREFOX|open"
check "a first link with another scheme is not opened" "$(actions)" "dunstctl history-pop 4;"
jq '.data[0][0].urls.data = "-flag"' "$SCRIPT_DIR/fixtures/dunst-history-1.13.2.json" >"$TMP/fixture.json"
FIXTURE="$TMP/fixture.json" run false "$L_FIREFOX|open"
check "a link that looks like a flag is not opened" "$(actions)" "dunstctl history-pop 4;"

blue "==> delete, back, clear, focus"
run false "$L_PLAIN|delete"
check "delete: history-rm of that id, bar refreshed" "$(actions)" "dunstctl history-rm 3;$SIG"
check "...and the list comes back re-read, without it" "$(menu_n 3 | sed 's/^.*<//')" \
    "󰂛  Turn on focus mode,󰎟  Clear all (2),$L_FIREFOX,$L_MAIL,>"
run false "$L_PLAIN|back"
check "back: nothing changed, the list comes back" "$(actions)|$(menu_n 3 | grep -c 'Clear all (3)')" "|1"
run false "$L_PLAIN"
check "Escape in the item menu closes the centre" "$(grep -c '^dmenu ' "$LOG")|$(actions)" "2|"
run false "󰎟  Clear all (3)"
check "clear all" "$(actions)" "dunstctl history-clear;$SIG"
run false "󰂛  Turn on focus mode"
check "focus entry toggles" "$(actions)|$(cat "$ST/paused")" "dunstctl set-paused toggle;$SIG|true"
run false "" -- toggle
check "dwm-notify toggle" "$(actions)|$(grep -c '^dmenu ' "$LOG")" "dunstctl set-paused toggle;$SIG|0"
run false "nonsense typed"
check "typed text matching no entry: nothing" "$(actions)" ""

blue "==> edge cases"
jq '.data[0] = []' "$SCRIPT_DIR/fixtures/dunst-history-1.13.2.json" >"$TMP/fixture.json"
FIXTURE="$TMP/fixture.json" run false "No notifications"
check "empty history: says so, does nothing" "$(menu_n 1 | sed 's/^.*<//')|$(actions)" \
    "󰂛  Turn on focus mode,No notifications,>|"
run down ""
check "dunst does not answer: says so" "$(menu_n 1 | sed 's/^.*<//')" "dunst does not answer,>"
jq '.data[0] |= reverse' "$SCRIPT_DIR/fixtures/dunst-history-1.13.2.json" >"$TMP/fixture.json"
FIXTURE="$TMP/fixture.json" run false ""
check "newest first by timestamp, whatever order dunst lists them in" \
    "$(menu_n 1 | sed 's/^.*<//')" "󰂛  Turn on focus mode,󰎟  Clear all (3),$L_FIREFOX,$L_PLAIN,$L_MAIL,>"
jq '.data = "not a list"' "$SCRIPT_DIR/fixtures/dunst-history-1.13.2.json" >"$TMP/fixture.json"
FIXTURE="$TMP/fixture.json" run false ""
check "a history jq cannot read: says so, not \"No notifications\"" \
    "$(menu_n 1 | sed 's/^.*<//')" "cannot read dunst's history,>"
run false "" -- bogus
check "unknown command: exit 2" "$RC" "2"
rm "$BIN/jq"
run false ""
check "no jq: exit 1 with a message, no menu" "$RC|$(grep -c '^dmenu ' "$LOG")|$(cat "$TMP/err")" \
    "1|0|dwm-notify: jq not found"

if ((rc == 0)); then green "notify-center: all checks passed"; else red "notify-center: FAILED"; fi
exit "$rc"
