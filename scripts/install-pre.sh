#!/usr/bin/env bash
# "pre" stage: sanity checks before install-fedora.sh's other stages run.
# Standalone-runnable — the install/restore/services stages each re-check
# what they individually need, but running this first gives a fast, clear
# failure on a non-Fedora system instead of a confusing error partway
# through a later stage.
#
# usage: install-pre.sh [--dry-run]

set -euo pipefail

for arg in "$@"; do
    case "$arg" in
        --dry-run) ;; # nothing in this stage mutates state — accepted for interface consistency with the other stages
        -h | --help)
            echo "usage: install-pre.sh [--dry-run]"
            exit 0
            ;;
        *)
            echo "unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

if ! command -v dnf >/dev/null 2>&1; then
    red "dnf not found — this script targets Fedora."
    exit 1
fi
green "ok      dnf found"

if [[ $EUID -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    red "sudo not found and not running as root."
    exit 1
fi
green "ok      privilege escalation available"
