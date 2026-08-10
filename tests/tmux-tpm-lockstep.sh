#!/usr/bin/env bash
# Keeps the TPM plugin directory in step between the two files that derive it.
#
#   * scripts/install-restore.sh  — pre-clones TPM there so first tmux launch
#     is not blocked on a network round-trip;
#   * config/tmux/conf.d/30-plugins.conf — tells tmux and TPM where to look,
#     and bootstraps a clone itself if nothing is there.
#
# Let those disagree and nothing errors: the installer clones to a directory
# tmux never reads, TPM's own bootstrap quietly fetches a second copy on first
# launch, and the pre-clone becomes dead weight that still cost a download.
# Two plugin trees then drift apart with no message anywhere.
#
# This is the same class of drift tests/picom-lockstep.sh guards between
# picom.conf and picom.dcol, and tests/autostart-daemons.sh guards between the
# two halves of install-session.sh.
#
# WHY THE tmux SIDE LOOKS THE WAY IT DOES. tmux.conf is not a shell: it
# expands $VAR and ${VAR} but has no ${VAR:-default}, so an unset
# XDG_DATA_HOME would collapse the path to "/tmux/plugins". Every path in
# 30-plugins.conf therefore sits inside a SINGLE-quoted run-shell body, which
# tmux passes through untouched for /bin/sh to expand. Double quotes would let
# tmux expand them first and reintroduce that bug, so this test rejects the
# undefaulted spelling outright rather than only comparing the two files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

INSTALLER="$DOTS_DIR/scripts/install-restore.sh"
TMUXCONF="$DOTS_DIR/config/tmux/conf.d/30-plugins.conf"
for f in "$INSTALLER" "$TMUXCONF"; do
    [[ -f "$f" ]] || {
        red "missing: $f"
        exit 1
    }
done

# The defaulted spelling both files must use, and the bare one neither may.
#
# Single-quoted on purpose, hence SC2016 twice: these are the literal texts to
# search the two files FOR. Expanding them here would turn each into this
# machine's own resolved path and the search would match nothing.
# shellcheck disable=SC2016
XDG_FORM='${XDG_DATA_HOME:-$HOME/.local/share}/tmux/plugins'
# shellcheck disable=SC2016
BARE_FORM='$HOME/.local/share/tmux/plugins'

rc=0

# --- 1: neither file may use the undefaulted path ---------------------------
blue "==> checking for the undefaulted \$HOME/.local/share spelling"
for f in "$INSTALLER" "$TMUXCONF"; do
    if grep -qF -- "$BARE_FORM" "$f"; then
        red "  $(basename "$f") still hardcodes $BARE_FORM:"
        grep -nF -- "$BARE_FORM" "$f" | sed 's/^/     /'
        red "     use $XDG_FORM instead"
        rc=1
    fi
done
((rc == 0)) && green "  ok: neither file hardcodes it"

# --- 2: every tmux-side plugin path uses the defaulted spelling -------------
# Counting both ways catches a path added in the wrong form as well as one
# quietly deleted, without this test needing to know how many there are.
#
# Comment lines are excluded first, and that is not a detail: the header of
# 30-plugins.conf discusses "/tmux/plugins" precisely to explain the quoting
# rule, so counting raw grep hits scores the explanation as a violation. Same
# trap the earlier autostart test fell into by matching a daemon name inside
# its own comment.
blue "==> checking every plugin path in 30-plugins.conf"
commands="$(grep -v '^[[:space:]]*#' "$TMUXCONF" || true)"
total="$(printf '%s\n' "$commands" | grep -c 'tmux/plugins' || true)"
defaulted="$(printf '%s\n' "$commands" | grep -cF -- "$XDG_FORM" || true)"
if [[ "$total" -eq 0 ]]; then
    red "  no tmux/plugins path in any command — the file was gutted, or this"
    red "     test is stale (only comments mention the path now)"
    rc=1
elif [[ "$total" -ne "$defaulted" ]]; then
    red "  $total plugin paths in commands, only $defaulted defaulted — these are not:"
    grep -n 'tmux/plugins' "$TMUXCONF" \
        | grep -v ':[[:space:]]*#' | grep -vF -- "$XDG_FORM" | sed 's/^/     /'
    rc=1
else
    green "  ok: all $total command-line paths use $XDG_FORM"
fi

# --- 3: the installer states it exactly once, and it resolves the same ------
# Evaluated rather than string-compared, so a difference in quoting or a
# trailing slash cannot pass. eval on first-party repo content only, and only
# on the right-hand side of a line this file just matched.
blue "==> resolving both sides under the same environment"
mapfile -t TPM_ASSIGN < <(grep -n '^TPM_DIR=' "$INSTALLER")
if [[ ${#TPM_ASSIGN[@]} -ne 1 ]]; then
    red "  expected exactly one TPM_DIR= assignment in $(basename "$INSTALLER"), found ${#TPM_ASSIGN[@]}"
    printf '     %s\n' "${TPM_ASSIGN[@]}"
    rc=1
else
    rhs="${TPM_ASSIGN[0]#*TPM_DIR=}"
    for xdh in /custom/data ""; do
        inst="$(env -i HOME=/home/probe ${xdh:+XDG_DATA_HOME="$xdh"} \
            bash -c "printf '%s' $rhs")"
        conf="$(env -i HOME=/home/probe ${xdh:+XDG_DATA_HOME="$xdh"} \
            sh -c "printf '%s' \"$XDG_FORM/tpm\"")"
        if [[ "$inst" == "$conf" ]]; then
            green "  ok: XDG_DATA_HOME='${xdh}' -> $inst"
        else
            red "  XDG_DATA_HOME='${xdh}': installer says '$inst', tmux says '$conf'"
            rc=1
        fi
    done
fi

if ((rc != 0)); then
    red "✗ TPM directory has drifted between the installer and the tmux config"
    exit 1
fi
green "✓ TPM directory: installer and 30-plugins.conf agree"
