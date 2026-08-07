#!/usr/bin/env bash
# Exercises starship.dcol through the real template engine. Its sibling
# tests/fastfetch-template.sh does the same for fastfetch.dcol; the two were
# split rather than combined because one file crossed the 250-line cap in
# rules/foundations/file-architecture.md. They duplicate a short harness on
# purpose, which is the same convention CLAUDE.md rule 2 sets for the colour
# helpers in scripts/.
#
# starship has no static counterpart to diff against the way picom does, so
# this checks the properties that actually break in practice:
#   * placeholders are all substituted (the engine never checks for leftovers)
#   * the splice is idempotent over repeated applies
#   * it refuses a starship.toml that does not carry our marker line
#   * the repo config always keeps a default [palettes.dots]
#
# SAFETY: the engine runs against a throwaway tree containing ONLY the template
# under test. Running the whole `always` group would fire every post-command,
# and three act on the live session however the environment is sandboxed —
# dunst.dcol runs `pkill -x dunst`, statusbar.dcol `pkill -x dwmblocks`, and
# xresources.dcol `xrdb -merge` against the running X server. pkill matches by
# process name system-wide, so env isolation cannot contain it. Fakes for
# pkill/xrdb/setsid go first on PATH as a second layer.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

PALETTE="$DOTS_DIR/themes/dark/colors.dcol"
ENGINE="$DOTS_DIR/scripts/theme/apply-templates.sh"
STARSHIP_TMPL="$DOTS_DIR/config/theme/templates/always/starship.dcol"
STARSHIP_CONF="$DOTS_DIR/config/starship/starship.toml"
MARKER='# ### dots-theme palette ###'

for f in "$PALETTE" "$ENGINE" "$STARSHIP_TMPL" "$STARSHIP_CONF"; do
    [[ -f "$f" ]] || {
        red "missing: $f"
        exit 1
    }
done

PASS=0
FAIL=0
SKIP=0
ok() {
    green "  ok: $*"
    PASS=$((PASS + 1))
}
bad() {
    red "  FAIL: $*"
    FAIL=$((FAIL + 1))
}
skip() {
    yellow "  skip: $*"
    SKIP=$((SKIP + 1))
}

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

mkdir -p "$SB/bin"
for f in pkill xrdb setsid; do
    printf '#!/bin/sh\nexit 0\n' >"$SB/bin/$f"
    chmod 755 "$SB/bin/$f"
done

# One throwaway DOTS_DIR per template. apply-templates.sh resolves
# TEMPLATES_DIR from its own location, so a copy of the script beside a
# one-template tree processes exactly that template.
make_tree() {
    local name="$1" tmpl="$2"
    mkdir -p "$SB/$name/dots/scripts/theme" \
        "$SB/$name/dots/config/theme/templates/always" \
        "$SB/$name/config" "$SB/$name/cache" "$SB/$name/home"
    cp "$ENGINE" "$SB/$name/dots/scripts/theme/"
    cp "$tmpl" "$SB/$name/dots/config/theme/templates/always/"
}

run_engine() {
    local name="$1"
    env -u DISPLAY PATH="$SB/bin:$PATH" HOME="$SB/$name/home" \
        XDG_CONFIG_HOME="$SB/$name/config" XDG_CACHE_HOME="$SB/$name/cache" \
        bash "$SB/$name/dots/scripts/theme/apply-templates.sh" \
        --palette "$PALETTE" always 2>&1
}

# Expected hex for a placeholder, read from the static palette.
palette_hex() { sed -n "s/^dcol_$1=\"\{0,1\}\([0-9A-Fa-f]*\)\"\{0,1\}$/\1/p" "$PALETTE"; }

# ---------------------------------------------------------------- starship --
blue "==> starship.dcol"
make_tree starship "$STARSHIP_TMPL"
mkdir -p "$SB/starship/config/starship"
cp "$STARSHIP_CONF" "$SB/starship/config/starship/starship.toml"

if ! out="$(run_engine starship)"; then
    red "engine failed:"
    printf '%s\n' "$out"
    exit 1
fi

SPLICED="$SB/starship/cache/dots/theme/starship.toml"
if [[ -f "$SPLICED" ]]; then
    ok "spliced config written to the cache"
else
    bad "no spliced starship.toml produced"
    printf '%s\n' "$out"
