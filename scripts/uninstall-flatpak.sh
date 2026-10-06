#!/usr/bin/env bash
# The "flatpak integration" uninstall step — reverts what
# install-restore-flatpak.sh added: the read-only global overrides and the
# Flathub remote, each only if the installer added it and it is still as the
# installer left it.
#
# Sourced by uninstall.sh only: assumes `set -euo pipefail`, global_fn.sh
# (manifest_rows, flatpak_override_file, flatpak_grants), uninstall.sh's own
# logging-aware red/green/yellow/blue plus confirm() and DRY_RUN.
#
# Left behind on purpose: ~/.local/share/flatpak itself. flatpak creates its
# repo/ and .changed on the first --user command and caches remote summaries
# under repo/tmp; the directory is flatpak's, shared with any app the user has
# installed since, and removing it is not ours to do.

# FLATPAK rows: "override <entry as written>" or "remote flathub <url>".
uninstall_flatpak() {
    blue "=== flatpak integration ==="
    local rows=()
    mapfile -t rows < <(manifest_rows FLATPAK)
    if [[ ${#rows[@]} -eq 0 ]]; then
        blue "  no FLATPAK rows in manifest — nothing to revert"
        return 0
    fi
    if ! confirm "Revert ${#rows[@]} Flatpak setting(s) dots made (Flathub remote, read-only overrides)?"; then
        yellow "  skipped flatpak settings"
        return 0
    fi
    local row kind value
    for row in "${rows[@]}"; do
        kind="$(cut -f2 <<<"$row")"
        value="$(cut -f3 <<<"$row")"
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would revert flatpak $kind $value if it is still ours"
            continue
        fi
        case "$kind" in
            override) uninstall_flatpak_grant "$value" ;;
            remote) uninstall_flatpak_remote "$value" ;;
            *) yellow "  unknown FLATPAK row kind '$kind' — left alone" ;;
        esac
    done
}

# Drops exactly one entry from [Context] filesystems=. An entry the user has
# since changed (a different mode, a negation) no longer matches and is kept.
# A [Context] group left with no key is dropped with its blank separator, and
# a file left with no key at all is removed — so a user's own [Environment]
# (or no file at all) comes back byte for byte. flatpak 1.18 groups are
# separated by one blank line; checked against the real binary.
uninstall_flatpak_grant() {
    local entry="$1" f have=0 e
    f="$(flatpak_override_file)"
    while IFS= read -r e; do
        [[ "$e" == "$entry" ]] && have=1
    done < <(flatpak_grants)
    if [[ $have -eq 0 ]]; then
        yellow "  kept     flatpak override $entry (changed or removed since install)"
        return 0
    fi
    # Inside an `if`, so a failed edit (an unwritable directory) says so
    # instead of `set -e` ending the whole uninstall without a word.
    if ! awk -v t="$entry" '/^\[/ { ctx = ($0 == "[Context]") }
        ctx && /^filesystems=/ {
            n = split(substr($0, 13), a, ";"); out = ""
            for (i = 1; i <= n; i++) if (a[i] != "" && a[i] != t) out = out a[i] ";"
            if (out == "") next
            $0 = "filesystems=" out
        }
        { n_l++; line[n_l] = $0; in_ctx[n_l] = ctx; if (ctx && /=/) ctx_keys = 1 }
        END {
            for (i = 1; i <= n_l; i++) if (ctx_keys || !in_ctx[i]) keep[++k] = line[i]
            while (k > 0 && keep[k] == "") k--
            for (i = 1; i <= k; i++) print keep[i]
        }' "$f" >"$f.dots-new" || ! mv "$f.dots-new" "$f"; then
        rm -f "$f.dots-new"
        red "  could not edit $f — flatpak override $entry left in place"
        return 0
    fi
    if ! grep -q '=' "$f"; then
        rm -f "$f"
    fi
    green "  removed  flatpak override $entry"
}

# `remote-delete` refuses a remote that installed refs still come from, but
# that error is not something to show as a failure: those apps are the user's.
uninstall_flatpak_remote() {
    local name="$1" names origins
    if ! command -v flatpak >/dev/null 2>&1; then
        yellow "  flatpak not found — Flathub remote left as it is"
        return 0
    fi
    names="$(flatpak remotes --user --columns=name 2>/dev/null || true)"
    if ! grep -qx "$name" <<<"$names"; then
        blue "  remote $name already gone"
        return 0
    fi
    origins="$(flatpak list --user --columns=origin 2>/dev/null || true)"
    if grep -qx "$name" <<<"$origins"; then
        yellow "  kept     remote $name — $(grep -cx "$name" <<<"$origins") installed ref(s) still come from it"
    elif flatpak remote-delete --user "$name" >/dev/null 2>&1; then
        green "  removed  remote $name"
    else
        red "  could not remove remote $name (flatpak remote-delete --user $name)"
    fi
}
