# Progress — flatpak-integration

## Status
`in-progress`

## Steps
- [x] 1. extra.lst: `flatpak` beside the portal block (name verified on mdapi f43+f44)
- [x] 2. NEW install-restore-flatpak.sh (sourced by install-restore-apps.sh): flathub remote --user + 3 grants, each only if absent; FLATPAK manifest rows; dry-run/no-binary paths
- [x] 3. NEW uninstall-flatpak.sh: drop our grants only if still present; remove flathub only if we added it and no ref uses it; wire into uninstall.sh
- [x] 4. Tests: NEW tests/flatpak-integration.sh (fake flatpak, sealed PATH, keyfile store); fake flatpak + sentinel in tests/lib/install-symmetry.sh
- [x] 5. dots doctor: flatpak grants check in doctor-session.sh (ok / warn / skip if no flatpak)
- [x] 6. Docs: CLAUDE.md rule 4 exception + map, UNINSTALL.md, CHANGELOG, ROADMAP, TESTING.md (+ missing color-scheme.sh entry)

## Deviations
- Step 2: install-restore-flatpak.sh is sourced by install-restore.sh (149 lines), not install-restore-apps.sh (220/250) — the orchestrator already sources each restore part. Shared keyfile readers (flatpak_override_file/grants/grant_for/grant_path) went into global_fn.sh beside dconf_cmd.

## Blockers
