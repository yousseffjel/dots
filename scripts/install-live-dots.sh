#!/usr/bin/env bash
# The live-ISO installer's last stage (scope J, J-2): put dots into the new
# system before the first boot. It copies the repo into the new user's home,
# gives that user a temporary password-free sudo rule, runs install-void.sh
# as that user inside the target, then takes the rule away again. After it,
# the first boot lands on ly.
#
# Sourced by install-live.sh after install-live-config.sh (live_in_target,
# live_write) and install-live-base.sh (live_run, live_ok). Never standalone.
#
# usage: source "$SCRIPT_DIR/install-live-dots.sh"
#
# The temporary rule exists only because install-void.sh runs sudo with
# stdin closed, so no password prompt can be answered. install-live.sh arms
# live_dots_cleanup on EXIT before granting it, so a failed or interrupted
# install-void.sh never leaves it behind, nor goes on running without it,
# and live_dots_install checks it is gone before reporting success. Every step converges on a re-run (rule 1):
# an existing clone is left alone, and the rule is rewritten, then removed.

LIVE_DOTS_SUDOERS=/etc/sudoers.d/99-dots-live-install
# Written inside the target only when install-void.sh succeeded. xchroot's
# exit status cannot say that on its own: see live_dots_release.
LIVE_DOTS_MARK=/var/tmp/dots-live-install.ok

# live_dots_home — the new user's home, read from the target's passwd. Under
# --dry-run the user may not exist yet, so the useradd default stands in.
live_dots_home() {
    local home
    home="$(awk -F: -v u="$LIVE_USERNAME" '$1 == u { print $6 }' "$LIVE_TARGET/etc/passwd" 2>/dev/null || true)"
    printf '%s\n' "${home:-/home/$LIVE_USERNAME}"
}

# live_dots_clone — copy the repo the installer runs from into ~/dots. A
# local clone needs no network and lands on exactly the commit being
# installed. Its origin is the live clone's origin, so `dots update` pulls
# from upstream. Only committed work is copied; uncommitted changes are
# named rather than silently dropped.
live_dots_clone() {
    local home dest url owner
    home="$(live_dots_home)"
    dest="$LIVE_TARGET$home/dots"
    if [[ -d $dest/.git ]]; then
        green "ok      $home/dots already cloned (left alone; \`dots update\` moves it)"
        return 0
    fi
    if [[ -n "$(git -C "$DOTS_DIR" status --porcelain 2>/dev/null)" ]]; then
        yellow "note    $DOTS_DIR has uncommitted changes; only commit $(git -C "$DOTS_DIR" rev-parse --short HEAD) is copied"
    fi
    live_run git clone --quiet --local --no-hardlinks "$DOTS_DIR" "$dest"
    url="$(git -C "$DOTS_DIR" remote get-url origin 2>/dev/null || true)"
    [[ -n $url ]] && live_run git -C "$dest" remote set-url origin "$url"
    owner="$(awk -F: -v u="$LIVE_USERNAME" '$1 == u { print $3 ":" $4 }' "$LIVE_TARGET/etc/passwd" 2>/dev/null || true)"
    live_run chown -R "${owner:-$LIVE_USERNAME}" "$dest"
    live_ok "dots cloned to $home/dots"
}

# live_dots_grant — the temporary rule, checked by visudo before use.
live_dots_grant() {
    printf '%s\n' '# Temporary: written and removed by the dots live installer (scope J, J-2).' \
        "$LIVE_USERNAME ALL=(ALL:ALL) NOPASSWD: ALL" | live_write "$LIVE_DOTS_SUDOERS" 440
    live_in_target visudo -cf "$LIVE_DOTS_SUDOERS"
}

# live_dots_revoke — the EXIT trap. It removes the rule from the live side,
# so it works even when the chroot is what failed, and it never fails
# itself: set -e still applies inside an EXIT trap.
live_dots_revoke() {
    [[ $DRY_RUN -eq 1 ]] && return 0
    rm -f "$LIVE_TARGET$LIVE_DOTS_SUDOERS" || true
}

# live_dots_rooted — the live pids whose root is the target, one a line.
# Matched by /proc/<pid>/root, never by user: uid 1000 can be the live ISO's
# own desktop user. LIVE_PROC stands in for /proc in tests; `kill -0` drops a
# pid that has already gone.
live_dots_rooted() {
    local p
    for p in "${LIVE_PROC:-/proc}"/[0-9]*; do
        [[ "$(readlink "$p/root" 2>/dev/null)" == "$LIVE_TARGET" ]] || continue
        kill -0 "${p##*/}" 2>/dev/null && printf '%s\n' "${p##*/}"
    done
    return 0
}

