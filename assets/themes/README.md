# assets/themes — vendored GTK theme shims

## Adwaita-dark (GTK3)

`Adwaita-dark/gtk-3.0/gtk.css` is one line, copied verbatim from
[gnome-themes-extra](https://gitlab.gnome.org/GNOME/gnome-themes-extra)
(`themes/Adwaita-dark/gtk-3.0/gtk.css`, last changed upstream in `5a09becd`,
2016-10-04; LGPL-2.1, the project's `LICENSE`):

```css
@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");
```

It names a stylesheet compiled **into libgtk-3 itself**, so it needs nothing
else installed. That is all gnome-themes-extra ever provided for GTK3's
`Adwaita-dark`.

**Why it is vendored.** Every `themes/*/theme.conf` sets
`gtk_theme=Adwaita-dark`. Fedora 44 retired gnome-themes-extra, and GTK 3.24
has no built-in theme by that name. In `gtk/gtkcssprovider.c`,
`_gtk_css_provider_load_named` retries an unresolved name *without* the
variant, then falls back to plain Adwaita. So GTK3 apps came up **light**, and
the `gtk-application-prefer-dark-theme=1` in `settings.ini` was discarded with
the rest. GTK4 is unaffected: it treats `Adwaita-dark` as a built-in alias for
its dark default. That is why the name was kept rather than changed to
`Adwaita`, which would have turned plain GTK4 apps light.

**How it is used.**

- `scripts/install-restore-gtk3-shim.sh` copies the directory to
  `~/.local/share/themes/Adwaita-dark`, only when nothing is there already. A
  real Adwaita-dark you install yourself wins.
- The copy is claimed as a THEME manifest row, so `dots uninstall` removes it.
- Flatpak apps see it through the `xdg-data/themes:ro` override in
  `scripts/install-restore-flatpak.sh`.
- `tests/gtk3-adwaita-dark-shim.sh` checks, where `gresource` and libgtk-3
  are available, that the imported resource still exists.
