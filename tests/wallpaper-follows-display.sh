#!/usr/bin/env bash
# The wallpaper follows display changes (added 2026-10-05): the autorandr
# postswitch hook config/autorandr/postswitch.d/10-dots-wallpaper, and the
# re-paint config/dwm/bin/dwm-display (Super+d) does after a layout.
#
# WHY. feh paints the root window at the screen size of that moment. At every
# login ~/.xinitrc paints it, THEN autostart's `autorandr --change` switches
# to the saved layout — on the first VM install that left a 1280x800
# wallpaper in the corner of a 1920x1080 screen. The hook is the fix, and it
# only works if the installer puts it where autorandr looks, executable.
#
# HOW. Three parts, all RUN rather than parsed:
#   1. the shipped hook, under /bin/sh, against a sandbox HOME whose ~/.fehbg
#      is a fake that logs — present, absent, not executable;
#   2. the real restore stage (scripts/install-restore.sh) in a sandboxed HOME
#      via tests/lib/install-symmetry.sh, asserting the hook lands in
#      $XDG_CONFIG_HOME/autorandr/postswitch.d/, executable, as a COPY (a
#      symlink would send `autorandr --save` profiles into this repo), and
#      claimed in the manifest so uninstall removes it;
#   3. dwm-display with fake xrandr/dmenu and a sandbox HOME: re-paints AFTER
#      the layout, not on a failed one, and a failing ~/.fehbg is not an
#      error. Split out of tests/dwm-display.sh at the 250-line cap.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

