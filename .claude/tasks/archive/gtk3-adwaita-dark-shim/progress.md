# Progress — gtk3-adwaita-dark-shim

## Status
`in-progress`

## Steps
- [x] 1. assets/themes/Adwaita-dark/gtk-3.0/gtk.css (the one @import, verbatim from gnome-themes-extra) + README with source and licence
- [x] 2. NEW install-restore-gtk3-shim.sh, sourced by install-restore-theme.sh like the cursor: copy to ~/.local/share/themes/Adwaita-dark only when absent; THEME row; dry-run; a theme of the user's own is left alone
- [x] 3. FLATPAK_GRANTS += xdg-data/themes:ro, so sandboxed GTK3 finds it; flatpak tests' expected sets updated
- [x] 4. dots doctor: warn when theme.conf's gtk_theme is Adwaita-dark and no gtk-3.0 theme dir by that name exists (user or system)
- [x] 5. Tests: NEW tests/gtk3-adwaita-dark-shim.sh (deploy, user's own kept, re-run, uninstall, dry-run; the imported resource exists in libgtk-3 when gresource is available); symmetry + doctor sandboxes
- [x] 6. Docs: theme.conf comments x4, extra.lst, THEMING.md, CLAUDE.md, HANDOFF.md, UNINSTALL.md, CHANGELOG, TESTING.md; scope-e decision 11

## Deviations
- Step 3: the flatpak test's hard-coded counts/sets (3, ALL) now derive from FLATPAK_GRANTS — adding the 4th grant broke four of them.
- Added (not in plan): tests/lib/sealed-path.sh fake() hardened against symlink write-through, found by this slot's failed-copy case.

## Blockers
