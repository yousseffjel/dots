#!/usr/bin/env bash
# Single reload entry point for the theming engine. Order matters:
# xrdb -merge runs first and alone, because every X11 consumer below
# re-reads its colors from the X resource database — merging after
# signalling them would have each one pick up the *previous* palette.
# Once the database is current, the per-app reloads are independent of
# each other and run concurrently.
#
# Every step is best-effort: a target that is not installed, or not
# running, is skipped with a log line and never fails the run. Applying a
# theme must not abort because the user has no compositor.
#
# Usage: reload.sh [--quiet]
set -euo pipefail

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h | --help)
            echo "usage: reload.sh [--quiet]"
            echo "  --quiet   only report failures"
            exit 0
            ;;
        *)
            red "unknown argument: $arg"
            exit 1
            ;;
    esac
done

say() { [[ $QUIET -eq 1 ]] || "$@"; }

cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"
XRESOURCES="$cacheDir/xresources"
# Best-effort: this script's contract is to skip and log, never to fail, so
# an uncreatable cache dir must not abort the reload under `set -e`. The
# lock probe and the xresources check below both degrade on their own when
# the directory is absent.
mkdir -p "$cacheDir" 2>/dev/null || true

# Serialize concurrent reloads. This is bound to a hotkey (Mod+Shift+w and
# friends), so back-to-back invocations are entirely normal — and two of
# them interleaving would race the kill/restart in reload_dwmblocks and
# can leave two dwmblocks instances alive.
#
# The lock is held on an explicit fd rather than via `exec flock ... "$0"`.
# The re-exec form leaks its lock fd into every descendant, including the
# *detached, long-lived* dwmblocks daemon spawned below — that daemon then
# holds the lock for its entire lifetime, so every later reload would
# block for the full timeout and fail. Holding our own fd lets us close it
# explicitly in that one spawn (see reload_dwmblocks).
#
# Degrades to unlocked if flock is missing or the lock file cannot be
# opened, rather than refusing to reload.
LOCKFD=""
# The `2>/dev/null` must precede the append redirect: bash applies
# redirections left to right, so with the natural ordering the failure
# message for an unopenable lock file escapes to the real stderr before
# stderr has been silenced.
if command -v flock >/dev/null 2>&1 && : 2>/dev/null >>"$cacheDir/.reload.lock"; then
    exec {LOCKFD}>>"$cacheDir/.reload.lock" 2>/dev/null
    if ! flock -w 30 "$LOCKFD"; then
        yellow "another reload held the lock for 30s — skipping this one"
        exit 0
    fi
fi

# Bound on any single external call that could wedge. kill/pkill/setsid
# return immediately, but xrdb can block on a hung X server and ~/.fehbg is
# an arbitrary user-owned script — either could otherwise hang the bare
# `wait` below forever with no escape hatch.
STEP_TIMEOUT=10
run_bounded() {
    if command -v timeout >/dev/null 2>&1; then
        timeout "$STEP_TIMEOUT" "$@"
    else
        "$@"
    fi
}

# Without a display there is nothing to reload — this is the normal case
# when the installer runs on a fresh box before startx, so it is a clean
# exit, not an error.
if [[ -z "${DISPLAY:-}" ]]; then
    say yellow "no DISPLAY — skipping reload (colors apply on next X start)"
    exit 0
fi

# --- step 1: the X resource database, alone and first ------------------
if [[ -f "$XRESOURCES" ]]; then
    if command -v xrdb >/dev/null 2>&1; then
        if run_bounded xrdb -merge "$XRESOURCES"; then
            say green "xrdb    merged $XRESOURCES"
        else
            red "xrdb    merge FAILED — downstream apps keep their old colors"
        fi
    else
        yellow "xrdb    not installed — skipping (xorg-x11-server-utils)"
    fi
else
    yellow "xrdb    no $XRESOURCES yet — run colorgen.sh + apply-templates.sh first"
fi

# --- step 2: everything else, concurrently -----------------------------
# Each helper is fully self-guarding so it can be backgrounded safely.

