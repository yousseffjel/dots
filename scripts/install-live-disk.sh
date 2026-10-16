#!/usr/bin/env bash
# The live-ISO installer's disk choice (scope J, J-3): list the disks it
# may erase, let the user pick one, and make them type its name before
# anything is written. An answers file names the disk twice instead (DISK=
# and WIPE=), so a copied file cannot erase some other disk by accident.
#
# Sourced by install-live.sh, never standalone. It assumes `set -euo
# pipefail`, the red/green/yellow/blue helpers, LIVE_TARGET,
# LIVE_INTERACTIVE, live_disk_of (install-live-base.sh) and the answers
# LIVE_DISK_ANSWER and LIVE_WIPE_ANSWER (install-live-answers.sh).
#
# usage: source "$SCRIPT_DIR/install-live-disk.sh"
#
# Sets LIVE_DISK (e.g. /dev/vda) and LIVE_DISK_BYTES.
#
# A disk is refused when it is read-only, a zram device, smaller than
# LIVE_MIN_DISK_BYTES, holds the live medium (its label anywhere on it), or
# has anything mounted outside the target, swap included. A mount inside
# the target is an earlier run of this installer, which
# install-live-part.sh takes down or resumes. LIVE_CMDLINE is read at call
# time, as in install-live-base.sh.

LIVE_MIN_DISK_BYTES=$((12 * 1024 * 1024 * 1024))
LIVE_DISK_BYTES=0

# live_disk_list — every whole, writable disk, as "NAME BYTES" lines.
live_disk_list() {
    local out
    out="$(lsblk -dnrpbo NAME,TYPE,SIZE,RO)" || return 1
    awk '$2 == "disk" && $4 == 0 && $1 !~ /^\/dev\/zram/ { print $1, $3 }' <<<"$out"
}

# The ISO boots with root=live:CDLABEL=VOID_LIVE (void-mklive), and that
# label is on whichever disk the ISO was written to.
live_medium_label() {
    local cmd
    cmd="$(cat "${LIVE_CMDLINE:-/proc/cmdline}" 2>/dev/null || true)"
    if [[ $cmd =~ root=live:(CD)?LABEL=([^[:space:]]+) ]]; then
        echo "${BASH_REMATCH[2]}"
    else
        echo VOID_LIVE
    fi
}