fi

if [[ -f "$SPLICED" ]] && grep -q 'wallbash_' "$SPLICED"; then
    bad "unsubstituted placeholder: $(grep -n 'wallbash_' "$SPLICED" | head -1)"
else
    ok "no unsubstituted placeholders"
fi

# Three applies must leave exactly one marker and one palette table. The splice
# always re-derives from the repo config, so a regression here would mean the
# sed range stopped matching — which silently doubles the table every apply.
run_engine starship >/dev/null 2>&1
run_engine starship >/dev/null 2>&1
markers="$(grep -c "^${MARKER}\$" "$SPLICED" || true)"
tables="$(grep -c '^\[palettes.dots\]$' "$SPLICED" || true)"
if [[ "$markers" == "1" && "$tables" == "1" ]]; then
    ok "idempotent over three applies (1 marker, 1 [palettes.dots])"
else
    bad "after three applies: $markers marker(s), $tables palette table(s)"
fi

# Every c_* entry must carry the palette's real value, not a stale default.
declare -A WANT=(
    [c_dir]=3xa8 [c_git_branch]=1xa5 [c_git_status]=1xa8
    [c_git_status_bg]=1xa2 [c_time]=1xa7
)
colour_rc=0
for key in "${!WANT[@]}"; do
    want="#$(palette_hex "${WANT[$key]}")"
    got="$(sed -n "s/^$key = '\(.*\)'\$/\1/p" "$SPLICED" | tail -1)"
    if [[ "$got" != "$want" ]]; then
        bad "$key is '$got', expected '$want' (dcol_${WANT[$key]})"
        colour_rc=1
    fi
done
((colour_rc == 0)) && ok "all five palette colours match themes/dark"

# The guard: a starship.toml without our marker must be left alone entirely.
# Without it the table is appended to a foreign config, and if that config
# already declares [palettes.dots] the result is a TOML parse error.
make_tree guard "$STARSHIP_TMPL"
mkdir -p "$SB/guard/config/starship"
printf 'add_newline = true\n[palettes.dots]\nc_dir = "#123456"\n' \
    >"$SB/guard/config/starship/starship.toml"
run_engine guard >/dev/null 2>&1
if [[ -e "$SB/guard/cache/dots/theme/starship.toml" ]]; then
    bad "spliced into a config that has no marker line"
else
    ok "refuses to splice a config without the marker"
fi

# The repo config must always carry a default table: `palette = 'dots'` with no
# [palettes.dots] drops every themed colour and warns once per new shell.
if grep -q '^\[palettes.dots\]$' "$STARSHIP_CONF" \
    && grep -q "^${MARKER}\$" "$STARSHIP_CONF"; then
    ok "repo starship.toml carries both the marker and a default palette"
else
    bad "repo starship.toml is missing its marker or its [palettes.dots]"
fi

if command -v starship >/dev/null 2>&1 && [[ -f "$SPLICED" ]]; then
    # Exit status AND stderr, not stderr alone. A starship that dies without
    # printing anything produces zero warning lines, so counting warnings by
    # itself calls a broken binary a pass — caught by shimming `starship` with
    # a script that just exits 127.
    #
    # A cold STARSHIP_CACHE matters too: starship dedupes config warnings
    # through a per-session log, so a warm cache hides them.
    rc=0
    err="$(cd "$SB" && STARSHIP_CACHE="$SB/sscache" STARSHIP_CONFIG="$SPLICED" \
        starship prompt --status=0 2>&1 >/dev/null)" || rc=$?
    warn="$(printf '%s' "$err" | grep -ci 'warn' || true)"
    if ((rc != 0)); then
        bad "starship exited $rc rendering the spliced config: ${err:-no output}"
    elif [[ "$warn" != "0" ]]; then
        bad "starship emitted $warn warning line(s) for the spliced config"
    else
        ok "starship renders the spliced config, exit 0 and no warnings"
    fi
else
    skip "starship not installed — spliced config not rendered"
fi

# ------------------------------------------------------------------ result --
printf '\n'
if ((FAIL > 0)); then
    red "✗ starship template: $PASS passed, $FAIL failed, $SKIP skipped"
    exit 1
fi
green "✓ starship template: $PASS passed, $SKIP skipped"
