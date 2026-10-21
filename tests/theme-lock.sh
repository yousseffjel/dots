#!/usr/bin/env bash
# Exercises scripts/theme/theme-lock.sh with a stand-in "change": a script
# that sources it the way wallpaper.sh and theme-apply.sh do, then logs its
# start and end around a short sleep.
#
# What is asserted:
#   * two changes started together never interleave (on the Void VM they
#     did, and the first one's palette ended up under the second wallpaper);
#   * the script's exit status comes through the lock;
#   * DOTS_THEME_LOCKED does not leak into what a change starts;
#   * a detached child the change leaves running does not hold the lock
#     (`flock -o`; reload.sh's header records that leak with dwmblocks);
#   * a change still waiting after DOTS_THEME_LOCK_WAIT exits 75 and says so;
#   * without flock on PATH the change runs anyway, unlocked;
#   * arguments that change nothing (--list, help, --login-random, --select)
#     never wait for the lock, and the real wallpaper.sh --select opens its
#     picker unlocked and applies the choice under the lock (2026-10-21);
#   * both real entry points source it with their own path and arguments.
# shellcheck disable=SC2016 # bash -c bodies and the grep pattern are literal
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

rc=0
check() {
    local name="$1"
    shift
    if "$@"; then
        green "  ok: $name"
    else
        red "  FAIL: $name"
        rc=1
    fi
}

LOG="$TMP/log"
CHANGE="$TMP/change.sh"
cat >"$CHANGE" <<EOF
#!/usr/bin/env bash
set -euo pipefail
red() { printf '%s\n' "\$*"; }
source "$DOTS_DIR/scripts/theme/theme-lock.sh" "\${BASH_SOURCE[0]}" "\$@"
echo "start \$1" >>"$LOG"
env | grep -c '^DOTS_THEME_LOCKED=' >>"$TMP/marker-\$1" || true
if [[ "\${2:-}" == detach ]]; then
    setsid sleep 30 </dev/null >/dev/null 2>&1 &
    echo "\$!" >"$TMP/child"
fi
sleep 0.4
echo "end \$1" >>"$LOG"
exit "\${EXIT:-0}"
EOF
chmod 755 "$CHANGE"
# change <tag> [detach] — one change in a sandbox cache, the caller's env kept.
change() { env -u DOTS_THEME_LOCKED XDG_CACHE_HOME="$TMP/cache" "$@"; }

blue "==> two changes at once"
change "$CHANGE" a &
sleep 0.1
change "$CHANGE" b &
wait
check "they ran one after the other, never interleaved" \
    test "$(tr '\n' ' ' <"$LOG")" == "start a end a start b end b "
check "the lock file is in the theme cache" test -f "$TMP/cache/dots/theme/.theme.lock"
check "DOTS_THEME_LOCKED does not reach what a change starts" test "$(cat "$TMP/marker-a")" == 0

blue "==> exit status"
st=0
EXIT=3 change "$CHANGE" c || st=$?
check "a change's exit status comes through the lock" test "$st" -eq 3

blue "==> a detached child does not hold the lock"
change "$CHANGE" d detach
start=$SECONDS
st=0
DOTS_THEME_LOCK_WAIT=5 change "$CHANGE" e || st=$?
check "the next change starts at once, not after the child's 30 s" \
    bash -c '[[ $1 == 0 && $2 -lt 4 ]]' _ "$st" "$((SECONDS - start))"
kill "$(cat "$TMP/child")" 2>/dev/null || true

blue "==> a change that waits too long"
flock "$TMP/cache/dots/theme/.theme.lock" sleep 3 &
holder=$!
sleep 0.2
st=0
out="$(DOTS_THEME_LOCK_WAIT=1 change "$CHANGE" f 2>&1)" || st=$?
wait "$holder"
check "exits 75" test "$st" -eq 75
check "...says another change is running" grep -q 'another wallpaper or theme change is still running' <<<"$out"
check "...and never started" bash -c '! grep -q "start f" "$1"' _ "$LOG"

blue "==> no flock"
mkdir -p "$TMP/bin"
seal_path "$TMP/bin" bash env grep sleep setsid mkdir cat
st=0
change PATH="$TMP/bin" "$CHANGE" g || st=$?
check "runs unlocked, exit 0" bash -c '[[ $1 == 0 ]] && grep -q "end g" "$2"' _ "$st" "$LOG"

