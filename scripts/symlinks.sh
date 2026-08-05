#!/usr/bin/env bash
# Symlink dotfiles from the repo into their system locations.
# Re-runnable: existing correct links are skipped; conflicting files are backed up.
#
# usage: symlinks.sh [--dry-run]

set -euo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$DOTS_DIR/config"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# source:target pairs
LINKS=(
    "$CONFIG_DIR/tmux:$HOME/.config/tmux"
    "$CONFIG_DIR/zsh:$HOME/.config/zsh"
    "$CONFIG_DIR/dwm:$HOME/.config/dwm"
)

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) echo "usage: symlinks.sh [--dry-run]"; exit 0 ;;
        *) red "unknown argument: $arg"; exit 1 ;;
    esac
done

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
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would relink $dst -> $src (currently -> $(readlink "$dst"))"
            return 0
        fi
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would back up $dst -> $BACKUP_DIR/ and link -> $src"
            return 0
        fi
        mkdir -p "$BACKUP_DIR"
        mv "$dst" "$BACKUP_DIR/"
        yellow "backup  $dst -> $BACKUP_DIR/"
    elif [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would link $dst -> $src"
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    green "linked  $dst -> $src"
}

for pair in "${LINKS[@]}"; do
    link "${pair%%:*}" "${pair#*:}"
done
