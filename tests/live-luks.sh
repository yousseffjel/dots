#!/usr/bin/env bash
# The live-ISO installer's optional encryption (scope J, J-4): the
# LUKS_PASSFILE checks, the dialog question (default No), LUKS2 made on
# dots-root with the passphrase on stdin only, the resume through an open
# mapping, closing mappings before a re-layout, and the dracut + GRUB
# settings an encrypted root boots from. Nothing touches a real disk or
# runs the real cryptsetup: the fakes are in tests/lib/live-disk-env.sh.
# The whole dry run with LUKS_PASSFILE is tests/live-dry-run-disk.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
# Called by the sourced modules, through in_live's eval.
# shellcheck disable=SC2329
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/live-disk-env.sh
source "$SCRIPT_DIR/lib/live-disk-env.sh"

# A passphrase with spaces, quotes, a $ and a non-ASCII letter. Exported, so
# the code in_live evaluates reads it without quoting it again.
# The $ is literal on purpose: a passphrase is never expanded.
# shellcheck disable=SC2016
export SECRET='p4ss w0rd "q" $HOME é'
ME="$(id -u)"
MAPPER="/dev/mapper/luks-$LUKS_UUID"
expect() { # <description> <condition-result: 0|1> [detail]
    if [[ $2 -eq 0 ]]; then pass "$1"; else fail "$1" "${3:-}"; fi
}
no_secret() { # <text...> — 0 when the passphrase is in none of them
    local t
    for t in "$@"; do [[ $t != *"$SECRET"* ]] || return 1; done
}

blue "==> LUKS_PASSFILE: root's, mode 600, one line"
pf="$SB/pass"
valid() { in_live "LIVE_PASSFILE_UID=${2:-$ME}; source \"\$DOTS_DIR/scripts/install-live-validate.sh\"; live_valid_passfile '$1' && echo VALID"; }
printf '%s\n' "$SECRET" >"$pf" && chmod 600 "$pf"
[[ "$(valid "$pf")" == VALID ]] && r=0 || r=1
expect "a one-line file, mode 600, owned by the expected uid" "$r"
chmod 400 "$pf"
[[ "$(valid "$pf")" == VALID ]] && r=0 || r=1
expect "mode 400 too" "$r"
chmod 644 "$pf"
[[ "$(valid "$pf")" != *VALID* ]] && r=0 || r=1
expect "readable by others (644): refused" "$r"
chmod 600 "$pf"
[[ "$(valid "$pf" $((ME + 1)))" != *VALID* ]] && r=0 || r=1
expect "owned by another uid than root's: refused" "$r"
# The default, as install-live.sh runs it: LIVE_PASSFILE_UID unset means
# root. The file is this user's, so only a root test run accepts it.
got="$(in_live "unset LIVE_PASSFILE_UID; source \"\$DOTS_DIR/scripts/install-live-validate.sh\"; live_valid_passfile '$pf' && echo VALID")"
if [[ $ME -eq 0 ]]; then [[ $got == VALID ]] && r=0 || r=1; else [[ $got != *VALID* ]] && r=0 || r=1; fi
expect "LIVE_PASSFILE_UID unset: the owner must be root (uid 0)" "$r" "$got"
ln -s "$pf" "$SB/link"
[[ "$(valid "$SB/link")" != *VALID* ]] && r=0 || r=1
expect "a symlink: refused" "$r"
[[ "$(cd "$SB" && valid pass)" != *VALID* ]] && r=0 || r=1
expect "a relative path: refused" "$r"
printf '%s\n%s\n' one two >"$SB/two" && chmod 600 "$SB/two"
[[ "$(valid "$SB/two")" != *VALID* ]] && r=0 || r=1
expect "two lines: refused" "$r"
printf '\n' >"$SB/empty" && chmod 600 "$SB/empty"
[[ "$(valid "$SB/empty")" != *VALID* ]] && r=0 || r=1
expect "an empty passphrase: refused" "$r"
[[ "$(valid "$SB/absent")" != *VALID* ]] && r=0 || r=1
expect "a missing file: refused" "$r"

blue "==> the passphrase is read without its newline"
printf '%s\r\n' "$SECRET" >"$SB/crlf" && chmod 600 "$SB/crlf"
# shellcheck disable=SC2016
got="$(in_live "live_luks_load_passfile $SB/crlf"' && [[ $LIVE_LUKS_SECRET == "$SECRET" && $LIVE_LUKS -eq 1 ]] && echo LOADED')"
[[ $got == LOADED ]] && r=0 || r=1
expect "CRLF stripped, LIVE_LUKS on" "$r" "$got"
# shellcheck disable=SC2016
got="$(in_live 'LIVE_LUKS=1; live_luks_plan; LIVE_LUKS=0; live_luks_plan')"
[[ $got == *"LUKS2 (argon2id)"* && $got == *"encrypt    no"* ]] && no_secret "$got" && r=0 || r=1
expect "the plan line says LUKS2 or no, never the passphrase" "$r" "$got"

