#!/usr/bin/env bash
# sysfile_install — copy one repo file to a root-owned path, with a SYSFILE
# manifest row: `SYSFILE <kind> <installed path> <repo path>`.
# uninstall-sysfiles.sh is the other half.
#
# SOURCED, never run alone: it assumes DRY_RUN, SUDO, DOTS_DIR, global_fn.sh
# (manifest_has_path, manifest_append_row, file_matches_history) and the
# colour helpers. Callers: drivers-laptop.sh (the touchpad snippet) and
# install-services-maint.sh (weekly TRIM, the zram sysctl). The dnf speed
# drop-in was another until the Void port removed it.
#
# The APP rows' contract (install-restore-apps.sh), with sudo: a re-run
# replaces the installed copy only while it is byte-identical to a version
# this repo shipped (file_matches_history), so an edit is never overwritten;
# a file there that we did not write is never claimed; and uninstall removes
# it on the same condition.

# sysfile_install <kind> <repo path> <installed path> <what> <after> <fail> [mode]
#   what   names the file in the "already current" and dry-run lines
#   after  what writing it means, e.g. "applies at your next login"
#   fail   what a failed write costs
#   mode   644 by default; 755 for a script (run-parts runs only executables)
# Returns 1 only on a failed write; the caller decides what that costs.
sysfile_install() {
    local kind="$1" rel="$2" dst="$3" what="$4" after="$5" fail="$6" mode="${7:-644}"
    local src="$DOTS_DIR/$rel"
    if [[ -e "$dst" ]] && cmp -s "$src" "$dst"; then
        green "  ok      $dst ($what) already current"
        return 0
    fi
    if [[ -e "$dst" ]] && ! { manifest_has_path SYSFILE "$dst" && file_matches_history "$dst" "$rel"; }; then
        yellow "  kept    $dst — edited, or not written by dots; compare with $rel"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would install $dst ($what)"
        return 0
    fi
    if "${SUDO[@]}" install -D -m "$mode" "$src" "$dst"; then
        manifest_append_row SYSFILE "$kind" "$dst" "$rel"
        green "  wrote   $dst — $after"
        return 0
    fi
    yellow "  FAILED: could not write $dst — $fail"
    return 1
}
