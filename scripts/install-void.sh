#!/usr/bin/env bash
# Bootstrap a full dwm desktop on Void Linux: zsh + tmux, X11 + suckless
# build deps, fonts/theming, desktop utilities, the ly display manager, and
# dwm/st/dmenu/dwmblocks/slock built from suckless/.
#
# This is the ONE supported installer for this repo. Its target is a fresh
# **Void Linux glibc (x86_64) base install** with runit (user decision
# 2026-10-15, replacing Fedora Server; .claude/tasks/scope-i-void-port.md).
# It installs Xorg itself, so a base system with no GUI is the starting point.
#
# PORT IN PROGRESS: the stages below still speak dnf/systemd. Sub-tasks I-3
# to I-8 in the scope file move each one to xbps/runit/elogind. Until those
# land, this script does not work on either distro.
#
# A thin orchestrator over four stages, each its own standalone-runnable,
# idempotent script: pre (sanity checks) -> install (xbps packages + suckless
# build) -> restore (config symlinks + shell/tmux plugin managers) ->
# services (default shell, runit services, groups, ly built from source on
# tty2). Re-runnable: every stage is
# idempotent on its own, so re-running this script after a partial or full
# success converges to the same state rather than erroring or duplicating
# work.
#
# usage: install-void.sh [--only-pre] [--only-install] [--only-restore]
#                           [--only-services] [--skip-suckless] [--dry-run]
#
#   --only-pre        run only the pre stage (sanity checks).
#   --only-install    run only the install stage (dnf packages + suckless build).
#   --only-restore    run only the restore stage (config symlinks + plugin managers).
#   --only-services   run only the services stage (shell, runit services, groups, ly).
#                      Any combination of --only-* flags may be given; with
#                      none given, all four stages run in order (the
#                      default, full-install path).
#   --skip-suckless   skip building dwm/st/dmenu/dwmblocks/slock. Only takes
#                      effect during the install stage. Run
#                      scripts/install-suckless.sh directly later to build
#                      them on their own.
#   --dry-run         thread through every stage: print what would happen
#                      without installing packages, writing files, cloning,
#                      or building anything.
#
# Node.js is intentionally not installed here — install nvm yourself
# afterwards (https://github.com/nvm-sh/nvm) and let it manage Node, since
# its installer needs to touch your zsh rc files and those are symlinked
# from this repo.
#
# lazygit is not installed: it was left out when Fedora only had it in a
# COPR. Void's main repo has it (`sudo xbps-install lazygit`); adding it to
# packages/extra.lst is a roster decision, not made in the port.
#
# The Bibata cursor theme used to be listed here for the same reason. It is
# no longer a COPR decision at all: the upstream release tarball is vendored
# under assets/cursors/ and unpacked by the restore stage, so nothing needs
# enabling. See assets/cursors/README.md.
#
# clipmenu + clipnotify (dwm-clipmenu's backend) were COPR-only on Fedora;
# on Void they are plain desktop.lst packages from the main repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# For manifest_set_meta alone (the "complete" stamp at the end); this script
# defines its own red/green/yellow/blue below, which take precedence.
# shellcheck source=global_fn.sh
source "$SCRIPT_DIR/global_fn.sh"
stop_on_interrupt

# --help prints the header above, up to its first non-comment line (the
# idiom install-live.sh uses; a fixed line range cut it off mid-sentence).
# Handled before the log tee below: a help request is not a run.
for arg in "$@"; do
    case "$arg" in
        -h | --help)
            sed -n '2,/^[^#]/{/^#/s/^# \{0,1\}//p}' "${BASH_SOURCE[0]}"
            exit 0
            ;;
    esac
done

# Tee this run's full output (stdout+stderr, including every stage script
# invoked below as a child process) into install.log at the repo root, so
# repeated runs can be diffed later, while still showing live colored
# output in the terminal. ANSI color codes are stripped before the log
# write only (sed -u keeps it unbuffered/live) — the terminal stays
# colored, the log file stays plain text. Append mode: runs accumulate in
# the same file, separated by the timestamp header below. --dry-run runs
# ARE logged too (deliberate, not skipped) — a dry-run's stage plan is
# exactly the kind of thing worth comparing against a later real run.
LOG_FILE="$DOTS_DIR/install.log"
exec > >(tee >(sed -u 's/\x1b\[[0-9;]*m//g' >>"$LOG_FILE")) 2>&1

