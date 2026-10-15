#!/usr/bin/env bash
# Tiered package installation — the machinery install-pkg.sh drives.
#
# Sourced by install-pkg.sh (and doctor-checks.sh, for the list helpers),
# never standalone: every function here assumes the caller has already
# `set -euo pipefail` and defined DRY_RUN, PACKAGES_DIR, SUDO and the
# red/green/yellow/blue helpers.
#
# usage: source "$SCRIPT_DIR/install-pkg-tiers.sh"
#
# The tiers themselves (which list means what) are documented in
# install-pkg.sh's header and in each packages/*.lst file.
#
# xbps behaviour this file is built on, probed with xbps-static 0.60.7 against
# the live repos on 2026-10-15 (a scratch root via -r; tests/pkg-tiers.sh's
# fakes reproduce exactly these exit codes and messages):
#   * `xbps-install -y a b` with ONE unknown name installs nothing:
#     "ERROR: Package 'b' not found in repository pool.", exit 2. There is no
#     --skip-unavailable, so names are filtered with `xbps-query -R` first.
#   * `xbps-query -R <name>` reads the synced local index, needs no root, and
#     exits 0 for a package, 2 for an unknown name. Case matters (`Thunar`).
#   * `xbps-query <name>` exits 0 when installed, 2 when not.

# Strips '#' comments (whole-line or trailing) and blank lines from a .lst file.
read_pkg_list() {
    sed 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^$'
}

# pkg_list_chassis <lst> — the chassis a list is limited to (its
# `# chassis: <kind>` header line, e.g. laptop), or nothing for a list that
# applies everywhere. Generic on purpose: a consumer that globs
# packages/*.lst asks the list, never names it (CLAUDE.md rule 10).
pkg_list_chassis() {
    sed -n 's/^# chassis: *\([a-z]*\).*/\1/p;T;q' "$1"
}

# pkg_installed <name> / pkg_available <name> — the two questions every
# consumer asks xbps (doctor-checks.sh uses the first too).
pkg_installed() { xbps-query "$1" >/dev/null 2>&1; }
pkg_available() { xbps-query -R "$1" >/dev/null 2>&1; }
# pkg_index_synced — is there a local repo index to ask at all? xbps itself
# is in every Void index, so its absence means "never synced", not "missing".
pkg_index_synced() { pkg_available xbps; }

# Packages that failed, collected for the closing summary. Two arrays so the
# report can lead with the ones that break the desktop.
FAILED_DESKTOP=()
FAILED_EXTRA=()

# Why the most recent package failed, so the report can say what went wrong.
PKG_ERR=""

