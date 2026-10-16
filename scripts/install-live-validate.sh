#!/usr/bin/env bash
# Validators for the live-ISO installer's answers: one predicate per
# answer, silent, returning 0 when the value is usable. The dialog loop
# re-asks on a 1, and the answers-file parser stops on a 1. So both paths
# accept exactly the same values (scope J, J-1).
#
# Sourced by install-live-answers.sh, never standalone. It assumes the
# caller has already `set -euo pipefail`.
#
# usage: source "$SCRIPT_DIR/install-live-validate.sh"
#
# The three system paths are read at CALL time, not when sourced, so a test
# can point them at fixtures after sourcing:
#   LIVE_ZONEINFO_DIR  (default /usr/share/zoneinfo)
#   LIVE_KEYMAP_DIR    (default /usr/share/kbd/keymaps)
#   LIVE_LOCALES_FILE  (default /etc/default/libc-locales)
# All three come from the live ISO. It is built from the same tzdata, kbd
# and glibc-locales packages that base-system installs into the target, so
# a name valid here is valid there.

# An RFC 1123 label: lowercase letters, digits and inner hyphens, 1-63 long.
live_valid_hostname() {
    [[ $1 =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]
}

# The shadow default NAME_REGEX, also capped at useradd's 32 characters.
# root and the names base-system already uses are refused, so useradd
# can never just modify an account that is already there.
live_valid_username() {
    [[ $1 =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || return 1
    case "$1" in
        root | nobody | bin | daemon | sys | sync | adm | mail | _*) return 1 ;;
    esac
}

# A zone file under the live zoneinfo tree. The character class rules out
# `..` and absolute paths before the path is touched.
live_valid_timezone() {
    local dir="${LIVE_ZONEINFO_DIR:-/usr/share/zoneinfo}"
    [[ $1 =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]] || return 1
    [[ -f "$dir/$1" ]]
}

# A console keymap that kbd ships (`us` is i386/qwerty/us.map.gz). The name
# is checked first, so find never sees a glob character.
live_valid_keymap() {
    local dir="${LIVE_KEYMAP_DIR:-/usr/share/kbd/keymaps}" hit
    [[ $1 =~ ^[A-Za-z0-9._-]+$ ]] || return 1
    hit="$(find "$dir" \( -name "$1.map.gz" -o -name "$1.map" \) -print -quit 2>/dev/null || true)"
    [[ -n $hit ]]
}

# A locale listed in glibc-locales' config, commented out or not
# (`#en_US.UTF-8 UTF-8`). The name is checked first: it goes into a grep -E
# pattern here, and into a sed address in install-live-config.sh.
live_valid_locale() {
    local file="${LIVE_LOCALES_FILE:-/etc/default/libc-locales}"
    [[ $1 =~ ^[A-Za-z0-9_.@-]+$ ]] || return 1
    [[ -f $file ]] || return 1
    grep -Eq "^#?${1//./\\.}[[:space:]]" "$file"
}

# A crypt(3) SHA-512 or SHA-256 hash (`openssl passwd -6`, `mkpasswd -m
# sha-512`). glibc always supports both. A plain password is refused on
# purpose: the answers file then never holds one (scope J, J-1 plan). No
# ':' or whitespace, because the hash goes to `chpasswd -e` as user:hash.
live_valid_hash() {
    [[ $1 =~ ^\$[56]\$(rounds=[0-9]+\$)?[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{43,86}$ ]]
}

# A repository URL for xbps: https, or http for a local mirror. No spaces
# or quotes.
live_valid_repo() {
    [[ $1 =~ ^https?://[A-Za-z0-9._~:/?#@!\&+,\;=%-]+$ ]]
}
