#!/usr/bin/env bash
# The live installer's dots stage (scope J, J-2), run for real against a
# sandbox target: the repo is cloned into the user's home with upstream's
# origin, install-void.sh runs as that user through `su -` while the
# temporary sudo rule exists, and the rule is gone afterwards on success,
# on failure (the EXIT trap) and is caught when its removal did not land.
# Interrupted (TERM, which install-live.sh treats as INT), everything still
# running in the target is stopped BEFORE the rule goes. Which processes
# live_dots_release stops is tests/live-release.sh.
#
# xchroot is a fake on PATH that records what would run inside the target
# and answers for visudo and su. git is the real one, cloning a throwaway
# fixture repo rather than this checkout. live_dots_release kills by /proc
# scan, so every call gets a fake /proc: never the real one. Last, the
# empty resolv.conf xchroot leaves in the target is removed, and nothing
# else is. The dry-run side (what the plan prints, --skip-dots, --reboot)
# is in tests/live-dry-run.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIVE_SCRIPTS="$DOTS_DIR/scripts"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
BIN="$SB/bin" REPO="$SB/repo"
RULE=etc/sudoers.d/99-dots-live-install
mkdir -p "$BIN" "$SB/noproc"
export SB RULE

# The fake runs inside "the target": it records the command and, for the
# install, whether the temporary rule existed at that moment. A successful
# install writes the marker as the real `sh -c` does. FAKE_XCHROOT_STATUS
# is xchroot's own cleanup failing afterwards (the VM run's gpg-agent).
# FAKE_XCHROOT_TERM is the J-4 interrupt: an orphaned stage keeps running in
# the target (registered in the fake /proc), and the installer is TERMed
# while it waits (FAKE_XCHROOT_KILL is its pid). The orphan records whether
# the rule was still there when it was stopped, which proves the order.
cat >"$BIN/xchroot" <<'EOF'
#!/usr/bin/env bash
t="$1"
shift
echo "$*" >>"$SB/called"
case "$1" in
    visudo) exit 0 ;;
    sh)
        [[ -e $t/$RULE ]] && echo granted >>"$SB/called"
        if [[ -n ${FAKE_XCHROOT_TERM:-} ]]; then
            bash -c 'trap "[[ -e $1/$2 ]] && echo rule-present >$3 || echo rule-gone >$3; exit 0" TERM
                while :; do sleep 0.1; done' _ "$t" "$RULE" "$SB/order" </dev/null >/dev/null 2>&1 &
            mkdir -p "$SB/noproc/$!"
            ln -s "$t" "$SB/noproc/$!/root"
            echo "$!" >"$SB/orphan"
            kill -TERM "$FAKE_XCHROOT_KILL"
            exit 143
        fi
        [[ ${FAKE_SU_STATUS:-0} -eq 0 ]] && : >"$t/var/tmp/dots-live-install.ok"
        exit "${FAKE_XCHROOT_STATUS:-${FAKE_SU_STATUS:-0}}"
        ;;
esac
EOF
chmod +x "$BIN/xchroot"

git init -q "$REPO"
git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m fixture
git -C "$REPO" remote add origin https://example.invalid/dots.git

# target — a fresh sandbox root with the user J-1 created.
target() {
    rm -rf "${SB:?}/mnt" "$SB/called"
    mkdir -p "$SB/mnt/etc/sudoers.d" "$SB/mnt/home/ysf" "$SB/mnt/var/tmp"
    echo "ysf:x:$(id -u):$(id -g)::/home/ysf:/bin/bash" >"$SB/mnt/etc/passwd"
}

# stage [prelude] — the dots stage in a subshell, armed the way
# install-live.sh arms it. The prelude runs after sourcing, to break things.
stage() {
    set +e
    out="$(
        # Bash clears -e inside $(...); install-live.sh runs the stage with it on.
        set -e
        # Local to this subshell on purpose: each stage sources afresh.
        # shellcheck disable=SC2030
        # LIVE_PROC: live_dots_release kills by /proc scan. No test call may
        # ever reach the real /proc (a loosened filter would kill the host).
        PATH="$BIN:$PATH" DRY_RUN=0 LIVE_TARGET="$SB/mnt" LIVE_USERNAME=ysf DOTS_DIR="$REPO" LIVE_PROC="$SB/noproc"
        # shellcheck source=../scripts/install-live-base.sh
        source "$LIVE_SCRIPTS/install-live-base.sh"
        # shellcheck source=../scripts/install-live-config.sh
        source "$LIVE_SCRIPTS/install-live-config.sh"
        # shellcheck source=../scripts/install-live-dots.sh
        source "$LIVE_SCRIPTS/install-live-dots.sh"
        eval "${1:-}"
        # As install-live.sh arms them.
        trap live_dots_cleanup EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        [[ -z ${FAKE_XCHROOT_TERM:-} ]] || export FAKE_XCHROOT_KILL=$BASHPID
        live_dots_install
    )"
    status=$?
    set -e
}

