#!/usr/bin/env bash
# A palette that lacks a key some template uses is refused before anything
# is written — by apply-templates.sh on every run, and by theme-apply.sh
# before its identity and wallpaper steps.
#
# WHY. On the Void VM (2026-10-21) a theme whose colors.dcol lacked
# dcol_pry1/dcol_txt1 was applied anyway: `#<wallbash_pry1>` reached
# xresources, dwm's restart died in drw_clr_create ("cannot allocate
# color"), ~/.xinitrc ended and ly logged the user out. The broken cache
# would have killed the next login the same way. Themes are not
# necessarily first-party (apply-templates.sh parses rather than sources
# them for that reason), so the engine is the gate.
#
# What is asserted:
#   * every shipped palette passes --check, and --check writes nothing;
#   * a palette without pry1/txt1 is refused by --check and by a real run,
#     naming both keys, with nothing written and no post-command run;
#   * only the selected template groups are read (all vs always);
#   * theme-apply.sh refuses that theme before writing the GTK identity,
#     rendering a wallpaper or reloading anything.
#
# SAFETY: a throwaway copy of the repo. Every copied template's
# post-command is replaced by a marker, reload.sh and wallpaper-default.sh
# are stubs, pkill/xrdb/setsid/notify-send are fakes first on PATH and
# there is no DISPLAY — so even the unfixed engine cannot reach a session.
# shellcheck disable=SC2016 # the bash -c bodies take $1.. as their own arguments
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
rc=0
check() {
    local name="$1"
    shift
    if "$@"; then
        green "  ok: $name"
    else
        red "  FAIL: $name"
        rc=1
    fi
}

COPY="$TMP/dots"
H="$TMP/home"
RAN="$TMP/ran"
mkdir -p "$COPY/config/theme" "$TMP/bin" "$RAN"
cp -r "$DOTS_DIR/scripts" "$DOTS_DIR/themes" "$COPY/"
cp -r "$DOTS_DIR/config/theme/templates" "$COPY/config/theme/"
for t in "$COPY"/config/theme/templates/*/*.dcol; do
    target="$(head -n1 "$t")"
    target="${target%%|*}"
    sed -i "1s#.*#$target|touch '$RAN/${t##*/}'#" "$t"
done
for stub in reload.sh wallpaper-default.sh; do
    printf '#!/bin/sh\ntouch "%s/%s"\n' "$RAN" "$stub" >"$COPY/scripts/theme/$stub"
done
for f in pkill xrdb setsid notify-send feh; do
    printf '#!/bin/sh\nexit 0\n' >"$TMP/bin/$f"
    chmod 755 "$TMP/bin/$f"
done
# Every template's target directory exists, so none is skipped as "app not
# installed" and a missing refusal would show as a written file.
mkdir -p "$H/.config"/{dunst,fastfetch,gtk-3.0,picom,starship} "$H/.cache"

sandbox() {
    env -i PATH="$TMP/bin:$PATH" HOME="$H" LANG=C.UTF-8 \
        XDG_CONFIG_HOME="$H/.config" XDG_CACHE_HOME="$H/.cache" \
        XDG_STATE_HOME="$H/.local/state" XDG_DATA_HOME="$H/.local/share" "$@"
}
# The theme lock (theme-lock.sh) is taken before anything is checked; it
# is an empty file and changes nothing.
tree() { (cd "$H" && find . -type f ! -name .theme.lock -exec md5sum {} + | sort) 2>/dev/null; }
nothing_ran() { [[ -z "$(ls -A "$RAN")" ]]; }

PARTIAL="$COPY/themes/partial"
mkdir -p "$PARTIAL"
cp "$COPY/themes/dark/theme.conf" "$PARTIAL/"
grep -vE '^dcol_(pry1|txt1)(_rgba)?=' "$COPY/themes/dark/colors.dcol" >"$PARTIAL/colors.dcol"
ENGINE="$COPY/scripts/theme/apply-templates.sh"

blue "==> shipped palettes"
before="$(tree)"
for p in "$DOTS_DIR"/themes/*/colors.dcol; do
    st=0
    sandbox bash "$ENGINE" --check --palette "$p" all >/dev/null 2>&1 || st=$?
    check "$(basename "$(dirname "$p")") passes --check" test "$st" -eq 0
done
check "--check wrote nothing and ran no post-command" \
    bash -c '[[ $1 == "$2" ]] && [[ -z $(ls -A "$3") ]]' _ "$before" "$(tree)" "$RAN"

blue "==> a palette without pry1 and txt1"
for mode in --check run; do
    args=(--palette "$PARTIAL/colors.dcol" all)
    [[ $mode == --check ]] && args=(--check "${args[@]}")
    st=0
    out="$(sandbox bash "$ENGINE" "${args[@]}" 2>&1)" || st=$?
    check "$mode: refused" test "$st" -ne 0
    check "$mode: names both keys" bash -c '[[ $1 == *pry1* && $1 == *txt1* ]]' _ "$out"
    check "$mode: nothing written" test "$(tree)" == "$before"
    check "$mode: no post-command ran" nothing_ran
done

blue "==> only the selected groups count"
# theme/ ships no template today, so one is made in the copy, using a key no
# palette has: `all` must refuse it, `always` must not read it.
mkdir -p "$COPY/config/theme/templates/theme"
printf '${cacheDir}/only-theme|touch %s/only-theme\n<wallbash_nosuchkey>\n' "'$RAN'" \
    >"$COPY/config/theme/templates/theme/only.dcol"
st=0
out="$(sandbox bash "$ENGINE" --check --palette "$COPY/themes/dark/colors.dcol" all 2>&1)" || st=$?
check "all: a gap in theme/ alone is refused" bash -c '[[ $1 -ne 0 && $2 == *nosuchkey* ]]' _ "$st" "$out"
st=0
sandbox bash "$ENGINE" --check --palette "$COPY/themes/dark/colors.dcol" always >/dev/null 2>&1 || st=$?
check "always: theme/ is not read" test "$st" -eq 0
rm "$COPY/config/theme/templates/theme/only.dcol"

blue "==> theme-apply.sh with that theme"
st=0
out="$(sandbox bash "$COPY/scripts/theme/theme-apply.sh" partial 2>&1)" || st=$?
check "refused" test "$st" -ne 0
check "...naming the missing keys" bash -c '[[ $1 == *pry1* && $1 == *txt1* ]]' _ "$out"
check "...before the GTK identity, a wallpaper or a reload" test "$(tree)" == "$before"
check "...and with nothing run" nothing_ran

if ((rc != 0)); then
    red "✗ palette completeness"
    exit 1
fi
green "✓ palette completeness: a palette missing a key is refused, nothing written"
