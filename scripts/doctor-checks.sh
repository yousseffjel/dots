#!/usr/bin/env bash
# The install and package checks of scripts/doctor.sh — SOURCED by it, never
# run alone. Assumes doctor.sh's report(), DOTS_DIR and `set -euo pipefail`.
# The session, theme and hardware checks are in doctor-session.sh (split at
# the 250-line cap).

# shellcheck source=global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"
# The installer's own list parser and consequence table, so a package's
# "what breaks without it" text is the one desktop.lst carries. Sourced at the
# top level on purpose: it declares CONSEQUENCE, which a source from inside a
# function would make local to that function.
PACKAGES_DIR="$DOTS_DIR/packages"
# Test override (tests/doctor.sh), like DWM_NET_SYSFS in dwm-net.
FEDORA_RELEASE="${DOTS_DOCTOR_RELEASE:-/etc/fedora-release}"
# shellcheck source=install-pkg-tiers.sh
source "$DOTS_DIR/scripts/install-pkg-tiers.sh"

check_install() {
    local s=install repo inst
    repo="$(tr -d '[:space:]' <"$DOTS_DIR/VERSION" 2>/dev/null || echo unknown)"
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        report fail "$s" manifest "no install manifest ($MANIFEST_FILE) — run scripts/install-fedora.sh as this user"
    else
        inst="$(manifest_get_meta version)"
        if [[ "$inst" == "$repo" ]]; then
            report ok "$s" manifest "installed version $inst matches the repo"
        else
            report warn "$s" manifest "installed version ${inst:-unknown}, repo is $repo — re-run scripts/install-fedora.sh"
        fi
    fi

    if [[ "$(readlink -f "$HOME/.local/bin/dots" 2>/dev/null || true)" == "$DOTS_DIR/scripts/dots" ]]; then
        report ok "$s" dots-command "the dots command (~/.local/bin/dots) points at this repo"
    else
        report warn "$s" dots-command "the dots command (~/.local/bin/dots) is not this repo's — scripts/install-fedora.sh --only-restore"
    fi

    local src dst name links
    if ! links="$(bash "$DOTS_DIR/scripts/symlinks.sh" --list-links 2>&1)"; then
        report warn "$s" links "could not list the linked configs: $links"
        links=""
    fi
    while IFS=$'\t' read -r src dst; do
        [[ -n "$dst" ]] || continue
        name="${dst#"$HOME"/}"
        if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
            report ok "$s" "link-${dst##*/}" "$name is linked to the repo"
        else
            report warn "$s" "link-${dst##*/}" "$name is not linked to the repo — scripts/symlinks.sh"
        fi
    done <<<"$links"

    local shell
    shell="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7 || true)"
    if [[ "${shell##*/}" == zsh ]]; then
        report ok "$s" login-shell "login shell is $shell"
    else
        report warn "$s" login-shell "login shell is ${shell:-unknown}, not zsh — scripts/install-fedora.sh --only-services"
    fi
    check_services
}

# The services the installer enabled, read from its manifest rather than
# named here. A SERVICE row is SERVICE<TAB>unit (install-services.sh), read
# the way uninstall_services reads it.
check_services() {
    local unit state
    command -v systemctl >/dev/null 2>&1 || return 0
    while IFS= read -r unit; do
        [[ -n "$unit" ]] || continue
        state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
        if [[ "$state" == enabled ]]; then
            report ok install "service-$unit" "$unit is enabled"
        else
            report fail install "service-$unit" "$unit is ${state:-unknown}, not enabled — the login screen will not start; scripts/install-fedora.sh --only-services"
        fi
    done < <(manifest_rows SERVICE | cut -f2 | sort -u)
}

# Every packages/*.lst, by glob. A missing package in a tier whose absence is
# silent breakage (desktop.lst, or core.lst) is a failure and carries its
# consequence text; any other tier — including one added later — is a warning.
check_packages() {
    local s=packages lst tier pkgs missing p
    # An rpm binary alone proves nothing: Arch ships one, over an empty
    # database, and every package would read as missing.
    if [[ ! -f "$FEDORA_RELEASE" ]] || ! command -v rpm >/dev/null 2>&1; then
        report skip "$s" rpm "not Fedora — the package checks need its rpm database"
        return 0
    fi
    load_consequences
    for lst in "$PACKAGES_DIR"/*.lst; do
        tier="$(basename "$lst" .lst)"
        mapfile -t pkgs < <(read_pkg_list "$lst")
        [[ ${#pkgs[@]} -gt 0 ]] || continue
        # --whatprovides also answers for a name that is a Provides rather
        # than a package name. rpm exits non-zero whenever one is missing.
        mapfile -t missing < <(rpm -q --whatprovides "${pkgs[@]}" 2>&1 \
            | sed -n 's/^no package provides \(.*\)$/\1/p; s/^package \(.*\) is not installed$/\1/p' || true)
        if [[ ${#missing[@]} -eq 0 ]]; then
            report ok "$s" "tier-$tier" "$tier.lst: all ${#pkgs[@]} installed"
        elif [[ "$tier" == desktop || "$tier" == core ]]; then
            for p in "${missing[@]}"; do
                report fail "$s" "pkg-$p" "$p is not installed — ${CONSEQUENCE[$p]:-$tier.lst says it is required}"
            done
        else
            report warn "$s" "tier-$tier" "$tier.lst: ${#missing[@]} not installed: ${missing[*]}"
        fi
    done
}
