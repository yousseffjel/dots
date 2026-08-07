# Progress — thunar-finalization

## Status
`complete`

## Steps
- [x] 1. `config/thunar/{thunarrc,uca.xml}` + `config/xfce4/helpers.rc`.
- [x] 2. `config/applications/dots-nvim.desktop` + `config/mimeapps.list`.
- [x] 3. `scripts/install-restore-apps.sh`: copy-deploy, no-clobber, APP manifest rows.
- [x] 4. Same file: guarded `xfconf-query -c thunar` preferences pass.
- [x] 5. `scripts/uninstall-apps.sh` + wire into `uninstall.sh`.
- [x] 6. `packages/extra.lst` += xfce4-settings; wire `restore_apps` into install-restore.sh.
- [x] 7. `docs/THUNAR.md` + verification.

## Deviations

- **Terminal integration re-asked mid-plan.** The user's first answer
  ("helpers.rc only, no package") rested on a premise disproven during
  exploration — Fedora's exo 4.20 no longer carries the helper framework, so
  the file would have been inert. Surfaced with the evidence and re-asked; the
  user chose to add `xfce4-settings` and wire both the built-in entry and a
  `uca.xml` action.

## Blockers

[none]
