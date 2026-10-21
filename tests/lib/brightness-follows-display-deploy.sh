#!/usr/bin/env bash
# The dwm-display and restore-stage cases of tests/brightness-follows-display.sh
# — SOURCED by it, never run alone (tests/lib/ is outside run-tests.sh's
# depth-1 glob). Uses that file's pass/fail/calls helpers, $TMP, $LOG and $H;
# split off at the 250-line cap.

blue "==> dwm-display syncs after a preset"
D="$TMP/dbin"
seal_path "$D" bash awk grep cat
printf '#!/bin/sh\n:\n' >"$D/notify-send"
printf '#!/bin/sh\ngrep -x "mirror HDMI-1 onto eDP-1"\n' >"$D/dmenu"
printf '#!/bin/sh\necho "dwm-brightness $*" >>"%s"\n' "$LOG" >"$D/dwm-brightness"
cat >"$D/xrandr" <<EOF
#!/bin/sh
if [ \$# -eq 0 ]; then
    printf '%s\n' 'eDP-1 connected primary 1920x1080+0+0 (normal) 344mm x 194mm' \
        'HDMI-1 connected 1920x1080+1920+0 (normal) 530mm x 300mm'
    exit 0
fi
echo xrandr >>"$LOG"
exit \${FAKE_XRANDR_RC:-0}
EOF
chmod 755 "$D/notify-send" "$D/dmenu" "$D/dwm-brightness" "$D/xrandr"
: >"$LOG"
env -i HOME="$H" PATH="$D" bash "$DISPLAY_SH" >/dev/null 2>&1 || true
if [[ "$(calls)" == "xrandr|dwm-brightness sync|" ]]; then
    pass "sync runs after the layout applies"
else
    fail "after a preset: $(calls)"
fi
: >"$LOG"
env -i HOME="$H" PATH="$D" FAKE_XRANDR_RC=1 bash "$DISPLAY_SH" >/dev/null 2>&1 || true
if [[ "$(calls)" == "xrandr|" ]]; then
    pass "a failed layout runs no sync"
else
    fail "after a failed preset: $(calls)"
fi

blue "==> the restore stage deploys the hook"
# shellcheck source=install-symmetry.sh
source "$SCRIPT_DIR/lib/install-symmetry.sh"
make_fakes
R="$TMP/restored"
mkdir -p "$R"
if in_sandbox "$R" "$DOTS_DIR/scripts/install-restore.sh" >"$TMP/restore.log" 2>&1; then
    DEPLOYED="$R/.config/autorandr/postswitch.d/20-dots-brightness"
    if [[ -x "$DEPLOYED" && ! -L "$DEPLOYED" ]] && grep -qF "$DEPLOYED" "$R/.local/state/dots/manifest"; then
        pass "deployed as an executable copy and claimed in the manifest"
    else
        fail "20-dots-brightness not deployed as a claimed executable copy"
    fi
else
    fail "restore stage exited non-zero: $(tail -n 5 "$TMP/restore.log")"
fi
if [[ -s "$SENTINEL_LOG" ]]; then
    fail "a sentinel command ran: $(cat "$SENTINEL_LOG")"
fi
