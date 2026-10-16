#!/usr/bin/env bash
# The live-ISO installer's questions: asked with dialog menus (scope J,
# decision 10), or read from an answers file so a VM re-test runs
# unattended. Both paths fill the same LIVE_* variables and use the same
# validators (install-live-validate.sh).
#
# Sourced by install-live.sh, never standalone. It assumes `set -euo
# pipefail` and the red/green/yellow/blue helpers.
#
# usage: source "$SCRIPT_DIR/install-live-answers.sh"
#
# Answers file: one KEY=VALUE per line, `#` comments, and optional matching
# quotes around the value. It is PARSED, never sourced, so a value is never
# run. Keys:
#   HOSTNAME USERNAME USER_PASSWORD_HASH TIMEZONE KEYMAP LOCALE   (required)
#   ROOT_PASSWORD_HASH  (optional; empty or absent locks root)
#   REPO                (optional; default LIVE_DEFAULT_REPO)
#   DISK WIPE           (the disk to erase, e.g. /dev/vda, named in both;
#                        required unless --target is given, refused with it.
#                        install-live-disk.sh checks the pair and the disk)
#   LUKS_PASSFILE       (optional; an absolute path to a file holding only
#                        the disk passphrase, root's and mode 600. Encrypts
#                        / with LUKS2. Refused with --target. J-4)
# Passwords are crypt hashes only (`openssl passwd -6`), so the file never
# holds a usable password, and the LUKS passphrase stays in a file of its
# own. The dialog path asks for the password itself and
# keeps it in memory only, handed to chpasswd on stdin
# (install-live-config.sh).

LIVE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/install-live-validate.sh
source "$LIVE_SCRIPT_DIR/install-live-validate.sh"
# shellcheck source=scripts/install-live-luks.sh
source "$LIVE_SCRIPT_DIR/install-live-luks.sh"

LIVE_DEFAULT_REPO="https://repo-default.voidlinux.org/current"
LIVE_ANSWER_KEYS=(HOSTNAME USERNAME USER_PASSWORD_HASH TIMEZONE KEYMAP LOCALE ROOT_PASSWORD_HASH REPO DISK WIPE LUKS_PASSFILE)
LIVE_REQUIRED_KEYS=(HOSTNAME USERNAME USER_PASSWORD_HASH TIMEZONE KEYMAP LOCALE)

LIVE_HOSTNAME="" LIVE_USERNAME="" LIVE_TIMEZONE="" LIVE_KEYMAP="" LIVE_LOCALE=""
LIVE_REPO="$LIVE_DEFAULT_REPO"
LIVE_DISK_ANSWER="" LIVE_WIPE_ANSWER=""
# <who>_SECRET holds the hash or the password, and <who>_KIND says which:
# hash | plain | none. A root KIND of none means the root account is locked.
LIVE_USER_SECRET="" LIVE_USER_KIND="none"
LIVE_ROOT_SECRET="" LIVE_ROOT_KIND="none"

# live_answer_valid <KEY> <value> — the validator for one answers-file key.
live_answer_valid() {
    case "$1" in
        HOSTNAME) live_valid_hostname "$2" ;;
        USERNAME) live_valid_username "$2" ;;
        TIMEZONE) live_valid_timezone "$2" ;;
        KEYMAP) live_valid_keymap "$2" ;;
        LOCALE) live_valid_locale "$2" ;;
        USER_PASSWORD_HASH) live_valid_hash "$2" ;;
        ROOT_PASSWORD_HASH) [[ -z $2 ]] || live_valid_hash "$2" ;;
        REPO) live_valid_repo "$2" ;;
        DISK | WIPE) live_valid_disk_path "$2" ;;
        LUKS_PASSFILE) live_valid_passfile "$2" ;;
        *) return 1 ;;
    esac
}

# live_answer_set <KEY> <value> — store one already-validated answer.
# DISK and WIPE are read by install-live-disk.sh, sourced after this file.
# shellcheck disable=SC2034
live_answer_set() {
    case "$1" in
        HOSTNAME) LIVE_HOSTNAME="$2" ;;
        USERNAME) LIVE_USERNAME="$2" ;;
        TIMEZONE) LIVE_TIMEZONE="$2" ;;
        KEYMAP) LIVE_KEYMAP="$2" ;;
        LOCALE) LIVE_LOCALE="$2" ;;
        USER_PASSWORD_HASH) LIVE_USER_SECRET="$2" LIVE_USER_KIND="hash" ;;
        ROOT_PASSWORD_HASH) if [[ -n $2 ]]; then LIVE_ROOT_SECRET="$2" LIVE_ROOT_KIND="hash"; fi ;;
        REPO) LIVE_REPO="$2" ;;
        DISK) LIVE_DISK_ANSWER="$2" ;;
        WIPE) LIVE_WIPE_ANSWER="$2" ;;
        LUKS_PASSFILE) live_luks_load_passfile "$2" ;;
    esac
}

