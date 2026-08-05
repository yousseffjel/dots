#!/usr/bin/env bash
# Reverses what install-fedora.sh did, using ~/.local/state/dots/manifest
# as the source of truth: removes deployed configs (restoring backups
# where one was made), uninstalls the vendored suckless binaries, removes
# ONLY the dnf packages this installer itself installed (never anything
# that was already present), disables services this installer enabled,
# and finally offers to remove the state dir itself.
#
# Interactive by default — every destructive step is confirmed one
# category at a time. --yes auto-confirms every prompt; --dry-run prints
# what would happen without changing anything. Refuses to run as root.
#
# usage: uninstall.sh [--yes] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/global_fn.sh"

refuse_root

ASSUME_YES=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --yes) ASSUME_YES=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) echo "usage: uninstall.sh [--yes] [--dry-run]"; exit 0 ;;
        *) echo "unknown argument: $arg" >&2; exit 1 ;;
    esac
done

# Sanity guard on the one directory this script ever rm -rf's (see the
# state-removal step at the bottom) — MANIFEST_DIR comes from global_fn.sh,
# but a future edit changing its shape there shouldn't silently turn this
# into a wider rm -rf.
if [[ -z "$MANIFEST_DIR" || "$MANIFEST_DIR" != */dots ]]; then
    echo "refusing to continue: unexpected state dir '$MANIFEST_DIR'" >&2
    exit 1
fi

LOG_FILE="$MANIFEST_DIR/uninstall.log"

