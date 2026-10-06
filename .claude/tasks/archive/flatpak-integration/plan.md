# Plan — flatpak-integration

## Goal
Install flatpak, add the Flathub remote (--user), and apply three read-only
`flatpak override --user` filesystem grants (user icons, gtk-3.0, fontconfig)
so Flatpak apps get the Bibata cursor, Papirus, and wallpaper gtk.css. Same
contract as the portal's DCONF rows: write only when absent, record what was
written, uninstall reverts only what is still ours. Decisions: scope-e file.

## Scope
- packages/extra.lst, scripts/install-restore-*.sh, scripts/uninstall*.sh, scripts/global_fn.sh, scripts/doctor*.sh
- tests/**, docs/**, CLAUDE.md, CHANGELOG.md, ROADMAP.md, TESTING.md, .claude/tasks/**

## Allowed

## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. extra.lst: `flatpak` beside the portal block (name verified on mdapi f43+f44)
2. NEW install-restore-flatpak.sh (sourced by install-restore-apps.sh): flathub remote --user + 3 grants, each only if absent; FLATPAK manifest rows; dry-run/no-binary paths
3. NEW uninstall-flatpak.sh: drop our grants only if still present; remove flathub only if we added it and no ref uses it; wire into uninstall.sh
4. Tests: NEW tests/flatpak-integration.sh (fake flatpak, sealed PATH, keyfile store); fake flatpak + sentinel in tests/lib/install-symmetry.sh
5. dots doctor: flatpak grants check in doctor-session.sh (ok / warn / skip if no flatpak)
6. Docs: CLAUDE.md rule 4 exception + map, UNINSTALL.md, CHANGELOG, ROADMAP, TESTING.md (+ missing color-scheme.sh entry)

## Out of scope
- GTK_THEME (dropped — scope-e decision 5); Flatseal; COPR uninstall
- Installing any Flatpak app or GTK theme extension

## Risks
- No unset-filesystem command — revert edits the global override keyfile; fixture must match real format
- Real overrides touched by a test — fake flatpak first on sealed PATH, sentinel
- install-restore-apps.sh at 220/250, symmetry test at 223 — new code in new files
