# Context — xdg-portal-gtk

## Background
"What is next" item 4, 2026-10-06. ROADMAP §3 left xdg-desktop-portal-gtk deferred (only pays off with Flatpak); the user now asked for it, with the dark preference.

## Prior Decisions
- uninstall-apps.sh: xfconf prefs are NOT reverted because no prior state is recorded. The DCONF rows here avoid that: written only when the key was unset, reset only when unchanged.

## References
- xdg-desktop-portal portals.conf(5): ~/.config/xdg-desktop-portal/portals.conf is read when XDG_CURRENT_DESKTOP is unset
- xdg-desktop-portal-gtk 1.15.3 src/settings.c: color-scheme comes only from GSettings org.gnome.desktop.interface
