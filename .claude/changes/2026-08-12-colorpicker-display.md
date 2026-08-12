# colorpicker-display
Date: 2026-08-12
Files: 13 | Lines: +541/-14

## What changed

- **`config/dwm/bin/dwm-colorpicker`** (111 lines, `Super+c`) — reads the pixel
  under the pointer and puts its hex on the clipboard with a dunst swatch.
  `xdotool getmouselocation` -> `maim -g 1x1` -> ImageMagick -> `xclip`.
- **`config/dwm/bin/dwm-display`** (128 lines, `Super+d`) — dmenu layout menu.
  autorandr's saved profiles first when it has any, then presets **derived from
  `xrandr` at run time**, never hardcoded.
- **`xdotool` in `desktop.lst`** (the picker's only new dependency) and
  **`gpick` in `extra.lst`** as the optional full palette tool.
- **Two sxhkd binds**, plus `KEYBINDINGS.md` and `CLAUDE.md`.
- **ROADMAP §3 reconciled and §9 marked closed** — see Why.

## Why

Epic scope-c sub-task 4, which closes the Epic. These were the last two `❌ add`
rows in ROADMAP §3.

The picker is a script rather than a package because **ROADMAP named a package
that does not exist**: there is no `xcolor` in Fedora, only `texlive-xcolor`, a
LaTeX package. Everything the script needs was already installed for the
screenshot and theming features — maim, ImageMagick, xclip, libnotify — so the
real cost was one dependency, `xdotool`, for `getmouselocation` alone.

`dwm-display` exists because autorandr and arandr solve different halves and
neither is the keybind. autorandr (sub-task 3) fingerprints monitors and
re-applies a profile on hotplug; arandr is a GUI for authoring a layout once,
and was rejected. What was missing between them was "put the displays how I
want them, now".

§3's status column had drifted badly enough to be misleading — the compositor
row still claimed nothing autostarts picom, fixed four days earlier — so the
whole column was re-verified against `packages/*.lst`, `config/`,
`scripts/install-session*.sh` and `suckless/*/patches/`. §9's priority list is
entirely done and is now labelled as a record rather than a backlog, pointing
at `MASTER_PLAN.md` as the real queue.

## Assumptions

- **Type B — presets derived from `xrandr`, not hardcoded.** Output names differ
  per machine and driver (`eDP-1` vs `eDP1` vs `LVDS-1`), so a fixed list would
  be wrong on the first laptop it met. Each "only <output>" entry disables the
  others **in the same xrandr call**, so the server never passes through a state
  with no output enabled.
- **Type B — `dwm-display` builds command strings and runs them word-split**,
  with a one-line scoped `SC2086` disable. Justified: the strings are built from
  xrandr output names, which cannot contain whitespace. Matches the scoped-
  disable practice already in `tests/tmux-tpm-lockstep.sh`.
- **Type C — no colours passed to dmenu.** Same as `dwm-powermenu`: dmenu reads
  them from the X resource database and explicit `-nb/-nf/-sb/-sf` would pin the
  menus to compiled-in colours and break theming.

## Test coverage

Full suite **10/10, exit 0** plus `tests/lint.sh --strict`. Annotated packages
32 -> 33; daemon count correctly unchanged at 9.

**The suite's green is necessary but not sufficient here, and that should be
said plainly: nothing in `tests/` exercises `config/dwm/bin/*` at all.** What
actually verified these two scripts was shimmed runs — and one of those shims
was wrong in a way that hid a total failure.

- `dwm-colorpicker`: hex extraction proven against **four** PNG variants —
  PNG32/RGBA, PNG24/RGB, PNG48/16-bit, PNG8/palette — all yielding correct
  6-digit hex. All four failure paths (dead X, garbage from xdotool, maim
  failing, unknown option) produce a named error and exit 1.
- `dwm-display`: menu derivation verified against a faked two-monitor xrandr
  (disconnected output excluded); single-monitor offers no extend/mirror
  entries; autorandr profiles list first; selection dispatch runs exactly the
  matching xrandr command; Escape exits 0 and runs nothing.
- Key freedom re-checked at code time: sxhkd holds `b, c, ctrl+r, ctrl+w, d, e,
  l, shift+w, w`; dwm compiles only `Mod4Mask|ShiftMask XK_x` and
  `Mod4Mask XK_v`. No overlap, no duplicates.
- Delivery path confirmed rather than assumed: `symlinks.sh:46` links
  `config/dwm` as a directory so new files ride along, and `.zshenv:28` puts
  `dwm/bin` on `$PATH`. Neither new name is shadowed in `~/.local/bin`.

**Unproven:** every external binary was shimmed. Neither script has met a real
pointer or a second monitor, and no `dnf`, Fedora box, live X session or CI run
was involved.

## Follow-ups

- **The reviewer BLOCKED round 1 on a real happy-path bug, and the lesson
  outlives it.** `%[hex:p{0,0}]` emits eight hex digits (RRGGBBAA) for maim's
  actual RGBA output, so the strict 6-digit validation rejected it and the
  picker would have failed *every time*. My test passed only because the fake
  `maim` wrote an RGB PNG — **the shim reproduced the real tool's interface but
  not its output format**, so it tested the code against a world that does not
  exist. Fixed with `-alpha off -depth 8`, which also covers the 16-bit case
  raised in the same review and independently reproduced as twelve digits. The
  strict check was deliberately kept so a future format change fails loudly.
  Round 2 confirmed `-alpha off` *discards* rather than composites — a
  semi-transparent pixel gives its true source RGB.
- **`config/dwm/bin/*` is the least test-covered surface in the repo** — nine
  scripts, zero tests. The picker's hex normalisation across PNG formats is
  exactly the kind of thing that regresses silently, and it would fit the
  existing shim-based test idiom (`tests/*-template.sh`) directly. Worth a
  queue item.
- **Another stale doc reference found and fixed:** CLAUDE.md credited `$PATH`
  setup to `20-path.zsh`, which does not exist — it is `.zshenv`, deliberately,
  since `conf.d` is interactive-only and dwm's autostart is not.
- **`sxhkd` has no parse-check mode.** `sxhkd -c <file> -n` is not a dry run; it
  launches the daemon and grabs keys. Attempted once here, killed by timeout,
  nothing disturbed — but do not retry it.
- Two ROADMAP §3 rows remain open **by decision, not omission**: a blue-light
  filter (undecided) and `xdg-desktop-portal-gtk` (deferred — only pays off with
  Flatpak; if ever added, the package alone is insufficient, see the row).
