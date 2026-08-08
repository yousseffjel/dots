#!/usr/bin/env bash
# Keeps the two halves of scripts/install-session.sh in agreement.
#
# That file describes the autostart daemon set TWICE, and the copies serve
# different users:
#
#   * the `autostart.sh` heredoc in install_session_autostart() — what a fresh
#     machine gets;
#   * session_autostart_report() — what someone with an existing autostart.sh
#     is told is missing, because CLAUDE.md rule 6 makes that file theirs the
#     moment it exists and the installer must never edit it.
#
# Add a daemon to only the heredoc and every existing install silently never
# runs it, with the installer reporting nothing wrong. Add it to only the
# report and the installer nags about a line fresh machines already have.
# Neither shows up in any other test: install-session.sh writes to $HOME and
# is sourced, not run, so nothing else here executes it.
#
# This is the same class of drift tests/picom-lockstep.sh guards between
# picom.conf and picom.dcol — two files that must be edited together.
#
# It compares the SET of daemons, not the exact text: the two copies
# legitimately differ in form — the heredoc is shell to execute, the report is
# a string for the user to paste. Each side is matched on its own canonical
# marker rather than on the daemon's name appearing somewhere; see the note
# above DAEMONS for why that distinction is load-bearing.

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

# The two function bodies. Both extractions are range-matched on the function
# header, so a rename or a restructure makes them come back empty rather than
# subtly partial — which the emptiness check below turns into a loud failure.
sed -n '/^session_autostart_template()/,/^}$/p' "$SRC" >"$SB/heredoc"
sed -n '/^session_autostart_report()/,/^}$/p' "$SRC" >"$SB/report"

for f in heredoc report; do
    if [[ ! -s "$SB/$f" ]]; then
        red "could not extract the $f section from install-session.sh"
        red "(its structure changed — update this test's sed ranges)"
        exit 1
    fi
done

# Every daemon this project may autostart.
DAEMONS=(picom dwmblocks clipmenud sxhkd dwm-lock)

# Presence is judged on the CANONICAL MARKER in each section, never on the bare
# name appearing somewhere. Both sections discuss their daemons in prose — the
# heredoc explains why picom starts first, the report explains what breaks
# without each one — so a loose `grep picom` matches the commentary and keeps
# reporting success after the launch line itself is deleted. That is not
# hypothetical: the first version of this test did exactly that and passed
# with `picom &` removed.
#
#   heredoc -> the name appears in an actually-backgrounded command
#   report  -> the name appears in this function's "already starts X" line
#
# Backgrounded commands are extracted once, and reused below to catch a daemon
# added to the heredoc that nothing else here knows about.
mapfile -t BACKGROUNDED < <(
    grep -oE '^[[:space:]]*[^#[:space:]][^&]*&[[:space:]]*$' "$SB/heredoc" \
        | sed 's/[[:space:]]*&[[:space:]]*$//; s/^[[:space:]]*//'
)

launched_in_heredoc() {
    local needle="$1" cmd
    for cmd in "${BACKGROUNDED[@]}"; do
        [[ "$cmd" == *"$needle"* ]] && return 0
    done
    return 1
}

blue "==> comparing the autostart heredoc against session_autostart_report"

rc=0
for d in "${DAEMONS[@]}"; do
    in_heredoc=0
    in_report=0
    launched_in_heredoc "$d" && in_heredoc=1
    grep -q "already starts $d" "$SB/report" && in_report=1

    if ((in_heredoc == 1 && in_report == 1)); then
        green "  ok: $d — launched on a fresh install, reported on an existing one"
    elif ((in_heredoc == 1)); then
        red "  $d is in the autostart.sh template but NOT in session_autostart_report"
        red "     -> every existing install silently never runs it"
        rc=1
    elif ((in_report == 1)); then
        red "  $d is reported as missing but is NOT in the autostart.sh template"
        red "     -> fresh installs get nagged about a line they already have"
        rc=1
    else
        red "  $d appears in neither section — remove it from DAEMONS in this"
        red "     test, or wire it up in install-session.sh"
        rc=1
    fi
done

# Catch a daemon added to the heredoc without being added to DAEMONS above,
# which would otherwise let it drift unchecked by the loop.
blue "==> checking for backgrounded commands the test does not know about"
if ((${#BACKGROUNDED[@]} == 0)); then
    red "  no backgrounded commands found in the heredoc at all — either every"
    red "     daemon launch was removed, or the extraction pattern is stale"
    rc=1
fi
for cmd in "${BACKGROUNDED[@]}"; do
    known=0
    for d in "${DAEMONS[@]}"; do
        [[ "$cmd" == *"$d"* ]] && known=1
    done
    if ((known == 0)); then
        red "  '$cmd' is backgrounded in autostart.sh but is not in this test's"
        red "     DAEMONS list — add it there and to session_autostart_report"
        rc=1
    fi
done

if ((rc != 0)); then
    red "✗ autostart daemon sets have drifted"
    exit 1
fi
green "✓ autostart daemons: heredoc and report agree on ${#DAEMONS[@]}"
