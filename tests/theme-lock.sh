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
