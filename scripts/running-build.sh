#!/usr/bin/env bash
# running_build_stale / running_build_report — is a running dwm or dwmblocks
# still the build from before the last install?
#
# Sourced by install-suckless.sh, install-void.sh and doctor-session.sh, never
# run alone. `make install` replaces /usr/local/bin/dwm under a running
# session, and the running process keeps executing the old file
# (/proc/<pid>/exe reads "... (deleted)") until something restarts it: a
# theme change does, nothing else in a `dots update` did, and nobody was told
# (Void VM, 2026-10-20). Replaced AND different content counts as stale, so
# a rebuild of unchanged sources stays quiet.
#
# Only this user's processes are looked at. DOTS_PROC replaces /proc (tests);
# it is read at call time, never captured when this file is sourced.
#
# usage: source "$SCRIPT_DIR/running-build.sh"

# The long-running suckless programs and how to restart each in place.
# st, dmenu and slock are short-lived: their next start is the new build.
declare -gA RUNNING_BUILD_RESTART=(
    [dwm]="pkill -HUP -x dwm   (restarts in place; windows and tags are kept)"
    [dwmblocks]="pkill -x dwmblocks; setsid -f dwmblocks"
)

# running_build_stale <name> — 0 when a process of ours named <name> runs a
# binary that was replaced since it started and differs from the file now there.
running_build_stale() {
    local name="$1" proc="${DOTS_PROC:-/proc}" dir comm link
    for dir in "$proc"/[0-9]*; do
        # read, not $(cat): no fork per process. A process gone mid-scan
        # just fails the read.
        [[ -O $dir ]] || continue
        { read -r comm <"$dir/comm"; } 2>/dev/null || continue
        [[ $comm == "$name" ]] || continue
        # A binary never replaced compares equal to itself. One removed
        # outright (dots uninstall) is not stale: a restart would exec a
        # program that is gone, and a dwm that cannot re-exec ends the session.
        link="$(readlink "$dir/exe" 2>/dev/null)" || continue
        [[ -f ${link% (deleted)} ]] || continue
        cmp -s "$dir/exe" "${link% (deleted)}" || return 0
    done
    return 1
}

# running_build_report — one yellow block per stale program, nothing when
# none is. Uses the caller's yellow().
running_build_report() {
    local name
    for name in dwm dwmblocks; do
        running_build_stale "$name" || continue
        yellow "  - $name is still running the build from before this install; restart it:"
        yellow "      ${RUNNING_BUILD_RESTART[$name]}"
    done
}
