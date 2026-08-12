# Context — theme-roster-identity

## Background
Opened from `MASTER_PLAN.md ## Queue` -> "Framework parity with HyDE", item
"More than one theme under `themes/`", queued 2026-08-12 after diffing the local
HyDE clone (`8fa0073e`). `dwm-theme` already opens a dmenu picker over
`theme-apply.sh --list`, and that list has exactly one entry — the picker exists
with nothing to pick.

User decisions taken at `/plan` time (both are the fuller of the options offered):
- **Roster**: Gruvbox Dark + Nord + Tokyo Night (3 new, 4 total). Chosen for the
  widest visual spread from the existing Catppuccin-flavoured `dark`.
- **Identity**: wire it into the switch, rather than colours-only.

## Prior Decisions
- **Dark-only is locked** (scope-a, theming Epic). This task adds dark flavours;
  it does not add a light mode or a mode switch.
- **No wallpapers are committed** — `themes/dark/wallpapers/README.md` records
  why (size + redistribution licensing). New themes get no `wallpapers/` dir.
- **A theme is data, never code** — `themes/CREDITS.md`: the engine parses
  palettes and never sources them, and never `eval`s a template target path.
  Anything added here stays inert data.
- **`colors.dcol` is generated, not hand-written** — `themes/dark/colors.dcol`
  header records that it came out of `colorgen.sh` over a seed image built from
  Catppuccin Mocha's anchors, "so it is guaranteed to parse and to carry every
  key a template can reference (89 dcol_* entries)". Follow the same path.
- **Rule 10 / rule 8** — any new package name (e.g. a GTK or icon theme) must be
  declared in `packages/*.lst` and hand-verified against
  packages.fedoraproject.org. Preferred outcome: need no new packages.

## References
- `scripts/theme/theme-apply.sh:100-113` — static mode; `theme.conf` is printed
  and nothing more ("applying gtk-theme settings is sub-task 7's packaging work").
- `scripts/install-restore-theme-identity.sh:35` — `THEME_CONF_REL` hardcoded to
  `themes/dark/theme.conf`, read at 3 sites (`theme_conf_get` + both writers'
  existence guards).
- `scripts/install-restore-theme-identity.sh:46,95` — `theme_write_gtk_ini`,
  `theme_write_xsettingsd_conf`. Both depend on caller-provided `$DOTS_DIR`,
  `$CONF_HOME`, `$DRY_RUN` and the colour helpers — that coupling is the real
  integration cost of step 2.
- `scripts/theme/reload.sh:198` — comments that the xsettingsd config comes from
  `themes/dark/theme.conf`; already `pkill -HUP`s xsettingsd.
- `docs/THEMING.md:288-303` — the "Static themes" section that step 6 rewrites.
- `.claude/changes/2026-08-12-xsettingsd-theming.md` — where the identity split
  came from, including why `Xft/DPI` is deliberately omitted.

## Notes
- ImageMagick is available on this dev host (`/usr/bin/magick`), so step 3 runs
  locally.
- Line budgets before starting: `theme-apply.sh` 130, identity 127,
  `install-restore-theme.sh` 193, `reload.sh` **235** — the last is the one
  close to the 250 cap.
- Test fixtures in `tests/{starship,picom,fastfetch}-template.sh` hardcode
  `themes/dark/colors.dcol`. They are not in scope, but `themes/dark` must keep
  its name and format or three existing tests break.
- Hazard on file (memory): `apply-templates.sh` post-commands `pkill` dunst and
  dwmblocks system-wide, and env sandboxing does not stop them. Verification
  must stay at the identity-writer level.
