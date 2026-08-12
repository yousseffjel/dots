# Plan — theme-roster-identity

## Goal
Ship Gruvbox Dark, Nord and Tokyo Night alongside `themes/dark`, and make a
theme switch apply the selected theme's *identity* (GTK/icon/cursor/font), not
just its palette. Today `theme.conf` is report-only in `theme-apply.sh:108` and
the installer reads it from a hardcoded `themes/dark/theme.conf`
(`install-restore-theme-identity.sh:35`), so per-theme identity would be inert
without this wiring.

## Scope
- `themes/**`
- `scripts/theme/theme-apply.sh`
- `scripts/install-restore-theme-identity.sh`
- `scripts/install-restore-theme.sh`
- `tests/theme-identity.sh`
- `docs/THEMING.md`, `themes/CREDITS.md`, `CLAUDE.md`, `TESTING.md`
- `config/theme/templates/theme/README.md`

## Allowed
- themes/
- scripts/theme/theme-apply.sh
- scripts/install-restore-theme-identity.sh
- scripts/install-restore-theme.sh
- tests/theme-identity.sh
- docs/THEMING.md
- CLAUDE.md
- TESTING.md
- config/theme/templates/theme/README.md

## Forbidden
- scripts/theme/colorgen.sh
- scripts/theme/apply-templates.sh
- config/theme/templates/always/
- suckless/

## Steps
1. Parameterize `THEME_CONF_REL` so both writers read a caller-chosen theme dir; prove the installer path byte-identical for `dark`.
2. Wire `theme-apply.sh` static mode to render identity from the selected theme, then confirm `reload.sh` already covers the HUP.
3. Generate `colors.dcol` for gruvbox / nord / tokyo-night via seed image + `colorgen.sh`.
4. Write each `theme.conf`, using only GTK/icon themes that `packages/*.lst` actually declares.
5. Add `tests/theme-identity.sh` (suite 12 -> 13) proving the *selected* theme's identity is what lands.
6. Update `docs/THEMING.md`, `themes/CREDITS.md`, `CLAUDE.md`.

## Out of scope
- Light mode — dark-only is a locked scope-a decision.
- Committing wallpapers (see `themes/dark/wallpapers/README.md`).
- A HyDE-style external theme patcher that clones theme repos.

## Risks
- Running `theme-apply.sh`/`reload.sh` on this dev box kills dunst/dwmblocks system-wide — verify at writer level under a sandboxed `$HOME`, never end-to-end.
- `reload.sh` is 235/250 lines — a change there may force a split.
- A per-theme GTK/icon name that no package provides falls back silently; step 4 constrains names to declared packages.