blue "==> --target encrypts nothing"
got="$(in_live "LIVE_DISK_MODE=0 LIVE_LUKS_PASSFILE=$pf; live_luks_choose && echo CHOSEN")"
[[ $got == *"Drop one"* && $got != *CHOSEN* ]] && r=0 || r=1
expect "--target with LUKS_PASSFILE: refused" "$r" "$got"
got="$(in_live "LIVE_DISK_MODE=0 LIVE_INTERACTIVE=1; live_luks_choose && echo CHOSEN")"
[[ $got == CHOSEN ]] && r=0 || r=1
expect "--target in dialog: no question asked" "$r" "$got"

blue "==> the dialog question"
ask() {
    printf '%s\n' "$@" >"$STATE/replies"
    rm -f "$STATE/n" "$STATE/dialog-calls"
    # shellcheck disable=SC2016
    got="$(in_live 'LIVE_DISK_MODE=1 LIVE_INTERACTIVE=1 LIVE_DISK=/dev/vdc LIVE_KEYMAP=de; clear() { :; }
        live_ask_password() { printf "%s" "$SECRET"; }
        live_luks_choose && echo "CHOSEN $LIVE_LUKS" && [[ $LIVE_LUKS_SECRET == "${LUKS_WANT:-}" ]] && echo SECRET-OK')"
}
LUKS_WANT="" ask CANCEL
[[ $got == *"CHOSEN 0"*SECRET-OK* ]] && grep -q -- '--defaultno' "$STATE/dialog-calls" && r=0 || r=1
expect "No (the default button): not encrypted" "$r" "$got"
LUKS_WANT="$SECRET" ask yes
[[ $got == *"CHOSEN 1"*SECRET-OK* && $got == *"would run: loadkeys -q de"* ]] && r=0 || r=1
expect "Yes: the console takes the keymap, then the passphrase is asked" "$r" "$got"
ask ESC
[[ $got == *"Cancelled. Nothing was written."* && $got != *CHOSEN* ]] && r=0 || r=1
expect "Esc: cancelled" "$r" "$got"

blue "==> LUKS2 made on dots-root, passphrase on stdin only"
dots_vdc() { printf '%s\n' '/dev/vdc  ' '/dev/vdc1 1 dots-esp' '/dev/vdc2 2 dots-boot' '/dev/vdc3 3 dots-root'; }
dots_vdc >"$STATE/after-sfdisk"
dots_vdc | says -nrpo NAME,PARTN,PARTLABEL /dev/vdc
mkdir -p "$SB/mnt"
prepare() { # <LIVE_LUKS>
    : >"$STATE/called"
    : >"$STATE/key-in"
    # shellcheck disable=SC2016
    out="$(in_live "LIVE_TARGET=$SB/mnt LIVE_DISK=/dev/vdc DRY_RUN=0 LIVE_LUKS=$1"'; LIVE_LUKS_SECRET="$SECRET"; live_part_prepare; echo "ROOT=$(live_luks_root_dev)"')"
    called="$(cat "$STATE/called")"
}
: >"$STATE/mounts"
prepare 1
want="sfdisk*mkfs.ext4 -F -q -L boot /dev/vdc2*cryptsetup luksFormat --batch-mode --type luks2 --pbkdf argon2id --key-file - /dev/vdc3"
want+="*cryptsetup luksUUID /dev/vdc3*cryptsetup open --key-file - /dev/vdc3 luks-$LUKS_UUID"
want+="*mkfs.ext4 -F -q -L void $MAPPER*mount $MAPPER $SB/mnt*mount /dev/vdc2 $SB/mnt/boot*"
# shellcheck disable=SC2053
[[ $called == $want ]] && [[ $called != *"mkfs.ext4 -F -q -L void /dev/vdc3"* ]] && r=0 || r=1
expect "format, open as luks-<UUID>, then ext4 and the mount on the mapping" "$r" "$out"$'\n'"$called"
[[ "$(cat "$STATE/key-in")" == "$SECRET"$'\n'"$SECRET" ]] && no_secret "$out" "$called" && r=0 || r=1
expect "the passphrase reached cryptsetup twice on stdin, with no newline, and is in no argv or output" "$r" "$(cat "$STATE/key-in")"

blue "==> an earlier encrypted run: resumed, or laid out again"
printf '%s\n' "$MAPPER" /dev/vdc3 | says -nrspo NAME "$MAPPER"
echo "$SB/mnt $MAPPER" >"$STATE/mounts"
echo 0 >"$STATE/test-pass"
prepare 1
[[ $out == *"is $MAPPER from an earlier run: resuming it"* && $out == *"ROOT=$MAPPER"* && $called == *"open --test-passphrase --key-file - /dev/vdc3"* &&
    $called != *sfdisk* && $called != *luksFormat* && $called != *"mount $MAPPER"* && $called == *"mount /dev/vdc2"* ]] && r=0 || r=1
