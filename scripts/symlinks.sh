#!/usr/bin/env bash
# Symlink dotfiles from the repo into their system locations.
# Re-runnable: existing correct links are skipped; conflicting files are backed up.

set -euo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$DOTS_DIR/config"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# source:target pairs
LINKS=(
    "$CONFIG_DIR/tmux:$HOME/.config/tmux"
    "$CONFIG_DIR/zsh:$HOME/.config/zsh"
)

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

link() {
    local src="$1" dst="$2"

    if [[ ! -e "$src" ]]; then
        red   "missing source: $src"
        return 1
    fi

    if [[ -L "$dst" ]]; then
        if [[ "$(readlink "$dst")" == "$src" ]]; then
            green "ok      $dst"
            return 0
        fi
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        mkdir -p "$BACKUP_DIR"
        mv "$dst" "$BACKUP_DIR/"
        yellow "backup  $dst -> $BACKUP_DIR/"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    green "linked  $dst -> $src"
}

for pair in "${LINKS[@]}"; do
    link "${pair%%:*}" "${pair#*:}"
done
