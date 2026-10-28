#!/usr/bin/env bash
# "services" stage: sets zsh as the default login shell, enables the runit
# services the desktop needs (dbus, elogind, NetworkManager, bluetoothd —
# install-services-runit.sh), adds the user to the groups it needs
# (install-services-groups.sh), builds ly from source
# (install-services-ly.sh) and hands tty2 from its getty to ly. tty1's getty
# is deliberately left alone as a rescue login. Then system upkeep: a weekly
# SSD TRIM and zram swap tuning (install-services-maint.sh).
#
# usage: install-services.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/global_fn.sh"
stop_on_interrupt

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

# shellcheck source=install-services-runit.sh
source "$SCRIPT_DIR/install-services-runit.sh"
# shellcheck source=install-services-groups.sh
source "$SCRIPT_DIR/install-services-groups.sh"
# shellcheck source=install-services-ly.sh
source "$SCRIPT_DIR/install-services-ly.sh"
# shellcheck source=install-services-maint.sh
source "$SCRIPT_DIR/install-services-maint.sh"

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
# The directory is resolved physically (2026-10-05, Fedora 44 VM). Since f42
# /usr/sbin is a symlink to /usr/bin, and a PATH with sbin first — root's, and
# ly's — finds /usr/sbin/zsh. Taken as-is, that spelling went into passwd and
# /etc/shells, and a later run under a bin-first PATH saw "/usr/bin/zsh !=
# /usr/sbin/zsh", ran usermod again and recorded zsh as the PREVIOUS shell —
# the one uninstall restores. Only the directory is resolved: the binary
# itself may be a symlink to a versioned name nobody should log in through.
if [[ -n "$ZSH_BIN" ]]; then
    zsh_dir="$(cd "${ZSH_BIN%/*}" 2>/dev/null && pwd -P || true)"
    [[ -n "$zsh_dir" ]] && ZSH_BIN="$zsh_dir/zsh"
fi
if [[ -n "$ZSH_BIN" ]]; then
    if ! grep -qx "$ZSH_BIN" /etc/shells; then
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would add $ZSH_BIN -> /etc/shells"
        else
            echo "$ZSH_BIN" | "${SUDO[@]}" tee -a /etc/shells >/dev/null
            green "added   $ZSH_BIN -> /etc/shells"
        fi
    fi
    # $USER is not guaranteed to be set. A container, a cron job and `su -c`
    # all leave it empty, and under `set -u` that is fatal — it took the whole
    # services stage down after every earlier stage had already succeeded.
    # `id -un` asks the passwd database instead of trusting the environment.
    #
    # The trailing `|| true` covers the other half of the same line: with
    # `pipefail`, a getent miss (a user with no passwd entry at all) fails the
    # command substitution, and `set -e` then aborts on the ASSIGNMENT, printing
    # nothing. An empty CURRENT_SHELL is fine — it just is not zsh, so the shell
    # branch below runs and degrades on its own terms.
    #
    # usermod, not chsh (2026-10-05, first real Fedora install). chsh run as
    # the user authenticates through PAM and wants the password on a terminal;
    # inside this script it failed silently — stderr was suppressed — and the
    # login shell stayed bash. Fedora Server may not ship chsh at all (it is
    # util-linux-user). usermod is shadow-utils, always present, and runs under
    # the sudo this stage already requires; its stderr is left visible.
    CURRENT_USER="${USER:-$(id -un 2>/dev/null || true)}"
    CURRENT_SHELL="$(getent passwd "$CURRENT_USER" 2>/dev/null | cut -d: -f7 || true)"
    if [[ "$CURRENT_SHELL" == "$ZSH_BIN" ]]; then
        green "ok      login shell is already zsh"
    elif [[ -n "$CURRENT_SHELL" && "$CURRENT_SHELL" -ef "$ZSH_BIN" ]]; then
        # Already zsh, spelled another way (/usr/sbin/zsh from an install that
        # predates the resolution above). Respell it, but append NO SHELL row:
        # the row from the run that switched to zsh holds the real previous
        # shell, and uninstall reads the last row.
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would usermod -s $ZSH_BIN $CURRENT_USER (was $CURRENT_SHELL, same binary)"
        elif "${SUDO[@]}" usermod -s "$ZSH_BIN" "$CURRENT_USER"; then
            green "login shell $CURRENT_SHELL -> $ZSH_BIN (same binary, canonical path)"
        else
            yellow "could not respell the login shell — it still works; to fix:  sudo usermod -s $ZSH_BIN \$USER"
        fi
    else
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would usermod -s $ZSH_BIN $CURRENT_USER"
        elif [[ -n "$CURRENT_USER" ]] \
            && "${SUDO[@]}" usermod -s "$ZSH_BIN" "$CURRENT_USER"; then
            # Recorded only on the one run that actually changes the shell —
            # once it's zsh, this branch is never re-entered, so a re-run
            # never clobbers the real previous shell with "zsh".
            manifest_append_row SHELL "$CURRENT_SHELL" "$ZSH_BIN"
            green "default shell -> $ZSH_BIN"
        else
            yellow "could not set the login shell — run manually:  sudo usermod -s $ZSH_BIN \$USER"
        fi
    fi
else
    yellow "zsh not found on PATH — run the install stage first (packages/core.lst) so this stage can set it as the default shell"
fi

services_enable_desktop
services_maintenance
groups_add "${USER:-$(id -un 2>/dev/null || true)}"

# ly, then tty2. tty2 is handed over only once a ly binary is really there and
# ly_take_tty2 can link its service; every other path leaves tty2's login
# prompt alone (install-services-ly.sh). Uninstall re-links the getty
# (uninstall-runit.sh).
if ly_install || [[ -x "$(ly_bin)" ]]; then
    ly_take_tty2 || true
    # The login screen's colours, from the active static theme (themes/dark on
    # a first install). Its own script, because a theme switch runs it too;
    # it never aborts this stage — a refusal is a yellow line, not a failure.
    ly_args=()
    [[ $DRY_RUN -eq 1 ]] && ly_args+=(--dry-run)
    "$DOTS_DIR/scripts/theme/ly-theme.sh" "${ly_args[@]}" \
        || yellow "ly login screen not themed — run:  dots login-theme"
fi

green "✓ services stage complete"
