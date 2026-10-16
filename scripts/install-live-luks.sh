#!/usr/bin/env bash
# The live-ISO installer's optional encryption (scope J, J-4): LUKS2 with
# argon2id on the root partition (dots-root), unlocked at boot by dracut
# with one passphrase prompt. /boot stays plain ext4, so GRUB never needs
# cryptodisk support (scope J, decision 6).
#
# Sourced by install-live-answers.sh, never standalone. It assumes `set -euo
# pipefail`, the colour helpers, and at call time live_run and live_ok
# (install-live-base.sh), live_write (install-live-config.sh),
# live_ask_password (install-live-answers.sh), LIVE_DISK, LIVE_PART3 and
# LIVE_KEYMAP.
#
# usage: source "$SCRIPT_DIR/install-live-luks.sh"
#
# The passphrase is asked for twice in dialog (encryption is off unless
# chosen, decision 14), or read from the file LUKS_PASSFILE names (root's,
# mode 600, decision 13). It lives in LIVE_LUKS_SECRET only, and reaches
# cryptsetup on stdin from printf, a builtin, so it is never in an argv, a
# log or the dry-run output. It goes in with no newline, as typed at boot.
#
# The open mapping is named luks-<UUID> here too, the name dracut gives it
# at boot, so whatever grub-mkconfig or xgenfstab read from the live side
# names the same device in the booted system.
#
# Nothing is added to /etc/crypttab (base-files' copy is comments only, and
# itself says not to list /). dracut opens root from rd.luks.uuid=, and
# runit's /etc/runit/crypt.awk then runs `cryptsetup luksOpen` on every
# crypttab line with no check for a device already open, so a root line
# there could ask a second time (user decision, 2026-10-16).

LIVE_LUKS=0
LIVE_LUKS_SECRET=""
LIVE_LUKS_PASSFILE=""
# /dev/mapper/luks-<UUID> once open (or resumed).
LIVE_LUKS_DEV=""
LIVE_LUKS_DRACUT_CONF=/etc/dracut.conf.d/10-dots-crypt.conf

# live_luks_load_passfile <file> — the passphrase from an already-validated
# file: its one line, without the newline (or CR) after it.
live_luks_load_passfile() {
    local secret
    secret="$(cat -- "$1")" || return 1
    LIVE_LUKS_SECRET="${secret%$'\r'}" LIVE_LUKS_PASSFILE="$1" LIVE_LUKS=1
}

# live_luks_ask — the dialog question, default No. A yes switches the
# console to the chosen keymap (the boot prompt uses it too, through
# rd.vconsole.keymap=) and asks for the passphrase. 1 on Cancel/Esc.
live_luks_ask() {
    local rc=0
    dialog --defaultno --title "Encrypt the disk?" --yesno \
        "Encrypt / on $LIVE_DISK with LUKS2?"$'\n\n'"You type a passphrase at every boot. /boot stays unencrypted. Without the passphrase the data cannot be recovered." 11 64 || rc=$?
    [[ $rc -eq 1 ]] && return 0
    [[ $rc -eq 0 ]] || return 1
    live_run loadkeys -q "$LIVE_KEYMAP" 2>/dev/null \
        || yellow "note    the console stays on its keymap; type the passphrase as you will at boot ($LIVE_KEYMAP)" >&2
    LIVE_LUKS_SECRET="$(live_ask_password "Disk passphrase (asked at every boot)" 0)" || return 1
    LIVE_LUKS=1
}

# live_luks_choose — after the disk choice. --target installs onto what is
# mounted, so it encrypts nothing and refuses LUKS_PASSFILE.
live_luks_choose() {
    if [[ $LIVE_DISK_MODE -eq 0 ]]; then
        if [[ -n $LIVE_LUKS_PASSFILE ]]; then
            red "answers file: LUKS_PASSFILE encrypts the disk to erase, but --target installs onto $LIVE_TARGET as mounted. Drop one."
            return 1
        fi
        return 0
    fi
    if [[ $LIVE_INTERACTIVE -eq 1 ]] && ! live_luks_ask; then
        clear
        yellow "Cancelled. Nothing was written."
        return 1
    fi
}

# live_luks_plan — the plan's encryption line, never the passphrase.
live_luks_plan() {
    if [[ $LIVE_LUKS -eq 1 ]]; then
        printf '%-10s %s\n' encrypt "/ is LUKS2 (argon2id): one passphrase at every boot"
    else
        printf '%-10s %s\n' encrypt "no"
    fi
}

# live_luks_root_dev — what root's ext4 is made on and mounted from.
live_luks_root_dev() {
    if [[ $LIVE_LUKS -eq 1 ]]; then echo "$LIVE_LUKS_DEV"; else echo "$LIVE_PART3"; fi
}

