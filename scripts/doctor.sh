#!/usr/bin/env bash
# doctor.sh — a read-only health report for an installed dots desktop.
# Reached as `dots doctor`. It changes nothing; every line names what is wrong
# and, where there is one, the command that fixes it.
#
# Two formats from ONE code path: every check calls report(), and only
# report() knows the format. Human text by default; --tsv prints
#     status<TAB>section<TAB>id<TAB>detail
# one line per check, for a script or a diff between two machines. A check
# can therefore never appear in one format and not the other.
#
# status: ok | warn (degraded, the desktop still works) | fail (something the
# install promises is broken) | skip (cannot be checked here). Exit 1 when
# anything failed, so `dots doctor || ...` works.
#
# Every list it walks is read from the place that already declares it: the
# package tiers from packages/*.lst (via install-pkg-tiers.sh's own parser),
# the linked configs from `symlinks.sh --list-links`, the daemons from the
# installer's session_autostart_report. See scripts/doctor-checks.sh.
#
# usage: doctor.sh [--tsv]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Only red() is needed before doctor-checks.sh sources global_fn.sh, which
# defines all four (the same rule-2 helpers), so the other three would be dead.
red() { printf '\033[31m%s\033[0m\n' "$*"; }

usage() {
    echo "usage: ${DOTS_CMD:-doctor.sh} [--tsv]"
    echo
    echo "Checks the install, packages, X session, theme and hardware, and"
    echo "prints what is wrong. Read-only. --tsv: status, section, id, detail."
}

FORMAT=human
for arg in "$@"; do
    case "$arg" in
        --tsv) FORMAT=tsv ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            red "unknown argument: $arg"
            usage >&2
            exit 1
            ;;
    esac
done

FAILS=0
WARNS=0
SECTION=""

# report <status> <section> <id> <text> — the only place output is formatted.
report() {
    local status="$1" section="$2" id="$3" text="$4"
    case "$status" in
        fail) FAILS=$((FAILS + 1)) ;;
        warn) WARNS=$((WARNS + 1)) ;;
    esac
    if [[ "$FORMAT" == tsv ]]; then
        text="${text//$'\t'/ }"
        printf '%s\t%s\t%s\t%s\n' "$status" "$section" "$id" "${text//$'\n'/ }"
        return 0
    fi
    if [[ "$section" != "$SECTION" ]]; then
        SECTION="$section"
        echo
        blue "== $section"
    fi
    case "$status" in
        ok) green "  ok    $text" ;;
        warn) yellow "  warn  $text" ;;
        fail) red "  FAIL  $text" ;;
        *) printf '  %-5s %s\n' "$status" "$text" ;;
    esac
}

# shellcheck source=doctor-checks.sh
source "$SCRIPT_DIR/doctor-checks.sh"
# shellcheck source=doctor-session.sh
source "$SCRIPT_DIR/doctor-session.sh"
# shellcheck source=doctor-portal.sh
source "$SCRIPT_DIR/doctor-portal.sh"

check_install
check_packages
check_session
check_theme
check_portal
check_gtk3_theme
check_flatpak
check_system

if [[ "$FORMAT" == human ]]; then
    echo
    if ((FAILS > 0)); then
        red "$FAILS failed, $WARNS warning(s)"
    elif ((WARNS > 0)); then
        yellow "no failures, $WARNS warning(s)"
    else
        green "all checks passed"
    fi
fi
((FAILS == 0))
