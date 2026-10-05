# wallpaper-follows-display
Date: 2026-10-05
Files: 9 | Lines: +244/-5 (7 modified + 2 new; excludes task folder and state)

## What changed
- New `config/autorandr/postswitch.d/10-dots-wallpaper` (POSIX sh, mode
  755). If `~/.fehbg` is executable, it `exec`s it; otherwise it exits 0.
- `restore_apps` (`scripts/install-restore-apps.sh`) deploys the hook with
  `deploy_app_file` to `$XDG_CONFIG_HOME/autorandr/postswitch.d/`. It is
  COPIED and claimed with an APP manifest row, so uninstall removes it. It is
  `chmod 755`'d only when the manifest claims it, never when it is the
  user's own file.
- `config/dwm/bin/dwm-display` (Super+d) re-runs `~/.fehbg` after a layout
  applies successfully. A failed layout skips it, and a failure in
  `~/.fehbg` is ignored, so it never fails the layout.
- Tests:
  - New `tests/wallpaper-follows-display.sh` covers three things. First, the
    hook under `/bin/sh` with `~/.fehbg` executable, non-executable and
    absent. Second, the real restore stage in a sandbox via
    `tests/lib/install-symmetry.sh`: the hook is deployed, executable, a copy
    and not a symlink, claimed in the manifest, and no sentinel command runs.
    Third, the dwm-display re-paint: it runs after the layout, never on a
    failed one, and a failing or absent `~/.fehbg` is fine.
  - `tests/dwm-display.sh` now sets a sandbox `HOME` on every run.
- Docs: THEMING.md (re-paint after a resolution change, plus
  `autorandr --save`), TESTING.md, CHANGELOG.md (Unreleased/Added), and the
  CLAUDE.md project map (`config/autorandr/`: copied, never linked).

## Why
On the Fedora 44 VM the user set 1920x1080 by hand and wants it kept. The
generated wallpaper covered only the old 1280x800 corner, because feh
paints the root window at the screen size of the moment. Login has the same
ordering problem: `~/.xinitrc` paints the wallpaper, then autostart's
`autorandr --change` applies a saved layout. Real hardware hits it too, on
monitor hotplug and Super+d. The fixed resolution itself is per-machine, so
it is set with `autorandr --save vm` on the VM, not in the repo.

## Assumptions
- autorandr runs every executable in `~/.config/autorandr/postswitch.d/`
  in filename order, per its README (verified via WebFetch, not on the VM).
  If the profile is already active, `--change` may run no hooks; in that
  case nothing changed, so nothing needs fixing.
- `config/autorandr` must never be added to `symlinks.sh`, because
  `autorandr --save` writes profiles into that directory. This follows the
  same rule-7 reasoning as dunst/picom/thunar. Only the one hook file is
  copied.
- Uninstall removes the hook by its APP row (existing semantics, even if
  the user edited it) and leaves the `postswitch.d/` directory, as it does
  for every other directory it created.
- A raw hand-typed `xrandr` has no hook point. This is documented: run
  `~/.fehbg` afterwards, or use Super+d.
- spice-vdagent auto-resize was not pursued. The user chose a fixed layout.
  Its socket was inactive on the VM, likely because the package was
  installed after boot; that is unverified and left alone.

## Test coverage
- `tests/run-tests.sh`: 27/27 OK, 0 skipped. `tests/lint.sh` clean.
  `install-uninstall-symmetry` still round-trips (the new APP row is removed).
- Mutations, all run on scratch copies, all caught:
  - deploy line removed;
  - hook `exec` replaced by `exit 0`;
  - hook's `-x` guard removed;
  - dwm-display re-paint removed;
  - dwm-display's `|| true` removed;
  - repo exec bit and the `chmod` both dropped.
  The two dwm-display mutations were re-run after the split and are still
  caught.
- Found during /code:
  - `tests/dwm-display.sh` ran dwm-display with the REAL `$HOME`. It would
    now execute the live `~/.fehbg`, so it is sandboxed.
  - Adding the re-paint cases took that file to 273 lines (cap 250). They
    were moved into the new test, which was renamed from
    `autorandr-wallpaper-hook.sh` to `wallpaper-follows-display.sh`.
- Reviewer gate: READY (round 1).
- NOT covered: real autorandr running the hook on the VM.

## Follow-ups
- VM:
  - `autorandr --save vm` while at 1920x1080.
  - `scripts/install-fedora.sh --only-restore`.
  - Log out and back in.
  - Expect 1920x1080 with the wallpaper filling the screen.
- Still open:
  - the `%q` quoting in `scripts/theme/wallpaper.sh`;
  - archiving the 54 change logs older than 14 days;
  - the main-side `CURRENT_AUDIT.md`/`MASTER_PLAN.md` fold (uncommitted on
    main, awaiting the user).
