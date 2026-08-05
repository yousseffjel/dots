#!/usr/bin/env bash
# Prints repo version, installed version (from the install manifest), the
# repo's current git commit, Fedora version, and dwm's build version (if
# installed).
#
# usage: version.sh [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/global_fn.sh"

JSON=0
for arg in "$@"; do
    case "$arg" in
        --json) JSON=1 ;;
        -h|--help) echo "usage: version.sh [--json]"; exit 0 ;;
        *) red "unknown argument: $arg"; exit 1 ;;
    esac
done

repo_version="$(tr -d '[:space:]' < "$DOTS_DIR/VERSION" 2>/dev/null || echo unknown)"
installed_version="$(manifest_get_meta version)"
installed_date="$(manifest_get_meta date)"
installed_commit="$(manifest_get_meta commit)"
repo_commit="$(git -C "$DOTS_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"

fedora_version="unknown"
if [[ -f /etc/fedora-release ]]; then
    fedora_version="$(tr -d '\n' < /etc/fedora-release)"
elif command -v rpm >/dev/null 2>&1; then
    fedora_version="Fedora $(rpm -E %fedora 2>/dev/null || echo unknown)"
fi

dwm_version="not installed"
if command -v dwm >/dev/null 2>&1; then
    dwm_version="$(dwm -v 2>&1 | head -1 | sed 's/^dwm-//')"
fi

json_str_or_null() {
    if [[ -z "$2" ]]; then
        printf '  "%s": null%s\n' "$1" "$3"
    else
        printf '  "%s": "%s"%s\n' "$1" "$2" "$3"
    fi
}

if [[ $JSON -eq 1 ]]; then
    printf '{\n'
    json_str_or_null repo_version "$repo_version" ","
    json_str_or_null installed_version "$installed_version" ","
    json_str_or_null installed_date "$installed_date" ","
    json_str_or_null installed_commit "$installed_commit" ","
    printf '  "repo_commit": "%s",\n'       "$repo_commit"
    printf '  "fedora_version": "%s",\n'    "$fedora_version"
    printf '  "dwm_version": "%s"\n'        "$dwm_version"
    printf '}\n'
else
    echo "dots repo version:  $repo_version (commit $repo_commit)"
    if [[ -n "$installed_version" ]]; then
        echo "installed version:  $installed_version (commit ${installed_commit:-unknown}, installed $installed_date)"
    else
        echo "installed version:  not installed (no manifest at $MANIFEST_FILE)"
    fi
    echo "fedora version:      $fedora_version"
    echo "dwm version:          $dwm_version"
fi
