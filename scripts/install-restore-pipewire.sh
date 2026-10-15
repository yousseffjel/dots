#!/usr/bin/env bash
# PipeWire's per-user session config: the two links the Void handbook gives,
# so that `pipewire` (started by ~/.xinitrc) launches WirePlumber and its
# PulseAudio server itself. Sourced by install-restore.sh, never standalone:
# assumes `set -euo pipefail`, DRY_RUN, global_fn.sh (manifest_*) and the
# colour helpers.
#
# usage: source "$SCRIPT_DIR/install-restore-pipewire.sh"; restore_pipewire
#
#   ~/.config/pipewire/pipewire.conf.d/10-wireplumber.conf
#       -> /usr/share/examples/wireplumber/10-wireplumber.conf
#   ~/.config/pipewire/pipewire.conf.d/20-pipewire-pulse.conf
#       -> /usr/share/examples/pipewire/20-pipewire-pulse.conf
#
# Both targets ship in Void's packages (wireplumber-0.5.18_1, pipewire-1.6.9_1,
# read 2026-10-15); each holds one `context.exec` line that has pipewire
# start the program once it is ready. Per user, not in /etc: no sudo, and the
# links live with the rest of this user's config.
#
# A link is made only when its target exists (the package is installed) and
# nothing is at its path yet, and is recorded as `LINK pipewire <path>
# <target>`. uninstall-pipewire.sh removes it only while it still points there.
# DOTS_EXAMPLES_DIR overrides /usr/share/examples (tests), read at call time.

PIPEWIRE_LINKS=(wireplumber/10-wireplumber.conf pipewire/20-pipewire-pulse.conf)

restore_pipewire() {
    local examples="${DOTS_EXAMPLES_DIR:-/usr/share/examples}" rel target dir path
    dir="${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/pipewire.conf.d"
    blue "==> PipeWire session config"
    for rel in "${PIPEWIRE_LINKS[@]}"; do
        target="$examples/$rel"
        path="$dir/${rel##*/}"
        if [[ ! -e "$target" ]]; then
            yellow "skip    $target missing — is ${rel%%/*} installed? No sound until it is"
        elif [[ -L "$path" && "$(readlink "$path")" == "$target" ]]; then
            green "ok      ${path/#$HOME/\~} already links $target"
        elif [[ -e "$path" || -L "$path" ]]; then
            green "ok      ${path/#$HOME/\~} exists (left untouched, not tracked for removal)"
        elif [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would link ${path/#$HOME/\~} -> $target"
        else
            mkdir -p "$dir"
            ln -s "$target" "$path"
            manifest_append_row LINK pipewire "$path" "$target"
            green "linked  ${path/#$HOME/\~} -> $target"
        fi
    done
}
