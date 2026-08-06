#!/usr/bin/env bash
# "restore" stage: deploys this repo's config into place. Sets ZDOTDIR,
# symlinks config/ via symlinks.sh, deploys the theming engine's base
# configs (install-restore-theme.sh), and pre-clones the zinit/TPM plugin
# managers so first shell/tmux launch isn't blocked on a network round-trip.
#
# usage: install-restore.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# Must match symlinks.sh's own BACKUP_ROOT — used below only to detect
# whether that script created a fresh backup dir during this run.
BACKUP_ROOT="$HOME/.dotfiles-backup"
source "$SCRIPT_DIR/global_fn.sh"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            echo "usage: install-restore.sh [--dry-run]"
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

# ~/.zshenv must set ZDOTDIR before .zshrc loads — the configs key off it.
ZSHENV="$HOME/.zshenv"
if [[ -f "$ZSHENV" ]] && grep -q 'ZDOTDIR' "$ZSHENV"; then
    green "ok      ~/.zshenv already sets ZDOTDIR"
elif [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would append ZDOTDIR export to ~/.zshenv"
else
    # Literal shell syntax written into .zshenv, meant to expand at its own
    # runtime, not here.
    # shellcheck disable=SC2016
    printf '%s\n' 'export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"' >>"$ZSHENV"
    green "wrote   ZDOTDIR export -> ~/.zshenv"
fi

blue "==> linking dotfiles"
symlinks_args=()
[[ $DRY_RUN -eq 1 ]] && symlinks_args+=(--dry-run)

# Snapshot BACKUP_ROOT before linking so any timestamp dir symlinks.sh
# creates during this run (it uses one timestamp per invocation) can be
# told apart from pre-existing backups, for the manifest's backup column.
backups_before=""
[[ -d "$BACKUP_ROOT" ]] && backups_before="$(ls -1 "$BACKUP_ROOT" 2>/dev/null)"

"$SCRIPT_DIR/symlinks.sh" "${symlinks_args[@]}"

if [[ $DRY_RUN -eq 0 ]]; then
    run_backup_dir=""
    if [[ -d "$BACKUP_ROOT" ]]; then
        # `|| true`: under pipefail, `head -1` closing the pipe early on
        # multi-line output can SIGPIPE `comm`, which would otherwise trip
        # this script's own set -e (same class of bug as version.sh's
        # `dwm -v` pipeline). BACKUP_ROOT only ever contains entries this
        # repo's own symlinks.sh names as timestamps (YYYYMMDD_HHMMSS),
        # never arbitrary/adversarial filenames.
        # shellcheck disable=SC2012
        run_backup_dir="$(comm -13 <(printf '%s\n' "$backups_before" | sort) <(ls -1 "$BACKUP_ROOT" | sort) | head -1)" || true
    fi
    while IFS=$'\t' read -r src dst; do
        [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]] || continue
        backup="-"
        if [[ -n "$run_backup_dir" && -e "$BACKUP_ROOT/$run_backup_dir/$(basename "$dst")" ]]; then
            backup="$BACKUP_ROOT/$run_backup_dir/$(basename "$dst")"
        fi
        # Only touch the row when this run made a real backup, or when no
        # row exists yet (first-ever deploy, nothing to back up) — an
        # idempotent re-run with backup="-" must never clobber a real
        # backup path a previous run already recorded.
        existing_row="$(awk -F'\t' -v s="$src" -v d="$dst" \
            '$1=="CONFIG" && $2==s && $3==d {print; exit}' "$MANIFEST_FILE" 2>/dev/null || true)"
        if [[ "$backup" != "-" || -z "$existing_row" ]]; then
            manifest_upsert_row CONFIG "$src" "$dst" "$backup"
        fi
    done < <("$SCRIPT_DIR/symlinks.sh" --list-links)
fi

source "$SCRIPT_DIR/install-restore-theme.sh"
restore_theme

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
