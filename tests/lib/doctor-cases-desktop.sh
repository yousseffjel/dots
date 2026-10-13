#!/usr/bin/env bash
# The desktop-integration cases of tests/doctor.sh (notifications, portal,
# GTK3 theme, cursor, flatpak) — SOURCED by it, never run alone (tests/lib/ is
# outside run-tests.sh's depth-1 glob). Uses that file's tsv/row/check
# helpers and the sandbox from doctor-sandbox.sh; split off at the 250-line
# cap.

blue "==> notifications (dunst)"
tsv
check "healthy: dunst answers" row ok session notifications
check "xdg-user-dirs-update is a one-shot, never 'running' or 'not started'" \
    grep -q 'runs once at login' <(detail daemon-xdg-user-dirs-update)
FAKE_DUNST=true tsv
check "do not disturb left on warns, naming the key" grep -q 'Super+Shift+n' <(detail notifications)
check "...as a warn, not a fail" row warn session notifications
FAKE_DUNST=dead tsv
check "a dunst that does not answer warns" grep -q 'does not answer' <(detail notifications)
FAKE_NO_DWM=1 tsv
check "no dwm session: no notification row at all" no_row '[a-z]+' session notifications

blue "==> desktop portal"
tsv
check "healthy: the portal answers dark" row ok theme portal
FAKE_PORTAL=dead tsv
check "a portal that does not answer warns, quoting why" grep -q 'startup job failed' <(detail portal)
FAKE_PORTAL=light tsv
check "a portal answering light warns" row warn theme portal
FAKE_GST=inactive tsv
check "no graphical-session.target, no dots-session.target in ~/.xinitrc: names the fix" \
    grep -q 'does not start dots-session.target' <(detail session-target)
check "...and does not also ask the portal" no_row '[a-z]+' theme portal
printf 'systemctl --user start dots-session.target\n' >"$H/.xinitrc"
FAKE_GST=inactive tsv
check ".xinitrc already starts it: just log out and in" grep -q 'log out and back in' <(detail session-target)
rm -f "$H/.xinitrc"
DISPLAY_SET="" tsv
check "no X: the portal check skips" row skip theme portal

blue "==> GTK3 theme"
SHIM="$H/.local/share/themes/Adwaita-dark"
mv "$SHIM" "$SB/shim.bak"
tsv
check "an Adwaita-dark nothing provides warns" row warn theme gtk3
check "...saying GTK3 falls back to light" grep -q 'fall back to light Adwaita' <(detail gtk3)
INI="$H/.config/gtk-3.0/settings.ini"
cp "$INI" "$SB/ini.bak"
sed -i 's/^gtk-theme-name=.*/gtk-theme-name=Adwaita/' "$INI"
tsv
check "plain Adwaita is built in, ok without a theme dir" grep -q 'built into GTK' <(detail gtk3)
cp "$SB/ini.bak" "$INI"
mv "$SB/shim.bak" "$SHIM"

blue "==> non-GTK cursor"
want="$(sed -n 's/^gtk-cursor-theme-name=//p' "$INI")"
check "the installer's index.theme alone is ok" grep -q "same cursor as GTK ($want)" <(detail cursor)
FAKE_XCURSOR=Other-Cursor tsv
check "an Xcursor.theme unlike GTK's warns, naming it" grep -q "'Other-Cursor', GTK uses $want" <(detail cursor)
IDX="$H/.local/share/icons/default/index.theme"
mv "$IDX" "$SB/idx.bak"
FAKE_XCURSOR="$want" tsv
check "a matching Xcursor.theme is ok on its own" row ok session cursor
tsv
check "neither set: warns, the X default" grep -q "'the X default'" <(detail cursor)
mv "$SB/idx.bak" "$IDX"

blue "==> flatpak"
G="$H/.local/share/flatpak/overrides/global"
cp "$G" "$SB/global.bak"
sed -i 's|xdg-config/gtk-3.0:ro;||' "$G"
tsv
check "a missing grant warns, naming it" grep -q 'cannot see xdg-config/gtk-3.0:ro' <(detail flatpak)
sed -i 's|^filesystems=|filesystems=xdg-config/gtk-3.0;|' "$G"
tsv
check "a grant set another way is the user's, and ok" grep -q 'your own way' <(detail flatpak)
cp "$SB/global.bak" "$G"
mv "$SB/fp/remotes" "$SB/remotes.bak" && : >"$SB/fp/remotes"
tsv
check "no Flathub remote warns" row warn theme flathub
mv "$SB/remotes.bak" "$SB/fp/remotes"
mv "$BIN/flatpak" "$SB/flatpak.bak"
tsv
check "no flatpak: one skip, no warn" row skip theme flatpak
check "...and still exit 0" rc_is 0
mv "$SB/flatpak.bak" "$BIN/flatpak"
