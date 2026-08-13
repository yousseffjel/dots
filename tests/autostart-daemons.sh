#!/usr/bin/env bash
# Keeps the two halves of scripts/install-session.sh in agreement.
#
# That file describes the autostart daemon set TWICE, and the copies serve
# different users:
#
#   * session_autostart_template() — what a fresh machine gets written into
#     $XDG_DATA_HOME/dwm/autostart.sh;
#   * session_autostart_report() — what someone with an existing autostart.sh
#     is told is missing, because CLAUDE.md rule 6 makes that file theirs the
#     moment it exists and the installer must never edit it.
#
# Add a daemon to only the template and every existing install silently never
# runs it, with the installer reporting nothing wrong. Add it to only the
# report and fresh installs get nagged about a line they already have.
# Neither shows up in any other test: install-session.sh writes to $HOME and
# is sourced, not run, so nothing else here executes it.
#
# This is the same class of drift tests/picom-lockstep.sh guards between
# picom.conf and picom.dcol — two files that must be edited together.
#
# HOW IT CHECKS. Both sides are RUN, not parsed. The template function is
# executed and its stdout — the actual autostart.sh — is scanned for
# backgrounded commands; the report function is executed against a throwaway
# autostart.sh that mentions nothing, and every daemon it complains about is
# collected. An earlier version sed-extracted the function bodies and matched
# text inside them, which broke the moment those functions were split, and
# which had already produced one false PASS by matching a daemon's name in
# its own explanatory comment rather than in a command.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

SRC="$DOTS_DIR/scripts/install-session.sh"
[[ -f "$SRC" ]] || {
    red "missing: $SRC"
    exit 1
}

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

# install-session.sh only defines functions, so sourcing it runs nothing.
# shellcheck source=/dev/null
source "$SRC"

for fn in session_autostart_template session_autostart_report; do
    if ! declare -F "$fn" >/dev/null; then
        red "$fn() is not defined after sourcing install-session.sh"
        red "(renamed or restructured — update this test)"
        exit 1
    fi
done

# Every daemon this project may autostart.
DAEMONS=(picom xsettingsd autorandr dwmblocks clipmenud sxhkd udiskie lxpolkit dwm-lock)

# --- side 1: what a fresh install actually launches -------------------------
# The generated file, straight from the shipped function. A launch counts only
# when it appears as a backgrounded command — matching the bare name anywhere
# would also match the comments, which discuss every daemon by name.
session_autostart_template >"$SB/autostart.sh"
mapfile -t BACKGROUNDED < <(
    grep -oE '^[[:space:]]*[^#[:space:]][^&]*&[[:space:]]*$' "$SB/autostart.sh" \
        | sed 's/[[:space:]]*&[[:space:]]*$//; s/^[[:space:]]*//'
)

launched() {
    local needle="$1" cmd
    for cmd in "${BACKGROUNDED[@]}"; do
        [[ "$cmd" == *"$needle"* ]] && return 0
    done
    return 1
}

# --- side 2: what an existing install is told is missing --------------------
# Run the real report against an autostart.sh that mentions nothing, in a
# subshell whose colour helpers are plain so the text is easy to read back.
: >"$SB/empty-autostart.sh"
(
    # Invoked indirectly, from inside session_autostart_report — shellcheck
    # cannot see through the sourced call, hence SC2329. Overriding them only
    # for this subshell keeps the colour codes out of the text parsed below
    # without disturbing this test's own output.
    # shellcheck disable=SC2329
    green() { printf '%s\n' "$*"; }
    # shellcheck disable=SC2329
    yellow() { printf '%s\n' "$*"; }
    session_autostart_report "$SB/empty-autostart.sh"
) >"$SB/report.out"

mapfile -t REPORTED < <(
    sed -n 's/.*does not mention \([A-Za-z0-9._-]*\).*/\1/p' "$SB/report.out"
)

reported() {
    local needle="$1" name
    for name in "${REPORTED[@]}"; do
        [[ "$name" == "$needle" ]] && return 0
    done
    return 1
}

blue "==> comparing the generated autostart.sh against session_autostart_report"

rc=0
if ((${#BACKGROUNDED[@]} == 0)); then
    red "  the generated autostart.sh backgrounds nothing at all — either every"
    red "     daemon launch was removed, or the extraction pattern is stale"
    rc=1
fi
if ((${#REPORTED[@]} == 0)); then
    red "  session_autostart_report named no missing daemon for an autostart.sh"
    red "     that mentions none — its wording changed, or every branch is gone"
    rc=1
fi

for d in "${DAEMONS[@]}"; do
    in_template=0
    in_report=0
    launched "$d" && in_template=1
    reported "$d" && in_report=1

    if ((in_template == 1 && in_report == 1)); then
        green "  ok: $d — launched on a fresh install, reported on an existing one"
    elif ((in_template == 1)); then
        red "  $d is launched by the generated autostart.sh but NOT reported by"
        red "     session_autostart_report -> every existing install silently never runs it"
        rc=1
    elif ((in_report == 1)); then
        red "  $d is reported as missing but is NOT in the generated autostart.sh"
        red "     -> fresh installs get nagged about a line they already have"
        rc=1
    else
        red "  $d appears in neither — remove it from DAEMONS in this test, or"
        red "     wire it up in install-session.sh"
        rc=1
    fi
done

# Catch a daemon added to one side without being added to DAEMONS above, which
# would otherwise drift unchecked by the loop.
blue "==> checking for daemons this test does not know about"
known() {
    local hay="$1" d
    for d in "${DAEMONS[@]}"; do
        [[ "$hay" == *"$d"* ]] && return 0
    done
    return 1
}
for cmd in "${BACKGROUNDED[@]}"; do
    if ! known "$cmd"; then
        red "  '$cmd' is backgrounded in autostart.sh but matches no DAEMONS entry"
        rc=1
    fi
done
for name in "${REPORTED[@]}"; do
    if ! known "$name"; then
        red "  '$name' is reported as missing but matches no DAEMONS entry"
        rc=1
    fi
done
((rc == 0)) && green "  ok"

if ((rc != 0)); then
    red "✗ autostart daemon sets have drifted"
    exit 1
fi
green "✓ autostart daemons: template and report agree on ${#DAEMONS[@]}"