# package -> consequence text, read from the trailing '#' comment on each
# desktop.lst line. Keeping the note on the same line the name is read from
# means the two cannot drift apart; tests/desktop-consequences.sh fails the
# build if an entry is missing one.
declare -A CONSEQUENCE=()
load_consequences() {
    local line
    while IFS= read -r line; do
        [[ "$line" =~ ^([A-Za-z0-9][A-Za-z0-9._+-]*)[[:space:]]+#[[:space:]]*(.*)$ ]] || continue
        CONSEQUENCE["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    done <"$PACKAGES_DIR/desktop.lst"
}

# pkg_install_one <pkg> — one package, its own transaction. Used only after a
# batch failed, so each package can succeed or fail on its own.
pkg_install_one() {
    PKG_ERR=""
    # stderr kept, not discarded: a network drop, a signature error and a
    # conflict must not all read as "not found".
    PKG_ERR="$("${SUDO[@]}" xbps-install -y "$1" 2>&1 >/dev/null </dev/null)" || return 1
}

# pkg_run_streamed <cmd>... — runs a privileged xbps command with its output
# shown as it comes (a silent ten-minute download looks hung), indented, and
# kept in PKG_LOG. Returns the command's own status.
#
# </dev/null matters: with stdin on the terminal, sudo (use_pty) puts that
# terminal in raw mode while the command runs, and the indented lines this
# pipeline writes lose their carriage returns (seen with dnf on the Fedora 44
# VM, 2026-10-14; the mechanism is sudo's, not the package manager's). sudo
# still prompts for a password: it reads /dev/tty, not stdin.
PKG_LOG=""
pkg_run_streamed() {
    local rcf rc
    PKG_LOG="$(mktemp)"
    rcf="$(mktemp)"
    # The status goes through a file: in a pipeline the command runs in a
    # subshell, and under pipefail its failure would abort the caller.
    {
        rc=0
        "${SUDO[@]}" "$@" 2>&1 </dev/null || rc=$?
        echo "$rc" >"$rcf"
    } | tee "$PKG_LOG" | sed -u 's/^/    /'
    rc="$(<"$rcf")"
    rm -f "$rcf"
    return "${rc:-1}"
}

# xbps's own line about <pkg> from the batch log, else its last line.
pkg_batch_reason() {
    local line
    line="$(grep -F -- "$1" "$PKG_LOG" 2>/dev/null | tail -n1 || true)"
    [[ -n "$line" ]] || line="$(tail -n1 "$PKG_LOG" 2>/dev/null || true)"
    printf '%s' "$line"
}

# One loop for every tier; `mode` decides what a failure costs.
install_tier() {
    local label="$1" list="$2" mode="$3" pkg have=0 batch=0 unsynced=0
    local -a pending=() missing=()
    if [[ ! -f "$list" ]]; then
        red "missing package list: $list"
        exit 1
    fi
    blue "==> $label"
    # A dry run skips xbps_prepare's sync (it writes as root), so on a box
    # never synced every name would read as unknown and the core tier would
    # abort. Say so once and list them as would-install, unchecked. A real
    # run has just synced; there an unknown name is a real failure.
    if [[ $DRY_RUN -eq 1 ]] && ! pkg_index_synced; then
        unsynced=1
        yellow "  note: no synced repo index (dry run skips the sync) — availability unchecked"
    fi
    while IFS= read -r pkg; do
        if pkg_installed "$pkg"; then
            have=$((have + 1))
        elif ((unsynced)) || pkg_available "$pkg"; then
            pending+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done < <(read_pkg_list "$list")
    ((have == 0)) || green "  ok      $have already installed"
    # Reported before the transaction: one unknown name would abort it.
    for pkg in "${missing[@]}"; do
        PKG_ERR="not in the repository index (xbps-query -R $pkg)"
        tier_fail "$pkg" "$mode"
    done
    ((${#pending[@]} > 0)) || return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        for pkg in "${pending[@]}"; do blue "  (dry-run) would install: $pkg"; done
        return 0
    fi
    blue "  installing ${#pending[@]} package(s) in one xbps transaction"
    pkg_run_streamed xbps-install -y "${pending[@]}" || batch=$?
    ((batch == 0)) || yellow "  the transaction failed (xbps exit $batch) — retrying one package at a time"
    for pkg in "${pending[@]}"; do
        tier_settle "$pkg" "$mode" "$batch"
    done
    rm -f "$PKG_LOG"
}

# tier_settle <pkg> <mode> <batch status> — report one package after the
# batch: installed (with its PACKAGE row), or a failure. After a failed
# transaction nothing in it was installed, so each package gets its own run,
# which also names the one that broke it.
tier_settle() {
    local pkg="$1" mode="$2" batch="$3"
    PKG_ERR=""
    if pkg_installed "$pkg" || { ((batch != 0)) && pkg_install_one "$pkg"; }; then
        green "  installed: $pkg"
        manifest_append_row PACKAGE "$pkg"
        return 0
    fi
    ((batch != 0)) || PKG_ERR="$(pkg_batch_reason "$pkg")"
    tier_fail "$pkg" "$mode"
}

# tier_fail <pkg> <mode> — what a failure costs in this tier. Reads PKG_ERR.
tier_fail() {
    local pkg="$1" mode="$2"
    [[ -n "$PKG_ERR" ]] && yellow "    xbps: $(printf '%s' "$PKG_ERR" | tail -n1)"
    case "$mode" in
        hard)
            red "required package failed to install: $pkg"
            exit 1
            ;;
        desktop)
            yellow "  FAILED: $pkg — ${CONSEQUENCE[$pkg]:-consequence not recorded in desktop.lst}"
            FAILED_DESKTOP+=("$pkg")
            ;;
        *)
            yellow "  skipped: $pkg"
            FAILED_EXTRA+=("$pkg")
            ;;
    esac
}

# Closing report. ~100 packages each print a green line, so a lone yellow
# "skipped" three screens up is invisible — that is exactly how picom stayed
# unlaunched for two months. Everything that failed is repeated here.
install_summary() {
    local pkg
    if [[ ${#FAILED_DESKTOP[@]} -eq 0 && ${#FAILED_EXTRA[@]} -eq 0 ]]; then
        green "✓ every package installed"
        return 0
    fi
    echo
    if [[ ${#FAILED_DESKTOP[@]} -gt 0 ]]; then
        red "==> ${#FAILED_DESKTOP[@]} DESKTOP-CRITICAL package(s) did not install:"
        for pkg in "${FAILED_DESKTOP[@]}"; do
            red "  $pkg"
            red "      ${CONSEQUENCE[$pkg]:-consequence not recorded in desktop.lst}"
        done
        red "  Install these by hand before relying on the desktop."
    fi
    if [[ ${#FAILED_EXTRA[@]} -gt 0 ]]; then
        yellow "==> ${#FAILED_EXTRA[@]} optional package(s) skipped:"
        yellow "  ${FAILED_EXTRA[*]}"
        yellow "  Each costs you that program alone — nothing else changes."
    fi
}
