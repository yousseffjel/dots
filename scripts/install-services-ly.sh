#!/usr/bin/env bash
# Builds and installs the ly display manager from source (scope I, decision
# D1: Void does not package ly). Sourced by install-services.sh, never
# standalone: assumes `set -euo pipefail`, DRY_RUN, SUDO, global_fn.sh
# (manifest_*) and the colour helpers.
#
# usage: source "$SCRIPT_DIR/install-services-ly.sh"; ly_install
#
# EVERYTHING IS PINNED, nothing floats:
#   * ly is a git TAG, verified against its COMMIT after the clone (Codeberg
#     builds source archives on the fly, so their bytes are not a stable pin);
#   * its zig dependencies come from the release's vendor.tar.zst (sha256),
#     unpacked as the project-local zig-pkg/ cache, so `zig build` runs
#     offline;
#   * zig is the official release tarball (sha256 from ziglang.org's
#     index.json). Void packages zig 0.13.0 and ly 1.4.x needs 0.16.0
#     (build.zig.zon minimum_zig_version). It is used for this build only,
#     never installed (user decision, 2026-10-15).
# tests/ly-pins.sh holds the pins well-formed and consistent.
#
# Why ly 1.4.1 and not 1.5.0: 1.4.1 keeps every config.ini key
# scripts/theme/ly-theme.sh writes (its fixture is 1.4.0). 1.5.0 drops
# hide_version_string and the *_cmd power keys, and ly's master has already
# moved to config.lua. Verified by building 1.4.1 with zig 0.16.0 into a
# staging dir (2026-10-15), which is also where the file list came from.
#
# INSTALL. The build installs into a staging directory as the user
# (-Ddest_directory), then each staged path is copied into place with sudo and
# recorded as `LYBUILD ly <path>` (the path in column 3, where
# manifest_has_path looks, like `THEME theme <path>`), so uninstall-runit.sh removes exactly those.
# A /usr/bin/ly that has no row is someone else's ly: left alone, and only its
# service is enabled.
#
# A PIN BUMP reaches existing installs: the build in place is recorded, and
# one older than the pins is rebuilt. Placing, the record and the rebuild
# rules (config.ini kept, nothing restarted) are in install-services-ly-place.sh.

LY_VERSION=1.4.1
LY_COMMIT=afb1dc62a0568743c9a7952623ec179128c73340
LY_GIT=https://codeberg.org/fairyglade/ly.git
LY_VENDOR_URL=https://codeberg.org/fairyglade/ly/releases/download/v$LY_VERSION/vendor.tar.zst
LY_VENDOR_SHA256=0e90692bb89c6fc47ebe3c04812deea4fdd58a0f19b20f308312540a34362752
# ly's own requirement, from its build.zig.zon at the tag above.
LY_MIN_ZIG=0.16.0
ZIG_VERSION=0.16.0
ZIG_URL=https://ziglang.org/download/$ZIG_VERSION/zig-x86_64-linux-$ZIG_VERSION.tar.xz
ZIG_SHA256=70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00
# Headers the build links against; in packages/build.lst, which the install
# stage installs before this stage runs.
LY_BUILD_DEPS=(pam-devel libxcb-devel zstd)

# Its own directory, not the caller's SCRIPT_DIR: tests source this file too.
# shellcheck source=install-services-ly-place.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-services-ly-place.sh"

# Test overrides, resolved at call time: the install root and the binary path.
ly_root() { printf '%s\n' "${DOTS_LY_ROOT:-}"; }
ly_bin() { printf '%s/usr/bin/ly\n' "$(ly_root)"; }

# ly_zig_ok — the pinned zig meets ly's minimum (sort -V; the two pins can
# drift when one is bumped without the other).
ly_zig_ok() {
    local sorted
    mapfile -t sorted < <(printf '%s\n' "$LY_MIN_ZIG" "$ZIG_VERSION" | sort -V)
    [[ "${sorted[0]}" == "$LY_MIN_ZIG" ]]
}

# ly_fetch <url> <sha256> <out> — download and verify; a mismatch deletes it.
ly_fetch() {
    xbps-fetch -o "$3" "$1" >/dev/null 2>&1 || {
        yellow "  could not download $1"
        return 1
    }
    if [[ "$(sha256sum "$3" | cut -d' ' -f1)" != "$2" ]]; then
        rm -f "$3"
        red "  checksum mismatch on $(basename "$3") — refusing to build"
        return 1
    fi
}

