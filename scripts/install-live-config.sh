#!/usr/bin/env bash
# The live-ISO installer's second half (scope J, J-1): configure the
# bootstrapped target, then make it bootable. That covers fstab, hostname,
# keymap, timezone and locale, the user in wheel, passwords, the wheel
# sudoers rule, dhcpcd, GRUB for UEFI or BIOS, and both kernels' dracut
# images.
#
# Sourced by install-live.sh after install-live-base.sh (live_run,
# LIVE_FIRMWARE, LIVE_DISK) and install-live-answers.sh (the LIVE_*
# answers). Never standalone.
#
# usage: source "$SCRIPT_DIR/install-live-config.sh"
#
# Plain files are written from the live side. Anything that must run in the
# new system (useradd, chpasswd, grub-install, xbps-reconfigure) goes
# through xchroot, which binds /dev, /proc and /sys, efivars included.
# Every step converges on a re-run (rule 1): files are rewritten, the user
# is only created once, and grub-install and the reconfigures are
# idempotent.

# live_in_target <cmd...> — run a command inside the target root.
live_in_target() {
    live_run xchroot "$LIVE_TARGET" "$@"
}

# live_write <path-in-target> <mode> — write stdin to a file in the target,
# atomically. Under --dry-run, show what would be written. Never used for a
# secret.
live_write() {
    local dest="$LIVE_TARGET$1" content
    content="$(cat)"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would write $dest (mode $2):"
        printf '%s\n' "$content" | sed 's/^/                /'
        return 0
    fi
    printf '%s\n' "$content" >"$dest.dots-new"
    chmod "$2" "$dest.dots-new"
    mv -f "$dest.dots-new" "$dest"
}

# live_set_rc <KEY> <value> — set one KEY="value" in the target's
# /etc/rc.conf, replacing the commented example base-files ships
# (`#KEYMAP="es"`) or an earlier run's line, and appending otherwise.
live_set_rc() {
    local rc="$LIVE_TARGET/etc/rc.conf"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would set $1=\"$2\" in $rc"
    elif grep -q "^#\?$1=" "$rc" 2>/dev/null; then
        sed -i "0,/^#\?$1=.*/s//$1=\"$2\"/" "$rc"
    else
        printf '%s="%s"\n' "$1" "$2" >>"$rc"
    fi
}

# live_configure_system — fstab and the machine's identity.
live_configure_system() {
    local locales="$LIVE_TARGET/etc/default/libc-locales" loc_re="${LIVE_LOCALE//./\\.}"
    blue "==> configuring $LIVE_TARGET"
    live_run chown root:root "$LIVE_TARGET"
    live_run chmod 755 "$LIVE_TARGET"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run: xgenfstab -U $LIVE_TARGET > $LIVE_TARGET/etc/fstab"
    else
        xgenfstab -U "$LIVE_TARGET" >"$LIVE_TARGET/etc/fstab.dots-new"
        mv -f "$LIVE_TARGET/etc/fstab.dots-new" "$LIVE_TARGET/etc/fstab"
    fi
    printf '%s\n' "$LIVE_HOSTNAME" | live_write /etc/hostname 644
    live_set_rc KEYMAP "$LIVE_KEYMAP"
    live_run ln -sfn "/usr/share/zoneinfo/$LIVE_TIMEZONE" "$LIVE_TARGET/etc/localtime"
    live_run sed -i "s/^#\(${loc_re}[[:space:]]\)/\1/" "$locales"
    printf 'LANG=%s\n' "$LIVE_LOCALE" | live_write /etc/locale.conf 644
    live_in_target xbps-reconfigure -f glibc-locales
    live_ok "hostname $LIVE_HOSTNAME, keymap $LIVE_KEYMAP, $LIVE_TIMEZONE, $LIVE_LOCALE"
}

