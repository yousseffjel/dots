#!/usr/bin/env bash
# Reverts install-restore-pipewire.sh: its `LINK pipewire <path> <target>`
# rows. Sourced by uninstall.sh, never standalone: assumes `set -euo
# pipefail`, DRY_RUN, global_fn.sh (confirm, manifest_rows) and the colour
# helpers.
#
# A link is removed only while it is still a symlink to the target it was
# made for; anything the user has put there since is theirs. The two
# directories go only when empty.

uninstall_pipewire() {
    local rows row path target dir
    blue "=== PipeWire session config ==="
    mapfile -t rows < <(manifest_rows LINK | awk -F'\t' '$2=="pipewire"')
    if [[ ${#rows[@]} -eq 0 ]]; then
        blue "  no PipeWire LINK rows in manifest — nothing to remove"
        return 0
    fi
    confirm "Remove the ${#rows[@]} PipeWire config link(s) dots made?" || {
        yellow "  skipped PipeWire config"
        return 0
    }
    for row in "${rows[@]}"; do
        IFS=$'\t' read -r _ _ path target <<<"$row"
        if [[ ! -L "$path" || "$(readlink "$path")" != "$target" ]]; then
            yellow "  kept ${path/#$HOME/\~} — no longer the link dots made"
        elif [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would remove ${path/#$HOME/\~}"
        else
            rm -f "$path" && green "  removed ${path/#$HOME/\~}"
        fi
    done
    [[ $DRY_RUN -eq 1 ]] && return 0
    dir="${XDG_CONFIG_HOME:-$HOME/.config}/pipewire"
    rmdir "$dir/pipewire.conf.d" 2>/dev/null || true
    rmdir "$dir" 2>/dev/null || true
}
