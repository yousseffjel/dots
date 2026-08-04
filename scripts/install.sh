#!/usr/bin/env bash
# Bootstrap zsh + tmux on Debian/Ubuntu (incl. Ubuntu Server).
# Re-runnable: every step is idempotent.
#
# usage: install.sh [--with-suckless]
#
#   --with-suckless   also build and install dwm, st and dwmblocks, and wire
#                     up the dwm autostart hook. Off by default: this script
#                     targets servers, which have no X11 to run them on.
#
# On Arch (no apt-get) run scripts/install-suckless.sh directly instead.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

WITH_SUCKLESS=0
for arg in "$@"; do
    case "$arg" in
        --with-suckless) WITH_SUCKLESS=1 ;;
        -h|--help)
            sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) red "unknown argument: $arg"; exit 1 ;;
    esac
done

if ! command -v apt-get >/dev/null 2>&1; then
    red "apt-get not found — this script targets Debian/Ubuntu."
    yellow "for the suckless programs on another distro, run:"
    yellow "  $SCRIPT_DIR/install-suckless.sh"
    exit 1
fi

SUDO=""
if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        red "sudo not found and not running as root."
        exit 1
    fi
    SUDO="sudo"
fi

REQUIRED=(zsh tmux git curl ca-certificates)
# Guarded by `command -v` in the configs, so install best-effort.
OPTIONAL=(fzf bat fd-find ripgrep zoxide eza)

export DEBIAN_FRONTEND=noninteractive

blue "==> apt-get update"
$SUDO apt-get update -y

blue "==> installing required: ${REQUIRED[*]}"
$SUDO apt-get install -y "${REQUIRED[@]}"

blue "==> installing optional (best-effort): ${OPTIONAL[*]}"
for pkg in "${OPTIONAL[@]}"; do
    if $SUDO apt-get install -y "$pkg" >/dev/null 2>&1; then
        green "  installed: $pkg"
    else
        yellow "  skipped (not available on this release): $pkg"
    fi
done

# Ubuntu ships fd as `fdfind` and bat as `batcat`. Shim them under ~/.local/bin
# so the configs' `command -v fd` / `bat` checks succeed.
mkdir -p "$HOME/.local/bin"
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    green "shim    fdfind -> ~/.local/bin/fd"
fi
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    green "shim    batcat -> ~/.local/bin/bat"
fi

# ~/.zshenv must set ZDOTDIR before .zshrc loads — the configs key off it.
ZSHENV="$HOME/.zshenv"
if [[ -f "$ZSHENV" ]] && grep -q 'ZDOTDIR' "$ZSHENV"; then
    green "ok      ~/.zshenv already sets ZDOTDIR"
else
    printf '%s\n' 'export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"' >> "$ZSHENV"
    green "wrote   ZDOTDIR export -> ~/.zshenv"
fi

blue "==> linking dotfiles"
"$SCRIPT_DIR/symlinks.sh"

# Pre-clone plugin managers so first launch isn't blocked on a network round-trip.
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME/.git" ]]; then
    blue "==> bootstrapping zinit"
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

TPM_DIR="$HOME/.local/share/tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR/.git" ]]; then
    blue "==> bootstrapping TPM"
    mkdir -p "$(dirname "$TPM_DIR")"
    git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# Default login shell -> zsh
ZSH_BIN="$(command -v zsh)"
if [[ -n "$ZSH_BIN" ]]; then
    if ! grep -qx "$ZSH_BIN" /etc/shells; then
        echo "$ZSH_BIN" | $SUDO tee -a /etc/shells >/dev/null
        green "added   $ZSH_BIN -> /etc/shells"
    fi
    CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$CURRENT_SHELL" != "$ZSH_BIN" ]]; then
        if chsh -s "$ZSH_BIN" 2>/dev/null; then
            green "default shell -> $ZSH_BIN"
        else
            yellow "could not chsh non-interactively — run manually:  chsh -s $ZSH_BIN"
        fi
    else
        green "ok      login shell is already zsh"
    fi
fi

# dwm/st/dwmblocks: opt-in, because the common target here is a headless
# server. install-suckless.sh handles its own build deps and the autostart
# hook that actually launches the status bar.
if [[ $WITH_SUCKLESS -eq 1 ]]; then
    blue "==> building suckless programs"
    "$SCRIPT_DIR/install-suckless.sh"
fi

green "✓ install complete"
yellow "  - open a new shell or run: exec zsh"
yellow "  - on first tmux start, TPM auto-installs plugins"
if [[ $WITH_SUCKLESS -eq 0 ]]; then
    yellow "  - dwm/st/dwmblocks were skipped — re-run with --with-suckless for a desktop"
fi