blue "==> arguments that change nothing never wait"
# The Super+Shift+t menu builds its list from `theme-apply.sh --list`; with
# the lock taken first, it waited behind any change and then failed with 75.
# Held for longer than the whole loop: a short holder would expire while the
# first argument waited, and every later one would find the lock free.
flock "$TMP/cache/dots/theme/.theme.lock" sleep 30 &
holder=$!
sleep 0.2
for arg in --list --help -h --login-random --select; do
    start=$SECONDS
    st=0
    DOTS_THEME_LOCK_WAIT=2 change "$CHANGE" "$arg" >/dev/null 2>&1 || st=$?
    check "$arg runs at once while a change holds the lock" \
        bash -c '[[ $1 == 0 && $2 -lt 2 ]] && grep -qxF -- "start $3" "$4"' _ "$st" "$((SECONDS - start))" "$arg" "$LOG"
done
pkill -P "$holder" sleep 2>/dev/null || true
wait "$holder" || true

blue "==> wallpaper.sh --select: the picker unlocked, the change locked"
# The real wallpaper.sh in a copy of scripts/ whose engine steps are stubs
# (their post-commands act on the live desktop), with fakes for dmenu and
# feh first on PATH and no display or session bus. Each fake records
# whether the lock was free when it ran.
COPY="$TMP/repo"
LOCK="$TMP/sel/cache/dots/theme/.theme.lock"
mkdir -p "$COPY" "$TMP/sel/home" "$TMP/sel/walls" "$TMP/fake"
cp -r "$DOTS_DIR/scripts" "$COPY/"
: >"$TMP/sel/walls/pick.png"
# mkdir first: flock cannot open a lock file in a missing directory, and
# would report that failure as "held".
held() {
    printf '#!/usr/bin/env bash\nmkdir -p "%s"\nif flock -n "%s" true; then echo free; else echo held; fi >>"%s"\n%s\n' "${LOCK%/*}" "$LOCK" "$2" "$3" >"$1"
    chmod 755 "$1"
}
held "$COPY/scripts/theme/colorgen.sh" "$TMP/sel/colorgen" 'exit 0'
held "$TMP/fake/dmenu" "$TMP/sel/dmenu" 'read -r first; cat >/dev/null; echo "$first"'
printf '#!/bin/sh\nexit 0\n' >"$TMP/fake/feh"
chmod 755 "$TMP/fake/feh"
for stub in apply-templates.sh reload.sh; do printf '#!/bin/sh\nexit 0\n' >"$COPY/scripts/theme/$stub"; done
st=0
env -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS -u WAYLAND_DISPLAY -u DOTS_THEME_LOCKED \
    PATH="$TMP/fake:$PATH" HOME="$TMP/sel/home" XDG_CACHE_HOME="$TMP/sel/cache" \
    XDG_CONFIG_HOME="$TMP/sel/home/.config" XDG_STATE_HOME="$TMP/sel/home/.local/state" \
    XDG_DATA_HOME="$TMP/sel/home/.local/share" DOTS_WALLPAPER_DIR="$TMP/sel/walls" \
    bash "$COPY/scripts/theme/wallpaper.sh" --select >"$TMP/sel/out" 2>&1 || st=$?
check "exit 0" test "$st" -eq 0
check "dmenu ran with the lock free (a picker left open blocks no other change)" \
    test "$(cat "$TMP/sel/dmenu" 2>/dev/null)" == free
check "the chosen wallpaper was applied under the lock" \
    test "$(cat "$TMP/sel/colorgen" 2>/dev/null)" == held
check "...and recorded" test "$(cat "$TMP/sel/cache/dots/theme/wall.set" 2>/dev/null)" == "$TMP/sel/walls/pick.png"

blue "==> the entry points"
for f in wallpaper.sh theme-apply.sh; do
    check "$f sources it with its own path and arguments" \
        grep -qxF 'source "$SCRIPT_DIR/theme-lock.sh" "${BASH_SOURCE[0]}" "$@"' "$DOTS_DIR/scripts/theme/$f"
done

if ((rc != 0)); then
    red "✗ theme lock"
    exit 1
fi
green "✓ theme lock: one change at a time, nothing it starts holds the lock"
