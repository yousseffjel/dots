# theming-templates
Date: 2026-08-05
Files: 12 | Lines: +523/-3

## What changed
- Added the five `.dcol` templates the engine renders, all in
  `config/theme/templates/always/` (every one is purely color-driven, so
  every one must re-render on each wallpaper change):
  - **xresources.dcol** -> `${cacheDir}/xresources`, post `xrdb -merge`.
    Carries the generic `*.background/foreground/color0-15` plus every
    resource name sub-task 1's C patches actually read: `dwm.norm*`/
    `dwm.sel*`, `st.background/foreground/cursorColor/color0-15`,
    `dmenu.background/foreground/selbackground/selforeground`, and
    `slock.initcolor/inputcolor/failedcolor`.
  - **dunst.dcol** -> `${confDir}/dunst/dunstrc`, post: kill dunst (D-Bus
    activation respawns it on the next notification).
  - **picom.dcol** -> `${confDir}/picom/picom.conf`, post: `pkill -USR1`
    (in-place config reload).
  - **gtk.dcol** -> `${confDir}/gtk-3.0/gtk.css`, no post-command (GTK 3
    watches the file via GtkCssProvider).
  - **statusbar.dcol** -> `${cacheDir}/statusbar-colors.sh`, post:
    restart dwmblocks.
- Added base configs `config/dunst/dunstrc` and `config/picom/picom.conf`
  — the un-themed fallbacks, generated from the templates themselves
  against a static dark palette so they cannot drift from the real thing.
- Added `config/theme/templates/theme/README.md` explaining what belongs
  in the theme-switch-only group and why it is currently empty.
- Modified the 3 dwmblocks block scripts (`dwm-cpu`, `dwm-mem`,
  `dwm-clock`) to prefer the generated palette over their static one.
- One engine fix in `scripts/theme/apply-templates.sh`: generated files
  now get umask-derived permissions instead of `mktemp`'s 0600.

## Why
Sub-task 4 of `.claude/tasks/scope-a-theming-engine.md` — the templates
are what turn a `colors.dcol` palette into actual themed applications.

## Key Technical Decisions
**Spec/repo conflict on the statusbar contract, resolved by satisfying
both.** The spec asks for `STATUS_FG`/`STATUS_ACCENT1..4` as status2d
escape strings (`^c#RRGGBB^`). The existing block scripts in
`suckless/dwmblocks/scripts/` instead source `COL_CPU`/`COL_MEM`/
`COL_CLOCK` as raw `#RRGGBB` from a static `dwm-colors` file and build
the escape themselves. Emitting only `STATUS_*` would have made the
template inert — nothing consumes those names, so the bar would never
re-theme despite the file being written. The generated file therefore
emits both schemes, and each block script gained a
prefer-generated-then-fall-back-to-static lookup. Verified both paths:
themed `#89B4FA` with the palette present, static `#5294e2` without it.

**Base configs are copied, never symlinked.** `config/dunst` and
`config/picom` must stay out of `symlinks.sh`'s directory-linking
behavior (CLAUDE.md rule 7): the templates write the *whole* file to
`~/.config/...`, so a symlink would make every wallpaper change write
back into the git repo. Recorded in a comment at the top of each base
config and each template so a future symlinks.sh change cannot miss it.
Neither dunst nor picom supports an include directive, which is why the
whole file is generated rather than a colors fragment.

**ANSI color mapping is coherence-first, not hue-accurate.** A
wallpaper-derived palette has no inherent red/green/blue. The 16 ANSI
slots are filled from the four primaries' accent ramps so terminals look
consistent and stay readable; a program that hardcodes "color1 is red"
gets a palette-appropriate tint instead. Documented in the template.

## Assumptions
- **Type B** — all five templates live in `always/`, leaving `theme/`
  empty. Alternative considered: split some into `theme/` to match the
  spec's two-group phrasing — rejected because every one of the five is
  driven purely by wallpaper colors, so a theme-only template would
  render identically on every wallpaper and just skip needed updates.
  `theme/README.md` records what would genuinely belong there (anything
  keyed off `theme.conf`'s gtk/icon/cursor/font names). If incorrect:
  move the file between directories, no code change needed.

## Test coverage
Validated against the real parsers rather than by inspection — which is
what caught every bug below.
- Full pipeline live: `colorgen.sh <wallpaper>` -> `colors.dcol` ->
  `apply-templates.sh all` -> all 5 targets rendered.
- `xrdb -merge` completely silent, and `xrdb -query` afterwards confirmed
  to contain the exact resource names the C patches read (cross-checked
  against the `resources[]` arrays in `suckless/{dwm,dmenu,slock}/
  config.def.h` and st's `XRESOURCE_LOAD_*` calls).
- `dunst --config` and `picom --diagnostics` both parse the rendered
  configs *and* the repo-side base copies without error.
- Block scripts executed both with and without the generated palette.
- Repo CI (`bash tests/lint.sh`: shellcheck + shfmt + markdownlint)
  passes.
- Reviewer subagent independently re-ran all of the above plus a
  zero-`<wallbash_`-survivors check and a contrast sanity pass: READY.

### Bugs found and fixed during this sub-task
1. **`xrdb` pipes the file through `cpp`.** A comment containing
   `suckless/*/patches/` opened a C block comment that was never closed,
   making the whole merge fail with "unterminated comment". Apostrophes
   ("tool's", "primaries'") then opened character literals, producing
   warnings on every wallpaper change. Both classes are now avoided and
   the constraint is documented in the template so it cannot regress.
2. **Generated configs were mode 0600.** `mktemp` creates 0600 and `mv`
   preserves it, so every themed config landed user-only-readable. Fixed
   in `apply-templates.sh` by re-applying the umask-derived mode.
3. **Deprecated picom syntax.** `"_GTK_FRAME_EXTENTS@:c"` in
   shadow-exclude produced a deprecation warning; the `:c` type specifier
   is obsolete.

## Follow-ups
- Sub-task 5 (`reload.sh`) supersedes the per-template post-commands for
  the ordered/atomic reload; the post-commands stay as the correct
  behavior when a single template is rendered on its own.
- Sub-task 7 must deploy `config/dunst/dunstrc` and
  `config/picom/picom.conf` by **copy** (not symlink) and register both
  in the uninstall manifest. The reviewer confirmed no installer script
  copies them yet — that is this deferral, not a gap introduced here.
- `config/gtk-3.0/settings.ini` (dark GTK theme name + Papirus-Dark
  icons) is sub-task 7's packaging work; gtk.dcol only supplies accents.
