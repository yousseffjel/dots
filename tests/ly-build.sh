#!/usr/bin/env bash
# Exercises ly_install (scripts/install-services-ly.sh) and its revert
# (uninstall_ly_build in scripts/uninstall-runit.sh) with fake xbps-fetch,
# git, xbps-query and xbps-uhelper on PATH, and a fake zig inside a real
# .tar.xz. sha256sum, tar, zstd and cp are real: the checksums, the unpacking
# and the placing into DOTS_LY_ROOT (a sandbox standing in for /) all run for
# real. The pins are pointed at the fixtures' own checksums after sourcing.
#
# The fake zig writes the file list the real `zig build installexe
# -Dinit_system=runit` staged for ly v1.4.1 (built 2026-10-15), trimmed to
# one file per directory plus the supervise link.
#
# What is asserted:
#   * a fresh build places every staged path, symlink included, one LYBUILD
#     row each, with /usr/bin/ly last; the build ran with both zig caches
#     inside its workdir and -Dinit_system=runit;
#   * a re-run is a no-op, and a /usr/bin/ly with no row is left alone;
#   * the build is recorded; a build that predates the record is taken for
#     the first pin and recorded without a rebuild;
#   * raised pins rebuild: files renamed into place (a new inode, so a running
#     ly cannot make it fail), config.ini kept, a path the new version lacks
#     removed with its row, a new one added; a failed rebuild or --dry-run
#     changes nothing;
#   * a zig or vendor checksum mismatch, a moved tag (wrong commit), the
#     wrong zig version, pins out of order, a missing build dep, a non-x86_64
#     arch and --dry-run all install nothing;
#   * uninstall removes exactly the rows' paths and the directories that end
#     up empty, keeping one the user put a file in.

# The predicates are only called through check's "$@". See tests/pkg-repos.sh.
# SC2016: the eval'd checks are single-quoted on purpose, so they expand when
# check runs them, not when the line is read.
# shellcheck disable=SC2317,SC2329,SC2016

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# All four XDG variables: HOME alone leaks into the real install manifest.
export HOME="$SB/home" XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/config" \
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache" TMPDIR="$SB/tmp" \
    DOTS_LY_ROOT="$SB/root" FIX="$SB/fix" LOG="$SB/calls.log"
mkdir -p "$TMPDIR" "$FIX"

# --- fixtures: a zig tarball holding a fake zig, and a vendor .tar.zst ------
mkdir -p "$FIX/zig-x86_64-linux-0.16.0"
cat >"$FIX/zig-x86_64-linux-0.16.0/zig" <<'ZIG'
#!/usr/bin/env bash
[[ "$1" == version ]] && { echo "${FAKE_ZIG_VERSION:-0.16.0}"; exit 0; }
echo "zig $*" >>"$LOG"
[[ -d zig-pkg ]] || { echo "no zig-pkg: offline build impossible" >&2; exit 1; }
for a in "$@"; do case "$a" in -Ddest_directory=*) d="${a#*=}" ;; esac; done
mkdir -p "$d/etc/ly/lang" "$d/etc/pam.d" "$d/etc/sv/ly" "$d/usr/bin"
# FAKE_LY_NEW: a later version, which ships de.ini instead of en.ini.
lang=en; [[ -n "${FAKE_LY_NEW:-}" ]] && lang=de
for f in etc/ly/config.ini etc/ly/lang/$lang.ini etc/pam.d/ly etc/sv/ly/run usr/bin/ly; do echo "$f${FAKE_LY_NEW:+ new}" >"$d/$f"; done
chmod 755 "$d/usr/bin/ly" "$d/etc/sv/ly/run"
ln -s /run/runit/supervise.ly "$d/etc/sv/ly/supervise"
ZIG
chmod 755 "$FIX/zig-x86_64-linux-0.16.0/zig"
tar -cJf "$FIX/zig.tar.xz" -C "$FIX" zig-x86_64-linux-0.16.0
mkdir -p "$FIX/v/zig-pkg/clap" && echo x >"$FIX/v/zig-pkg/clap/build.zig"
tar -cf - -C "$FIX/v" zig-pkg | zstd -q >"$FIX/vendor.tar.zst"

