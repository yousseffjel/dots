#!/usr/bin/env bash
# Keeps .github/workflows/ci.yml's build-suckless "Install build dependencies"
# step in lockstep with packages/build.lst.
#
# That step used to hardcode 12 package names under a comment claiming to
# match scripts/install-suckless.sh's install_deps() "exactly" — it didn't:
# build.lst declared 13, and `patch` was the one silently missing. The step
# now parses packages/build.lst directly instead of restating it, and this
# test proves that by running the step's own shell block — extracted from the
# YAML, not retyped — against a shimmed `xbps-install` that records what it
# was asked to install, rather than assuming the YAML says what it looks like
# it says. (On Fedora the shim was dnf.)
#
# usage: tests/ci-build-deps.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CI_YML="$DOTS_DIR/.github/workflows/ci.yml"
BUILD_LST="$DOTS_DIR/packages/build.lst"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

for f in "$CI_YML" "$BUILD_LST"; do
    if [[ ! -f "$f" ]]; then
        red "missing: $f"
        exit 1
    fi
done

# Same rule as read_pkg_list() in scripts/install-pkg-tiers.sh /
# scripts/install-suckless.sh / tests/pkglist.sh.
read_pkg_list() {
    sed 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^$'
}

blue "==> extracting the 'Install build dependencies' run block from ci.yml"
# The step's `run: |` block is indented 10 spaces; it ends at the next line
# indented 6 spaces (the next step) or shallower. Extracted by content, not
# retyped, so a rewrite of the step is what this test actually exercises.
BLOCK="$(awk '
    /^      - name: Install build dependencies$/ { found=1; next }
    found && /^        run: \|$/ { inblock=1; next }
    inblock && /^          / { sub(/^          /, ""); print; next }
    inblock { exit }
' "$CI_YML")"

if [[ -z "$BLOCK" ]]; then
    red "  could not extract the run block (step renamed or restructured?)"
    red "  (update this test's awk pattern to match ci.yml)"
    exit 1
fi
green "  ok: $(printf '%s\n' "$BLOCK" | wc -l) lines"

blue "==> running it against a shimmed xbps-install"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
CAPTURE="$SB/xbps-install-args"

cat >"$SB/xbps-install" <<'SHIM'
#!/usr/bin/env bash
# Records what "xbps-install -y ..." was asked to install; that is the only
# call the extracted block makes.
[[ "${1:-}" == -y ]] && shift
printf '%s\n' "$@" >"$XBPS_CAPTURE"
SHIM
chmod +x "$SB/xbps-install"

printf '%s\n' "$BLOCK" >"$SB/block.sh"

(
    cd "$DOTS_DIR"
    export PATH="$SB:$PATH"
    export XBPS_CAPTURE="$CAPTURE"
    bash "$SB/block.sh"
)

if [[ ! -f "$CAPTURE" ]]; then
    red "  the block never called 'xbps-install' — shim never triggered"
    exit 1
fi

blue "==> comparing installed packages to packages/build.lst"
GOT="$(sort "$CAPTURE")"
WANT="$(read_pkg_list "$BUILD_LST" | sort)"

if [[ "$GOT" != "$WANT" ]]; then
    red "  mismatch between what ci.yml installs and what build.lst declares:"
    diff <(echo "$WANT") <(echo "$GOT") | sed 's/^/    /' || true
    exit 1
fi

green "✓ ci.yml's build-suckless job installs exactly packages/build.lst ($(echo "$GOT" | wc -l) packages)"
