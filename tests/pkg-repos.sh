#!/usr/bin/env bash
# Exercises scripts/install-pkg-repos.sh and scripts/uninstall-repos.sh — the
# Sublime HQ repo, RPM Fusion and the ffmpeg swap — against fake rpm, dnf and
# uname on a sealed PATH. The fakes keep a package database in a file, so the
# install and the uninstall act on the same simulated system.
#
# What is asserted:
#   * a fresh install adds the Sublime repo file, both RPM Fusion release
#     packages, swaps ffmpeg-free for ffmpeg, installs sublime-text, runs
#     the drivers step (intel-media-driver for the fixture's Intel GPU — the
#     per-device logic is tests/drivers.sh's job), and writes one REPO row
#     per change it made;
#   * a re-run changes nothing: no second swap, no new rows;
#   * a repo that already existed gets no REPO row, so uninstall leaves it;
#   * an arch Sublime HQ does not publish for skips Sublime and nothing else;
#   * a failed repo add is reported in FAILED_EXTRA, with no REPO row;
#   * install-pkg-tiers.sh counts ffmpeg-free as satisfied by ffmpeg, so a
#     re-run never tries to install it over RPM Fusion's build;
#   * uninstall swaps ffmpeg back BEFORE packages go, then removes the repo
#     file and the release packages once nothing installed comes from them;
#   * a package of yours from rpmfusion-nonfree-updates keeps BOTH releases
#     (nonfree's release requires free's), and a sublime-text that is still
#     installed keeps the repo file;
#   * when dnf repoquery itself fails, RPM Fusion is kept (fails closed).

# The predicates below are called only through check's "$@", which shellcheck
# cannot follow. Both codes, as in tests/autostart-daemons.sh: the finding was
# SC2317 before shellcheck 0.10.0 and SC2329 after.
# shellcheck disable=SC2317,SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# No red/green/blue of its own (CLAUDE.md rule 2): it sources global_fn.sh,
# and then replaces those with plain ones below, so the scripts' output can
# be matched without colour codes. Same exemption as tests/manifest-has-path.sh.

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
export DB="$SB/rpmdb" LOG="$SB/calls.log" SUBLIME_REPO_FILE="$SB/yum.repos.d/sublime-text.repo"
mkdir -p "$SB/yum.repos.d"

seal_path "$SB/bin" bash grep awk sed mkdir touch mktemp mv rm tail cut sort cat wc basename tr \
    dirname readlink head od
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    fake "$SB/bin" uname 'echo "${FAKE_ARCH:-x86_64}"'
    fake "$SB/bin" rpm 'echo "rpm $*" >>"$LOG"
case "$1" in
-q) grep -q "^$2 " "$DB" ;;
-E) echo 43 ;;
--import) exit 0 ;;
esac'
    fake "$SB/bin" dnf 'echo "dnf $*" >>"$LOG"
add() { echo "$1 ${2:-fedora}" >>"$DB"; }
del() { grep -v "^$1 " "$DB" >"$DB.new" || true; mv "$DB.new" "$DB"; }
case "$1" in
install)
    p="${3##*/}"; p="${p%-43.noarch.rpm}"
    [[ " ${FAKE_FAIL:-} " == *" $p "* ]] && exit 1
    grep -q "^$p " "$DB" || add "$p" "${p%-release}" ;;
config-manager)
    [[ " ${FAKE_FAIL:-} " == *" addrepo "* ]] && exit 1
    touch "$SUBLIME_REPO_FILE" ;;
swap) del "$3"; if [[ "$4" == ffmpeg ]]; then add "$4" rpmfusion-free; else add "$4"; fi ;;
remove) shift 2; for p in "$@"; do del "$p"; done ;;
repoquery)
    [[ " ${FAKE_FAIL:-} " == *" repoquery "* ]] && exit 1
    cat "$DB" ;;
esac'
}
PATH="$SB/bin"
# The drivers step reads this machine instead of the real one: one Intel GPU,
# in a VM (so no microcode or fwupd), with a clean kernel log.
mkdir -p "$SB/sys/bus/pci/devices/0000:00:02.0"
printf '%s\n' 0x030000 >"$SB/sys/bus/pci/devices/0000:00:02.0/class"
printf '%s\n' 0x8086 >"$SB/sys/bus/pci/devices/0000:00:02.0/vendor"
printf '%s\n' 0x9a49 >"$SB/sys/bus/pci/devices/0000:00:02.0/device"
: >"$SB/kmsg"
export DOTS_SYSFS="$SB/sys" DOTS_VIRT=kvm DOTS_KERNEL_LOG="$SB/kmsg"
export HOME="$SB/home" XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/config" \
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache"

# shellcheck source=../scripts/global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"
red() { printf '%s\n' "$*"; }
green() { red "$@"; }
yellow() { red "$@"; }
blue() { red "$@"; }
# shellcheck source=../scripts/install-pkg-repos.sh
source "$DOTS_DIR/scripts/install-pkg-repos.sh"
# shellcheck source=../scripts/uninstall-repos.sh
source "$DOTS_DIR/scripts/uninstall-repos.sh"
DRY_RUN=0 SUDO=() ASSUME_YES=1

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then printf '\033[32m  ok    %s\033[0m\n' "$what"; else
        printf '\033[31m  FAIL  %s\033[0m\n' "$what"
        FAILS=$((FAILS + 1))
    fi
}
has() { grep -q "^$1 " "$DB"; }
lacks() { ! has "$1"; }
rows() { manifest_rows REPO | wc -l; }
# Captured first: `manifest_rows | grep -q` under pipefail can report a match
# as a failure (SIGPIPE, 141), which `!` would turn into a false pass.
no_row_kind() {
    local kinds
    kinds="$(manifest_rows REPO | cut -f2)"
    ! grep -qx "$1" <<<"$kinds"
}
logged() { grep -q -- "$1" "$LOG"; }
not_logged() { ! logged "$1"; }
# in_list <word> <list...> — FAILED_EXTRA membership.
in_list() {
    local want="$1"
    shift
    [[ " $* " == *" $want "* ]]
}
# reset <package>... — a system with only these installed and no manifest.
reset() {
    rm -rf "$SB/state" "$SUBLIME_REPO_FILE" "$LOG"
    : >"$DB"
    for p in "$@"; do echo "$p fedora" >>"$DB"; done
    touch "$LOG"
    FAILED_EXTRA=()
}
# What uninstall_packages would do: dnf remove every PACKAGE row.
remove_our_packages() {
    local p
    while read -r p; do
        grep -v "^$p " "$DB" >"$DB.new" || true
        mv "$DB.new" "$DB"
    done \
        < <(manifest_rows PACKAGE | cut -f2)
}

