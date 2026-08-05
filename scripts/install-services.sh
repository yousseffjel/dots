#!/usr/bin/env bash
# "services" stage: sets zsh as the default login shell and enables the ly
# display manager service. Does not touch getty units — whether tty1's
# getty needs disabling depends on the user's existing layout.
#
# usage: install-services.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
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
            echo "usage: install-services.sh [--dry-run]"
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

SUDO=()
if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        red "sudo not found and not running as root."
        exit 1
    fi
    SUDO=(sudo)
fi

# zsh is a required package (packages/core.lst) installed by the install
# stage, but this stage is standalone-runnable — guard for the case where
# it hasn't run yet rather than aborting on an unguarded command substitution.
ZSH_BIN="$(command -v zsh || true)"
if [[ -n "$ZSH_BIN" ]]; then
    if ! grep -qx "$ZSH_BIN" /etc/shells; then
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would add $ZSH_BIN -> /etc/shells"
        else
            echo "$ZSH_BIN" | "${SUDO[@]}" tee -a /etc/shells >/dev/null
            green "added   $ZSH_BIN -> /etc/shells"
        fi
    fi
    CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$CURRENT_SHELL" != "$ZSH_BIN" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would chsh -s $ZSH_BIN"
        elif chsh -s "$ZSH_BIN" 2>/dev/null; then
            # Recorded only on the one run that actually changes the shell —
            # once it's zsh, this branch is never re-entered, so a re-run
            # never clobbers the real previous shell with "zsh".
            manifest_append_row SHELL "$CURRENT_SHELL" "$ZSH_BIN"
            green "default shell -> $ZSH_BIN"
        else
            yellow "could not chsh non-interactively — run manually:  chsh -s $ZSH_BIN"
        fi
    else
        green "ok      login shell is already zsh"
    fi
else
    yellow "zsh not found on PATH — run the install stage first (packages/core.lst) so this stage can set it as the default shell"
fi

# ly: enable the service, but don't touch getty units — whether tty1's getty
# needs disabling depends on the user's existing layout.
if command -v ly >/dev/null 2>&1 || rpm -q ly >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would enable ly.service"
    elif systemctl is-enabled ly.service >/dev/null 2>&1; then
        green "ok      ly.service already enabled"
    else
        "${SUDO[@]}" systemctl enable ly.service
        manifest_append_row SERVICE ly.service
        green "enabled ly.service"
    fi
fi

green "✓ services stage complete"