# Overrides global_fn.sh's color helpers to also mirror every line (sans
# ANSI codes) into uninstall.log, so every script below can keep calling
# red/green/yellow/blue exactly as install-*.sh already does and get
# logging for free. No-op under --dry-run — a preview run shouldn't leave
# a log file behind.
_log_line() {
    # -d "$MANIFEST_DIR" guards against the state-removal step below having
    # already rm -rf'd LOG_FILE's own directory — without it, a >> to a
    # missing directory prints straight to the real stderr (redirection
    # failures land there before any 2>/dev/null on the same line can take
    # effect) and, being the last command in this `&&` chain, would abort
    # the whole script under `set -e` on the final "uninstall complete" line.
    [[ $DRY_RUN -eq 0 && -d "$MANIFEST_DIR" ]] && printf '%s\n' "$1" >> "$LOG_FILE"
    return 0
}
red()    { printf '\033[31m%s\033[0m\n' "$*"; _log_line "[ERROR] $*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; _log_line "[OK]    $*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; _log_line "[WARN]  $*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; _log_line "[INFO]  $*"; }

if [[ ! -f "$MANIFEST_FILE" ]]; then
    yellow "no manifest at $MANIFEST_FILE — nothing was installed by install-fedora.sh, or it's already uninstalled."
    exit 0
fi

if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$MANIFEST_DIR"
    : > "$LOG_FILE"
fi

blue "=== dots uninstall: $(date -u +%Y-%m-%dT%H:%M:%SZ) (args: $*) ==="

SUDO=()
if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO=(sudo)
    else
        yellow "sudo not found — suckless/service/package removal below will be skipped if it needs root."
    fi
fi

# --- (a) configs -------------------------------------------------------------
blue "=== configs ==="
mapfile -t config_rows < <(manifest_rows CONFIG)
if [[ ${#config_rows[@]} -eq 0 ]]; then
    blue "  no CONFIG rows in manifest — nothing to remove"
elif confirm "Remove ${#config_rows[@]} deployed config symlink(s) (restoring a backup where one exists)?"; then
    for row in "${config_rows[@]}"; do
        IFS=$'\t' read -r _ src target backup <<< "$row"
        if [[ ! -L "$target" || "$(readlink "$target")" != "$src" ]]; then
            yellow "  skip    $target (not currently our symlink — left alone)"
            continue
        fi
        if [[ $DRY_RUN -eq 1 ]]; then
            if [[ "$backup" != "-" ]]; then
                blue "  (dry-run) would remove $target and restore backup $backup"
            else
                blue "  (dry-run) would remove $target (no backup to restore)"
            fi
            continue
        fi
        rm "$target"
        if [[ "$backup" != "-" && -e "$backup" ]]; then
            mkdir -p "$(dirname "$target")"
            mv "$backup" "$target"
            green "  restored $target (from $backup)"
        else
            green "  removed  $target"
        fi
    done
else
    yellow "  skipped configs"
fi

# --- (b) suckless binaries -----------------------------------------------------
blue "=== suckless binaries ==="
mapfile -t suckless_progs < <(manifest_rows SUCKLESS | cut -f2 | sort -u)
if [[ ${#suckless_progs[@]} -eq 0 ]]; then
    blue "  no SUCKLESS rows in manifest — nothing to uninstall"
elif confirm "Uninstall ${#suckless_progs[@]} suckless program(s) (${suckless_progs[*]})?"; then
    for prog in "${suckless_progs[@]}"; do
        dir="$DOTS_DIR/suckless/$prog"
        if [[ ! -f "$dir/Makefile" ]]; then
            yellow "  skip    $prog (no Makefile at $dir)"
            continue
        fi
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would run: make -C $dir uninstall"
            continue
        fi
        if "${SUDO[@]}" make -C "$dir" uninstall >/dev/null 2>&1; then
            green "  uninstalled $prog"
        else
            red "  failed to uninstall $prog (needs root — check sudo access)"
        fi
    done
else
    yellow "  skipped suckless binaries"
fi

# --- (c) packages --------------------------------------------------------------
blue "=== packages ==="
mapfile -t pkgs < <(manifest_rows PACKAGE | cut -f2 | sort -u)
if [[ ${#pkgs[@]} -eq 0 ]]; then
    blue "  no PACKAGE rows in manifest — nothing to remove"
else
    blue "  packages installed by this installer:"
    for p in "${pkgs[@]}"; do blue "    - $p"; done
    if confirm "dnf remove these ${#pkgs[@]} package(s)? (pre-existing packages are never touched)"; then
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would run: dnf remove -y ${pkgs[*]}"
        elif command -v dnf >/dev/null 2>&1; then
            if "${SUDO[@]}" dnf remove -y "${pkgs[@]}" >/dev/null 2>&1; then
                green "  removed ${#pkgs[@]} package(s)"
            else
                red "  dnf remove failed — remove manually: ${pkgs[*]}"
            fi
        else
            yellow "  dnf not found — remove manually: ${pkgs[*]}"
        fi
    else
        yellow "  skipped packages"
    fi
fi

# --- (d) services ----------------------------------------------------------------
blue "=== services ==="
mapfile -t services < <(manifest_rows SERVICE | cut -f2 | sort -u)
if [[ ${#services[@]} -eq 0 ]]; then
    blue "  no SERVICE rows in manifest — nothing to disable"
elif confirm "Disable ${#services[@]} service(s) enabled by this installer (${services[*]})?"; then
    for svc in "${services[@]}"; do
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would run: systemctl disable $svc"
            continue
        fi
        if "${SUDO[@]}" systemctl disable "$svc" >/dev/null 2>&1; then
            green "  disabled $svc"
        else
            red "  failed to disable $svc"
        fi
    done
else
    yellow "  skipped services"
fi

# --- (e) state -------------------------------------------------------------------
blue "=== state ==="
if [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would offer to remove $MANIFEST_DIR (manifest + this log)"
elif confirm "Remove the install state dir $MANIFEST_DIR (manifest + uninstall.log)?"; then
    keep_path=""
    if confirm "Keep a copy of uninstall.log somewhere else first?"; then
        keep_path="$HOME/dots-uninstall.log"
        if [[ "${ASSUME_YES:-0}" -ne 1 ]]; then
            read -r -p "  path to save the log to [$keep_path]: " reply || true
            keep_path="${reply:-$keep_path}"
        fi
        cp "$LOG_FILE" "$keep_path"
        green "  log saved -> $keep_path"
    fi
    rm -rf "$MANIFEST_DIR"
    echo "removed $MANIFEST_DIR"
    [[ -n "$keep_path" ]] && echo "log kept at $keep_path"
else
    yellow "  kept $MANIFEST_DIR"
fi

green "✓ uninstall complete"