# live_answers_load <file> — parse and validate an answers file into LIVE_*.
# Prints every problem (line numbers, never values: a value may be a hash)
# and returns 1 if there was any, so a bad file is reported in one go.
live_answers_load() {
    local file="$1" line key value n=0 bad=0 mode
    local -A seen=()
    [[ -f $file && -r $file ]] || {
        red "answers file not readable: $file"
        return 1
    }
    mode="$(stat -c %a "$file" 2>/dev/null || echo 600)"
    [[ ${mode: -2} == 00 ]] || yellow "warn    $file is readable by others (mode $mode) — it holds password hashes; chmod 600 it"
    while IFS= read -r line || [[ -n $line ]]; do
        n=$((n + 1))
        line="${line%$'\r'}"
        [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
        if [[ ! $line =~ ^([A-Z_]+)=(.*)$ ]]; then
            red "answers line $n: not KEY=VALUE"
            bad=1
            continue
        fi
        key="${BASH_REMATCH[1]}" value="${BASH_REMATCH[2]}"
        [[ $value =~ ^\"(.*)\"$ || $value =~ ^\'(.*)\'$ ]] && value="${BASH_REMATCH[1]}"
        if [[ " ${LIVE_ANSWER_KEYS[*]} " != *" $key "* ]]; then
            red "answers line $n: unknown key $key"
            bad=1
        elif [[ -n ${seen[$key]:-} ]]; then
            red "answers line $n: $key given twice (first on line ${seen[$key]})"
            bad=1
        elif ! live_answer_valid "$key" "$value"; then
            red "answers line $n: invalid $key"
            bad=1
        else
            seen[$key]=$n
            live_answer_set "$key" "$value"
        fi
    done <"$file"
    for key in "${LIVE_REQUIRED_KEYS[@]}"; do
        [[ -n ${seen[$key]:-} ]] || {
            red "answers file: missing $key"
            bad=1
        }
    done
    return "$bad"
}

# live_ask <validator> <title> <prompt> <default> — one dialog input box,
# asked again until the validator accepts the reply. The reply is printed on
# stdout. Returns 1 on Cancel/Esc, which the caller treats as "stop,
# nothing changed".
live_ask() {
    local check="$1" title="$2" prompt="$3" value="$4" error=""
    while true; do
        value="$(dialog --stdout --title "$title" --inputbox "$error$prompt" 10 64 "$value")" || return 1
        "$check" "$value" && {
            printf '%s\n' "$value"
            return 0
        }
        error="Not accepted: '$value'."$'\n\n'
    done
}

# live_ask_password <title> <may-be-empty: 0|1> — asks twice until both
# entries match. An empty password is accepted only when allowed (root:
# empty locks it). Prints the password on stdout, for the caller's $(),
# never anywhere else.
live_ask_password() {
    local title="$1" empty_ok="$2" first second error=""
    while true; do
        first="$(dialog --stdout --insecure --title "$title" --passwordbox "${error}Password:" 10 64)" || return 1
        second="$(dialog --stdout --insecure --title "$title" --passwordbox "Again:" 10 64)" || return 1
        if [[ $first != "$second" ]]; then
            error="The two entries differ."$'\n\n'
        elif [[ -z $first && $empty_ok -eq 0 ]]; then
            error="A password is required."$'\n\n'
        else
            printf '%s' "$first"
            return 0
        fi
    done
}

# live_answers_dialog — every question as a dialog menu, in install order.
# Returns 1 when the user cancels.
live_answers_dialog() {
    local tz_hint="Region/City as in /usr/share/zoneinfo, e.g. Europe/Berlin or UTC."
    LIVE_HOSTNAME="$(live_ask live_valid_hostname "Hostname" "Lowercase letters, digits and hyphens:" "void")" || return 1
    LIVE_USERNAME="$(live_ask live_valid_username "User" "Your login name (added to wheel, so it can sudo):" "")" || return 1
    # Both read by install-live-config.sh, which sources after this file.
    # shellcheck disable=SC2034
    LIVE_USER_SECRET="$(live_ask_password "Password for $LIVE_USERNAME" 0)" || return 1
    # shellcheck disable=SC2034
    LIVE_USER_KIND="plain"
    LIVE_ROOT_SECRET="$(live_ask_password "Root password (leave empty to lock root)" 1)" || return 1
    if [[ -n $LIVE_ROOT_SECRET ]]; then LIVE_ROOT_KIND="plain"; else LIVE_ROOT_KIND="none"; fi
    LIVE_TIMEZONE="$(live_ask live_valid_timezone "Timezone" "$tz_hint" "UTC")" || return 1
    LIVE_KEYMAP="$(live_ask live_valid_keymap "Console keymap" "kbd keymap name, e.g. us, de, fr, uk:" "us")" || return 1
    LIVE_LOCALE="$(live_ask live_valid_locale "Locale" "As listed in /etc/default/libc-locales:" "en_US.UTF-8")" || return 1
}

# live_answers_summary — the answers as plain lines, never a secret.
live_answers_summary() {
    printf '%-10s %s\n' hostname "$LIVE_HOSTNAME" user "$LIVE_USERNAME (wheel)" \
        timezone "$LIVE_TIMEZONE" keymap "$LIVE_KEYMAP" locale "$LIVE_LOCALE" repo "$LIVE_REPO"
    if [[ $LIVE_ROOT_KIND == none ]]; then
        printf '%-10s %s\n' root "locked (use sudo)"
    else
        printf '%-10s %s\n' root "password set"
    fi
}