# live_luks_format — LUKS2 on LIVE_PART3, opened as luks-<UUID>.
live_luks_format() {
    local dev="$LIVE_PART3" uuid
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run: cryptsetup luksFormat --batch-mode --type luks2 --pbkdf argon2id --key-file - $dev (passphrase on stdin)"
        blue "  (dry-run) would run: cryptsetup open --key-file - $dev luks-<UUID> (passphrase on stdin)"
        LIVE_LUKS_DEV="/dev/mapper/luks-<UUID>"
        return 0
    fi
    printf '%s' "$LIVE_LUKS_SECRET" | cryptsetup luksFormat --batch-mode --type luks2 --pbkdf argon2id --key-file - "$dev"
    uuid="$(cryptsetup luksUUID "$dev")"
    printf '%s' "$LIVE_LUKS_SECRET" | cryptsetup open --key-file - "$dev" "luks-$uuid"
    LIVE_LUKS_DEV="/dev/mapper/luks-$uuid"
    green "ok      $dev is LUKS2, open at $LIVE_LUKS_DEV"
}

# live_luks_resumable <source> — whether the target's mounted root is what
# this run's answers would make on LIVE_PART3: the partition itself, or,
# encrypted, a mapping on it that this run's passphrase opens. Otherwise
# the disk is laid out again: its erasure is confirmed, and the answers win.
live_luks_resumable() {
    if [[ $LIVE_LUKS -eq 0 ]]; then
        [[ $1 == "$LIVE_PART3" ]]
        return
    fi
    [[ "$(lsblk -nrspo NAME "$1" 2>/dev/null | sed -n 2p)" == "$LIVE_PART3" ]] || return 1
    printf '%s' "$LIVE_LUKS_SECRET" | cryptsetup open --test-passphrase --key-file - "$LIVE_PART3" 2>/dev/null || return 1
    LIVE_LUKS_DEV="$1"
}

# live_luks_close_all — close every dm-crypt mapping on LIVE_DISK: an
# earlier run's, before sfdisk rewrites the disk, or this run's, once the
# target is unmounted. Only call it with nothing on the disk mounted.
live_luks_close_all() {
    local out name type
    out="$(lsblk -nrpo NAME,TYPE "$LIVE_DISK")" || return 1
    while read -r name type; do
        if [[ $type == crypt ]]; then
            live_run cryptsetup close "$name"
        fi
    done <<<"$out"
}

# live_luks_backing — the partition under the target's root when root is a
# dm-crypt mapping, else nothing. Read from what is mounted, so a resumed
# run and a --target root opened by hand are both seen.
live_luks_backing() {
    local src
    src="$(findmnt -nvo SOURCE --mountpoint "$LIVE_TARGET" 2>/dev/null)" || return 0
    [[ "$(lsblk -ndro TYPE "$src" 2>/dev/null)" == crypt ]] || return 0
    lsblk -nrspo NAME "$src" | sed -n 2p
}

# live_luks_grub <tokens> — the target's GRUB_CMDLINE_LINUX with an earlier
# run's rd.luks.uuid= and rd.vconsole.keymap= taken out, then <tokens>
# (maybe none) added. Not _DEFAULT: grub-mkconfig gives that to the normal
# entries only, and the recovery ("single") entries must unlock root too
# (seen on the J-4 UEFI VM). Void ships no such line, so it is appended.
live_luks_grub() {
    local grub="$LIVE_TARGET/etc/default/grub" key=GRUB_CMDLINE_LINUX
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would set $key in $grub: rd.luks.uuid= and rd.vconsole.keymap= replaced by '$1'"
        return 0
    elif ! grep -q "^$key=\"" "$grub"; then
        [[ -z $1 ]] || printf '%s="%s"\n' "$key" "$1" >>"$grub"
        return 0
    fi
    sed -i -E "/^$key=/s/ ?rd\.(luks\.uuid|vconsole\.keymap)=[^ \"]*//g" "$grub"
    if [[ -n $1 ]]; then
        sed -i -E "/^$key=/{s/\"\$/ $1\"/; s/=\" /=\"/}" "$grub"
    fi
}

# live_luks_configure — before the dracut images are made: on an encrypted
# root, the crypt module and the kernel arguments dracut unlocks it from;
# otherwise both are taken back out, so a re-run without encryption
# converges.
live_luks_configure() {
    local part="" uuid="<LUKS UUID of $LIVE_PART3>"
    if [[ $DRY_RUN -eq 0 ]]; then
        part="$(live_luks_backing)"
        [[ -z $part ]] || uuid="$(cryptsetup luksUUID "$part")"
    elif [[ $LIVE_LUKS -eq 1 ]]; then
        part="$LIVE_PART3"
    fi
    if [[ -z $part ]]; then
        live_run rm -f "$LIVE_TARGET$LIVE_LUKS_DRACUT_CONF"
        live_luks_grub ""
        return 0
    fi
    if [[ $DRY_RUN -eq 0 && ! $uuid =~ ^[0-9a-f-]{36}$ ]]; then
        red "No LUKS UUID on $part (cryptsetup luksUUID said '$uuid')."
        return 1
    fi
    live_run mkdir -p "$LIVE_TARGET/etc/dracut.conf.d"
    printf '%s\n' '# Written by the dots live installer (scope J, J-4): root is LUKS2.' \
        'add_dracutmodules+=" crypt "' | live_write "$LIVE_LUKS_DRACUT_CONF" 644
    live_luks_grub "rd.luks.uuid=$uuid rd.vconsole.keymap=$LIVE_KEYMAP"
    live_ok "root on $part is unlocked by dracut at boot (rd.luks.uuid=$uuid)"
}
