# Scope G — polish, per-tag restart, release 0.2.0

Opened 2026-10-12 from "what is next" (user picked options 1 + 2 + 3).
Scope F closed the same day; CI green on 68cfb53.

## Slots (in order — the release goes LAST so 0.2.0 ships the other two)

1. `polish-bundle` (option 2):
   a. `session_xinitrc_report`: an `.xinitrc` that already has
      `dots_session_end` but lacks some stops gets ONLY the missing lines,
      not the whole block (seen on the VM 2026-10-12: it lacked one line).
   b. `dots doctor`: the daemon_applies skip names the one reason that
      applies (today: "no VM / no bluetooth adapter / no NetworkManager").
   c. Wallpaper keys (decision 2).
   d. Split `config/dwm/bin/dwm-screenshot` (exactly 250 lines).
   e. Strike the resolved queue item "Watch the first CI run after
      2026-08-10" (lint + build-suckless green on every run since).
2. `pertag-restart` (option 3): preserveonrestart also restores each
   monitor's Pertag state — nmasters, mfacts, sellts, ltidxs, showbars per
   tag — before restorestate() re-views. Rule 5: its own `*-local.diff`.
   Xvfb test: per-tag mfact + layout survive a SIGHUP.
3. `release-0.2.0` (option 1): real `0.1.0-to-0.2.0.sh` (decision 1),
   `dots update` (decision 3), a test for migrate.sh + the migration,
   CHANGELOG `[Unreleased]` → `[0.2.0] - <date>`, VERSION 0.2.0. Tagging
   and pushing the tag: ask at the time (outward-facing).

## Locked decisions (user, 2026-10-12)

1. **Stale generated headers:** the migration backs up and regenerates a
   `config.h` / `blocks.h` ONLY when it is byte-identical to some past
   version of its `*.def.h` in git history (never edited). An edited one is
   left alone and the migration prints the `*.def.h` changes to merge.
   Rejected: always regenerate; report only.
2. **Wallpaper keys:** the dir becomes `$(xdg-user-dir PICTURES)/wallpapers`
   (dwm-lib-xdg.sh's rule, `DOTS_WALLPAPER_DIR` still wins); created on first
   use and seeded with the theme's generated default wallpaper so the menu is
   never empty; any remaining failure is a notification, never silent.
   Rejected: XDG dir + notify only.
3. **`dots update`:** new subcommand — `git pull --ff-only`, then re-run
   `install-fedora.sh` (migrate, packages, rebuild, paste reports). Refuses a
   dirty tree or a non-fast-forward. Rejected: document the two commands.

## Explore notes (2026-10-12)

- migrate.sh is called unconditionally by install-fedora.sh before the
  install stage; no test covers it; `0.1.0-to-0.2.0.sh` is the no-op template.
- The migration may not edit autostart.sh/.xinitrc (rule 6): it reports.
- install-fedora.sh re-run already installs new desktop.lst packages and
  rebuilds; the generated headers are the gap.
- `scripts/dots` SUBCOMMANDS is the single declaration (help, completion,
  tests read it) — `update` is one new row.
- Pertag: 6 per-tag fields × (LENGTH(tags)+1), one Pertag per monitor;
  restore must precede the view() calls in restorestate().
- 0.1.0 was dated at d997704 but never tagged; no git tags exist.
