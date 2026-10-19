#!/usr/bin/env bash
# "install" stage, package half: brings the system up to date
# (install-pkg-xbps.sh — Void does not support partial upgrades), installs
# three tiers of xbps packages — one transaction per tier — then the repos
# and drivers step (install-pkg-repos.sh). The suckless build
# (dwm/st/dmenu/dwmblocks/slock) is the other half of the "install" stage — see install-suckless.sh, which
# owns packages/build.lst and installs those deps itself.
#
# The three tiers this script reads, in install order:
#
#   core.lst    hard-fail. The installer's own next step breaks without it —
#               git for the zinit/TPM clones, zsh for the login-shell step.
#   desktop.lst never aborts, but each failure is repeated in a red closing
#               summary with the consequence taken from the package's own
#               trailing comment. These are the ones whose absence would
#               otherwise be SILENT: a dead keybind, a daemon that never
#               starts, a theming engine that cannot run.
#   extra.lst   never aborts. Applications and conveniences; failures are
#               listed in the closing summary as a single yellow line.
#
# Re-runnable: an installed package is skipped, never reinstalled.
#
# usage: install-pkg.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$DOTS_DIR/packages"
source "$SCRIPT_DIR/global_fn.sh"
stop_on_interrupt

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            echo "usage: install-pkg.sh [--dry-run]"
            exit 0
            ;;
        *)
            red "unknown argument: $arg"
            exit 1
            ;;
    esac
done

if [[ $DRY_RUN -eq 0 ]]; then
    manifest_init \
        "$(tr -d '[:space:]' <"$DOTS_DIR/VERSION" 2>/dev/null || echo unknown)" \
        "$(git -C "$DOTS_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi

if ! command -v xbps-install >/dev/null 2>&1 || ! command -v xbps-query >/dev/null 2>&1; then
    red "xbps not found — this script targets Void Linux."
    exit 1
fi

SUDO=()
if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        red "sudo not found and not running as root."
        exit 1
    fi
    SUDO=(sudo)
fi

# Tier machinery: read_pkg_list, install_tier, install_summary and the
# desktop.lst consequence map. Split out to stay under the 250-line cap — see
# that file's header.
source "$SCRIPT_DIR/install-pkg-tiers.sh"

# Sync, update xbps, upgrade the system — before the first install.
source "$SCRIPT_DIR/install-pkg-xbps.sh"
xbps_prepare

load_consequences

install_tier "installing required packages (hard-fail — later stages depend on them)" \
    "$PACKAGES_DIR/core.lst" hard
install_tier "installing desktop-critical packages (never aborts; failures are repeated at the end)" \
    "$PACKAGES_DIR/desktop.lst" desktop
install_tier "installing optional packages (best-effort)" \
    "$PACKAGES_DIR/extra.lst" extra

# starship (the prompt) and fd used to need special handling here: Fedora
# did not package starship, so it came from its upstream install script, and
# Fedora's fd ships as `fdfind`, so it needed a ~/.local/bin/fd shim. Void
# packages both under their real names (extra.lst), so both steps are gone.

# Void's nonfree repository (for sublime-text4, an explicitly authorised
# rule-4 choice) — then the hardware drivers. See that file's
# header for what each adds and how uninstall reverts it.
source "$SCRIPT_DIR/install-pkg-repos.sh"
repos_install

install_summary
green "✓ package stage complete"
