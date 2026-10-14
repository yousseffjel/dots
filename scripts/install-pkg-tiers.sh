#!/usr/bin/env bash
# Tiered package installation — the machinery install-pkg.sh drives.
#
# Sourced by install-pkg.sh only, never standalone: every function here
# assumes the caller has already `set -euo pipefail` and defined DRY_RUN,
# PACKAGES_DIR, SUDO and the red/green/yellow/blue helpers. Same split
# install-restore.sh makes with install-restore-theme.sh — the tier logic
# and the stage's own orchestration are separate concerns, and keeping both
# in one file put it over the repo's 250-line cap.
#
# usage: source "$SCRIPT_DIR/install-pkg-tiers.sh"
#
# The tiers themselves (which list means what) are documented in
# install-pkg.sh's header and in each packages/*.lst file.

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

# Packages that failed, collected for the closing summary. Two arrays so the
# report can lead with the ones that break the desktop.
FAILED_DESKTOP=()
FAILED_EXTRA=()

# stderr from the most recent dnf_install, so a failure can say what actually
# went wrong.
DNF_ERR=""

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

# package -> a package that stands in for it. RPM Fusion's ffmpeg replaces
# Fedora's ffmpeg-free (install-pkg-repos.sh swaps them) and conflicts with it,
# so without this every re-run would try to reinstall ffmpeg-free and report
# a false red failure.
declare -A SATISFIED_BY=(["ffmpeg-free"]=ffmpeg)

dnf_install() {
    local pkg="$1"
    DNF_ERR=""
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would install: $pkg"
        return 0
    fi
    # Keep stderr rather than discarding it. The old code sent everything to
    # /dev/null and then reported every failure as "not found in enabled
    # repos" — the same message for a rename, a network drop, a GPG error and
    # a transaction conflict.
    DNF_ERR="$("${SUDO[@]}" dnf install -y "$pkg" 2>&1 >/dev/null)" || return 1
    return 0
}

# dnf_install_batch <pkg>... — ONE dnf transaction for a whole tier. A run per
# package (the old way) cost ~130 dnf processes on a fresh install, each
# loading repo metadata, and serialised every download. --skip-unavailable
# lets one renamed package skip instead of failing the transaction;
# install_tier then asks rpm what actually landed. stderr — dnf's progress
# and its errors — is shown as it comes (a silent ten-minute download looks
# hung) and kept in DNF_BATCH_LOG for the per-package reasons. Returns dnf's
# status: non-zero means the transaction itself failed (a conflict, the
# network), and install_tier falls back to one package at a time.
#
# </dev/null matters: with stdin on the terminal, sudo (use_pty) puts that
# terminal in raw mode while dnf runs, and the indented lines this pipeline
# writes to it lose their carriage returns — every line started where the
# last one ended (Fedora 44 VM, 2026-10-14). sudo still prompts for a
# password: it reads /dev/tty, not stdin.
DNF_BATCH_LOG=""
dnf_install_batch() {
    local rcf rc
    DNF_BATCH_LOG="$(mktemp)"
    rcf="$(mktemp)"
    # The status goes through a file: in a pipeline dnf runs in a subshell,
    # and under pipefail its failure would abort the caller. `|| rc=$?`
    # rather than `$?` on the next line: install_tier's `||` suppresses set -e
    # here today, but a bare call would let set -e end the subshell first.
    {
        rc=0
        "${SUDO[@]}" dnf install -y --skip-unavailable "$@" 2>&1 >/dev/null </dev/null || rc=$?
        echo "$rc" >"$rcf"
    } \
        | tee "$DNF_BATCH_LOG" | sed -u 's/^/    /'
    rc="$(<"$rcf")"
    rc="${rc:-1}"
    rm -f "$rcf"
    return "$rc"
}

# dnf's own line about <pkg> from the batch log ("No match for argument:
# <pkg>"), else its last line.
dnf_batch_reason() {
    local line
    line="$(grep -F -- "$1" "$DNF_BATCH_LOG" 2>/dev/null | tail -n1 || true)"
    [[ -n "$line" ]] || line="$(tail -n1 "$DNF_BATCH_LOG" 2>/dev/null || true)"
    printf '%s' "$line"
}

# One loop for all three tiers; `mode` decides what a failure costs.
install_tier() {
    local label="$1" list="$2" mode="$3" pkg have=0 batch=0
    local -a pending=()
    if [[ ! -f "$list" ]]; then
        red "missing package list: $list"
        exit 1
    fi
    blue "==> $label"
    while IFS= read -r pkg; do
        if [[ -n "${SATISFIED_BY[$pkg]:-}" ]] && rpm -q "${SATISFIED_BY[$pkg]}" >/dev/null 2>&1; then
            green "  ok: $pkg (${SATISFIED_BY[$pkg]} installed in its place)"
            continue
        fi
        # Already there: no dnf at all. `dnf install` never upgrades an
        # installed package, so skipping it changes nothing but the output,
        # which used to say "installed:" for every package on every re-run.
        # --whatprovides, as doctor's check_packages asks: `thunar` is a
        # Provides of Fedora's `Thunar`, so a name-only `rpm -q` called it
        # missing on every run and, where Thunar came preinstalled, wrote a
        # PACKAGE row that would have had `dots uninstall` remove a file
        # manager dots never installed.
        if rpm -q --whatprovides "$pkg" >/dev/null 2>&1; then
            have=$((have + 1))
            continue
        fi
        pending+=("$pkg")
    done < <(read_pkg_list "$list")
    ((have == 0)) || green "  ok      $have already installed"
    ((${#pending[@]} > 0)) || return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        for pkg in "${pending[@]}"; do blue "  (dry-run) would install: $pkg"; done
        return 0
    fi
    blue "  installing ${#pending[@]} package(s) in one dnf transaction"
    dnf_install_batch "${pending[@]}" || batch=$?
    ((batch == 0)) || yellow "  the transaction failed (dnf exit $batch) — retrying one package at a time"
    for pkg in "${pending[@]}"; do
        tier_settle "$pkg" "$mode" "$batch"
    done
    rm -f "$DNF_BATCH_LOG"
}

# tier_settle <pkg> <mode> <batch status> — report one package after the
# batch: installed (with its PACKAGE row), or a failure whose cost is the
# tier's. After a failed transaction nothing in it was installed, so each
# package gets its own dnf run — which also names the one that broke it.
tier_settle() {
    local pkg="$1" mode="$2" batch="$3"
    if rpm -q --whatprovides "$pkg" >/dev/null 2>&1 \
        || { ((batch != 0)) && dnf_install "$pkg"; }; then
        green "  installed: $pkg"
        manifest_append_row PACKAGE "$pkg"
        return 0
    fi
    ((batch != 0)) || DNF_ERR="$(dnf_batch_reason "$pkg")"
    [[ -n "$DNF_ERR" ]] && yellow "    dnf: $(printf '%s' "$DNF_ERR" | tail -n1)"
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
