# Context — gtk3-adwaita-dark-shim

## Background
VM check of flatpak-integration (2026-10-06): Mousepad (Flatpak GTK3) rendered light; `--env=GTK_THEME=Adwaita:dark` rendered dark. Host /usr/share/themes has only Default/Emacs/Raleigh.

## Prior Decisions
- scope-e decision 11 (user, round 4): restore the shim, keep the name `Adwaita-dark`. Rejected: rename to `Adwaita` (plain GTK4 loses its alias; a managed gtk-4.0/settings.ini would make libadwaita warn on every start).

## References
- gtk-3-24 gtk/gtkcssprovider.c `_gtk_css_provider_load_named`: unresolved name -> retry without variant -> default Adwaita (light)
- gtk main gtk/gtkcssprovider.c: GTK4 accepts "Adwaita-dark" as an alias for Default:dark
- gnome-themes-extra themes/Adwaita-dark/gtk-3.0/gtk.css: `@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");`
- GTK3/GTK4 gdk/x11/gdksettings.c: no XSETTINGS key carries prefer-dark
- Pattern to mirror: scripts/install-restore-cursor.sh (THEME row on a directory; uninstall_theme rm -rf's it)

## Notes
- This bug predates Flatpak: it has affected native GTK3 apps on Fedora 44 since 2026-08-12, masked where gtk.css repaints.