# ly_build <workdir> — fetch, verify and build into <workdir>/stage.
ly_build() {
    local w="$1" head
    ly_fetch "$ZIG_URL" "$ZIG_SHA256" "$w/zig.tar.xz" || return 1
    mkdir -p "$w/zig" && tar -xJf "$w/zig.tar.xz" -C "$w/zig" --strip-components=1 || return 1
    if [[ "$("$w/zig/zig" version 2>/dev/null || true)" != "$ZIG_VERSION" ]]; then
        red "  the unpacked zig is not $ZIG_VERSION — refusing to build"
        return 1
    fi
    git clone -q --depth 1 --branch "v$LY_VERSION" "$LY_GIT" "$w/src" 2>/dev/null || {
        yellow "  could not clone ly v$LY_VERSION"
        return 1
    }
    head="$(git -C "$w/src" rev-parse HEAD 2>/dev/null || true)"
    if [[ "$head" != "$LY_COMMIT" ]]; then
        red "  ly v$LY_VERSION is commit ${head:-unknown}, pinned $LY_COMMIT — the tag moved; refusing to build"
        return 1
    fi
    ly_fetch "$LY_VENDOR_URL" "$LY_VENDOR_SHA256" "$w/vendor.tar.zst" || return 1
    # zstd | tar rather than tar --zstd: works with any tar.
    zstd -dc "$w/vendor.tar.zst" | tar -x -C "$w/src" || return 1
    # Both zig caches inside the workdir: nothing lands in ~/.cache.
    (cd "$w/src" && "$w/zig/zig" build installexe -Dinit_system=runit -Doptimize=ReleaseSafe \
        -Ddest_directory="$w/stage" --cache-dir "$w/cache" --global-cache-dir "$w/gcache" \
        >"$w/build.log" 2>&1) || {
        yellow "  zig build failed — last lines of $w/build.log:"
        tail -n 5 "$w/build.log" | sed 's/^/    /'
        return 1
    }
}

# ly_take_tty2 — hand tty2 from its getty to ly, never leaving it with
# neither. Nothing happens unless ly's service dir exists (a foreign ly may
# have none). The getty goes first, so the two never run on tty2 together; if
# ly then cannot be linked, the getty is put straight back.
ly_take_tty2() {
    local getty=agetty-tty2 down
    if runit_enabled ly; then
        green "ok      ly already enabled"
        return 0
    fi
    if [[ ! -d "$(runit_sv)/ly" ]]; then
        yellow "skip    no runit service at $(runit_sv)/ly — tty2 keeps its getty; log in there and run startx"
        return 1
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would hand tty2 from $getty to ly"
        return 0
    fi
    down=""
    [[ -e "$(runit_sv)/$getty/down" ]] || down=made
    runit_disable "$getty" down || return 1
    runit_enable ly && return 0
    # Undo the handover: tty2 must not be left without a login.
    if runit_enabled "$getty" || [[ ! -d "$(runit_sv)/$getty" ]]; then
        return 1
    fi
    [[ -n "$down" ]] && "${SUDO[@]}" rm -f "$(runit_sv)/$getty/down"
    if "${SUDO[@]}" ln -s "$(runit_sv)/$getty" "$(runit_service)/"; then
        yellow "        ly could not be enabled — tty2's getty is back"
    else
        red "        tty2 has no login: run  sudo ln -s $(runit_sv)/$getty $(runit_service)/"
    fi
    return 1
}

ly_install() {
    local p w ours=""
    blue "==> ly login screen (built from source: v$LY_VERSION, zig $ZIG_VERSION)"
    if manifest_has_path LYBUILD /usr/bin/ly; then
        ours=1
        if [[ -x "$(ly_bin)" && "$(ly_built)" == "$(ly_pinned)" ]]; then
            # Writes the record for a build that predates it; same value after.
            [[ $DRY_RUN -eq 1 ]] || manifest_set_meta ly_build "$(ly_pinned)"
            green "ok      ly v$LY_VERSION already built and installed by dots"
            return 0
        fi
        blue "  dots built ly $(ly_built | cut -d' ' -f1); the pins say v$LY_VERSION — rebuilding"
    elif [[ -e "$(ly_bin)" ]]; then
        green "ok      $(ly_bin) exists and is not ours — left as it is"
        return 0
    fi
    if [[ "$(xbps-uhelper arch 2>/dev/null || true)" != x86_64 ]]; then
        yellow "skip    the pinned zig is x86_64-linux glibc only — log in on a TTY and run startx"
        return 1
    fi
    if ! ly_zig_ok; then
        red "  zig $ZIG_VERSION is older than ly v$LY_VERSION needs ($LY_MIN_ZIG) — fix the pins"
        return 1
    fi
    for p in "${LY_BUILD_DEPS[@]}"; do
        xbps-query "$p" >/dev/null 2>&1 || {
            yellow "skip    $p is not installed (packages/build.lst) — run the install stage first"
            return 1
        }
    done
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would fetch zig $ZIG_VERSION + ly v$LY_VERSION, build, and install ly"
        return 0
    fi
    w="$(mktemp -d)"
    if ly_build "$w" && ly_place "$w/stage" "$ours" && ly_prune "$w/stage"; then
        manifest_set_meta ly_build "$(ly_pinned)"
        green "installed ly v$LY_VERSION"
        [[ -z "$ours" ]] || yellow "        a running ly is still the old one; v$LY_VERSION starts at the next boot"
        rm -rf "$w"
        return 0
    fi
    rm -rf "$w"
    if [[ -n "$ours" ]]; then
        yellow "ly not rebuilt — $(ly_built | cut -d' ' -f1) stays; re-run: scripts/install-void.sh --only-services"
    else
        yellow "ly not installed — log in on a TTY and run startx; re-run: scripts/install-void.sh --only-services"
    fi
    return 1
}
