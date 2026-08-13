#!/usr/bin/env bash
# "services" stage: sets zsh as the default login shell and enables the ly
# display manager on tty2 (`ly@tty2.service` — the unit is templated per TTY).
# Still does not touch getty units by hand: the unit's own
# `Conflicts=getty@%i.service` releases tty2 when ly starts, and tty1's getty
# is deliberately left alone as a rescue login.
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
    # $USER is not guaranteed to be set. A container, a cron job and `su -c`
    # all leave it empty, and under `set -u` that is fatal — it took the whole
    # services stage down after every earlier stage had already succeeded.
    # `id -un` asks the passwd database instead of trusting the environment.
    #
    # The trailing `|| true` covers the other half of the same line: with
    # `pipefail`, a getent miss (a user with no passwd entry at all) fails the
    # command substitution, and `set -e` then aborts on the ASSIGNMENT, printing
    # nothing. An empty CURRENT_SHELL is fine — it just is not zsh, so the chsh
    # branch below runs and degrades on its own terms.
    CURRENT_USER="${USER:-$(id -un 2>/dev/null || true)}"
    CURRENT_SHELL="$(getent passwd "$CURRENT_USER" 2>/dev/null | cut -d: -f7 || true)"
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

# ly ships a TEMPLATED unit — `ly@.service`, instantiated per TTY — and no
# plain `ly.service` and no Alias= for one. This stage enabled `ly.service`
# from the day it was written, so it has never enabled a display manager on
# any machine; `systemctl enable ly.service` fails with "Unit ly.service does
# not exist". Found 2026-08-13 by the install-container CI job, on its first
# real run, which is the entire reason that job exists.
#
# tty2 rather than tty1: the unit carries `Conflicts=getty@%i.service`, so
# instantiating it takes that TTY away from its getty by itself — no manual
# getty step, and tty1's getty survives as a rescue login if ly misbehaves.
LY_UNIT="ly@tty2.service"
if command -v ly >/dev/null 2>&1 || rpm -q ly >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would enable $LY_UNIT"
    elif systemctl is-enabled "$LY_UNIT" >/dev/null 2>&1; then
        green "ok      $LY_UNIT already enabled"
    # Same degrade-don't-abort shape as the chsh call above, so a failure here
    # cannot take the whole stage down via set -e after every earlier stage has
    # already succeeded. Unlike chsh, stderr is NOT suppressed: systemctl's own
    # message is the useful half of this branch. The observed one was
    # "Failed to enable unit: Unit ly.service does not exist" — which is how
    # the wrong-unit bug above was finally caught, and exactly the text someone
    # debugging a fresh install needs to see.
    elif "${SUDO[@]}" systemctl enable "$LY_UNIT"; then
        # Recorded only on the run that actually enables it, so a re-run
        # never appends a duplicate row.
        manifest_append_row SERVICE "$LY_UNIT"
        green "enabled $LY_UNIT"
    else
        yellow "could not enable $LY_UNIT — run manually:  sudo systemctl enable $LY_UNIT"
    fi
fi

green "✓ services stage complete"
