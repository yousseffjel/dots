#!/usr/bin/env bash
# What a user reads — every --help and every message a script prints — names
# Void's tools, not Fedora's.
#
# WHY. Six days after the port merged, `install-void.sh --help` still said
# "PORT IN PROGRESS ... this script does not work on either distro" and that
# --only-install installs "dnf packages", and dwm-record's missing-ffmpeg error
# named Fedora's ffmpeg-free (Void VM, 2026-10-21). Comments may keep the
# Fedora history; what is printed may not tell a Void user to run dnf.
#
# HOW. (1) Runs --help for every script under scripts/ whose source handles
# --help — the list is read from the code, never written here, and a script
# that does not handle it is never run (reload.sh, for one, would act on the
# live desktop). HOME, the XDG dirs and the display are sandboxed away.
# (2) Greps every printed string literal (red/green/yellow/blue/echo/printf/
# fail/notify/report) in scripts/ and config/*/bin, comments excluded.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }
indent() { while IFS= read -r line; do printf '      %s\n' "$line"; done <<<"$1"; }

# Fedora-era tools and the port's own placeholder. "Fedora" alone is allowed:
# help text may say what the port replaced.
STALE='\b(dnf|rpm|systemctl|ffmpeg-free)\b|PORT IN PROGRESS|does not work on either distro'

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
rc=0

blue "==> --help of every script that handles it"
mapfile -t HELPERS < <(cd "$DOTS_DIR" && grep -lE '^[[:space:]]*(-h \| --help|--help)\)' \
    scripts/*.sh scripts/dots scripts/theme/*.sh | sort)
if ((${#HELPERS[@]} < 5)); then
    red "  FAIL: only ${#HELPERS[@]} script(s) handle --help — the pattern no longer matches the code"
    rc=1
fi
for f in "${HELPERS[@]}"; do
    out="$(env -i PATH="$PATH" HOME="$TMP/home" LANG=C.UTF-8 \
        XDG_CONFIG_HOME="$TMP/home/.config" XDG_CACHE_HOME="$TMP/home/.cache" \
        XDG_STATE_HOME="$TMP/home/.local/state" XDG_DATA_HOME="$TMP/home/.local/share" \
        timeout 20 bash "$DOTS_DIR/$f" --help </dev/null 2>&1 || true)"
    if hits="$(grep -nE "$STALE" <<<"$out")"; then
        red "  FAIL: $f --help:"
        indent "$hits"
        rc=1
    fi
done
if ((rc == 0)); then green "  ok: ${#HELPERS[@]} --help texts name no Fedora-era tool"; fi

blue "==> printed strings"
# A line whose first non-blank character is # is a comment; the rest are
# searched only inside the arguments of a printing command.
hits="$(cd "$DOTS_DIR" && grep -rnE "^[[:space:]]*[^#[:space:]].*\b(red|green|yellow|blue|echo|printf|fail|notify|notify-send|report)\b[^#]*['\"][^'\"]*($STALE)" \
    scripts config/*/bin || true)"
if [[ -n "$hits" ]]; then
    red "  FAIL: printed text names a Fedora-era tool:"
    indent "$hits"
    rc=1
else
    green "  ok: no printed string names a Fedora-era tool"
fi

if ((rc != 0)); then
    red "✗ runtime text"
    exit 1
fi
green "✓ runtime text: help and messages speak Void"
