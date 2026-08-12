#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-display against a faked xrandr.
#
# Sibling of tests/dwm-colorpicker.sh, split for the same reason
# tests/fastfetch-template.sh and tests/starship-template.sh are: one file
# covering both scripts would cross the 250-line cap. They duplicate a short
# harness on purpose, per CLAUDE.md rule 2.
#
# WHAT IS ACTUALLY AT RISK HERE. dwm-display derives its menu from `xrandr`
# rather than hardcoding output names, so the interesting failures are in the
# derivation, not the plumbing:
#   * a disconnected output leaking into the menu (the `$2 == "connected"`
#     match is what prevents it, and a bare /connected/ pattern would not);
#   * "only <output>" forgetting to switch the OTHERS off, which would leave
#     two enabled outputs, or switching them off in a SEPARATE xrandr call,
#     which would briefly leave the X server with no output at all;
#   * extend/mirror entries appearing on a single-monitor machine, where they
#     are meaningless;
#   * autorandr profiles being buried below the generated presets, when the
#     point of a saved profile is that it beats anything generated.
# Every one of those keeps the script exit-0 and looks fine in a screenshot,
# which is why they are asserted individually.
#
# SAFETY: xrandr, dmenu, autorandr and notify-send are all faked on PATH. A
# real xrandr call would reconfigure the tester's actual displays; a real dmenu
# would block forever waiting for input. `--list` is used wherever possible
# precisely because it prints the menu and the command behind each entry
# WITHOUT applying anything.
#
# Needs nothing beyond bash + coreutils, so unlike its colorpicker sibling this
# runs everywhere, including CI's ubuntu-latest `tests` job.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

