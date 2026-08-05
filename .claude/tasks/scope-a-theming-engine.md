# Scope A — dark-mode-only theming engine (wallbash-for-X11)

Epic decomposition per `.claude/rules/foundations/task-planning.md` §
"Any -> Epic". Source request: user spec dated 2026-08-05 (full text in
that day's chat, not re-copied here — see the dated change log this
sub-task produces for a summary).

Note on "layers": this repo has no FSD layers (it's a bash/C dotfiles
repo, not a frontend app). "Layers" below means subsystem areas:
`suckless/<tool>` (C + patches), `scripts/theme/` (bash), `config/theme/`
(templates/config), `packages/` (dnf lists), `docs/` (markdown),
`scripts/install-*.sh` + `uninstall.sh` (integration).

---

## Sub-task 1 — xresources patches (dwm, st, dmenu, slock)

- Scope: `suckless/dwm/patches/`, `suckless/dwm/{dwm.c,config.h}`,
  `suckless/st/patches/`, `suckless/st/{st.c,config.h}`,
  `suckless/dmenu/patches/`, `suckless/dmenu/{dmenu.c,config.h}`,
  `suckless/slock/` (patch or generated-header fallback), one
  `PATCHES.md` per tool.
- Highest-risk sub-task: dwm's xresources patch must be hand-merged
  against 5 already-applied patches (status2d, systray, statuscmd,
  pertag, + others) — real `.c`/`.h` conflict resolution, not a
  mechanical `patch -p1`. st needs the xresources-signal-reload variant
  specifically (USR1 live reload), not the plain xresources patch.
- Exit: `make` succeeds for all 4 tools; PATCHES.md documents every
  manual merge decision.
- Est. sessions: 1-2 (dwm merge may spill into a second session if
  conflicts are extensive).

## Sub-task 2 — color extraction (colorgen.sh)

- Scope: `scripts/theme/colorgen.sh`.
- ImageMagick-only quantization/histogram extraction; HyDE dcol key
  naming (`dcol_pry1..4`, `dcol_txt1..4`, `dcol_1xa1..dcol_4xa9`, `_rgba`
  variants); hardcoded dark-mode floor on `pry1` luminance; cache keyed
  on wallpaper path+mtime hash under `~/.cache/dots/theme/`.
- Depends on: nothing from Sub-task 1 (independent; can reorder if useful).
- Est. sessions: 1.

## Sub-task 3 — template engine (apply-templates.sh)

- Scope: `scripts/theme/apply-templates.sh`.
- Parses `target_path|post_command` header line + `${confDir}`/`${cacheDir}`
  expansion + `<wallbash_NAME>` placeholder substitution from the
  Sub-task 2 palette; processes `config/theme/templates/always/` and
  `config/theme/templates/theme/` groups.
- Depends on: Sub-task 2's `.dcol` key names (must match placeholder
  vocabulary).
- Est. sessions: 1.

## Sub-task 4 — templates + base configs

- Scope: `config/theme/templates/{always,theme}/*.dcol`,
  `config/dunst/dunstrc` (new base config), `config/picom/picom.conf`
  (new base config), gtk.css template, statusbar-colors.sh template.
- 5 templates: xresources.dcol, dunst.dcol, picom.dcol, gtk.dcol,
  statusbar.dcol (status2d escapes for dwmblocks).
- Depends on: Sub-task 1 (needs final dwm/st/dmenu xresources resource
  names) and Sub-task 3 (engine must exist to test templates against).
- Est. sessions: 1-2.

## Sub-task 5 — atomic reload (reload.sh)

- Scope: `scripts/theme/reload.sh`.
- Ordered: xrdb -merge first, then parallel HUP dwm / USR1 st / restart
  dwmblocks / restart dunst / reload picom / re-run ~/.fehbg. Every step
  guards on "is it running/installed" — skip + log, never fail.
- Depends on: Sub-tasks 1, 3, 4 (needs real targets to reload).
- Est. sessions: 1.

## Sub-task 6 — user commands + keybinds

- Scope: `scripts/theme/wallpaper.sh`, `scripts/theme/theme-apply.sh`,
  `suckless/dwm/config.h` (keybind snippet as a comment block, since
  dwm's actual config.h is user-built — don't force a rebuild), a
  `KEYBINDINGS.md` update or creation if one doesn't exist yet (per repo
  state it doesn't — see CLAUDE.md "Still genuinely pending").
- dmenu-driven `--select` wallpaper picker (NOT rofi) mirroring the
  existing `config/dwm/bin/dwm-*` pattern.
- Depends on: Sub-tasks 2, 3, 5.
- Est. sessions: 1.

## Sub-task 7 — static dark theme + packaging + docs

- Scope: `themes/dark/{colors.dcol,theme.conf,wallpapers/README.md,CREDITS.md}`,
  `packages/extra.lst` or `core.lst` additions (ImageMagick, feh, dunst,
  picom, papirus-icon-theme, gtk-murrine-engine — verified against
  packages.fedoraproject.org per repo rule 8), `scripts/install-restore.sh`
  / `symlinks.sh` hook for template+theme deployment, `scripts/uninstall.sh`
  manifest registration, `docs/THEMING.md`.
- Depends on: everything above (this is the integration + packaging pass).
- Est. sessions: 1-2.

---

## Execute in order

1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 (2 and 1 could swap order with no cost;
sequence otherwise follows real dependencies, not just the user's
part numbering).

One sub-task per session (may span 2 sessions for sub-tasks 1 and 7 if
conflicts/verification run long). Each sub-task gets its own slot
worktree (`.claude/worktrees/theming-sub-N/` on `slot/theming-sub-N`),
its own `/plan` -> `/code` -> audit-loop -> reviewer -> `/commit` pass,
and its own dated change log. Merge to `main` after each sub-task before
starting the next, so later sub-tasks build on real (not staged) state —
sub-tasks 3-7 have real file/name dependencies on earlier ones.

## Out of scope (explicitly, per user request)

- No Wayland templates (waybar, hyprlock, swaync, rofi) — X11/dwm only.
- No light theme, no mode-switching UI — dark mode is hardcoded.
- No pywal/wallust — ImageMagick only.
- No rofi anywhere — dmenu only, matching existing repo convention.