reload_dwm() {
    # restartsig: SIGHUP makes dwm re-exec itself, which re-runs
    # xresupdate() at startup and so re-reads the freshly merged database.
    if pidof -s dwm >/dev/null 2>&1; then
        # shellcheck disable=SC2046  # pidof -s yields exactly one pid
        if kill -HUP $(pidof -s dwm) 2>/dev/null; then
            say green "dwm     HUP sent (restartsig re-exec)"
        else
            yellow "dwm     HUP failed"
        fi
    else
        say yellow "dwm     not running — skipped"
    fi
}

reload_st() {
    # The xresources-signal-reload patch re-reads colors in place, so
    # running shells survive. Every st instance gets the signal.
    if pgrep -x st >/dev/null 2>&1; then
        if pkill -USR1 -x st 2>/dev/null; then
            say green "st      USR1 sent to all instances"
        else
            yellow "st      USR1 failed"
        fi
    else
        say yellow "st      not running — skipped"
    fi
}

reload_dwmblocks() {
    # No reload signal of its own: the block scripts read the generated
    # palette at exec time, so the bar only re-themes on restart. setsid
    # detaches it from this script, otherwise it dies with us.
    if ! command -v dwmblocks >/dev/null 2>&1; then
        say yellow "blocks  dwmblocks not installed — skipped"
        return 0
    fi
    if pkill -x dwmblocks 2>/dev/null; then
        # {LOCKFD}>&- closes our flock fd in the child only. Without it the
        # daemon inherits and holds the lock for its whole lifetime, and
        # every subsequent reload stalls on flock and then fails.
        if [[ -n "$LOCKFD" ]]; then
            setsid dwmblocks >/dev/null 2>&1 {LOCKFD}>&- &
        else
            setsid dwmblocks >/dev/null 2>&1 &
        fi
        disown
        say green "blocks  restarted"
    else
        say yellow "blocks  not running — skipped"
    fi
}

reload_dunst() {
    # dunst is D-Bus activated: killing it is enough, the next
    # notification respawns it against the regenerated dunstrc. Starting
    # it here would race that activation.
    if ! command -v dunst >/dev/null 2>&1; then
        say yellow "dunst   not installed — skipped"
        return 0
    fi
    if pkill -x dunst 2>/dev/null; then
        say green "dunst   killed (D-Bus respawns on next notification)"
    else
        say yellow "dunst   not running — skipped"
    fi
}

reload_picom() {
    if ! command -v picom >/dev/null 2>&1; then
        say yellow "picom   not installed — skipped"
        return 0
    fi
    if pkill -USR1 -x picom 2>/dev/null; then
        say green "picom   USR1 sent (config reload)"
    else
        say yellow "picom   not running — skipped"
    fi
}

reload_xsettingsd() {
    # SIGHUP makes xsettingsd re-read its config and push the new values to
    # every GTK client over the XSETTINGS property — no app restart needed.
    #
    # Unlike the other targets here, this one usually has nothing to do: its
    # config is rendered from themes/dark/theme.conf, which a wallpaper change
    # does not touch (see install-restore-theme-identity.sh). It matters after
    # an installer re-run or a theme.conf edit, and it is in the sweep so those
    # do not need a separate command or a logout.
    if ! command -v xsettingsd >/dev/null 2>&1; then
        say yellow "xsett   not installed — skipped"
        return 0
    fi
    if pkill -HUP -x xsettingsd 2>/dev/null; then
        say green "xsett   HUP sent (settings re-read)"
    else
        say yellow "xsett   not running — skipped"
    fi
}

reload_wallpaper() {
    # feh writes ~/.fehbg as an executable snippet that re-applies the
    # current wallpaper. Re-running it repaints the root window, which
    # matters after a compositor restart blanks it.
    local fehbg="$HOME/.fehbg"
    if [[ -x "$fehbg" ]]; then
        if run_bounded "$fehbg" >/dev/null 2>&1; then
            say green "wall    ~/.fehbg re-applied"
        else
            yellow "wall    ~/.fehbg failed"
        fi
    else
        say yellow "wall    no ~/.fehbg — skipped"
    fi
}

for step in reload_dwm reload_st reload_dwmblocks reload_dunst reload_picom \
    reload_xsettingsd reload_wallpaper; do
    "$step" &
done
wait

say green "✓ reload complete"