DISPLAY_SH="$DOTS_DIR/config/dwm/bin/dwm-display"
[[ -f "$DISPLAY_SH" ]] || {
    red "missing: $DISPLAY_SH"
    exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

rc=0
pass() { green "  ok: $1"; }
fail() {
    red "  FAIL: $1"
    rc=1
}

cat >"$TMP/bin/notify-send" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$TMP/notify.log"
EOF
chmod 755 "$TMP/bin/notify-send"

# Writes a fake xrandr whose no-argument output is $1 (real xrandr's format:
# "<name> connected|disconnected ..."). With arguments it logs the call instead
# of touching any display.
fake_xrandr() {
    cat >"$TMP/bin/xrandr" <<EOF
#!/bin/sh
if [ \$# -eq 0 ]; then
    cat <<'SCREENS'
$1
SCREENS
    exit 0
fi
printf 'xrandr %s\n' "\$*" >> "$TMP/applied.log"
EOF
    chmod 755 "$TMP/bin/xrandr"
}

TWO_MONITORS='Screen 0: minimum 320 x 200, current 3840 x 1080, maximum 16384 x 16384
eDP-1 connected primary 1920x1080+0+0 (normal left inverted right) 344mm x 194mm
HDMI-1 connected 1920x1080+1920+0 (normal left inverted right) 530mm x 300mm
DP-2 disconnected (normal left inverted right)'

ONE_MONITOR='eDP-1 connected primary 1920x1080+0+0 (normal left inverted right) 344mm x 194mm
DP-2 disconnected (normal left inverted right)'

menu() { PATH="$TMP/bin:$PATH" bash "$DISPLAY_SH" --list; }

# --- derivation from what is actually connected -----------------------------

blue "==> menu derivation"

fake_xrandr "$TWO_MONITORS"
labels="$(menu | cut -f1)"

if grep -q 'DP-2' <<<"$labels"; then
    fail "the DISCONNECTED output DP-2 leaked into the menu"
else
    pass "disconnected outputs are excluded"
fi

for want in "only eDP-1" "only HDMI-1" "extend HDMI-1 right of eDP-1" \
    "extend HDMI-1 left of eDP-1" "mirror HDMI-1 onto eDP-1" "all on (auto)"; do
    if grep -qxF "$want" <<<"$labels"; then
        pass "offers '$want'"
    else
        fail "missing menu entry '$want'"
    fi
done

# "only X" must disable every other output, and do it in ONE xrandr call — a
# second call would leave the server briefly with nothing enabled.
only_cmd="$(menu | awk -F'\t' '$1 == "only eDP-1" { print $2 }')"
if [[ "$only_cmd" == *"--output HDMI-1 --off"* ]]; then
    pass "'only eDP-1' switches HDMI-1 off"
else
    fail "'only eDP-1' leaves HDMI-1 enabled: $only_cmd"
fi
if [[ "$(grep -c 'xrandr' <<<"$only_cmd")" == 1 && "$only_cmd" == xrandr\ * ]]; then
    pass "'only eDP-1' is a single xrandr invocation"
else
    fail "'only eDP-1' is not one xrandr call: $only_cmd"
fi

# Every preset must name a primary. Without --primary, xrandr can leave the
# screen with no primary output at all, which decides where dwm puts its bar
# and where new windows land — a silent, cosmetic-looking regression that no
# other assertion here would notice.
for entry in "only eDP-1" "extend HDMI-1 right of eDP-1" "mirror HDMI-1 onto eDP-1"; do
    cmd="$(menu | awk -F'\t' -v e="$entry" '$1 == e { print $2 }')"
    if [[ "$cmd" == *"--primary"* ]]; then
        pass "'$entry' sets a primary output"
    else
        fail "'$entry' sets no --primary: $cmd"
    fi
done

# --- a single monitor must not be offered arrangements ----------------------

blue "==> single-monitor machine"

fake_xrandr "$ONE_MONITOR"
solo="$(menu | cut -f1)"
if [[ "$(wc -l <<<"$solo")" -eq 1 && "$solo" == "only eDP-1" ]]; then
    pass "one connected output offers exactly one entry"
else
    fail "single monitor offered: $(tr '\n' '|' <<<"$solo")"
fi

# --- autorandr profiles come first ------------------------------------------

blue "==> autorandr integration"

fake_xrandr "$TWO_MONITORS"
cat >"$TMP/bin/autorandr" <<'EOF'
#!/bin/sh
[ "$1" = "--list" ] && { echo docked; echo mobile; }
EOF
chmod 755 "$TMP/bin/autorandr"

first_two="$(menu | cut -f1 | head -2 | tr '\n' '|')"
if [[ "$first_two" == "profile: docked|profile: mobile|" ]]; then
    pass "saved profiles are listed before the generated presets"
else
    fail "profiles not first — menu starts: $first_two"
fi
if [[ "$(menu | awk -F'\t' '$1 == "profile: docked" { print $2 }')" == "autorandr --load docked" ]]; then
    pass "a profile entry loads that profile"
else
    fail "profile entry has the wrong command"
fi

rm -f "$TMP/bin/autorandr"
if menu | grep -q '^profile: '; then
    fail "profiles still offered with autorandr absent"
else
    pass "degrades cleanly when autorandr is not installed"
fi

# --- selection actually applies, and Escape does not ------------------------

blue "==> selection dispatch"

: >"$TMP/applied.log"
printf '#!/bin/sh\ngrep -x "mirror HDMI-1 onto eDP-1"\n' >"$TMP/bin/dmenu"
chmod 755 "$TMP/bin/dmenu"
if PATH="$TMP/bin:$PATH" bash "$DISPLAY_SH" >/dev/null 2>&1; then
    if grep -qF -- "--output HDMI-1 --auto --same-as eDP-1" "$TMP/applied.log"; then
        pass "choosing an entry runs exactly that entry's xrandr command"
    else
        fail "wrong command applied: $(cat "$TMP/applied.log")"
    fi
else
    fail "selecting a valid entry exited non-zero"
fi

# Escape: dmenu exits non-zero having printed nothing. That is an ordinary way
# to dismiss the menu, so it must be a clean exit 0 with nothing applied.
: >"$TMP/applied.log"
printf '#!/bin/sh\nexit 1\n' >"$TMP/bin/dmenu"
chmod 755 "$TMP/bin/dmenu"
if PATH="$TMP/bin:$PATH" bash "$DISPLAY_SH" >/dev/null 2>&1; then
    if [[ -s "$TMP/applied.log" ]]; then
        fail "Escape applied something: $(cat "$TMP/applied.log")"
    else
        pass "Escape exits 0 and applies nothing"
    fi
else
    fail "Escape should exit 0, not report an error"
fi

# --- no connected outputs at all --------------------------------------------

fake_xrandr 'DP-2 disconnected (normal left inverted right)'
if PATH="$TMP/bin:$PATH" bash "$DISPLAY_SH" --list >/dev/null 2>&1; then
    fail "no connected outputs should be an error, not an empty menu"
else
    pass "no connected outputs fails loudly"
fi

if ((rc != 0)); then
    red "✗ dwm-display is broken"
    exit 1
fi
green "✓ dwm-display: derivation, single-monitor, autorandr ordering and dispatch"
