# Context — xsettingsd-theming

## Background
Scope C sub-task 2. The user chose to keep xsettingsd after being told the
rationale originally given for it was wrong — see Prior Decisions. Proceeding on
the narrower case they accepted, not the one first pitched.

## Prior Decisions
- `.claude/tasks/scope-c-roster-gap-fill.md` locked decision 2 — **read it
  first.** xsettingsd is NOT here to make wallpaper re-theming live: `gtk.dcol`
  writes `gtk.css`, and its own header records that GTK 3 re-reads that file via
  `GtkCssProvider` (which is why it has no post-command). XSETTINGS carries
  theme/icon/cursor/font from `themes/dark/theme.conf`, which is static — one
  theme, dark-only per Scope A. XSETTINGS also has no CSS channel. The accepted
  case is Xft centralisation + future-theme proofing.
- Therefore **not a `.dcol` template**: content derives from theme.conf, not the
  palette, so a per-wallpaper-change render would rewrite an unchanged file.
  `theme_write_gtk_ini` is the precedent to copy.
- CLAUDE.md rule 10 — `desktop.lst`'s trailing `#` comment is load-bearing
  consequence text, read back by `load_consequences()`; `tests/desktop-consequences.sh`
  fails the build without it.
- CLAUDE.md rule 6 — `autostart.sh` is user-owned once it exists; the installer
  only reports the needed line to someone who already has one.
- `manifest_has_path THEME <path>` (2026-08-12) is the no-clobber predicate to
  use; do not hand-roll a lookup.

## References
- `scripts/install-restore-theme.sh` — `theme_write_gtk_ini` (~35 lines) is the
  shape to mirror; `theme_claim_fastfetch` shows the mkdir-parent obligation.
- `scripts/theme/reload.sh:181-214` — `reload_picom` is the closest template
  (command -v guard, pkill, three-way say green/yellow). Targets run in
  **parallel** (`for step in …; do "$step" & done; wait`), so ordering is free.
- `scripts/install-session.sh:68-116` — the `command -v` + `pgrep -x` daemon
  pattern; `install-session-report.sh` must gain the matching branch.
- `tests/autostart-daemons.sh` — pairs the two sides by RUNNING both, not by
  parsing. It needed no change across the last file split; keep that property.
- `themes/dark/theme.conf` — gtk_theme=Adwaita-dark, icon_theme=Papirus-Dark,
  cursor_theme=Adwaita, cursor_size=24, font=JetBrains Mono 10.
- Memory: `dots-theming-engine-test-hazard`, `dots-test-sourcing-global-fn-helpers`.

## Notes
- Fedora: `xsettingsd` 1.0.2, in 43/44/Rawhide. Verified 2026-08-12.
- **Step 2 is already answered — verified against the local 1.0.2 binary, not
  assumed.** Run with a sandboxed `$XDG_CONFIG_HOME` and `DISPLAY=:99`, it
  printed `Loaded 1 setting from <XDG_CONFIG_HOME>/xsettingsd/xsettingsd.conf`
  before failing on the X connection. Three things follow:
  1. It **does** honour `$XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf`. The
     `--help` text claiming `~/.xsettingsd` is stale. So the file goes where
     every other config in this repo goes, and the autostart line needs **no
     `-c` flag** — which removes what would otherwise have been a two-places-
     must-agree coupling between install-session.sh and install-restore-theme.sh.
  2. The `Key/Name "value"` form parses. Strings quoted, integers bare.
  3. Config is read **before** the X connection, so it is safe to syntax-check
     a generated file with `DISPLAY=:99` in a test without touching a live
     session — the same trick the template tests use for pkill.
- Open for step 4: 223 + ~35 ≈ 258 > 250. Expect the split. The seam old queue
  item 1 named was the manifest predicates vs the deploy/claim/backup writers;
  those predicates are now gone, so re-derive the seam rather than reusing it.
