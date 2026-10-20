# visual-defaults
Date: 2026-10-05
Files: 16 | Lines: +436/-19 (14 modified + 2 new; excludes task folder and state)

## What changed
- **Generated default wallpaper.** New `scripts/theme/wallpaper-default.sh
  <theme> <palette>` uses ImageMagick (`magick`, falling back to IM6
  `convert`) to render a 2560x1440 SouthEast gradient `#dcol_1xa2 -> #dcol_pry1`
  to `~/.cache/dots/theme/wallpapers/<theme>.png`. It renders to a temp file
  and renames it into place. It writes `~/.fehbg` with a
  `# dots: generated wallpaper` marker line and a POSIX single-quoted path.
  `~/.fehbg` is claimed only when it is absent or already has the marker.
  `theme-apply.sh` calls it in static mode before `reload.sh`, which then runs
  `~/.fehbg`; a failure only costs the wallpaper. Uninstall
  (`uninstall-theme.sh`) removes `~/.fehbg` only when it has the marker.
- **picom inactive dimming.** Added to `picom.conf` and `picom.dcol` in
  lockstep: `inactive-dim = 0.15`, `use-ewmh-active-win`,
  `mark-ovredir-focused` (bar, systray, dmenu, dunst and slock are never
  dimmed) and `detect-transient`. Shadows, rounded corners and blur stay off.
- **VM auto-resize.** `spice-vdagent` added to `packages/extra.lst`
  (new "virtual machines" section). `session_autostart_display` launches it
  only when `systemd-detect-virt --vm --quiet` succeeds. It has a paired
  `session_report_daemon` line and a `DAEMONS` entry (rule 6).
- **Tests.** New `tests/wallpaper-default.sh` uses a sealed PATH, a fake
  magick/convert and a sandbox HOME. It covers: generate, theme switch,
  never touching a user's `.fehbg` (including one naming the generated png
  without the marker), a render that fails midway, no ImageMagick, a palette
  missing its keys, the IM6 fallback, and a hostile HOME (space, quote, `$`,
  tab) where `.fehbg` is run under `/bin/sh`. It also runs a sandbox copy of
  `theme-apply.sh` with fake apply-templates/reload to prove the ordering, and
  does a real 2560x1440 render when ImageMagick is installed.
- **Docs.** THEMING.md ("The generated default wallpaper"), UNINSTALL.md,
  `themes/dark/wallpapers/README.md`, TESTING.md, CHANGELOG.md (Unreleased/Added)
  and CLAUDE.md (theming paragraph and project map).

## Why
After the first-boot-fixes re-test on the Fedora 44 VM, the user asked to
"fix the wallpaper and picom and the resolution". Their answers:
- **Wallpaper:** generate it from the palette. The repo's no-binaries rule
  stays intact, since no image is committed.
- **picom:** "no visible effect", then "make it simple and make it stable".
- **Resolution:** auto-fit the VM window.
The desktop came up on a black root window, picom ran on xrender with nothing
to show, and the guest stayed at 1280x800 inside a 1920x1080 viewer.

## Assumptions
- **DECISION REVERSAL (partial), Type B:** this reverses part of
  `2026-08-07-picom-perf-tuning.md` (no shadows, opacity 1.0 everywhere). The
  conflict was surfaced and the user answered "make it simple and make it
  stable". That was read as option C: cheap effects only, so inactive-dim
  alone, which behaves the same on xrender and glx. Shadows, corners and blur
  are unchanged.
- `inactive-dim`, `mark-ovredir-focused` and `use-ewmh-active-win` are
  "discouraged" in the picom v13 man page in favour of `rules`, but still
  supported. Moving to `rules` would change how every existing `*-exclude`
  option applies, so they were kept. The local picom v13 parsed the config
  with no warnings. The dimming has NOT been seen under dwm on the VM.
- `spice-vdagent`: verified on packages.fedoraproject.org (f43/f44/rawhide).
  Rule 8: not checked against a live dnf. Assumed: `spice-vdagentd` is
  activated by the package when the SPICE port appears. This is unverified,
  and the template comment says so.
- `extra.lst` tier, not `desktop.lst`: this is a VM-only convenience, and a
  fixed resolution shows itself immediately.
- The gruvbox wallpaper is reddish-brown. That is its own `dcol_1xa2`, kept
  deliberately (raised by the reviewer).

## Test coverage
- `tests/run-tests.sh`: 26/26 OK, 0 skipped. `tests/lint.sh` clean.
- Mutations, all run on scratch copies:
  - First pass:
    - Ownership check removed: caught.
    - Gradient colours swapped: caught.
    - `convert` fallback removed: caught.
    - theme-apply hook removed: caught.
    - `chmod` dropped: caught.
    - `TMP=TARGET`: caught.
    - `mv` dropped: caught.
  - `rm -f "$TMP"` removed: **SURVIVED** the first pass. The failing fake
    never created a partial file. The fake now fails midway, and the
    mutation is caught.
  - After the round-1 review fix, both were caught:
    - reverting to `%q`, caught by a tab in the hostile HOME (`%q` only emits
      `$'...'` for control characters);
    - reverting to path-grep ownership.
- Reviewer gate:
  - Round 1: WARN — `%q` in `.fehbg`, plus the gruvbox tint.
  - Fixed: POSIX quoting, plus the marker. Grepping the quoted path could
    never match a HOME containing `'`.
  - Round 2: READY.
- Uninstall branch: checked in a sandbox with stubbed helpers (`.fehbg` with
  the marker is removed; the user's own is kept). It is not in the automated
  suite.
- NOT covered: anything on the VM (dimming under dwm, the spice resize, how
  the wallpaper looks on screen).

## Follow-ups
- VM:
  - `git pull`, then `dots theme dark` (the cache already exists, so the
    wallpaper won't appear by itself).
  - `scripts/install-fedora.sh --only-install`.
  - Remove `~/.local/share/dwm/autostart.sh` or paste the printed spice line.
  - virt-manager: View > Scale Display > Auto resize VM with window.
  - Check with `pgrep -a spice-vdagent` and `systemctl status spice-vdagentd`.
- `scripts/theme/wallpaper.sh` still writes `~/.fehbg` with bash `%q` (same
  latent `/bin/sh` issue). Pre-existing, left out of scope.
- Still open from first-boot-fixes: archive the 54 change logs older than
  14 days (paths to them are cited across the repo).
