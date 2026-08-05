#!/usr/bin/env bash
# "install" stage, package half: installs the C toolchain group, required
# and best-effort dnf packages from packages/core.lst and packages/extra.lst,
# the clipmenu/clipnotify COPR (backs dwm-clipmenu, Super+v), and the
# fdfind -> fd shim. The suckless build (dwm/st/dmenu/dwmblocks/slock) is
# the other half of the "install" stage — see install-suckless.sh.
#
# Re-runnable: every dnf install is idempotent. The required-packages loop
# hard-fails (exit 1) since later stages (restore, services) and the
# suckless build depend on git/zsh/make/gcc/patch/pkgconf-pkg-config
# unconditionally — see packages/core.lst.
#
# usage: install-pkg.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$DOTS_DIR/packages"
source "$SCRIPT_DIR/global_fn.sh"

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

if ! command -v dnf >/dev/null 2>&1; then
    red "dnf not found — this script targets Fedora."
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

# Strips '#' comments (whole-line or trailing) and blank lines from a .lst file.
read_pkg_list() {
    sed 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^$'
}

dnf_install() {
    local pkg="$1"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would install: $pkg"
        return 0
    fi
    "${SUDO[@]}" dnf install -y "$pkg" >/dev/null 2>&1
}

blue "==> installing C Development Tools and Libraries (group)"
if [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would install group: C Development Tools and Libraries"
elif ! "${SUDO[@]}" dnf group install -y "C Development Tools and Libraries" 2>/dev/null; then
    if ! "${SUDO[@]}" dnf groupinstall -y "C Development Tools and Libraries" 2>/dev/null; then
        yellow "  skipped (group unavailable under this dnf) — individual packages below still cover the build toolchain"
    fi
fi

blue "==> installing required packages (hard-fail — later stages depend on them)"
while IFS= read -r pkg; do
    already=0
    rpm -q "$pkg" >/dev/null 2>&1 && already=1
    if dnf_install "$pkg"; then
        green "  installed: $pkg"
        [[ $DRY_RUN -eq 0 && $already -eq 0 ]] && manifest_append_row PACKAGE "$pkg"
    else
        red "required package failed to install: $pkg"
        exit 1
    fi
done < <(read_pkg_list "$PACKAGES_DIR/core.lst")

blue "==> installing packages (best-effort, one at a time so a single renamed/missing package doesn't abort the rest)"
while IFS= read -r pkg; do
    already=0
    rpm -q "$pkg" >/dev/null 2>&1 && already=1
    if dnf_install "$pkg"; then
        green "  installed: $pkg"
        [[ $DRY_RUN -eq 0 && $already -eq 0 ]] && manifest_append_row PACKAGE "$pkg"
    else
        yellow "  skipped (not found in enabled repos): $pkg"
    fi
done < <(read_pkg_list "$PACKAGES_DIR/extra.lst")

# clipmenu + clipnotify back dwm-clipmenu (Super+v) and aren't in Fedora's
# official repos — enabling this COPR is a deliberate exception to this
# repo's usual "COPR is opt-in, never auto-enabled" rule, since the feature
# is core to the desktop rather than a nice-to-have.
blue "==> enabling skidnik/clipmenu COPR"
if [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would enable COPR skidnik/clipmenu and install clipmenu, clipnotify"
elif "${SUDO[@]}" dnf copr enable -y skidnik/clipmenu; then
    for pkg in clipmenu clipnotify; do
        already=0
        rpm -q "$pkg" >/dev/null 2>&1 && already=1
        if "${SUDO[@]}" dnf install -y "$pkg" >/dev/null 2>&1; then
            green "  installed: $pkg"
            [[ $already -eq 0 ]] && manifest_append_row PACKAGE "$pkg"
        else
            yellow "  skipped (not found in enabled repos): $pkg"
        fi
    done
else
    yellow "  could not enable skidnik/clipmenu — dwm-clipmenu (Super+v) needs clipmenu+clipnotify installed manually"
fi

# Fedora's fd-find package ships its binary as `fdfind` (name clash with
# another package, same as Debian/Ubuntu) — shim it under ~/.local/bin so
# the configs' `command -v fd` checks succeed.
if [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would shim fdfind -> ~/.local/bin/fd (if fdfind present and fd absent)"
else
    mkdir -p "$HOME/.local/bin"
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
        green "shim    fdfind -> ~/.local/bin/fd"
    fi
fi

green "✓ package stage complete"
