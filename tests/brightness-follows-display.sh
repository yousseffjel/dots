#!/usr/bin/env bash
# A screen X turns on again comes back at full gamma while the others stay
# dimmed (seen on the Void VM, 2026-10-21: Virtual-2 re-enabled at 1.0 beside
# Virtual-1 at 0.5). This proves the three pieces that put the level back:
#   * dwm-brightness records the level it sets on the gamma paths, and
#     `dwm-brightness sync` re-applies it to EVERY connected output; it does
#     nothing on a backlight, before any level was set, or with a corrupt
#     record, and defers to dwm-nightlight while that daemon owns the ramps;
#   * the autorandr hook config/autorandr/postswitch.d/20-dots-brightness runs
#     that sync with dwm/bin on PATH, and is a no-op without dwm-brightness;
#   * dwm-display runs it after a preset applies, never after one that failed;
#   * the restore stage deploys the hook as an executable, claimed copy.
#
# SAFETY: xrandr, brightnessctl, pgrep and dwm-nightlight are fakes on a
# sealed PATH (a real xrandr would change the tester's screens), and every
# HOME and XDG_STATE_HOME is under $TMP.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SUT="$DOTS_DIR/config/dwm/bin/dwm-brightness"
HOOK="$DOTS_DIR/config/autorandr/postswitch.d/20-dots-brightness"
DISPLAY_SH="$DOTS_DIR/config/dwm/bin/dwm-display"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
seal_path "$BIN" bash sh awk cat cut mkdir grep
LOG="$TMP/calls.log"
STATE="$TMP/state"
LEVEL="$STATE/dots/brightness"

rc=0
pass() { green "  ok: $1"; }
fail() {
    red "  FAIL: $1"
    rc=1
}

