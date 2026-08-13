#!/usr/bin/env bash
# Reverses what install-fedora.sh did, using ~/.local/state/dots/manifest
# as the source of truth: removes deployed configs (restoring backups
# where one was made), uninstalls the vendored suckless binaries, removes
# ONLY the dnf packages this installer itself installed (never anything
# that was already present), disables services this installer enabled,
# and finally offers to remove the state dir itself.
#
# Interactive by default — every destructive step is confirmed one
# category at a time. --yes auto-confirms every prompt; --dry-run prints
# what would happen without changing anything. Refuses to run as root.
#
# usage: uninstall.sh [--yes] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/global_fn.sh"

refuse_root

ASSUME_YES=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --yes) ASSUME_YES=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            # DOTS_CMD is set by scripts/dots when this was reached through the
            # dispatcher, so the help names how it was actually invoked.
            echo "usage: ${DOTS_CMD:-uninstall.sh} [--yes] [--dry-run]"
            exit 0
            ;;
        *)
            echo "unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

# Sanity guard on the one directory this script ever rm -rf's (see the
# state-removal step at the bottom) — MANIFEST_DIR comes from global_fn.sh,
# but a future edit changing its shape there shouldn't silently turn this
# into a wider rm -rf.
if [[ -z "$MANIFEST_DIR" || "$MANIFEST_DIR" != */dots ]]; then
    echo "refusing to continue: unexpected state dir '$MANIFEST_DIR'" >&2
    exit 1
fi

LOG_FILE="$MANIFEST_DIR/uninstall.log"

# Overrides global_fn.sh's color helpers to also mirror every line (sans
# ANSI codes) into uninstall.log, so every script below can keep calling
# red/green/yellow/blue exactly as install-*.sh already does and get
# logging for free. No-op under --dry-run — a preview run shouldn't leave
# a log file behind.
_log_line() {
    # -d "$MANIFEST_DIR" guards against the state-removal step below having
    # already rm -rf'd LOG_FILE's own directory — without it, a >> to a
    # missing directory prints straight to the real stderr (redirection
    # failures land there before any 2>/dev/null on the same line can take
    # effect) and, being the last command in this `&&` chain, would abort
    # the whole script under `set -e` on the final "uninstall complete" line.
    [[ $DRY_RUN -eq 0 && -d "$MANIFEST_DIR" ]] && printf '%s\n' "$1" >>"$LOG_FILE"
    return 0
}
red() {
    printf '\033[31m%s\033[0m\n' "$*"
    _log_line "[ERROR] $*"
}
green() {
    printf '\033[32m%s\033[0m\n' "$*"
    _log_line "[OK]    $*"
}
yellow() {
    printf '\033[33m%s\033[0m\n' "$*"
    _log_line "[WARN]  $*"
}
blue() {
    printf '\033[34m%s\033[0m\n' "$*"
    _log_line "[INFO]  $*"
}

if [[ ! -f "$MANIFEST_FILE" ]]; then
    yellow "no manifest at $MANIFEST_FILE — nothing was installed by install-fedora.sh, or it's already uninstalled."
    exit 0
fi

if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$MANIFEST_DIR"
    : >"$LOG_FILE"
fi

blue "=== dots uninstall: $(date -u +%Y-%m-%dT%H:%M:%SZ) (args: $*) ==="

SUDO=()
if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO=(sudo)
    else
        yellow "sudo not found — suckless/service/package removal below will be skipped if it needs root."
    fi
fi

# One function per category, in the order they run — see uninstall_steps.sh.
# Split out once this file crossed the 250-line cap (file-architecture.md).
# uninstall-apps.sh is separate again for the same reason: uninstall_steps.sh
# is itself at 230 of that cap.
source "$SCRIPT_DIR/uninstall_steps.sh"
source "$SCRIPT_DIR/uninstall-apps.sh"

uninstall_configs
uninstall_suckless
uninstall_scripts
uninstall_theme
uninstall_apps
uninstall_packages
uninstall_services
uninstall_shell
uninstall_state

green "✓ uninstall complete"