blue "==> fresh install"
reset ffmpeg-free
repos_install >/dev/null
check "Sublime repo file added" test -e "$SUBLIME_REPO_FILE"
check "sublime-text installed" has sublime-text
check "rpmfusion-free-release installed" has rpmfusion-free-release
check "rpmfusion-nonfree-release installed" has rpmfusion-nonfree-release
check "ffmpeg-free swapped out" lacks ffmpeg-free
check "ffmpeg swapped in" has ffmpeg
check "intel-media-driver installed" has intel-media-driver
check "four REPO rows (file, two releases, swap)" test "$(rows)" -eq 4
check "PACKAGE rows for sublime-text and intel-media-driver" \
    test "$(manifest_rows PACKAGE | cut -f2 | sort | tr '\n' ' ')" = "intel-media-driver sublime-text "
check "nothing reported failed" test "${#FAILED_EXTRA[@]}" -eq 0

blue "==> re-run is a no-op"
: >"$LOG"
repos_install >/dev/null
check "no second swap" not_logged "dnf swap"
check "no new REPO rows" test "$(rows)" -eq 4

blue "==> ffmpeg-free is satisfied by ffmpeg in the tier loop"
PACKAGES_DIR="$SB"
# shellcheck source=../scripts/install-pkg-tiers.sh
source "$DOTS_DIR/scripts/install-pkg-tiers.sh"
echo "ffmpeg-free  # recorder" >"$SB/tier.lst"
: >"$LOG"
out="$(install_tier t "$SB/tier.lst" desktop)"
check "the tier loop ran to the end (no crash passing for success)" grep -q "ffmpeg-free" <<<"$out"
check "no dnf install of ffmpeg-free" not_logged "dnf install -y ffmpeg-free"
check "said why" grep -q "ffmpeg installed in its place" <<<"$out"
FAILED_EXTRA=()

blue "==> uninstall reverts in order"
remove_our_packages
uninstall_repo_swaps >/dev/null
check "ffmpeg-free back" has ffmpeg-free
check "RPM Fusion ffmpeg gone" lacks ffmpeg
uninstall_repos >/dev/null
check "repo file removed" test ! -e "$SUBLIME_REPO_FILE"
check "rpmfusion-free-release removed" lacks rpmfusion-free-release
check "rpmfusion-nonfree-release removed" lacks rpmfusion-nonfree-release

blue "==> uninstall keeps what is still in use"
reset ffmpeg-free
repos_install >/dev/null
uninstall_repo_swaps >/dev/null
remove_our_packages
# Swapped back first, as uninstall.sh does: otherwise RPM Fusion's ffmpeg
# alone keeps rpmfusion-free, and the family rule below is never exercised.
check "only a nonfree package is left from RPM Fusion" lacks ffmpeg
echo "steam rpmfusion-nonfree-updates" >>"$DB"
echo "sublime-text sublime-text" >>"$DB"
uninstall_repos >/dev/null
check "a nonfree package keeps rpmfusion-free-release too" has rpmfusion-free-release
check "and rpmfusion-nonfree-release" has rpmfusion-nonfree-release
check "an installed sublime-text keeps the repo file" test -e "$SUBLIME_REPO_FILE"

blue "==> uninstall fails closed"
reset ffmpeg-free
repos_install >/dev/null
uninstall_repo_swaps >/dev/null
remove_our_packages
FAKE_FAIL=repoquery uninstall_repos >/dev/null
check "dnf cannot answer: RPM Fusion kept" has rpmfusion-free-release

blue "==> pre-existing repos are not ours"
reset ffmpeg rpmfusion-free-release rpmfusion-nonfree-release
touch "$SUBLIME_REPO_FILE"
repos_install >/dev/null
check "no REPO rows" test "$(rows)" -eq 0
check "no rpm --import for an existing repo" not_logged "rpm --import"

blue "==> arch and failure paths"
reset ffmpeg-free
FAKE_ARCH=armv7l repos_install >/dev/null
check "unsupported arch: no Sublime repo" test ! -e "$SUBLIME_REPO_FILE"
check "unsupported arch: codecs still set up" has ffmpeg
reset ffmpeg-free
FAKE_FAIL=addrepo repos_install >/dev/null
check "failed repo add is reported" in_list sublime-text "${FAILED_EXTRA[@]}"
check "failed repo add writes no file row" no_row_kind file
reset ffmpeg-free
FAKE_FAIL=rpmfusion-nonfree-release repos_install >/dev/null
check "failed RPM Fusion: no swap attempted" not_logged "dnf swap"
check "failed RPM Fusion is reported" in_list rpmfusion-nonfree-release "${FAILED_EXTRA[@]}"

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ third-party repos: added once, reverted only when unused"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
