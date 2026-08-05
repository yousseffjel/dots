#!/usr/bin/env bash
# "restore" stage: deploys this repo's config into place. Sets ZDOTDIR,
# symlinks config/ via symlinks.sh, and pre-clones the zinit/TPM plugin
# managers so first shell/tmux launch isn't blocked on a network round-trip.
#
# usage: install-restore.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue()  { printf '\033[34m%s\033[0m\n' "$*"; }

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) echo "usage: install-restore.sh [--dry-run]"; exit 0 ;;
        *) red "unknown argument: $arg"; exit 1 ;;
    esac
done

# ~/.zshenv must set ZDOTDIR before .zshrc loads — the configs key off it.
ZSHENV="$HOME/.zshenv"
if [[ -f "$ZSHENV" ]] && grep -q 'ZDOTDIR' "$ZSHENV"; then
    green "ok      ~/.zshenv already sets ZDOTDIR"
elif [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would append ZDOTDIR export to ~/.zshenv"
else
    printf '%s\n' 'export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"' >> "$ZSHENV"
    green "wrote   ZDOTDIR export -> ~/.zshenv"
fi

blue "==> linking dotfiles"
symlinks_args=()
[[ $DRY_RUN -eq 1 ]] && symlinks_args+=(--dry-run)
"$SCRIPT_DIR/symlinks.sh" "${symlinks_args[@]}"

# Pre-clone plugin managers so first launch isn't blocked on a network round-trip.
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME/.git" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would clone zinit -> $ZINIT_HOME"
    else
        blue "==> bootstrapping zinit"
        mkdir -p "$(dirname "$ZINIT_HOME")"
        git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    fi
else
    green "ok      zinit already cloned"
fi

TPM_DIR="$HOME/.local/share/tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR/.git" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would clone TPM -> $TPM_DIR"
    else
        blue "==> bootstrapping TPM"
        mkdir -p "$(dirname "$TPM_DIR")"
        git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
    fi
else
    green "ok      TPM already cloned"
fi

green "✓ restore stage complete"