# live_dots_release — stop whatever still runs in the target, then unmount
# what xchroot left behind. Two ways to get here with something running:
#   - after a good install: the gpg-agent flatpak's Flathub key import starts
#     (through ostree) held /mnt/dev on the J-2 VM run, so xchroot's umount
#     and its exit status failed;
#   - after Ctrl-C: `su -c` runs install-void.sh in its own session, so the
#     terminal's SIGINT never reaches it. su TERMs install-void.sh alone,
#     which orphans the stage it was waiting on (J-4: the package stage ran
#     on with the sudo rule already gone).
# TERM first, so each script's stop_on_interrupt trap ends it; then KILL,
# scanning again each round, since a loop can start its next child between
# a scan and the kill.
live_dots_release() {
    local m round pids=()
    [[ $DRY_RUN -eq 1 ]] && return 0
    for round in 1 2 3 4 5; do
        mapfile -t pids < <(live_dots_rooted)
        [[ ${#pids[@]} -gt 0 ]] || break
        if [[ $round -eq 1 ]]; then
            yellow "note    stopping ${#pids[@]} process(es) still running in $LIVE_TARGET"
            kill "${pids[@]}" 2>/dev/null || true
            sleep 2
        else
            kill -9 "${pids[@]}" 2>/dev/null || true
            sleep 0.5
        fi
    done
    mapfile -t pids < <(live_dots_rooted)
    [[ ${#pids[@]} -eq 0 ]] || yellow "note    ${#pids[@]} process(es) in $LIVE_TARGET would not stop"
    for m in etc/resolv.conf sys proc dev; do
        if findmnt -rn --mountpoint "$LIVE_TARGET/$m" >/dev/null; then
            umount -R "$LIVE_TARGET/$m" || yellow "note    $LIVE_TARGET/$m is still mounted"
        fi
    done
}

# live_dots_cleanup — install-live.sh's EXIT trap for this stage: stop what
# runs in the target BEFORE the rule goes, so nothing carries on without it.
live_dots_cleanup() {
    live_dots_release || true
    live_dots_revoke
}

# live_dots_install — clone, grant, install as the user, revoke. `su -`
# gives install-void.sh a login environment: USER and HOME are the new
# user's, never root's (install-services.sh reads $USER for the login shell
# and the groups). The user name passed live_valid_username, so it is safe
# inside the sh -c string.
live_dots_install() {
    blue "==> dots (install-void.sh as $LIVE_USERNAME, inside $LIVE_TARGET)"
    live_dots_clone
    live_dots_grant
    live_run rm -f "$LIVE_TARGET$LIVE_DOTS_MARK"
    live_in_target sh -c "su - $LIVE_USERNAME -c 'cd ~/dots && ./scripts/install-void.sh' && : >$LIVE_DOTS_MARK" || true
    live_dots_release
    live_dots_revoke
    if [[ -e $LIVE_TARGET$LIVE_DOTS_SUDOERS ]]; then
        red "The temporary sudo rule is still in $LIVE_TARGET$LIVE_DOTS_SUDOERS. Delete it before booting."
        return 1
    fi
    if [[ $DRY_RUN -eq 0 && ! -e $LIVE_TARGET$LIVE_DOTS_MARK ]]; then
        red "install-void.sh failed inside $LIVE_TARGET (its log: ~$LIVE_USERNAME/dots/install.log there)."
        red "Re-run install-live.sh with the same answers: every step converges."
        return 1
    fi
    live_run rm -f "$LIVE_TARGET$LIVE_DOTS_MARK"
    live_ok "dots installed; the temporary sudo rule is removed"
}

# live_dots_finish — unmount the target (and close the root's mapping when
# this run encrypted it), then reboot when --reboot was given
# or the user says yes. Without either, say what is left to do.
live_dots_finish() {
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run: umount -R $LIVE_TARGET"
        [[ $LIVE_LUKS -eq 0 ]] || blue "  (dry-run) would run: cryptsetup close luks-<UUID>"
        [[ $LIVE_REBOOT -eq 1 ]] && blue "  (dry-run) would run: reboot"
        return 0
    fi
    sync
    if umount -R "$LIVE_TARGET"; then
        green "ok      $LIVE_TARGET unmounted"
        if [[ $LIVE_LUKS -eq 1 ]]; then
            live_luks_close_all
        fi
    else
        yellow "note    $LIVE_TARGET is still busy; a reboot unmounts it"
    fi
    if [[ $LIVE_REBOOT -eq 1 ]] \
        || { [[ $LIVE_INTERACTIVE -eq 1 ]] && dialog --title "Done" --yesno "Void and dots are installed. Reboot now?" 7 50; }; then
        # runit's reboot only signals init and returns: say nothing after it.
        reboot
        return 0
    fi
    [[ $LIVE_INTERACTIVE -eq 1 ]] && clear
    blue "Next: remove the live medium and reboot into the ly login screen."
}
