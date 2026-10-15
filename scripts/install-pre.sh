#!/usr/bin/env bash
# "pre" stage: sanity checks before install-void.sh's other stages run.
# Standalone-runnable — the install/restore/services stages each re-check
# what they individually need, but running this first gives a fast, clear
# failure on a non-Void system instead of a confusing error partway
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
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

if ! command -v xbps-install >/dev/null 2>&1; then
    red "xbps-install not found — this script targets Void Linux."
    exit 1
fi
green "ok      xbps found"

if [[ $EUID -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    red "sudo not found and not running as root."
    exit 1
fi
green "ok      privilege escalation available"

# wheel is the one group the install cannot add for you (scope I, decision
# D4): every privileged step runs through sudo, and Void's sudoers grants it
# to %wheel. Not in it means every later sudo fails, so stop here, saying how
# to fix it. Root needs no sudo, so it is exempt.
if [[ $EUID -ne 0 ]]; then
    me="$(id -un 2>/dev/null || true)"
    if [[ " $(id -nG 2>/dev/null || true) " != *" wheel "* ]]; then
        red "$me is not in the wheel group — sudo will refuse every step of the install."
        red "        As root:  usermod -aG wheel $me   then log in again and re-run."
        exit 1
    fi
    green "ok      $me is in wheel"
fi

# The supported target is Void glibc (scope I). A musl install shares most
# package names, but the nonfree repo the default editor comes from is
# glibc-only and nothing here has been tried on musl. Said up front and
# loudly, but not refused, the same way the old Fedora Workstation note was.
# xbps-uhelper prints the native arch: x86_64, or x86_64-musl.
arch="$(xbps-uhelper arch 2>/dev/null || true)"
if [[ "$arch" == *-musl ]]; then
    yellow "note    this is Void musl ($arch); the supported target is Void glibc."
    yellow "        The install continues, but the editor (nonfree, glibc-only) will"
    yellow "        not install and nothing here has been tested on musl."
fi
