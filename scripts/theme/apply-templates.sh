#!/usr/bin/env bash
# wallbash-for-X11 template engine. Processes every *.dcol file under
# config/theme/templates/{always,theme}/, substitutes <wallbash_NAME>
# placeholders from a dcol palette, writes the result to each template's
# declared target, and runs its optional post-write command.
# Reimplements HyDE-Project/HyDE's fn_wallbash (read as a design
# reference only, see CLAUDE.md rule 9) without its eval-based path
# expansion, its background+disown post-commands, or its `source`-the-
# palette step — see .claude/changes/2026-08-05-theming-apply-templates.md
# for rationale on each.
#
# Usage: apply-templates.sh [--palette PATH] <always|theme|all>...
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATES_DIR="$DOTS_DIR/config/theme/templates"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"
PALETTE="$cacheDir/colors.dcol"

usage() {
    echo "usage: apply-templates.sh [--palette PATH] <always|theme|all>..."
    echo "  --palette PATH   dcol file to read instead of \$cacheDir/colors.dcol"
    echo "                   (e.g. a static theme's own colors.dcol)"
}

TEMPLATE_GROUPS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --palette)
            PALETTE="$2"
            shift 2
            ;;
        all)
            TEMPLATE_GROUPS+=(always theme)
            shift
            ;;
        always | theme)
            TEMPLATE_GROUPS+=("$1")
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            red "unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ ${#TEMPLATE_GROUPS[@]} -eq 0 ]]; then
    red "no template group given"
    usage
    exit 1
fi
if [[ ! -f "$PALETTE" ]]; then
    red "palette not found: $PALETTE"
    yellow "  run colorgen.sh <wallpaper> first, or pass --palette PATH"
    exit 1
fi

# Parse, never `source`. A .dcol is strictly `dcol_NAME="VALUE"` lines
# plus `#` comments, so a line-by-line parser reads it exactly as well as
# sourcing would — without handing arbitrary bash in the file the right
# to run. That matters because --palette points at theme-supplied
# colors.dcol files (themes/<name>/colors.dcol), which are not
# necessarily first-party: sourcing would make installing a third-party
# theme equivalent to running its author's shell script. Malformed or
# unexpected lines are skipped loudly rather than silently ignored.
#
# Each parsed pair becomes one sed rule: <wallbash_SUFFIX> -> value,
# one per line, written to a script file consumed via `sed -f`. Passing
# the rules as a single argument instead would cap the palette size at
# ARG_MAX and abort a large (not necessarily malicious) palette with a
# cryptic "Argument list too long"; -f has no such limit.
# Delimiter is '|'. The value allowlist below already excludes backslash,
# pipe and ampersand, so the escaping applied to each value is currently
# unreachable — it stays as belt-and-braces so that widening the
# allowlist later can't silently reintroduce a sed-RHS injection.
build_sed_script() {
    local line key value lineno=0 parsed=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        [[ -z "${line//[[:space:]]/}" || "$line" == \#* ]] && continue
        # Values are restricted to a positive allowlist covering every
        # form a palette legitimately holds (hex, "R,G,B,A" tuples,
        # rgba(...) functional notation, color names, percentages) while
        # excluding every shell metacharacter — notably $, backtick and
        # backslash. That second layer matters even though this parser
        # never executes the value: some generated targets ARE shell
        # files (statusbar-colors.sh is sourced by dwmblocks scripts), so
        # a literal `$(...)` passed through into one would execute later,
        # at source time, turning a theme file into remote code
        # execution one step removed.
        if [[ "$line" =~ ^(dcol_[A-Za-z0-9_]+)=\"([A-Za-z0-9\ ,.:#%()/+_-]*)\"[[:space:]]*$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ ^(dcol_[A-Za-z0-9_]+)=([A-Za-z0-9,.:#%()/+_-]*)[[:space:]]*$ ]]; then
            # Unquoted form — same allowlist minus the space.
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
        else
            yellow "  ignoring malformed palette line $lineno: $line" >&2
            continue
        fi
        value="${value//\\/\\\\}"
        value="${value//|/\\|}"
        value="${value//&/\\&}"
        printf 's|<wallbash_%s>|%s|g\n' "${key#dcol_}" "$value"
        parsed=$((parsed + 1))
    done <"$PALETTE"
    if [[ $parsed -eq 0 ]]; then
        red "no dcol_* entries found in $PALETTE" >&2
        return 1
    fi
}

# Both temp files are cleaned up on every exit path — including a signal
# and a mid-render `set -e` abort, which is why WORK_TMP is script-scoped
# rather than local to apply_one.
SED_SCRIPT_FILE="$(mktemp)"
WORK_TMP=""
trap 'rm -f "$SED_SCRIPT_FILE" "$WORK_TMP"' EXIT INT TERM HUP
build_sed_script >"$SED_SCRIPT_FILE"

# ${confDir}/${cacheDir} only — deliberately not eval: template headers
# are first-party repo content today, but a plain string substitution of
# two known tokens costs nothing and never runs arbitrary shell.
expand_path() {
    local s="$1"
    s="${s//\$\{confDir\}/$confDir}"
    s="${s//\$\{cacheDir\}/$cacheDir}"
    printf '%s' "$s"
}

apply_one() {
    local template="$1" header target post_command parent
    header="$(head -n1 "$template")"
    target="$(expand_path "${header%%|*}")"
    post_command=""
    [[ "$header" == *"|"* ]] && post_command="$(expand_path "${header#*|}")"

    parent="$(dirname "$target")"
    if [[ ! -d "$parent" ]]; then
        SKIPPED=$((SKIPPED + 1))
        yellow "skip    $(basename "$template") — $parent doesn't exist (app not installed?)"
        return 0
    fi

    WORK_TMP="$(mktemp)"
    tail -n +2 "$template" | sed -f "$SED_SCRIPT_FILE" >"$WORK_TMP"
    # mktemp creates 0600 and mv preserves it, which would leave every
    # generated config user-only-readable — surprising for ordinary config
    # files. Re-apply the umask-derived default instead.
    chmod "$(printf '%o' $((0666 & ~$(umask))))" "$WORK_TMP"
    mv "$WORK_TMP" "$target"
    WORK_TMP=""
    WRITTEN=$((WRITTEN + 1))
    green "wrote   $target"

    if [[ -n "$post_command" ]]; then
        if bash -c "$post_command"; then
            blue "  post-command ok: $post_command"
        else
            yellow "  post-command failed (continuing): $post_command"
        fi
    fi
}

WRITTEN=0
SKIPPED=0
for group in "${TEMPLATE_GROUPS[@]}"; do
    dir="$TEMPLATES_DIR/$group"
    if [[ ! -d "$dir" ]]; then
        yellow "skip    $group/ — no such directory"
        continue
    fi
    shopt -s nullglob
    templates=("$dir"/*.dcol)
    shopt -u nullglob
    if [[ ${#templates[@]} -eq 0 ]]; then
        yellow "skip    $group/ — no *.dcol templates"
        continue
    fi
    blue "==> processing $group/ (${#templates[@]} template(s))"
    for template in "${templates[@]}"; do
        apply_one "$template"
    done
done

if [[ $SKIPPED -gt 0 ]]; then
    green "✓ applied $WRITTEN template(s), skipped $SKIPPED"
else
    green "✓ applied $WRITTEN template(s)"
fi