echo "=== install-void.sh run started: $(date '+%Y-%m-%d %H:%M:%S') (args: $*) ==="
trap 'echo "=== install-void.sh run finished: $(date "+%Y-%m-%d %H:%M:%S") ==="' EXIT

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

RUN_PRE=0
RUN_INSTALL=0
RUN_RESTORE=0
RUN_SERVICES=0
ANY_ONLY=0
SKIP_SUCKLESS=0
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --only-pre)
            RUN_PRE=1
            ANY_ONLY=1
            ;;
        --only-install)
            RUN_INSTALL=1
            ANY_ONLY=1
            ;;
        --only-restore)
            RUN_RESTORE=1
            ANY_ONLY=1
            ;;
        --only-services)
            RUN_SERVICES=1
            ANY_ONLY=1
            ;;
        --skip-suckless) SKIP_SUCKLESS=1 ;;
        --dry-run) DRY_RUN=1 ;;
        *)
            red "unknown argument: $arg"
            exit 1
            ;;
    esac
done

# No --only-* flag given -> run every stage (the default, full-install path).
if [[ $ANY_ONLY -eq 0 ]]; then
    RUN_PRE=1
    RUN_INSTALL=1
    RUN_RESTORE=1
    RUN_SERVICES=1
fi

dry_run_args=()
[[ $DRY_RUN -eq 1 ]] && dry_run_args+=(--dry-run)

if [[ $RUN_PRE -eq 1 ]]; then
    blue "=== pre stage ==="
    "$SCRIPT_DIR/install-pre.sh" "${dry_run_args[@]}"
fi

# Runs unconditionally (regardless of which --only-* stages were picked):
# a no-op on a fresh install (no manifest yet) or one already at VERSION,
# and otherwise brings an older existing install's manifest version
# forward before any stage below re-stamps it via manifest_init.
blue "=== migrations ==="
"$SCRIPT_DIR/migrate.sh" "${dry_run_args[@]}"

if [[ $RUN_INSTALL -eq 1 ]]; then
    blue "=== install stage ==="
    "$SCRIPT_DIR/install-pkg.sh" "${dry_run_args[@]}"
    if [[ $SKIP_SUCKLESS -eq 0 ]]; then
        blue "==> building suckless programs"
        # No --skip-deps: install-suckless.sh installs packages/build.lst
        # itself, immediately before it compiles. Keeping the build deps in
        # that stage rather than in install-pkg.sh is what makes
        # --skip-suckless need no special handling — skip the build and they
        # are simply never installed.
        "$SCRIPT_DIR/install-suckless.sh" "${dry_run_args[@]}"
    else
        yellow "  --skip-suckless passed — run scripts/install-suckless.sh later to build dwm/st/dmenu/dwmblocks/slock"
    fi
fi

if [[ $RUN_RESTORE -eq 1 ]]; then
    blue "=== restore stage ==="
    "$SCRIPT_DIR/install-restore.sh" "${dry_run_args[@]}"
fi

if [[ $RUN_SERVICES -eq 1 ]]; then
    blue "=== services stage ==="
    "$SCRIPT_DIR/install-services.sh" "${dry_run_args[@]}"
fi

# Only a full run that got here finished: every stage stamps `commit` as it
# STARTS, so a run stopped partway (Ctrl-C during the package stage, on the
# VM, 2026-10-13) used to read as current to `dots update`. --only-* runs one
# stage and --dry-run changes nothing, so neither counts as a finished install.
if [[ $ANY_ONLY -eq 0 && $DRY_RUN -eq 0 ]]; then
    manifest_set_meta complete "$(git -C "$DOTS_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
        || yellow "warn    could not record the finished install — the next dots update re-runs it"
fi

green "✓ install complete"
yellow "  - open a new shell or run: exec zsh"
yellow "  - on first tmux start, TPM auto-installs plugins"
yellow "  - log in via ly on tty2 on next boot; tty1's getty is left alone on purpose as a rescue login"
yellow "  - Node.js: install nvm yourself (https://github.com/nvm-sh/nvm), then nvm install --lts"
yellow "  - lazygit is not installed by default: sudo xbps-install lazygit"