seal_path "$SB/bin" bash grep sed tr mkdir touch cut sort cat mv rm tail wc awk tee mktemp \
    readlink dirname basename find cp chmod ln tar xz zstd sha256sum head rmdir stat
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    fake "$SB/bin" xbps-fetch 'echo "xbps-fetch $*" >>"$LOG"
case "$3" in *ziglang*) src="$FIX/zig.tar.xz" ;; *vendor*) src="$FIX/vendor.tar.zst" ;; *) exit 1 ;; esac
cp "$src" "$2"'
    fake "$SB/bin" git 'echo "git $*" >>"$LOG"
case "$1" in
clone) mkdir -p "${!#}" ;;
-C) echo "${FAKE_HEAD:-afb1dc62a0568743c9a7952623ec179128c73340}" ;;
esac'
    fake "$SB/bin" xbps-query '[[ " ${FAKE_NODEP:-} " == *" $1 "* ]] && exit 2; exit 0'
    fake "$SB/bin" xbps-uhelper 'echo "${FAKE_ARCH:-x86_64}"'
}
PATH="$SB/bin"

# No red/green/blue of its own (CLAUDE.md rule 2): it sources global_fn.sh,
# then replaces them with plain ones so output is greppable.
# shellcheck source=../scripts/global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"
red() { printf 'RED %s\n' "$*"; }
green() { printf '%s\n' "$*"; }
yellow() { green "$@"; }
blue() { green "$@"; }
# shellcheck source=../scripts/install-services-ly.sh
source "$DOTS_DIR/scripts/install-services-ly.sh"
# shellcheck source=../scripts/uninstall-runit.sh
source "$DOTS_DIR/scripts/uninstall-runit.sh"
SUDO=() DRY_RUN=0 ASSUME_YES=1
ZIG_SHA256="$(sha256sum "$FIX/zig.tar.xz" | cut -d' ' -f1)"
LY_VENDOR_SHA256="$(sha256sum "$FIX/vendor.tar.zst" | cut -d' ' -f1)"

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then printf '\033[32m  ok    %s\033[0m\n' "$what"; else
        printf '\033[31m  FAIL  %s\033[0m\n' "$what"
        FAILS=$((FAILS + 1))
    fi
}
said() { grep -qF -- "$1" "$SB/out"; }
nothing_placed() { [[ ! -e "$SB/root" ]] && [[ -z "$(manifest_rows LYBUILD)" ]]; }
fresh() {
    rm -rf "$SB/root" "$SB/state"
    : >"$LOG"
}
run() { ly_install >"$SB/out" 2>&1; }

printf '\033[34m%s\033[0m\n' "==> a fresh build"
fresh
run
check "every staged path placed" test "$(cd "$SB/root" && find . \( -type f -o -type l \) | wc -l)" -eq 6
check "...the supervise link kept a link" test "$(readlink "$SB/root/etc/sv/ly/supervise")" = /run/runit/supervise.ly
check "...the binary executable" test -x "$SB/root/usr/bin/ly"
check "one LYBUILD row per path, /usr/bin/ly last" \
    test "$(manifest_rows LYBUILD | cut -f3 | tail -n1):$(manifest_rows LYBUILD | wc -l)" = "/usr/bin/ly:6"
check "built offline for runit, caches inside the workdir" \
    grep -qE "^zig build installexe -Dinit_system=runit .*--cache-dir $SB/tmp/.* --global-cache-dir $SB/tmp/" "$LOG"
check "the workdir is cleaned up" test -z "$(find "$SB/tmp" -mindepth 1)"

printf '\033[34m%s\033[0m\n' "==> a re-run"
: >"$LOG"
run
check "nothing fetched or built" test ! -s "$LOG"
check "says it is ours already" said "already built and installed by dots"

printf '\033[34m%s\033[0m\n' "==> someone else's ly"
fresh
mkdir -p "$SB/root/usr/bin" && echo theirs >"$SB/root/usr/bin/ly"
run
check "left alone, no build, no rows" test "$(cat "$SB/root/usr/bin/ly"):$(wc -l <"$LOG"):$(manifest_rows LYBUILD | wc -l)" = "theirs:0:0"