# live_set_password <account> <kind> <secret> — hand the secret to chpasswd
# on stdin, never in argv or a log: `-e` for a crypt hash, `-c SHA512` for a
# plain password. A kind of none locks the account (root only).
#
# Never plain `chpasswd` with no method. In the Void target it exits 0 and
# changes nothing: the first real dialog-path run (2026-10-16, BIOS VM) left
# the user with no password and reported success. `-c SHA512` hashes in
# shadow itself and was verified on the same VM. live_check_password then
# reads the result back, so a silent no-op fails the run.
live_set_password() {
    local who="$1" kind="$2" secret="$3"
    if [[ $kind == none ]]; then
        live_in_target passwd -l "$who"
        return 0
    elif [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would set the $who password ($kind, chpasswd on stdin)"
        return 0
    elif [[ $kind == hash ]]; then
        printf '%s:%s\n' "$who" "$secret" | xchroot "$LIVE_TARGET" chpasswd -e
    else
        printf '%s:%s\n' "$who" "$secret" | xchroot "$LIVE_TARGET" chpasswd -c SHA512
    fi
    live_check_password "$who"
}

# live_check_password <account> — the target's shadow entry must now hold a
# crypt hash ($id$...), not the `!` useradd leaves or an empty field.
live_check_password() {
    local field
    field="$(awk -F: -v u="$1" '$1 == u { print $2 }' "$LIVE_TARGET/etc/shadow")"
    if [[ $field != \$* ]]; then
        red "The $1 password was not set (its shadow entry holds no hash)."
        return 1
    fi
    green "ok      $1 password set"
}

# live_configure_accounts — the user (wheel only: dots adds the rest in
# J-2), both passwords, and the sudoers rule that makes wheel mean sudo.
# Void's /etc/sudoers ships that rule commented out and includes
# /etc/sudoers.d, so the rule gets its own file, checked by visudo
# before anything relies on it.
live_configure_accounts() {
    blue "==> accounts"
    if grep -q "^$LIVE_USERNAME:" "$LIVE_TARGET/etc/passwd" 2>/dev/null; then
        green "ok      user $LIVE_USERNAME already exists"
    else
        live_in_target useradd -m -G wheel -s /bin/bash "$LIVE_USERNAME"
    fi
    live_set_password "$LIVE_USERNAME" "$LIVE_USER_KIND" "$LIVE_USER_SECRET"
    live_set_password root "$LIVE_ROOT_KIND" "$LIVE_ROOT_SECRET"
    printf '%s\n' '# Written by the dots live installer (scope J): wheel may sudo.' \
        '%wheel ALL=(ALL:ALL) ALL' | live_write /etc/sudoers.d/10-wheel 440
    live_in_target visudo -cf /etc/sudoers.d/10-wheel
    live_ok "$LIVE_USERNAME in wheel, sudo enabled"
}

# live_drop_empty_resolv — every xchroot call touches the target's
# /etc/resolv.conf to bind the ISO's copy over it, and the empty file stays
# behind. On the J-2 VM run (2026-10-16) the first boot kept it empty:
# NetworkManager handed openresolv the nameserver, nothing was written, and
# no name resolved. With the file absent, openresolv writes it at boot. Run
# after the last xchroot call; a file with content is someone's and stays.
live_drop_empty_resolv() {
    local f="$LIVE_TARGET/etc/resolv.conf"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would remove $f if xchroot left it empty"
    elif [[ -f $f && ! -L $f && ! -s $f ]]; then
        rm -f "$f"
        green "ok      removed the empty /etc/resolv.conf xchroot left (written at boot)"
    fi
}

# live_configure_boot — dhcpcd, so the first boot has a network before
# install-void.sh switches it to NetworkManager; GRUB; then the dracut
# images and grub.cfg. On an encrypted root, install-live-luks.sh adds
# dracut's crypt module and rd.luks.uuid= first. reconfigure -fa runs every kernel hook, so both
# `linux` and `linux-lts` get an initramfs. grub-mkconfig puts the newest
# kernel (linux) first and the LTS one under "Advanced options"
# (scope J, decision 9).
live_configure_boot() {
    blue "==> bootloader ($LIVE_FIRMWARE)"
    live_run ln -sfn /etc/sv/dhcpcd "$LIVE_TARGET/etc/runit/runsvdir/default/dhcpcd"
    if [[ $LIVE_FIRMWARE == uefi ]]; then
        live_in_target grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Void
        # The fallback path too (EFI/BOOT/BOOTX64.EFI): some firmware forgets
        # or ignores NVRAM entries (Void Handbook, chroot guide).
        live_in_target grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable
    else
        live_in_target grub-install --target=i386-pc "$LIVE_DISK"
    fi
    live_luks_configure
    live_in_target xbps-reconfigure -fa
    live_in_target grub-mkconfig -o /boot/grub/grub.cfg
    live_ok "GRUB installed, both kernels in its menu"
}