# live_disk_check <disk> — returns 0 when the disk may be erased; otherwise
# prints why on stdout and returns 1. Reads only.
live_disk_check() {
    local disk="$1" bytes labels mounts mnt
    bytes="$(live_disk_list | awk -v d="$disk" '$1 == d { print $2 }')"
    if [[ -z $bytes ]]; then
        echo "$disk is not a writable whole disk"
        return 1
    elif [[ $bytes -lt $LIVE_MIN_DISK_BYTES ]]; then
        echo "$disk is $(numfmt --to=iec "$bytes"), under the $(numfmt --to=iec "$LIVE_MIN_DISK_BYTES") minimum"
        return 1
    fi
    labels="$(lsblk -nrpo LABEL "$disk")"
    if grep -qxF "$(live_medium_label)" <<<"$labels"; then
        echo "$disk holds the live medium"
        return 1
    fi
    mounts="$(lsblk -nrpo MOUNTPOINT "$disk")"
    while IFS= read -r mnt; do
        # lsblk -r writes a space as \x20.
        mnt="$(printf '%b' "$mnt")"
        [[ -z $mnt || $mnt == "$LIVE_TARGET" || $mnt == "$LIVE_TARGET"/* ]] && continue
        echo "$disk is in use at $mnt"
        return 1
    done <<<"$mounts"
}

# live_disk_menu — a dialog menu of the disks that may be erased; prints
# the choice. Returns 2 when there is none (the reasons go to stderr), 1
# on Cancel.
live_disk_menu() {
    local d bytes why model items=() refused="" text=""
    while read -r d bytes; do
        if why="$(live_disk_check "$d")"; then
            read -r model < <(lsblk -dno MODEL "$d") || model=""
            items+=("$d" "$(numfmt --to=iec "$bytes")  $model")
        else
            refused+="$why"$'\n'
        fi
    done < <(live_disk_list)
    if [[ ${#items[@]} -eq 0 ]]; then
        red "No disk can be erased:" >&2
        printf '%s' "$refused" | sed 's/^/  /' >&2
        return 2
    fi
    [[ -n $refused ]] && text="Not offered:"$'\n'"$refused"$'\n'
    dialog --stdout --title "Disk to erase" --menu \
        "${text}Install Void on which disk? Everything on it is erased." 18 72 8 "${items[@]}"
}

# live_disk_confirm <disk> — asks until the disk's name is typed exactly.
# Returns 1 on Cancel.
live_disk_confirm() {
    local disk="$1" reply error=""
    while true; do
        reply="$(dialog --stdout --title "Erase $disk?" --inputbox \
            "${error}Everything on $disk is erased. Type $disk to confirm:" 10 64)" || return 1
        [[ $reply == "$disk" ]] && return 0
        error="'$reply' is not $disk."$'\n\n'
    done
}

# live_disk_pick — the interactive path: menu, then the typed name. A
# Cancel clears the screen and says nothing was written.
live_disk_pick() {
    local disk menu_rc=0
    disk="$(live_disk_menu)" || menu_rc=$?
    if [[ $menu_rc -eq 0 ]] && live_disk_confirm "$disk"; then
        printf '%s\n' "$disk"
        return 0
    fi
    if [[ $menu_rc -ne 2 ]]; then
        clear >&2
        yellow "Cancelled. Nothing was written." >&2
    fi
    return 1
}

# live_disk_choose — set LIVE_DISK: from the menu and the typed name, or
# from DISK= and WIPE= in the answers file. Either way the disk is checked
# here, and a target already mounted from some other disk is refused.
live_disk_choose() {
    local disk why other
    if [[ $LIVE_INTERACTIVE -eq 1 ]]; then
        disk="$(live_disk_pick)" || return 1
    elif [[ -z $LIVE_DISK_ANSWER ]]; then
        red "answers file: missing DISK, the disk to erase (or pass --target to use a mounted root)"
        return 1
    elif [[ $LIVE_WIPE_ANSWER != "$LIVE_DISK_ANSWER" ]]; then
        red "answers file: WIPE must repeat DISK ($LIVE_DISK_ANSWER) before it is erased"
        return 1
    else
        disk="$(readlink -f -- "$LIVE_DISK_ANSWER" || true)"
    fi
    if ! why="$(live_disk_check "$disk")"; then
        red "$why"
        return 1
    fi
    other="$(live_disk_of "$LIVE_TARGET" 2>/dev/null || true)"
    if [[ -n $other && $other != "$disk" ]]; then
        red "$LIVE_TARGET is mounted from $other. Unmount it, or pass --target $LIVE_TARGET to install there."
        return 1
    fi
    # Read by install-live-part.sh and install-live-config.sh (GRUB on BIOS).
    # shellcheck disable=SC2034
    LIVE_DISK="$disk"
    LIVE_DISK_BYTES="$(live_disk_list | awk -v d="$disk" '$1 == d { print $2 }')"
    green "ok      $disk chosen to be erased ($(numfmt --to=iec "$LIVE_DISK_BYTES"))"
}

# live_disk_answers_unused — --target installs onto what is mounted, so an
# answers file that names a disk to erase is a mistake, refused.
live_disk_answers_unused() {
    if [[ -n $LIVE_DISK_ANSWER || -n $LIVE_WIPE_ANSWER ]]; then
        red "answers file: DISK/WIPE erase a disk, but --target installs onto $LIVE_TARGET as mounted. Drop one."
        return 1
    fi
}
