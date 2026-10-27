#!/usr/bin/env bash
# tmux's terminal settings (config/tmux/conf.d/00-options.conf), loaded into a
# real, isolated tmux server (its own -L socket and TMUX_TMPDIR, so the user's
# server is never touched):
#
#   * default-terminal is tmux-256color where its terminfo entry exists, and
#     screen-256color where it does not. Void ships tmux-256color in
#     ncurses-term, not ncurses-base; with a TERM that has no entry, zsh inside
#     tmux cannot clear a line and every redraw leaves junk behind (2026-10-27).
#     Both sides are run: TERMINFO_DIRS points at a directory that holds the
#     entry, then at one that holds only screen-256color;
#   * every terminal-features entry names a terminal pattern followed by its
#     features. A ',' where a ':' belongs starts a new entry, and tmux took
#     "clipboard" and "sync" for terminal names that way, so kitty got RGB alone;
#   * alacritty, the main terminal, gets RGB (true colour).
#
# Skips loudly without tmux, infocmp or tic.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

CONF="$DOTS_DIR/config/tmux/conf.d/00-options.conf"
[[ -f "$CONF" ]] || {
    red "missing: $CONF"
    exit 1
}

for t in tmux infocmp tic; do
    if ! command -v "$t" >/dev/null 2>&1; then
        yellow "skip: tmux-terminal.sh needs $t"
        exit 0
    fi
done

rc=0
check() {
    local name="$1" got="$2" want="$3"
    if [[ "$got" == "$want" ]]; then
        green "  ok: $name"
    else
        red "  FAIL: $name — got '$got', want '$want'"
        rc=1
    fi
}

TMP="$(mktemp -d)"
trap 'env -i PATH="$PATH" TMUX_TMPDIR="$TMP" tmux -L termtest kill-server 2>/dev/null || true; rm -rf -- "$TMP"' EXIT

# terminfo <dir> <name>... — a terminfo dir holding these names, each a copy of
# screen-256color (renamed), so the test needs only ncurses-base.
terminfo() {
    local dir="$1" name
    shift
    mkdir -p "$dir"
    for name in "$@"; do
        infocmp -x screen-256color | sed "s/^screen-256color|[^,]*,/$name|test copy,/" \
            | tic -x -o "$dir" - 2>/dev/null
    done
}
# tmx <terminfo dir> <tmux command>... — one run of the config in a fresh server.
tmx() {
    local dir="$1"
    shift
    env -i PATH="$PATH" HOME="$TMP" TMUX_TMPDIR="$TMP" TERMINFO="$dir" TERMINFO_DIRS="$dir" \
        tmux -L termtest -f "$CONF" new-session -d -s t \; "$@" \; kill-server
}

blue "==> default-terminal follows the terminfo there is"
terminfo "$TMP/with" screen-256color tmux-256color
terminfo "$TMP/without" screen-256color
check "tmux-256color when its entry exists" \
    "$(tmx "$TMP/with" show -gv default-terminal)" "tmux-256color"
check "screen-256color when it does not" \
    "$(tmx "$TMP/without" show -gv default-terminal)" "screen-256color"

blue "==> terminal-features: one terminal per entry"
features="$(tmx "$TMP/with" show -g terminal-features | cut -d' ' -f2-)"
# A tmux feature name standing alone is the ',' mistake.
bare="$(grep -xE 'RGB|clipboard|sync|title|hyperlinks|osc7|focus|mouse|256' <<<"$features" | paste -sd, || true)"
check "no feature name parsed as a terminal" "$bare" ""
check "alacritty gets true colour" \
    "$(grep -cE '^alacritty:([^:]*:)*RGB(:|$)' <<<"$features" || true)" "1"
check "kitty gets more than RGB" \
    "$(grep -cE '^xterm-kitty:RGB:.*clipboard' <<<"$features" || true)" "1"

if ((rc == 0)); then green "tmux-terminal: all checks passed"; else red "tmux-terminal: FAILED"; fi
exit "$rc"
