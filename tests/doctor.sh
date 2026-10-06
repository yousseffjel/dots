#!/usr/bin/env bash
# `dots doctor` (scripts/doctor.sh) against a sandbox that looks like a
# healthy install, then with one thing broken at a time. Checked:
#   * healthy: exit 0, no warn or fail, in both formats;
#   * the two formats come from one code path: same statuses, same order;
#   * a missing desktop.lst package FAILS with that line's consequence text;
#     a missing extra.lst package only warns;
#   * a disabled manifest SERVICE fails; no manifest fails;
#   * daemons: the list is the installer's report, every DAEMON_PROCESS key
#     is in it, a daemon absent from autostart.sh and one that died get
#     different advice, a VM-only daemon off a VM is skipped, dwm-lock is
#     found as xss-lock;
#   * no X session, not Fedora: whole sections skip instead of failing;
#   * it is read-only: the sandbox HOME is byte-identical afterwards.
# SEALED PATH: the fakes in tests/lib/doctor-sandbox.sh are all it can reach.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

PASS=0
FAIL=0
ok() {
    green "  ok: $*"
    PASS=$((PASS + 1))
}
bad() {
    red "  FAIL: $*"
    FAIL=$((FAIL + 1))
}
# check <description> <command...> — ok when the command succeeds.
check() {
    local what="$1"
    shift
    if "$@"; then ok "$what"; else bad "$what"; fi
}

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# shellcheck source=lib/doctor-sandbox.sh
source "$SCRIPT_DIR/lib/doctor-sandbox.sh"

mapfile -t DAEMONS < <(daemon_names)
make_fakes
make_home

tsv() { run_doctor --tsv >"$SB/out.tsv" 2>&1 && echo 0 >"$SB/rc" || echo $? >"$SB/rc"; }
rc_is() { [[ "$(cat "$SB/rc")" == "$1" ]]; }
row() { grep -qE "^$1	$2	$3	" "$SB/out.tsv"; }
none_of() { ! grep -qE "^($1)	" "$SB/out.tsv"; }
detail() { grep -E "^[a-z]+	[a-z]+	$1	" "$SB/out.tsv" | cut -f4; }

blue "==> healthy install"
check "the installer's report names daemons (${#DAEMONS[@]})" test "${#DAEMONS[@]}" -gt 5
tsv
check "exit 0" rc_is 0
check "no warn or fail" none_of 'warn|fail'
check "packages checked per tier" row ok packages tier-desktop
check "the manifest's service is checked" row ok install service-ly@tty2.service
check "every linked config is checked" \
    test "$(grep -cE $'^ok\tinstall\tlink-' "$SB/out.tsv")" -eq "$(HOME="$H" bash "$DOTS_DIR/scripts/symlinks.sh" --list-links | grep -c .)"
check "every reported daemon is checked" \
    test "$(grep -cE $'^[a-z]+\tsession\tdaemon-' "$SB/out.tsv")" -eq "${#DAEMONS[@]}"
check "dwm-lock is found as xss-lock" row ok session daemon-dwm-lock
check "autorandr is one-shot, not a daemon" row skip session daemon-autorandr
find "$H" -printf '%p %s %l\n' | sort >"$SB/before"

blue "==> one code path, two formats"
run_doctor >"$SB/out.human" 2>&1 || true
sed -n 's/^[^ ]* *\(ok\|warn\|FAIL\|skip\) .*/\1/p' "$SB/out.human" | tr '[:upper:]' '[:lower:]' >"$SB/h"
cut -f1 "$SB/out.tsv" >"$SB/t"
check "human and tsv list the same statuses in the same order" cmp -s "$SB/h" "$SB/t"
cmp -s "$SB/h" "$SB/t" || diff "$SB/h" "$SB/t" | head -5
check "human output ends with the verdict" grep -q 'all checks passed' "$SB/out.human"

blue "==> each DAEMON_PROCESS key is a daemon the installer reports"
keys="$(sed -n 's/^declare -A DAEMON_PROCESS=(\(.*\))$/\1/p' "$DOTS_DIR/scripts/doctor-session.sh" \
    | grep -o '\["[^"]*"\]' | tr -d '[]"')"
check "found the DAEMON_PROCESS table" test -n "$keys"
for k in $keys; do
    check "DAEMON_PROCESS[$k] is reported" grep -qx "$k" <(printf '%s\n' "${DAEMONS[@]}")
done
for k in spice-vdagent blueman-applet; do
    check "daemon_applies' $k is reported" grep -qx "$k" <(printf '%s\n' "${DAEMONS[@]}")
done

blue "==> packages"
FAKE_MISSING="sxhkd pavucontrol" tsv
check "a missing desktop package fails, exit 1" row fail packages pkg-sxhkd
check "...with desktop.lst's consequence text" grep -q 'EVERY non-dwm keybind' <(detail pkg-sxhkd)
check "a missing extra package only warns" row warn packages tier-extra
check "exit 1" rc_is 1
FAKE_MISSING=pavucontrol tsv
check "extra only: exit 0" rc_is 0
RELEASE="" tsv
check "not Fedora: the package section skips" row skip packages rpm

blue "==> install"
FAKE_SERVICE=disabled tsv
check "a disabled service fails" row fail install service-ly@tty2.service
mv "$H/.local/state/dots/manifest" "$SB/manifest.bak"
tsv
check "no manifest fails" row fail install manifest
mv "$SB/manifest.bak" "$H/.local/state/dots/manifest"

blue "==> session"
FAKE_DOWN=sxhkd tsv
check "a daemon in autostart.sh that is not running warns" row warn session daemon-sxhkd
check "...and says it exited" grep -q 'not running' <(detail daemon-sxhkd)
cp "$H/.local/share/dwm/autostart.sh" "$SB/autostart.bak"
grep -v '^sxhkd ' "$SB/autostart.bak" >"$H/.local/share/dwm/autostart.sh"
FAKE_DOWN=sxhkd tsv
check "a daemon autostart.sh never starts says so" grep -q 'does not mention' <(detail daemon-sxhkd)
cp "$SB/autostart.bak" "$H/.local/share/dwm/autostart.sh"
FAKE_DOWN=xss-lock tsv
check "dwm-lock without xss-lock warns" row warn session daemon-dwm-lock
FAKE_DOWN=spice-vdagent FAKE_NOT_VM=1 tsv
check "spice-vdagent off a VM is skipped" row skip session daemon-spice-vdagent
DISPLAY_SET="" tsv
check "no X: one skip for the whole session section" \
    test "$(grep -c $'\tsession\t' "$SB/out.tsv")" -eq 1
check "no X: still exit 0" rc_is 0

blue "==> read-only"
find "$H" -printf '%p %s %l\n' | sort >"$SB/after"
check "the sandbox HOME is unchanged" cmp -s "$SB/before" "$SB/after"

blue "==> arguments"
check "--help exits 0" run_doctor --help
if run_doctor --bogus >/dev/null 2>&1; then bad "an unknown argument exits 1"; else ok "an unknown argument exits 1"; fi

echo
if [[ $FAIL -eq 0 ]]; then
    green "doctor: $PASS passed"
else
    red "doctor: $FAIL failed, $PASS passed"
    exit 1
fi
