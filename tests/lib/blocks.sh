#!/usr/bin/env bash
# Shared harness for the tests/blocks-*.sh scripts — SOURCED, never run on its
# own (tests/lib/ is outside run-tests.sh's depth-1 glob). The caller defines
# red/green/blue (CLAUDE.md rule 2) and sources sealed-path.sh first.
#
# Every block runs under `env -i` on a sealed PATH: only $SB/fake (the tools a
# test fakes) and $SB/real (links to the few real tools blocks genuinely
# need). So "tool X is missing" is tested by deleting a fake, and cannot fall
# through to a real /usr/bin/X and pass for the wrong reason.
#
# The dwm-* control scripts (dwm-osd, dwm-brightness, dwm-nightlight) are
# faked in $SB/home/.config/dwm/bin, NOT on PATH, because that is where
# dwmblocks finds them on a real session: its PATH may lack that dir, and
# dwm-blockutil's block_bin falls back to it.

BLOCKS_DIR="$DOTS_DIR/suckless/dwmblocks/scripts"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
LOG="$SB/calls.log"
export LOG
DWM_BIN="$SB/home/.config/dwm/bin"

seal_path "$SB/real" cat sed head awk grep mkdir sleep rm
mkdir -p "$SB/fake" "$SB/home/.cache" "$DWM_BIN" "$SB/proc" "$SB/hwmon" "$SB/ps"
# timeout is a pass-through so the real one's process-group handling cannot
# interfere; that a block wraps its daemon calls in it is the point.
# shellcheck disable=SC2016
fake "$SB/fake" timeout 'shift; exec "$@"'
# Every fake below just records how it was called.
# shellcheck disable=SC2016
for t in alacritty st htop notify-send pavucontrol blueman-manager thunar; do
    fake "$SB/fake" "$t" 'echo "${0##*/} $*" >>"$LOG"'
done
# shellcheck disable=SC2016
for t in dwm-osd dwm-nightlight; do
    fake "$DWM_BIN" "$t" 'echo "${0##*/} $*" >>"$LOG"'
done

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

# block <name> [button] — runs a block as dwmblocks does (BUTTON set on a
# click), log cleared first. A block that dies is not an abort here: under
# `set -e` the bare assignment used to end the whole test with no message,
# so the checks after it — which say what is wrong — never ran. $OUT is its output with the status2d colour
# escapes stripped, $RAW the output as printed.
block() {
    : >"$LOG"
    RAW="$(env -i HOME="$SB/home" XDG_CACHE_HOME="$SB/home/.cache" \
        XDG_CONFIG_HOME="$SB/home/.config" LOG="$LOG" \
        DOTS_PROC_ROOT="$SB/proc" DOTS_HWMON_ROOT="$SB/hwmon" DOTS_POWER_SUPPLY_ROOT="$SB/ps" \
        ${2:+BUTTON="$2"} PATH="$SB/fake:$SB/real" \
        /bin/sh "$BLOCKS_DIR/$1" 2>/dev/null || true)"
    # shellcheck disable=SC2001 # [^^]* has no ${var//} equivalent
    OUT="$(sed 's/\^[^^]*\^//g' <<<"$RAW")"
}

is() { [[ "$OUT" == "$1" ]] || {
    red "        got: '$OUT'"
    return 1
}; }

# logged <line> — true once <line> appears in the call log. Polls, because
# the clicks background their terminal and pop-up on purpose.
logged() {
    for _ in $(seq 1 20); do
        grep -qxF -- "$1" "$LOG" && return 0
        sleep 0.05
    done
    red "        log: $(tr '\n' '|' <"$LOG")"
    return 1
}

# not_logged <pattern> — true when nothing matching <pattern> was called,
# after giving any backgrounded job time to show up.
not_logged() {
    sleep 0.3
    ! grep -q -- "$1" "$LOG" || {
        red "        log: $(tr '\n' '|' <"$LOG")"
        return 1
    }
}

blocks_done() {
    if [[ $FAILS -gt 0 ]]; then
        red "$FAILS check(s) failed"
        exit 1
    fi
    green "✓ $1"
}
