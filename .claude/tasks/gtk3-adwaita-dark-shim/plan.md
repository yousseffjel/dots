# Plan — gtk3-adwaita-dark-shim

## Goal
Make `gtk_theme=Adwaita-dark` resolve in GTK3 again, on the host and inside
Flatpak. Fedora 44 retired gnome-themes-extra, whose Adwaita-dark/gtk-3.0 was
one @import of GTK3's built-in gtk-contained-dark.css; without it GTK 3.24
falls back to LIGHT Adwaita and drops prefer-dark. Restore that shim; GTK2 and
GTK4 (which aliases Adwaita-dark itself) stay exactly as they are.

## Scope
- assets/themes/**, scripts/install-restore-*.sh, scripts/doctor*.sh
- tests/**, themes/*/theme.conf, packages/extra.lst
- docs/**, CLAUDE.md, CHANGELOG.md, TESTING.md, HANDOFF.md, .claude/tasks/**

## Allowed

## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. assets/themes/Adwaita-dark/gtk-3.0/gtk.css (the one @import, verbatim from gnome-themes-extra) + README with source and licence
2. NEW install-restore-gtk3-shim.sh, sourced by install-restore-theme.sh like the cursor: copy to ~/.local/share/themes/Adwaita-dark only when absent; THEME row; dry-run; a theme of the user's own is left alone
3. FLATPAK_GRANTS += xdg-data/themes:ro, so sandboxed GTK3 finds it; flatpak tests' expected sets updated
4. dots doctor: warn when theme.conf's gtk_theme is Adwaita-dark and no gtk-3.0 theme dir by that name exists (user or system)
5. Tests: NEW tests/gtk3-adwaita-dark-shim.sh (deploy, user's own kept, re-run, uninstall, dry-run; the imported resource exists in libgtk-3 when gresource is available); symmetry + doctor sandboxes
6. Docs: theme.conf comments x4, extra.lst, THEMING.md, CLAUDE.md, HANDOFF.md, UNINSTALL.md, CHANGELOG, TESTING.md; scope-e decision 11

## Out of scope
- Portal session target (next slot); flatpak exports/bin on PATH (Micro)
- Renaming gtk_theme to Adwaita (rejected: breaks GTK4's alias)

## Risks
- GTK3 in Flatpak may not search the per-app data dir for xdg-data/themes — verify on the VM (Mousepad dark with no GTK_THEME)
- install-restore-theme.sh at 221/250 — only a source + call line added there