failed=0
result() {
    if [[ $2 -eq 0 ]]; then
        green "  ok: $1"
    else
        red "  FAIL: $1 (status $status)"
        printf '%s\n' "$out" "--- called:" "$(cat "$SB/called" 2>/dev/null)" | sed 's/^/      /'
        failed=1
    fi
}

blue "==> success"
target
stage
ok=0
[[ $status -eq 0 ]] || ok=1
[[ -d $SB/mnt/home/ysf/dots/.git ]] || ok=1
[[ "$(git -C "$SB/mnt/home/ysf/dots" remote get-url origin)" == https://example.invalid/dots.git ]] || ok=1
grep -qF "su - ysf -c 'cd ~/dots && ./scripts/install-void.sh'" "$SB/called" || ok=1
grep -qx granted "$SB/called" || ok=1
[[ ! -e $SB/mnt/$RULE && ! -e $SB/mnt/var/tmp/dots-live-install.ok ]] || ok=1
result "cloned with upstream origin, installed as ysf under the rule, rule and marker removed" "$ok"

blue "==> re-run"
rm -f "$SB/called"
stage
ok=0
[[ $status -eq 0 ]] && grep -qF 'already cloned' <<<"$out" || ok=1
[[ ! -e $SB/mnt/$RULE ]] || ok=1
result "an existing clone is left alone, the stage still converges" "$ok"

blue "==> install-void.sh fails"
target
export FAKE_SU_STATUS=1
stage
unset FAKE_SU_STATUS
ok=0
[[ $status -ne 0 ]] && grep -qx granted "$SB/called" || ok=1
[[ ! -e $SB/mnt/$RULE ]] || ok=1
result "the run fails and the EXIT trap still removes the rule" "$ok"

blue "==> xchroot's own cleanup fails after a good install"
# As on the VM: something install-void.sh started still runs in the target.
# A real process, rooted there only through the fake /proc.
target
sleep 300 >/dev/null 2>&1 &
lingering=$!
mkdir -p "$SB/noproc/$lingering"
ln -s "$SB/mnt" "$SB/noproc/$lingering/root"
export FAKE_XCHROOT_STATUS=32
stage
unset FAKE_XCHROOT_STATUS
ok=0
[[ $status -eq 0 ]] && grep -qF 'dots installed' <<<"$out" || ok=1
[[ ! -e $SB/mnt/$RULE ]] || ok=1
wait "$lingering" 2>/dev/null || true
! kill -0 "$lingering" 2>/dev/null || ok=1
rm -rf "${SB:?}/noproc/$lingering"
result "the marker, not xchroot's status, decides success; the leftover is stopped" "$ok"

blue "==> interrupted while install-void.sh runs (the J-4 bug)"
target
rm -f "$SB/order" "$SB/orphan"
export FAKE_XCHROOT_TERM=1
stage
unset FAKE_XCHROOT_TERM
orphan="$(cat "$SB/orphan" 2>/dev/null || echo 0)"
wait "$orphan" 2>/dev/null || true
ok=0
[[ $status -eq 143 ]] || ok=1
[[ "$(cat "$SB/order" 2>/dev/null)" == rule-present ]] || ok=1
if kill -0 "$orphan" 2>/dev/null; then
    ok=1
    kill -KILL "$orphan" 2>/dev/null || true
fi
[[ ! -e $SB/mnt/$RULE ]] || ok=1
rm -rf "${SB:?}/noproc/$orphan"
result "exit 143; the orphan is stopped while the rule still exists, then the rule goes" "$ok"

blue "==> the removal does not land"
target
stage 'rm() { :; }'
ok=0
[[ $status -ne 0 ]] && grep -qF 'still in' <<<"$out" || ok=1
result "a rule left behind is reported, not success" "$ok"

blue "==> the empty resolv.conf xchroot leaves"
# Found on the J-2 VM run: the first boot kept it empty and resolved nothing.
target
: >"$SB/mnt/etc/resolv.conf"
echo 'nameserver 192.0.2.1' >"$SB/kept.conf"
resolv() {
    (
        DRY_RUN=0 LIVE_TARGET="$SB/mnt"
        # shellcheck source=../scripts/install-live-config.sh
        source "$LIVE_SCRIPTS/install-live-config.sh"
        live_drop_empty_resolv
    ) >/dev/null
}
resolv
ok=0
[[ ! -e $SB/mnt/etc/resolv.conf ]] || ok=1
cp "$SB/kept.conf" "$SB/mnt/etc/resolv.conf"
resolv
cmp -s "$SB/kept.conf" "$SB/mnt/etc/resolv.conf" || ok=1
rm -f "$SB/mnt/etc/resolv.conf"
ln -s /run/empty "$SB/mnt/etc/resolv.conf"
resolv
[[ -L $SB/mnt/etc/resolv.conf ]] || ok=1
status=0 out=""
result "an empty file is removed; one with content and a symlink are kept" "$ok"

exit "$failed"
