#!/usr/bin/env bash
# The live-ISO installer's answers file (scope J, J-1): a valid file fills
# every LIVE_* variable, and each kind of bad file is refused, naming the
# line but never printing a value (a value can be a password hash). The
# validators run against fixture zoneinfo/keymap/locale trees, so the result
# does not depend on the host's tzdata or kbd. The real paths are only
# defaults, read at call time.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=../scripts/install-live-answers.sh
source "$DOTS_DIR/scripts/install-live-answers.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/zoneinfo/Europe" "$SB/keymaps/i386/qwerty"
: >"$SB/zoneinfo/UTC"
: >"$SB/zoneinfo/Europe/Berlin"
: >"$SB/keymaps/i386/qwerty/us.map.gz"
printf '%s\n' '#en_US.UTF-8 UTF-8' 'de_DE.UTF-8 UTF-8' >"$SB/libc-locales"
export LIVE_ZONEINFO_DIR="$SB/zoneinfo" LIVE_KEYMAP_DIR="$SB/keymaps" LIVE_LOCALES_FILE="$SB/libc-locales"

# Real hashes (openssl passwd -6 / -5, salt dotsTEST1, password "dots"),
# single-quoted so the $ fields stay literal.
# shellcheck disable=SC2016
H6='$6$dotsTEST1$hmwaRIQo9Gf15e0pP1zaFWg8J31000TkbvDkltXxWUhZJNkfvT6pbnQUxQsow95stlBOn44W9KusWc/vVmZW1/'
# shellcheck disable=SC2016
H5='$5$dotsTEST1$aLK2E1QYKqwwVkOtX2BRp/hVMi0umiwCTQRAyyOs2i5'

good() {
    printf '%s\n' '# a comment' '' 'HOSTNAME=voidbox' 'USERNAME=ysf' \
        "USER_PASSWORD_HASH='$H6'" 'TIMEZONE="Europe/Berlin"' 'KEYMAP=us' \
        'LOCALE=en_US.UTF-8'
}

rc=0
# load <name> — run live_answers_load on $SB/<name> in a subshell (it sets
# globals) and capture its exit code and output, so each case starts clean.
load() {
    chmod 600 "$SB/$1"
    set +e
    out="$( (live_answers_load "$SB/$1" && declare -p LIVE_HOSTNAME LIVE_USER_KIND LIVE_ROOT_KIND LIVE_REPO LIVE_TIMEZONE) 2>&1)"
    status=$?
    set -e
}
expect_ok() {
    if [[ $status -eq 0 ]] && grep -qF "$2" <<<"$out"; then
        green "  ok: $1"
    else
        red "  FAIL: $1"
        printf '%s\n' "$out" | sed 's/^/      /'
        rc=1
    fi
}
expect_refused() {
    if [[ $status -ne 0 ]] && grep -qF "$2" <<<"$out" && ! grep -qF -e "$H6" -e "$H5" <<<"$out"; then
        green "  ok: $1"
    else
        red "  FAIL: $1 (status $status)"
        printf '%s\n' "$out" | sed 's/^/      /'
        rc=1
    fi
}

blue "==> live installer answers file"
good >"$SB/good"
load good
expect_ok "a valid file loads, quotes stripped" 'LIVE_TIMEZONE="Europe/Berlin"'
expect_ok "root is locked when no root hash is given" 'LIVE_ROOT_KIND="none"'
expect_ok "the default repo is used" 'repo-default.voidlinux.org/current'

{
    good
    printf '%s\n' "ROOT_PASSWORD_HASH=$H5" 'REPO=http://10.0.0.2/void/current'
} >"$SB/root"
load root
expect_ok "a SHA-256 root hash and a local http repo are accepted" 'LIVE_ROOT_KIND="hash"'

good | sed 's/^KEYMAP=.*/KEYMAP=dvorak-nope/' >"$SB/badkeymap"
load badkeymap
expect_refused "an unknown keymap" 'line 7: invalid KEYMAP'

good | sed "s|^USER_PASSWORD_HASH=.*|USER_PASSWORD_HASH=hunter2|" >"$SB/plain"
load plain
expect_refused "a plain password instead of a hash" 'invalid USER_PASSWORD_HASH'

{
    good
    echo "USER_PASSWORD_HASH=$H5"
} >"$SB/twice"
load twice
expect_refused "a key given twice, without echoing either hash" 'given twice (first on line 5)'

{
    good | grep -v '^LOCALE='
    echo 'SHELL=/bin/zsh'
} >"$SB/unknown"
load unknown
expect_refused "an unknown key" 'unknown key SHELL'
expect_refused "a missing required key, in the same pass" 'missing LOCALE'

good | sed 's|^TIMEZONE=.*|TIMEZONE=../../etc/passwd|' >"$SB/traversal"
load traversal
expect_refused "a timezone that climbs out of zoneinfo" 'invalid TIMEZONE'

good | sed 's/^HOSTNAME=.*/HOSTNAME=Void_Box/' >"$SB/host"
load host
expect_refused "a hostname that is not an RFC 1123 label" 'invalid HOSTNAME'

good | sed 's/^USERNAME=.*/USERNAME=root/' >"$SB/rootuser"
load rootuser
expect_refused "root as the user name" 'invalid USERNAME'

printf 'HOSTNAME voidbox\n' >"$SB/syntax"
load syntax
expect_refused "a line that is not KEY=VALUE" 'line 1: not KEY=VALUE'

blue "==> the summary never prints a secret"
summary="$( (live_answers_load "$SB/root" >/dev/null && live_answers_summary) 2>&1)"
if grep -q 'password set' <<<"$summary" && ! grep -qF -e "$H5" -e "$H6" <<<"$summary"; then
    green "  ok: summary says 'password set', shows no hash"
else
    red "  FAIL: summary"
    rc=1
fi

exit "$rc"
