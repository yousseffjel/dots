#!/usr/bin/env bash
# Symlink dotfiles from the repo into their system locations.
# Re-runnable: existing correct links are skipped; conflicting files are backed up.
#
# usage: symlinks.sh [--dry-run]
#        symlinks.sh --restore [timestamp] [--dry-run]
#        symlinks.sh --list-links
#
#   --restore [timestamp]   undo mode. With no timestamp, lists available
#                           backups under ~/.dotfiles-backup/ and exits.
#                           With a timestamp, reverses that backup: removes
#                           the symlink at each target this script manages
#                           and moves the backed-up original back into
#                           place. Never overwrites a target that isn't
#                           currently one of this script's own symlinks —
#                           such targets are skipped with a warning instead.
#   --list-links            print this script's managed source<TAB>target
#                           pairs, one per line, and exit. Lets other
#                           scripts (install-restore.sh's manifest writer)
#                           read the LINKS array without duplicating it.

set -euo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$DOTS_DIR/config"
BACKUP_ROOT="$HOME/.dotfiles-backup"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"

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
MODE="link"
RESTORE_TS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --list-links)
            MODE="list"
            shift
            ;;
        --restore)
            MODE="restore"
            shift
            if [[ $# -gt 0 && "$1" != --* ]]; then
                RESTORE_TS="$1"
                shift
            fi
            ;;
        -h|--help)
            sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) red "unknown argument: $1"; exit 1 ;;
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

list_backups() {
    if [[ ! -d "$BACKUP_ROOT" ]] || [[ -z "$(ls -A "$BACKUP_ROOT" 2>/dev/null)" ]]; then
        yellow "no backups found at $BACKUP_ROOT/"
        return
    fi
    blue "available backups:"
    for d in "$BACKUP_ROOT"/*/; do
        [[ -d "$d" ]] || continue
        printf '  %s\n' "$(basename "$d")"
    done
}

# Reverses one backup snapshot: for each LINKS target this script manages,
# if a matching backed-up entry exists, removes the current symlink (only
# if it IS this script's own symlink — never touches anything else) and
# moves the backup back into place.
restore_backup() {
    local ts="$1"
    local backup_dir="$BACKUP_ROOT/$ts"

    if [[ ! -d "$backup_dir" ]]; then
        red "no backup found at $backup_dir"
        list_backups
        exit 1
    fi

    local matched_any=0
    for pair in "${LINKS[@]}"; do
        local src="${pair%%:*}" dst="${pair#*:}"
        local name backed_up
        name="$(basename "$dst")"
        backed_up="$backup_dir/$name"

        [[ -e "$backed_up" ]] || continue
        matched_any=1

        if [[ -L "$dst" ]]; then
            if [[ "$(readlink "$dst")" != "$src" ]]; then
                yellow "skip    $dst is a symlink but not one this script manages — not touching it"
                continue
            fi
            if [[ $DRY_RUN -eq 1 ]]; then
                blue "  (dry-run) would remove symlink $dst and restore $backed_up -> $dst"
                continue
            fi
            rm "$dst"
        elif [[ -e "$dst" ]]; then
            yellow "skip    $dst exists and is not this script's symlink — not overwriting; restore $backed_up manually if needed"
            continue
        elif [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would restore $backed_up -> $dst"
            continue
        fi

        mkdir -p "$(dirname "$dst")"
        mv "$backed_up" "$dst"
        green "restored $dst (from $backed_up)"
    done

    if [[ $matched_any -eq 0 ]]; then
        yellow "nothing to restore — no matching backed-up entries in $backup_dir"
    elif [[ $DRY_RUN -eq 0 ]]; then
        # Only removes the timestamp dir if every entry in it was restored
        # (rmdir fails harmlessly on a non-empty dir — e.g. an entry that
        # was skipped above because its target wasn't our own symlink).
        rmdir "$backup_dir" 2>/dev/null || true
    fi
}

if [[ "$MODE" == "list" ]]; then
    for pair in "${LINKS[@]}"; do
        printf '%s\t%s\n' "${pair%%:*}" "${pair#*:}"
    done
    exit 0
fi

if [[ "$MODE" == "restore" ]]; then
    if [[ -z "$RESTORE_TS" ]]; then
        list_backups
        echo
        yellow "usage: symlinks.sh --restore <timestamp>"
        exit 0
    fi
    restore_backup "$RESTORE_TS"
    exit 0
fi

for pair in "${LINKS[@]}"; do
    link "${pair%%:*}" "${pair#*:}"
done