expect "the mapping is on this disk's dots-root and the passphrase opens it: resumed" "$r" "$out"$'\n'"$called"
printf '%s\n' '/dev/vdc disk' '/dev/vdc1 part' '/dev/vdc2 part' '/dev/vdc3 part' "$MAPPER crypt" | says -nrpo NAME,TYPE /dev/vdc
echo 2 >"$STATE/test-pass"
prepare 1
[[ $called == "cryptsetup open --test-passphrase"*"umount -R $SB/mnt"*"cryptsetup close $MAPPER"*sfdisk*luksFormat* ]] && r=0 || r=1
expect "another passphrase: unmounted, the mapping closed, then laid out again" "$r" "$called"
echo "$SB/mnt $MAPPER" >"$STATE/mounts"
prepare 0
[[ $called == "umount -R"*"cryptsetup close $MAPPER"*sfdisk* && $called != *luksFormat* ]] && r=0 || r=1
expect "encrypted before, plain now: laid out again, unencrypted" "$r" "$called"
echo "$SB/mnt /dev/vdc3" >"$STATE/mounts"
prepare 1
[[ $called == "umount -R"*sfdisk*luksFormat* ]] && r=0 || r=1
expect "plain before, encrypted now: laid out again, encrypted" "$r" "$called"
printf '%s\n' '/dev/vdc disk' '/dev/vdc1 part' '/dev/vdc2 part' '/dev/vdc3 part' | says -nrpo NAME,TYPE /dev/vdc

blue "==> what an encrypted root boots from"
T="$SB/tgt"
mkdir -p "$T/etc/default"
grub_void() { printf '%s\n' 'GRUB_DEFAULT=0' 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4"' >"$T/etc/default/grub"; }
configure() {
    out="$(in_live "LIVE_TARGET=$T DRY_RUN=0 LIVE_KEYMAP=de; source \"\$DOTS_DIR/scripts/install-live-config.sh\"; live_luks_configure")"
    lines="$(grep '^GRUB_CMDLINE_LINUX' "$T/etc/default/grub")"
}
want_luks="GRUB_CMDLINE_LINUX=\"rd.luks.uuid=$LUKS_UUID rd.vconsole.keymap=de\""
grub_void
echo "$T $MAPPER" >"$STATE/mounts"
echo crypt | says -ndro TYPE "$MAPPER"
configure
configure
[[ $lines == 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4"'$'\n'"$want_luks" ]] && r=0 || r=1
expect "GRUB_CMDLINE_LINUX (recovery entries too) appended once over two runs, _DEFAULT untouched" "$r" "$lines"
[[ "$(cat "$T/etc/dracut.conf.d/10-dots-crypt.conf" 2>/dev/null)" == *'add_dracutmodules+=" crypt "'* &&
"$(stat -c %a "$T/etc/dracut.conf.d/10-dots-crypt.conf")" == 644 ]] && r=0 || r=1
expect "dracut's crypt module asked for explicitly" "$r" "$out"
[[ ! -e $T/etc/crypttab ]] && r=0 || r=1
expect "no /etc/crypttab written (runit would open root a second time)" "$r"
echo "$T /dev/vdc3" >"$STATE/mounts"
echo part | says -ndro TYPE /dev/vdc3
configure
[[ $lines == 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4"'$'\n''GRUB_CMDLINE_LINUX=""' && ! -e $T/etc/dracut.conf.d/10-dots-crypt.conf ]] && r=0 || r=1
expect "a plain root afterwards: both taken back out" "$r" "$lines"
grub_void
configure
[[ $lines == 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4"' ]] && r=0 || r=1
expect "a plain root on Void's file: no line added" "$r" "$lines"
printf '%s\n' 'GRUB_CMDLINE_LINUX="quiet"' >"$T/etc/default/grub"
echo "$T $MAPPER" >"$STATE/mounts"
configure
[[ $lines == "GRUB_CMDLINE_LINUX=\"quiet rd.luks.uuid=$LUKS_UUID rd.vconsole.keymap=de\"" ]] && r=0 || r=1
expect "an existing GRUB_CMDLINE_LINUX: added after what it holds" "$r" "$lines"

blue "==> the finished install: unmounted, then the mapping closed"
printf '%s\n' '/dev/vdc disk' '/dev/vdc3 part' "$MAPPER crypt" | says -nrpo NAME,TYPE /dev/vdc
finish() { # <LIVE_LUKS>
    : >"$STATE/called"
    echo "$SB/mnt $MAPPER" >"$STATE/mounts"
    out="$(in_live "LIVE_TARGET=$SB/mnt LIVE_DISK=/dev/vdc DRY_RUN=0 LIVE_LUKS=$1 LIVE_REBOOT=0 LIVE_INTERACTIVE=0
        sync() { :; }; source \"\$DOTS_DIR/scripts/install-live-dots.sh\"; live_dots_finish")"
    called="$(cat "$STATE/called")"
}
finish 1
[[ $called == "umount -R $SB/mnt"$'\n'"cryptsetup close $MAPPER" ]] && r=0 || r=1
expect "umount -R, then cryptsetup close" "$r" "$out"$'\n'"$called"
finish 0
[[ $called == "umount -R $SB/mnt" ]] && r=0 || r=1
expect "not encrypted by this run: no cryptsetup call" "$r" "$called"

exit "$rc"