# Two connected outputs, the second just turned back on at full gamma.
printf -v TAB '\t'
cat >"$TMP/screens" <<EOF
Virtual-1 connected primary 1920x1080+0+0 (0x25) normal
${TAB}Brightness: 0.50
Virtual-2 connected 1920x1080+1920+0 (0x41) normal
${TAB}Brightness: 1.0
DP-9 disconnected (normal left inverted right x axis y axis)
${TAB}Brightness: 1.0
EOF
# The same machine with Virtual-2 switched off: connected, no geometry, no
# CRTC (the real shape, read on the Void VM 2026-10-21). Its xrandr refuses
# --brightness, so the fake fails a write to it as the real one does.
cat >"$TMP/one-off" <<EOF
Virtual-1 connected primary 1920x1080+0+0 (0x25) normal
${TAB}Brightness: 0.50
Virtual-2 connected (normal left inverted right x axis y axis)
EOF
fake "$BIN" xrandr "
S='$TMP/'\"\${FAKE_SCREENS:-screens}\"
if [[ \"\${1:-}\" == --output ]]; then
    echo \"xrandr \$*\" >>'$LOG'
    grep -q \"^\$2 connected [0-9]\" \"\$S\" || grep -q \"^\$2 connected primary [0-9]\" \"\$S\"
    exit
fi
if [[ \"\${1:-}\" == --verbose ]]; then cat \"\$S\"; exit 0; fi
awk '/^[^[:space:]]/' \"\$S\""
fake "$BIN" brightnessctl "
if [[ \"\$*\" == *' -m info'* ]]; then
    [[ -n \"\${FAKE_BACKLIGHT:-}\" ]] || { echo \"Failed to read any devices of class 'backlight'.\" >&2; exit 1; }
    echo 'intel_backlight,backlight,4882,51%,9600'; exit 0
fi
echo \"brightnessctl \$*\" >>'$LOG'"
fake "$BIN" pgrep "[[ -n \"\${FAKE_NIGHTLIGHT:-}\" ]]"
fake "$BIN" dwm-nightlight "echo \"dwm-nightlight \$*\" >>'$LOG'"

# brightness <args...> — dwm-brightness with only the sandbox state; sets RC.
brightness() {
    : >"$LOG"
    RC=0
    env -i PATH="$BIN" XDG_STATE_HOME="$STATE" \
        ${FAKE_BACKLIGHT+FAKE_BACKLIGHT=1} ${FAKE_NIGHTLIGHT+FAKE_NIGHTLIGHT=1} \
        ${FAKE_SCREENS+FAKE_SCREENS="$FAKE_SCREENS"} \
        bash "$SUT" "$@" >"$TMP/out" 2>"$TMP/err" || RC=$?
}
calls() { tr '\n' '|' <"$LOG"; }

blue "==> the level is recorded"
brightness sync
if [[ $RC -eq 0 && ! -s "$LOG" ]]; then
    pass "sync before any level was set: exit 0, nothing written"
else
    fail "sync with no record: rc=$RC calls=$(calls)"
fi
brightness set 40
if [[ "$(cat "$LEVEL" 2>/dev/null)" == 40 ]]; then
    pass "set 40 records 40 in \$XDG_STATE_HOME/dots/brightness"
else
    fail "set 40 recorded '$(cat "$LEVEL" 2>/dev/null)'"
fi
brightness down
if [[ "$(cat "$LEVEL" 2>/dev/null)" == 40 && "$(cat "$TMP/out")" == 40 ]]; then
    pass "down records the clamped result it applied (50 - 10 = 40)"
else
    fail "down: out='$(cat "$TMP/out")' recorded '$(cat "$LEVEL" 2>/dev/null)'"
fi
FAKE_NIGHTLIGHT=1 brightness set 70
if [[ "$(cat "$LEVEL" 2>/dev/null)" == 70 ]]; then
    pass "the nightlight path records it too (its last ramp outlives the daemon)"
else
    fail "nightlight set recorded '$(cat "$LEVEL" 2>/dev/null)'"
fi

blue "==> sync"
echo 40 >"$LEVEL"
brightness sync
if [[ $RC -eq 0 && "$(calls)" == "xrandr --output Virtual-1 --brightness 0.40|xrandr --output Virtual-2 --brightness 0.40|" ]]; then
    pass "re-applies 40 to every connected output, the disconnected one untouched"
else
    fail "sync: rc=$RC calls=$(calls)"
fi
if [[ ! -s "$TMP/out" ]]; then
    pass "prints nothing (a hook's output goes nowhere useful)"
else
    fail "sync printed '$(cat "$TMP/out")'"
fi
FAKE_BACKLIGHT=1 brightness sync
if [[ $RC -eq 0 && ! -s "$LOG" ]]; then
    pass "a backlight: no gamma write and no brightnessctl call"
else
    fail "backlight sync: rc=$RC calls=$(calls)"
fi
FAKE_NIGHTLIGHT=1 brightness sync
if [[ $RC -eq 0 && "$(calls)" == "dwm-nightlight apply|" ]]; then
    pass "the nightlight daemon running: its apply, no xrandr write"
else
    fail "nightlight sync: rc=$RC calls=$(calls)"
fi
echo garbage >"$LEVEL"
brightness sync
if [[ $RC -eq 0 && ! -s "$LOG" ]]; then
    pass "a corrupt record is ignored, nothing written"
else
    fail "corrupt record: rc=$RC calls=$(calls)"
fi
RC=0
env -i PATH="$BIN" bash "$SUT" set 60 >/dev/null 2>"$TMP/err" || RC=$?
if [[ $RC -eq 0 && ! -s "$TMP/err" ]]; then
    pass "no HOME and no XDG_STATE_HOME: set still works, records nothing"
else
    fail "set without HOME: rc=$RC err='$(cat "$TMP/err")'"
fi

blue "==> a connected screen that is switched off"
FAKE_SCREENS=one-off brightness set 30
if [[ $RC -eq 0 && "$(calls)" == "xrandr --output Virtual-1 --brightness 0.30|" ]]; then
    pass "set skips it (no CRTC to dim) and succeeds; the record is 30 for its sync"
else
    fail "set with a screen off: rc=$RC calls=$(calls) err='$(cat "$TMP/err")'"
fi
if [[ "$(cat "$LEVEL" 2>/dev/null)" != 30 ]]; then
    fail "set with a screen off recorded '$(cat "$LEVEL" 2>/dev/null)'"
fi

blue "==> the autorandr hook"
H="$TMP/home"
mkdir -p "$H/.config/dwm/bin"
# The stand-in logs its arguments and the first PATH entry it was given.
cat >"$H/.config/dwm/bin/dwm-brightness" <<EOF
#!/bin/sh
echo "hook \$* path=\${PATH%%:*}" >>"$LOG"
EOF
chmod 755 "$H/.config/dwm/bin/dwm-brightness"
: >"$LOG"
if env -i HOME="$H" PATH="$BIN" /bin/sh "$HOOK" && [[ "$(calls)" == "hook sync path=$H/.config/dwm/bin|" ]]; then
    pass "runs dwm-brightness sync with dwm/bin first on PATH"
else
    fail "hook: calls=$(calls)"
fi
rm "$H/.config/dwm/bin/dwm-brightness"
: >"$LOG"
if env -i HOME="$H" PATH="$BIN" /bin/sh "$HOOK" && [[ ! -s "$LOG" ]]; then
    pass "no dwm-brightness: exit 0"
else
    fail "hook without dwm-brightness failed"
fi
if [[ -x "$HOOK" && "$(git -C "$DOTS_DIR" ls-files -s -- "${HOOK#"$DOTS_DIR"/}" | cut -d' ' -f1)" =~ ^(100755)?$ ]]; then
    pass "the repo copy is executable (autorandr skips one that is not)"
else
    fail "$HOOK is not executable"
fi

# shellcheck source=lib/brightness-follows-display-deploy.sh
source "$SCRIPT_DIR/lib/brightness-follows-display-deploy.sh"

if ((rc != 0)); then
    red "✗ brightness does not follow a display change"
    exit 1
fi
green "✓ brightness follows a display change: recorded, synced, hooked, deployed"
