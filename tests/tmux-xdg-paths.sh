#!/usr/bin/env bash
# Every XDG data/state path under config/tmux/ honours $XDG_DATA_HOME /
# $XDG_STATE_HOME rather than hardcoding the ~/.local fallback.
#
# tests/tmux-tpm-lockstep.sh already guards the TPM directory, but only in the
# two files it names — so when the 2026-08-10 sweep fixed $XDG_DATA_HOME there,
# the same bug survived in config/tmux/bin/tmux-palette (resurrect save and
# restore) and, one variable over, in @resurrect-dir. This test covers the
# whole tree instead of a list of files, which is the lesson of that miss.
#
# ~/.config/tmux paths are deliberately NOT checked: scripts/symlinks.sh itself
# links config/tmux to $HOME/.config/tmux, so those are consistent by design.
#
# Two layers:
#   1. static — no command line under config/tmux/ may name .local/share or
#      .local/state except inside the ${XDG_…:-$HOME/.local/…} form;
#   2. live — when tmux is installed, the real @resurrect-dir line and the
#      palette's resurrect entries are loaded into an isolated tmux server
#      (its own -L socket and TMUX_TMPDIR, so the user's server is never
#      touched) and checked for where they actually resolve. Skips loudly
#      without tmux, because a static check alone cannot catch a quoting
#      mistake that tmux's own parser would make.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TMUX_DIR="$DOTS_DIR/config/tmux"
PLUGINS_CONF="$TMUX_DIR/conf.d/30-plugins.conf"
PALETTE="$TMUX_DIR/bin/tmux-palette"
for f in "$PLUGINS_CONF" "$PALETTE"; do
    [[ -f "$f" ]] || {
        red "missing: $f"
        exit 1
    }
done

# Literal texts to search FOR, hence single quotes.
# shellcheck disable=SC2016
DATA_FORM='${XDG_DATA_HOME:-$HOME/.local/share}'
# shellcheck disable=SC2016
STATE_FORM='${XDG_STATE_HOME:-$HOME/.local/state}'

rc=0

# --- 1: static sweep of the whole tree ---------------------------------------
# Comment lines are dropped first: headers explain the rule by quoting the bare
# path, and matching prose is how an earlier test here scored its own
# explanation as a violation. Then the two defaulted forms are deleted from
# each line; any .local/share or .local/state still left is a hardcode.
blue "==> no hardcoded ~/.local/{share,state} under config/tmux/"
hits="$(grep -rnE '\.local/(share|state)' "$TMUX_DIR" \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
    | awk -v d="$DATA_FORM" -v s="$STATE_FORM" '{
        line = $0
        while ((i = index(line, d)) > 0) line = substr(line, 1, i - 1) substr(line, i + length(d))
        while ((i = index(line, s)) > 0) line = substr(line, 1, i - 1) substr(line, i + length(s))
        if (line ~ /\.local\/(share|state)/) print $0
    }')" || true
if [[ -n "$hits" ]]; then
    red "  these lines hardcode the fallback instead of $DATA_FORM / $STATE_FORM:"
    printf '%s\n' "$hits" | sed "s|^$DOTS_DIR/|     |"
    rc=1
else
    green "  ok: every data/state path uses the XDG-defaulted form"
fi

# --- 2: live resolution in an isolated tmux server ---------------------------
if ! command -v tmux >/dev/null 2>&1; then
    yellow "SKIP: live check needs tmux — only the static sweep ran."
else
    blue "==> resolving in a real, isolated tmux server ($(tmux -V))"
    # The two tmux-plugins scripts are fakes that record they ran, so the
    # palette entries can be executed without the real plugin installed.
    TMP="$(mktemp -d)"
    trap 'env -i PATH="$PATH" TMUX_TMPDIR="$TMP" tmux -L xdgtest kill-server 2>/dev/null || true; rm -rf -- "$TMP"' EXIT
    grep -E '^run-shell .*@resurrect-dir' "$PLUGINS_CONF" >"$TMP/resurrect.conf" || true
    grep -E '^resurrect: ' "$PALETTE" | sed 's/^[^|]*|//' >"$TMP/palette.conf" || true
    [[ -s "$TMP/resurrect.conf" ]] || {
        red "  no run-shell line setting @resurrect-dir in 30-plugins.conf"
        rc=1
    }
    [[ "$(wc -l <"$TMP/palette.conf")" -eq 2 ]] || {
        red "  expected 2 resurrect entries in tmux-palette, found $(wc -l <"$TMP/palette.conf")"
        rc=1
    }
    home="$TMP/home"
    for case in custom unset; do
        # "custom" exports both variables; "unset" exports neither, so the
        # ~/.local fallbacks inside the defaulted forms are what gets tested.
        if [[ "$case" == custom ]]; then
            data="$TMP/data" state="$TMP/state"
            xdg_args=(XDG_DATA_HOME="$data" XDG_STATE_HOME="$state")
        else
            data="$home/.local/share" state="$home/.local/state"
            xdg_args=()
        fi
        mkdir -p "$data/tmux/plugins/tmux-resurrect/scripts"
        for act in save restore; do
            printf '#!/bin/sh\necho %s >>"%s/ran"\n' "$act" "$TMP" \
                >"$data/tmux/plugins/tmux-resurrect/scripts/$act.sh"
            chmod +x "$data/tmux/plugins/tmux-resurrect/scripts/$act.sh"
        done
        : >"$TMP/ran"
        tmx=(env -i PATH="$PATH" HOME="$home" TMUX_TMPDIR="$TMP" "${xdg_args[@]}" tmux -L xdgtest)
        "${tmx[@]}" -f "$TMP/resurrect.conf" new-session -d -s t 'sleep 30'
        got="$("${tmx[@]}" show-options -gv @resurrect-dir 2>/dev/null || true)"
        want="$state/tmux/resurrect"
        if [[ "$got" == "$want" ]]; then
            green "  ok: XDG ${case}: @resurrect-dir -> $got"
        else
            red "  XDG ${case}: @resurrect-dir is '$got', expected '$want'"
            rc=1
        fi
        "${tmx[@]}" source-file "$TMP/palette.conf" || true
        # Polled, not a fixed sleep: a slow runner must not read this early.
        for _ in $(seq 1 30); do
            [[ "$(wc -l <"$TMP/ran")" -ge 2 ]] && break
            sleep 0.1
        done
        if [[ "$(sort "$TMP/ran" | tr '\n' ' ')" == "restore save " ]]; then
            green "  ok: XDG ${case}: palette's resurrect save + restore reach $data"
        else
            red "  XDG ${case}: palette's resurrect entries ran [$(tr '\n' ' ' <"$TMP/ran")], expected both under $data"
            rc=1
        fi
        "${tmx[@]}" kill-server 2>/dev/null || true
    done
fi

if ((rc != 0)); then
    red "✗ a tmux path ignores XDG"
    exit 1
fi
green "✓ tmux XDG paths: data and state both honour their XDG variables"