HOOK="$DOTS_DIR/config/autorandr/postswitch.d/10-dots-wallpaper"
[[ -f "$HOOK" ]] || {
    red "missing: $HOOK"
    exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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
fails() { ! "$@"; }

blue "==> the hook re-runs ~/.fehbg"
H="$TMP/home"
mkdir -p "$H"
printf '#!/bin/sh\necho repainted >>"%s"\n' "$TMP/fehbg.log" >"$H/.fehbg"
chmod 755 "$H/.fehbg"
check "exits 0 with a ~/.fehbg" env -i HOME="$H" /bin/sh "$HOOK"
check "HOME/.fehbg ran" grep -qx repainted "$TMP/fehbg.log"

: >"$TMP/fehbg.log"
chmod 644 "$H/.fehbg"
check "exits 0 when ~/.fehbg is not executable" env -i HOME="$H" /bin/sh "$HOOK"
check "and does not try to run it" fails test -s "$TMP/fehbg.log"
rm -f "$H/.fehbg"
check "exits 0 with no ~/.fehbg at all" env -i HOME="$H" /bin/sh "$HOOK"

blue "==> the repo copy is executable (autorandr skips one that is not)"
check "config/autorandr/postswitch.d/10-dots-wallpaper is executable" test -x "$HOOK"
# Untracked (not yet committed) passes: the mode is checked once it is tracked.
git_mode_is_exec() {
    local m
    m="$(git -C "$DOTS_DIR" ls-files -s -- "$1" | cut -d" " -f1)"
    [[ -z "$m" || "$m" == 100755 ]]
}
check "git records it as 100755" git_mode_is_exec "config/autorandr/postswitch.d/10-dots-wallpaper"

blue "==> the restore stage deploys it"
# shellcheck source=lib/install-symmetry.sh
source "$SCRIPT_DIR/lib/install-symmetry.sh"
make_fakes
R="$TMP/restored"
mkdir -p "$R"
if in_sandbox "$R" "$DOTS_DIR/scripts/install-restore.sh" >"$TMP/restore.log" 2>&1; then
    green "  ok: restore stage ran"
else
    red "  FAIL: restore stage exited non-zero — tail of its log:"
    tail -n 15 "$TMP/restore.log"
    rc=1
fi
DEPLOYED="$R/.config/autorandr/postswitch.d/10-dots-wallpaper"
check "deployed to \$XDG_CONFIG_HOME/autorandr/postswitch.d/" test -f "$DEPLOYED"
check "deployed executable" test -x "$DEPLOYED"
check "deployed as a copy, not a symlink" fails test -L "$DEPLOYED"
check "HOME/.config/autorandr itself is not a symlink into the repo" fails test -L "$R/.config/autorandr"
check "claimed in the manifest (so uninstall removes it)" \
    grep -qF "$DEPLOYED" "$R/.local/state/dots/manifest"
check "no sentinel command ran" fails test -s "$SENTINEL_LOG"

blue "==> dwm-display re-paints after a layout"
# Fakes in the shape tests/dwm-display.sh uses: xrandr with no arguments
# prints real-format output, with arguments it logs the call; dmenu picks one
# entry; notify-send is silenced. HOME is the sandbox — the real ~/.fehbg
# would repaint the live desktop.
DISPLAY_SH="$DOTS_DIR/config/dwm/bin/dwm-display"
mkdir -p "$TMP/bin" "$TMP/home"
pass_() { green "  ok: $1"; }
fail_() {
    red "  FAIL: $1"
    rc=1
}
printf '#!/bin/sh\n:\n' >"$TMP/bin/notify-send"
cat >"$TMP/bin/xrandr" <<EOF
#!/bin/sh
if [ \$# -eq 0 ]; then
    printf '%s\n' 'eDP-1 connected primary 1920x1080+0+0 (normal) 344mm x 194mm' \
        'HDMI-1 connected 1920x1080+1920+0 (normal) 530mm x 300mm'
    exit 0
fi
printf 'xrandr %s\n' "\$*" >> "$TMP/applied.log"
EOF
chmod 755 "$TMP/bin/notify-send" "$TMP/bin/xrandr"
chmod 755 "$TMP/bin"/*

# The wallpaper is re-painted at the new size, AFTER the layout applies — feh
# painted the root window at the old size. Both fakes log to applied.log, so
# the order is visible.
printf '#!/bin/sh\necho fehbg >> "%s"\n' "$TMP/applied.log" >"$TMP/home/.fehbg"
chmod 755 "$TMP/home/.fehbg"
: >"$TMP/applied.log"
printf '#!/bin/sh\ngrep -x "mirror HDMI-1 onto eDP-1"\n' >"$TMP/bin/dmenu"
chmod 755 "$TMP/bin/dmenu"
HOME="$TMP/home" PATH="$TMP/bin:$PATH" bash "$DISPLAY_SH" >/dev/null 2>&1 || true
if [[ "$(tr '\n' '|' <"$TMP/applied.log")" == "xrandr "*"|fehbg|" ]]; then
    pass_ ".fehbg is re-run after the layout applies"
else
    fail_ "wallpaper not re-painted after the layout: $(tr '\n' '|' <"$TMP/applied.log")"
fi

# A failed layout must not touch the wallpaper; a failing ~/.fehbg must not
# turn a good layout into an error.
cat >"$TMP/bin/xrandr.fail" <<EOF
#!/bin/sh
[ \$# -eq 0 ] && { printf '%s\n' 'eDP-1 connected primary' 'HDMI-1 connected'; exit 0; }
exit 1
EOF
chmod 755 "$TMP/bin/xrandr.fail"
cp "$TMP/bin/xrandr" "$TMP/xrandr.ok"
cp "$TMP/bin/xrandr.fail" "$TMP/bin/xrandr"
: >"$TMP/applied.log"
HOME="$TMP/home" PATH="$TMP/bin:$PATH" bash "$DISPLAY_SH" >/dev/null 2>&1 || true
if grep -q fehbg "$TMP/applied.log"; then
    fail_ ".fehbg ran although the layout failed"
else
    pass_ "a failed layout leaves the wallpaper alone"
fi
cp "$TMP/xrandr.ok" "$TMP/bin/xrandr"
printf '#!/bin/sh\nexit 1\n' >"$TMP/home/.fehbg"
if HOME="$TMP/home" PATH="$TMP/bin:$PATH" bash "$DISPLAY_SH" >/dev/null 2>&1; then
    pass_ "a failing .fehbg does not fail the layout"
else
    fail_ "a failing .fehbg turned a good layout into an error"
fi
rm -f "$TMP/home/.fehbg"
if HOME="$TMP/home" PATH="$TMP/bin:$PATH" bash "$DISPLAY_SH" >/dev/null 2>&1; then
    pass_ "no .fehbg at all is fine"
else
    fail_ "a missing .fehbg turned a good layout into an error"
fi

if ((rc != 0)); then
    red "✗ wallpaper follows display"
    exit 1
fi
green "✓ wallpaper follows display: autorandr hook, its deployment, dwm-display re-paint"
