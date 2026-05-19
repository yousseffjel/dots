#!/usr/bin/env bash
# Bootstrap zsh + tmux on macOS via MacPorts.
# Re-runnable: every step is idempotent.
# Tested target: macOS Monterey 12.7.6.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
    red "This script targets macOS. For Debian/Ubuntu use install.sh."
    exit 1
fi

if ! command -v port >/dev/null 2>&1; then
    red "MacPorts not found."
    yellow "Install the .pkg for your macOS version from:"
    yellow "  https://www.macports.org/install.php"
    yellow "Monterey-compatible installer:"
    yellow "  https://github.com/macports/macports-base/releases"
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

REQUIRED=(zsh tmux git curl)
# Guarded by `command -v` in the configs, so install best-effort.
OPTIONAL=(fzf bat fd ripgrep zoxide eza neovim starship)

blue "==> port selfupdate"
$SUDO port selfupdate

blue "==> installing required: ${REQUIRED[*]}"
$SUDO port install "${REQUIRED[@]}"

blue "==> installing optional (best-effort): ${OPTIONAL[*]}"
for pkg in "${OPTIONAL[@]}"; do
    if $SUDO port install "$pkg" >/dev/null 2>&1; then
        green "  installed: $pkg"
    else
        yellow "  skipped (not available or already up to date): $pkg"
    fi
done

# Optional: a `python3` on PATH for the `py` alias.
if ! command -v python3 >/dev/null 2>&1; then
    if $SUDO port install python313 >/dev/null 2>&1; then
        $SUDO port select --set python3 python313 >/dev/null 2>&1 || true
        green "  installed: python313 (selected as default python3)"
    fi
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

# Default login shell -> MacPorts zsh (newer than Apple's bundled one).
ZSH_BIN="/opt/local/bin/zsh"
if [[ -x "$ZSH_BIN" ]]; then
    if ! grep -qx "$ZSH_BIN" /etc/shells; then
        echo "$ZSH_BIN" | $SUDO tee -a /etc/shells >/dev/null
        green "added   $ZSH_BIN -> /etc/shells"
    fi
    CURRENT_SHELL="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
    if [[ "$CURRENT_SHELL" != "$ZSH_BIN" ]]; then
        if chsh -s "$ZSH_BIN" 2>/dev/null; then
            green "default shell -> $ZSH_BIN"
        else
            yellow "could not chsh non-interactively — run manually:  chsh -s $ZSH_BIN"
        fi
    else
        green "ok      login shell is already MacPorts zsh"
    fi
fi

green "✓ install complete"
yellow "  - open a new shell or run: exec /opt/local/bin/zsh"
yellow "  - on first tmux start, TPM auto-installs plugins"
