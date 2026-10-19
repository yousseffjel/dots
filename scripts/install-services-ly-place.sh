#!/usr/bin/env bash
# Puts a staged ly build in place, records which build it is, and replaces an
# older build of ours. Sourced by install-services-ly.sh (split off from it at
# the 250-line cap), never standalone: the same assumptions (`set -euo
# pipefail`, SUDO, global_fn.sh's manifest_*, the colour helpers) plus its
# ly_root and LY_* pins.
#
# THE RECORD. `META ly_build v<version> <commit>` is written once a build is
# completely in place. A manifest with LYBUILD rows and no record predates
# the record: every such build came from the first pin, LY_FIRST_BUILD (the
# only one shipped until records existed, 2026-10-19).
#
# A REBUILD — the pins moved since the recorded build:
#   * each file is copied next to its target and renamed over it. A running ly
#     holds /usr/bin/ly open for execution, so copying onto it fails with
#     ETXTBSY; a rename does not. That ly keeps running the old binary until
#     the next boot. Nothing restarts it: that would end the session on tty2;
#   * an existing /etc/ly/config.ini is KEPT. `dots login-theme` themed it,
#     or you edited it. The new version's stock file is not applied;
#   * a path the old build had and the new one does not is removed, row and
#     all — except config.ini, for the same reason.
# The record moves only after all of that succeeded, so an interrupted or
# failed rebuild is retried by the next run.

LY_FIRST_BUILD="v1.4.1 afb1dc62a0568743c9a7952623ec179128c73340"
LY_CONFIG=/etc/ly/config.ini

# ly_pinned — the record the current pins describe.
ly_pinned() { printf 'v%s %s\n' "$LY_VERSION" "$LY_COMMIT"; }

# ly_built — the record of the build in place.
ly_built() {
    local b
    b="$(manifest_get_meta ly_build)"
    printf '%s\n' "${b:-$LY_FIRST_BUILD}"
}

# ly_place <stage> [keep-config] — copy each staged file or link into place,
# one row each. Sorted, so ./usr/bin/ly comes after every ./etc path: a
# binary in place means the rest is too, which is what ly_install's "already
# ours" check relies on after an interrupted fresh install.
ly_place() {
    local stage="$1" keep="${2:-}" rel dst
    while IFS= read -r rel; do
        dst="$(ly_root)/${rel#./}"
        if [[ -n "$keep" && "/${rel#./}" == "$LY_CONFIG" && -e "$dst" ]]; then
            yellow "kept    $LY_CONFIG — themed or edited; v$LY_VERSION's stock one is not applied"
            manifest_append_row LYBUILD ly "$LY_CONFIG"
            continue
        fi
        # -d keeps the supervise -> /run/runit/supervise.ly link a link, and
        # -T renames it over the old link rather than into what it points at.
        # A .dots-new an interrupted run left goes first: cp would write
        # through it if it were a link.
        if ! "${SUDO[@]}" mkdir -p "$(dirname "$dst")" \
            || ! "${SUDO[@]}" rm -f "$dst.dots-new" \
            || ! "${SUDO[@]}" cp -dp --no-preserve=ownership "$stage/$rel" "$dst.dots-new" \
            || ! "${SUDO[@]}" mv -fT "$dst.dots-new" "$dst"; then
            "${SUDO[@]}" rm -f "$dst.dots-new" 2>/dev/null || true
            red "  could not install /${rel#./}"
            return 1
        fi
        manifest_append_row LYBUILD ly "/${rel#./}"
    done < <(cd "$stage" && find . \( -type f -o -type l \) | sort)
}

# ly_drop_row <path> — the LYBUILD row of one path, every other row kept.
ly_drop_row() {
    local tmp
    tmp="$(mktemp)"
    awk -F'\t' -v p="$1" '!($1 == "LYBUILD" && $3 == p)' "$MANIFEST_FILE" >"$tmp"
    mv "$tmp" "$MANIFEST_FILE"
}

# ly_prune <stage> — remove what an older build placed and <stage> lacks.
ly_prune() {
    local stage="$1" p
    local -A staged=()
    while IFS= read -r p; do
        staged["/${p#./}"]=1
    done < <(cd "$stage" && find . \( -type f -o -type l \))
    while IFS= read -r p; do
        [[ -n "${staged[$p]:-}" || "$p" == "$LY_CONFIG" ]] && continue
        if ! "${SUDO[@]}" rm -f -- "$(ly_root)$p"; then
            red "  could not remove $p, which v$LY_VERSION no longer ships"
            return 1
        fi
        ly_drop_row "$p"
        blue "removed $p (not in v$LY_VERSION)"
    done < <(manifest_rows LYBUILD | cut -f3 | sort -u)
}
