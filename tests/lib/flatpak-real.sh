#!/usr/bin/env bash
# The real-binary half of tests/flatpak-integration.sh — SOURCED, never run on
# its own. Reads the caller's SB, DOTS_DIR, ALL and ok/bad/yellow/blue.
#
# The fake in fake-flatpak.sh encodes what flatpak 1.18 writes; this runs the
# same install -> uninstall round trip against the REAL binary, so a flatpak
# release that changes the keyfile layout fails here rather than silently
# leaving grants behind on users' machines. Skipped (yellow, not a failure)
# where no flatpak is installed, which includes the CI runner.
#
# Safe on a dev box: every run gets a fresh HOME under $SB with all four XDG
# variables pointed into it (a `--user` flatpak call writes under
# $XDG_DATA_HOME/flatpak and nowhere else), and FLATHUB_URL is replaced by a
# local path — remote-add records a non-.flatpakrepo URL without fetching it,
# so nothing touches the network. The URL constant itself is covered by the
# fake cases, which do not replace it.
real_flatpak_round_trip() {
    local real
    real="$(type -P flatpak || true)"
    blue "==> real flatpak"
    if [[ -z "$real" ]]; then
        yellow "  skip: no flatpak installed — the fake's format is unchecked on this host"
        return 0
    fi
    local seed home g
    for seed in "" "--env=FOO=bar --nofilesystem=home"; do
        home="$(mktemp -d "$SB/real.XXXXXX")"
        g="$home/.local/share/flatpak/overrides/global"
        if [[ -n "$seed" ]]; then
            # shellcheck disable=SC2086 # seed is a list of flatpak options
            real_env "$home" "$real" override --user $seed
            cp "$g" "$home/before"
        fi
        # shellcheck disable=SC2016 # the -c script expands in the sandbox shell
        real_env "$home" bash -c '
            set -euo pipefail
            ASSUME_YES=1
            red() { :; }; green() { :; }; yellow() { :; }; blue() { :; }
            source "$0/scripts/global_fn.sh"
            source "$0/scripts/install-restore-flatpak.sh"
            source "$0/scripts/uninstall-flatpak.sh"
            FLATHUB_URL="file://$HOME/no-repo"
            restore_flatpak
            sed -n "s/^filesystems=//p" "$(flatpak_override_file)" | tr ";" "\n" | sed "/^\$/d" | sort | tr "\n" " " >"$HOME/installed"
            uninstall_flatpak
            flatpak remotes --user --columns=name >"$HOME/remotes"
        ' "$DOTS_DIR" >"$home/out" 2>&1 || echo "EXIT $?" >>"$home/out"
        real_check "$home" "$g" "${seed:-fresh HOME}"
    done
}

real_env() {
    local home="$1"
    shift
    env -i PATH="$PATH" HOME="$home" XDG_DATA_HOME="$home/.local/share" \
        XDG_CONFIG_HOME="$home/.config" XDG_STATE_HOME="$home/.local/state" \
        XDG_CACHE_HOME="$home/.cache" DRY_RUN=0 "$@"
}

real_check() {
    local home="$1" g="$2" label="$3" want="$ALL"
    [[ ! -f "$home/before" ]] || want="!home $ALL"
    if [[ "$(cat "$home/installed" 2>/dev/null)" != "$want" ]]; then
        bad "real flatpak ($label): installed '$(cat "$home/installed" 2>/dev/null)' / $(cat "$home/out")"
    elif grep -qx flathub "$home/remotes"; then
        bad "real flatpak ($label): the Flathub remote survived uninstall"
    elif [[ -f "$home/before" ]] && ! cmp -s "$home/before" "$g"; then
        bad "real flatpak ($label): override file differs after uninstall: $(cat -A "$g")"
    elif [[ ! -f "$home/before" && -e "$g" ]]; then
        bad "real flatpak ($label): override file left behind"
    else
        ok "real flatpak ($label): grants written, then reverted byte for byte"
    fi
}
