# xsettingsd-theming
Date: 2026-08-12
Files: 14 | Lines: +385/-46

## What changed

- **`xsettingsd` declared in `packages/desktop.lst`** with its load-bearing
  consequence comment (rule 10). Verified in Fedora 43/44/Rawhide at 1.0.2.
- **New `theme_write_xsettingsd_conf`** renders
  `~/.config/xsettingsd/xsettingsd.conf` from `themes/dark/theme.conf`: the GTK
  theme identity (theme name, icons, cursor, font) plus `Xft/Antialias`,
  `Xft/Hinting`, `Xft/HintStyle` and `Xft/RGBA`. Same no-clobber rule as
  `theme_write_gtk_ini`, claimed in the manifest via `manifest_has_path THEME`.
- **`scripts/install-restore-theme.sh` split at 286 lines** — the theme.conf
  renderers (`theme_conf_get`, `theme_write_gtk_ini`,
  `theme_write_xsettingsd_conf`) moved to a new
  **`scripts/install-restore-theme-identity.sh`**. 193 + 121 lines.
- **`reload.sh` gains a 7th target**, `reload_xsettingsd` (`pkill -HUP`).
- **Autostart daemon set 6 -> 7** in `install-session.sh`, with its paired
  branch in `install-session-report.sh` and the roster in
  `tests/autostart-daemons.sh`.
- **`docs/THEMING.md` + `CLAUDE.md`** document what this does and — more
  importantly — what it does not.

## Why

Scope C sub-task 2. The user chose to keep xsettingsd **after** being told the
rationale originally given for it was wrong, so the honest version is recorded
here and in the scope file rather than quietly dropped.

**The wrong rationale, for the record:** xsettingsd was first pitched as
"closes a real hole — running GTK apps keep the old theme until restarted, so an
XSETTINGS daemon makes wallpaper re-theming live". That is false. The
wallpaper-driven GTK surface is `gtk.css`, and `gtk.dcol`'s own header already
recorded that GTK 3 re-reads it via `GtkCssProvider` — which is why that
template has no post-command. What XSETTINGS carries comes from
`themes/dark/theme.conf` and is static: one theme, dark-only per Scope A.
XSETTINGS also has no CSS channel, so even if that hot-reload claim were false
(it is stated as fact but was never verified here), xsettingsd could not fix it.

**The actual case, which is narrower and real:** the Xft font-rendering keys
live nowhere else in this repo — `xresources.dcol` carries colours only —  so
this is their first and only home, and it future-proofs a second theme or a
light mode without reworking the reload path.

The split was forced rather than chosen: adding the writer took the file to 286
of a 250-line cap. The seam is deliberate though. The parent file's remaining
job is *placement* (deploy a static config, claim a manifest path, back up what
the engine will overwrite); the new file's job is *rendering* one source into
two output formats. A third toolkit format belongs in the new file.

## Assumptions

- **Type B — not a `.dcol` template.** Every template under
  `templates/always/` re-renders per wallpaper change because its content is
  palette-derived; none of this is. A template would rewrite an identical file
  every time. `theme_write_gtk_ini` is the precedent — same source, same
  no-clobber rule, different output syntax. *If incorrect:* move the heredoc
  into an `xsettingsd.dcol` with a `${confDir}` target and drop the writer.
- **Type B — direct `xsettingsd &` with no `-c` flag.** Verified the binary
  reads `$XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf` unaided; its `--help`
  still claims `~/.xsettingsd` and is stale. Passing `-c` would restate the
  installer's path choice in a second file and create a lockstep hazard.
- **Type B — `Xft/DPI` deliberately omitted.** XSETTINGS wants 1024ths of an
  inch; hardcoding `96*1024` would override X's autodetection and render wrong
  on any HiDPI panel. *If incorrect:* add a `dpi=` key to `theme.conf` and read
  it, rather than hardcoding here.
- **Type C — sibling resolved from `BASH_SOURCE`**, matching
  `install-session.sh` rather than `install-restore.sh`'s caller-`SCRIPT_DIR`
  form, so a test can source the parent with no `SCRIPT_DIR` set.

## Test coverage

Full suite via TESTING.md's runner — **10/10, exit 0** — plus
`tests/lint.sh --strict` separately. Two counters moved, which is the signal the
changes are genuinely under test: daemons 6 -> 7, annotated packages 29 -> 30.

Verified against real binaries and sandboxes, not by reading:
- The generated config was loaded by **the real xsettingsd 1.0.2** ("Loaded 9
  settings"), and a deliberately malformed value was **rejected loudly**
  (`Unable to parse … Got invalid setting value`) — so a bad render cannot fail
  silently. Safe to run with `DISPLAY=:99` because the binary parses its config
  *before* connecting to X, which was confirmed first.
- Writer is idempotent — second run reports "already deployed by us".
- Guard works: with `themes/dark/theme.conf` absent, nothing is written.
- `uninstall.sh --yes` in a four-variable XDG sandbox removed the newly claimed
  path with **no change to uninstall** — it is generic over THEME rows.
- `reload.sh` fired `pkill -HUP -x xsettingsd` against a PATH shim; every
  mutating call hit a fake binary and dunst held PID 2652 throughout.
- **`tests/autostart-daemons.sh` caught the unpaired daemon by itself** before
  its roster was updated, and a mutant (deleting the report branch) reproduces
  that failure — the pairing guard is live, not decorative.
- The split is behaviour-preserving: the same sandbox script, which sources the
  parent with no `SCRIPT_DIR` set, produced identical output before and after.
  The reviewer re-ran this independently rather than taking it on trust.

**Not tested:** no real `dnf`, no Fedora box, no live X session, no GitHub
Actions. xsettingsd has never actually served settings to a running GTK app
here — only its config parsing and the wiring around it are proven.

## Follow-ups

- **Sub-task 3 must plan a function split.** `session_autostart_daemons()` is at
  **57 of 60 lines**; udiskie and autorandr add two more daemons to that exact
  function and will breach the cap. Plan it into that slot rather than
  discovering it mid-implementation, the way this slot's file split was planned.
- **The audit's best catch, worth remembering:** hoisting `theme_conf_get` out
  of `theme_write_gtk_ini` would have promoted `sed … | head -1` into shared
  use — a **fourth** instance of the SIGPIPE/pipefail trap this repo has already
  fixed three times. Rewritten pipe-free as `grep -m1`. When a helper is
  hoisted, its pipelines get re-examined, not just relocated.
- **Unverified claim now load-bearing in two places:** `gtk.dcol`'s header says
  GTK 3 re-reads `gtk.css` on its own, and `docs/THEMING.md` now repeats it.
  This repo elsewhere separates "verified" from "assumed" carefully (see the
  alacritty note in `templates/always/README.md`); this one is stated as fact
  and was never tested. Worth confirming on real hardware — change the wallpaper
  with a GTK app open and see whether its accent colours follow.
- Scope C sub-tasks 3 and 4 remain. Sub-task 1 (packages) is being folded into
  whichever sub-task needs each package, as planned.