printf '\033[34m%s\033[0m\n' "==> every refusal installs nothing"
fresh
ZIG_SHA256=0000 run || true
check "zig checksum mismatch" eval 'nothing_placed && said "checksum mismatch on zig.tar.xz"'
fresh
LY_VENDOR_SHA256=0000 run || true
check "vendor checksum mismatch" eval 'nothing_placed && said "checksum mismatch on vendor.tar.zst"'
fresh
FAKE_HEAD=deadbeef run || true
check "the tag moved (wrong commit)" eval 'nothing_placed && said "the tag moved; refusing to build"'
fresh
FAKE_ZIG_VERSION=0.15.2 run || true
check "the unpacked zig is the wrong version" eval 'nothing_placed && said "the unpacked zig is not 0.16.0"'
fresh
ZIG_VERSION=0.15.0 run || true
check "pins out of order (zig older than ly needs)" eval 'nothing_placed && said "older than ly v1.4.1 needs"'
fresh
FAKE_NODEP=pam-devel run || true
check "a build dep missing: skipped, nothing fetched" eval 'nothing_placed && [[ ! -s $LOG ]] && said "pam-devel is not installed"'
fresh
FAKE_ARCH=x86_64-musl run || true
check "not x86_64 glibc: skipped" eval 'nothing_placed && [[ ! -s $LOG ]]'
fresh
DRY_RUN=1 run
check "--dry-run: nothing fetched, nothing placed" eval 'nothing_placed && [[ ! -s $LOG ]]'

printf '\033[34m%s\033[0m\n' "==> the record"
fresh
run
check "a fresh build is recorded" test "$(manifest_get_meta ly_build)" = "v1.4.1 afb1dc62a0568743c9a7952623ec179128c73340"
awk -F'\t' '!($1 == "META" && $2 == "ly_build")' "$MANIFEST_FILE" >"$SB/m" && mv "$SB/m" "$MANIFEST_FILE"
: >"$LOG"
run
check "a build that predates the record: the first pin, recorded, not rebuilt" \
    eval '[[ ! -s $LOG && $(manifest_get_meta ly_build) == "v1.4.1 "* ]]'

printf '\033[34m%s\033[0m\n' "==> raised pins"
bump() { LY_VERSION=9.9.9 LY_COMMIT=c0ffee FAKE_HEAD="${FAKE_HEAD:-c0ffee}" FAKE_LY_NEW=1 run; }
fresh
run
echo themed >"$SB/root/etc/ly/config.ini"
inode="$(stat -c %i "$SB/root/usr/bin/ly")"
bump
check "rebuilt: the new binary" grep -qx 'usr/bin/ly new' "$SB/root/usr/bin/ly"
check "...renamed into place, not written over" test "$(stat -c %i "$SB/root/usr/bin/ly")" != "$inode"
check "...config.ini kept, and said so" eval '[[ $(cat "$SB/root/etc/ly/config.ini") == themed ]] && said "kept    /etc/ly/config.ini"'
check "...a path it no longer ships removed with its row" \
    eval '[[ ! -e $SB/root/etc/ly/lang/en.ini ]] && ! manifest_has_path LYBUILD /etc/ly/lang/en.ini'
check "...a new path placed with a row" eval '[[ -f $SB/root/etc/ly/lang/de.ini ]] && manifest_has_path LYBUILD /etc/ly/lang/de.ini'
check "...no temporary file left" test -z "$(find "$SB/root" -name '*.dots-new')"
check "...recorded, and the running ly left to the next boot" \
    eval '[[ $(manifest_get_meta ly_build) == "v9.9.9 c0ffee" ]] && said "starts at the next boot"'
: >"$LOG"
bump
check "...a re-run at those pins is a no-op" test ! -s "$LOG"
fresh
run
FAKE_HEAD=deadbeef bump || true
check "a failed rebuild changes nothing" eval '[[ $(cat "$SB/root/usr/bin/ly") == usr/bin/ly && -f $SB/root/etc/ly/lang/en.ini \
    && $(manifest_get_meta ly_build) == "v1.4.1 "* ]] && said "ly not rebuilt — v1.4.1 stays"'
: >"$LOG"
DRY_RUN=1 bump
check "--dry-run: nothing fetched, the record unchanged" eval '[[ ! -s $LOG && $(manifest_get_meta ly_build) == "v1.4.1 "* ]]'

printf '\033[34m%s\033[0m\n' "==> uninstall"
fresh
run
mkdir -p "$SB/root/etc/ly/custom-sessions" && echo mine >"$SB/root/etc/ly/custom-sessions/mine.desktop"
uninstall_ly_build >"$SB/out" 2>&1
check "every recorded path removed" test "$(find "$SB/root" \( -type f -o -type l \) | wc -l)" -eq 1
check "empty directories removed" eval '[[ ! -d $SB/root/etc/sv/ly && ! -d $SB/root/etc/ly/lang ]]'
check "a directory holding a user file is kept" test -f "$SB/root/etc/ly/custom-sessions/mine.desktop"

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ ly build: pinned, verified, placed and removed exactly"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
