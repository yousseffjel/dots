#!/usr/bin/env bash
# Keeps packages/desktop.lst and install-pkg.sh's failure summary in step.
#
# desktop.lst exists to answer one question when a package fails: what did I
# just lose? The answer lives in the trailing '#' comment on each package
# line, and install-pkg-tiers.sh reads it back out via load_consequences() to
# build the closing red summary. An entry with no note still installs fine
# and still gets reported — it just reports "consequence not recorded", which
# is precisely the silence this whole tier was introduced to remove.
#
# So: every desktop.lst entry must carry a note, and the note must survive
# the parser install-pkg-tiers.sh actually uses. Both are checked here by
# running that parser rather than a copy of it — a regex that drifts from the
# real one would make this test agree with itself and nothing else.
#
# Sibling of tests/autostart-daemons.sh (heredoc vs report) and
# tests/picom-lockstep.sh (picom.conf vs picom.dcol): two places that state
# the same fact, with nothing but a test holding them together.
#
# usage: tests/desktop-consequences.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

LIST="$DOTS_DIR/packages/desktop.lst"
TIERS="$DOTS_DIR/scripts/install-pkg-tiers.sh"
for f in "$LIST" "$TIERS"; do
    if [[ ! -f "$f" ]]; then
        red "missing: $f"
        exit 1
    fi
done

FAIL=0

# The two functions under test, lifted from the shipped file so this cannot
# drift from what the installer really runs. Extracted by function header, so
# a rename or restructure yields an empty block — caught immediately below.
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
{
    echo 'PACKAGES_DIR="'"$DOTS_DIR"'/packages"'
    sed -n '/^read_pkg_list()/,/^}$/p' "$TIERS"
    sed -n '/^declare -A CONSEQUENCE=()/,/^}$/p' "$TIERS"
} >"$SB/parser.sh"

blue "==> extracting the real parser from install-pkg-tiers.sh"
for fn in read_pkg_list load_consequences; do
    if ! grep -q "^$fn()" "$SB/parser.sh"; then
        red "  could not extract $fn() from install-pkg-tiers.sh"
        red "  (its structure changed — update this test's sed ranges)"
        exit 1
    fi
done
green "  ok: read_pkg_list + load_consequences"

# shellcheck source=/dev/null
source "$SB/parser.sh"
load_consequences

blue "==> every desktop.lst package resolves to a consequence"
declare -a NAMES=()
while IFS= read -r pkg; do NAMES+=("$pkg"); done < <(read_pkg_list "$LIST")

if [[ ${#NAMES[@]} -eq 0 ]]; then
    red "  desktop.lst parsed to zero packages"
    exit 1
fi

for pkg in "${NAMES[@]}"; do
    note="${CONSEQUENCE[$pkg]-}"
    if [[ -z "$note" ]]; then
        red "  $pkg has no consequence note"
        red "     -> its failure would report 'consequence not recorded' and tell the user nothing"
        red "     -> add:  $pkg  # <what breaks without it>"
        FAIL=1
    fi
done
[[ $FAIL -eq 0 ]] && green "  ok: all ${#NAMES[@]} entries annotated"

# A note that just restates the package name is worse than useless — it
# occupies the slot that would otherwise fail this test.
blue "==> notes actually say something"
for pkg in "${NAMES[@]}"; do
    note="${CONSEQUENCE[$pkg]-}"
    [[ -n "$note" ]] || continue
    if [[ ${#note} -lt 20 ]]; then
        red "  $pkg: note is only ${#note} chars — say what stops working, not what is missing"
        FAIL=1
    fi
done
[[ $FAIL -eq 0 ]] && green "  ok: no placeholder notes"

# load_consequences() keys off desktop.lst alone, so an entry parked in
# another tier would silently never get a note. Catch the reverse direction:
# a name that has a note but is not actually in desktop.lst.
blue "==> no orphaned notes"
for pkg in "${!CONSEQUENCE[@]}"; do
    found=0
    for name in "${NAMES[@]}"; do
        [[ "$name" == "$pkg" ]] && found=1
    done
    if [[ $found -eq 0 ]]; then
        red "  '$pkg' has a consequence note but is not a desktop.lst package"
        red "     -> it moved tiers, or the line is malformed and read_pkg_list drops it"
        FAIL=1
    fi
done
[[ $FAIL -eq 0 ]] && green "  ok"

if [[ $FAIL -ne 0 ]]; then
    red "✗ desktop.lst and the failure summary have drifted"
    exit 1
fi
green "✓ desktop consequences: ${#NAMES[@]} packages, all annotated"
