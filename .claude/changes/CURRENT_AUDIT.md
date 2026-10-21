# dots — Current Audit State

## Current Scope
Personal Fedora-only dotfiles + dwm/X11 desktop bootstrap repo. The
uninstall/versioning/migrations subsystem (below) and the CI/tooling setup
both landed 2026-08-05, concurrently, in the same working tree — see each
thread's dated log for the full collision account (mutually surfaced and
handled without data loss on either side). See recent dated logs in this
directory for the running history.
Since 2026-10-15 the target is Void Linux glibc (scope I): "Fedora-only"
above is history, kept verbatim from the pre-rotation snapshot.

## History Sources
- `.claude/changes/YYYY-MM-DD-*.md` — authoritative dated logs

## 2026-10-19 — nsxiv-package: nsxiv from Void's package (fast-forward)

- **`nsxiv-package`** (`30e9120`, log `2026-10-19-nsxiv-package.md`). User
  decisions: nsxiv comes from Void's package, and xcolor stays a script.
  - `suckless/nsxiv` deleted. nsxiv is out of `PROGRAMS`/`PROGRAM_BINS`, and
    `PROGRAM_INSTALL_TARGETS` is removed. `nsxiv` is in `extra.lst`;
    `imlib2-devel`/`libexif-devel` left `build.lst`.
  - `tests/default-apps.sh` maps `nsxiv.desktop` to the package.
  - The root `.gitignore` covers the old tree's build leftovers in existing
    clones. `install-suckless.sh --help` no longer truncates.
  - The package was verified from its .xbps and its void-packages template:
    the same v34, the same desktop file, Xft and libexif.
  - Suite 93 OK, lint ✓, 2/2 mutants, audit READY, reviewer WARN (a dead
    pointer, fixed).
- **Queued:** the 0.5.0 migration removes the `/usr/local` nsxiv build and
  its manifest rows.

## 2026-10-19 — claude-md-void: CLAUDE.md Fedora cleanup (fast-forward)

- **`claude-md-void`** (`45e575d`, log `2026-10-19-claude-md-void.md`).
  User item 6. Statements of current behaviour reconciled with the Void
  scripts; Fedora kept as marked history. Every new fact was checked
  against the repo or the .xbps. lint ✓, suite 93 OK, audit READY,
  reviewer READY.
- **Queued:** Void's `gnome-themes-extra(-gtk)` vs the vendored shim and
  the gtk2 template (a decision), and TESTING.md's Fedora sections. The
  0.5.0 release item is corrected: headers are already refreshed on every
  build, so the migration only removes the old nsxiv build.

## 2026-10-19 — release-0.5.0: cut 0.5.0 (fast-forward)

- **`release-0.5.0`** (`868a481`, log `2026-10-19-release-0.5.0.md`). User
  item 3, last part. VERSION 0.5.0, CHANGELOG `[0.5.0] - 2026-10-19` (two
  entries corrected for release), and the 0.4.0 → 0.5.0 migration: it
  removes the `/usr/local` nsxiv build only when a manifest row records it,
  drops the rows, and deletes unedited `suckless/nsxiv/` leftovers (an
  edited config.h is kept and named). sudo only for an unwritable prefix.
- `tests/migration-0.5.0.sh` (sandboxed, fake sudo); 7/7 mutants; suite
  94 OK; lint ✓; audit READY; reviewer READY.
- Local tag `v0.5.0` on main. Nothing pushed.

## 2026-10-19 — testing-void + ly-rebuild (fast-forward)

- **`testing-void`** (`863380a`, log `2026-10-19-testing-void.md`). User
  items 1 + 2. The GTK3 shim and gtk2 template stay by decision (facts read
  from the gnome-themes-extra 3.28_4 .xbps files); TESTING.md's Fedora-era
  statements reconciled (base-files 0.146 `usr/sbin -> bin`). Suite 94 OK,
  reviewer READY.
- **`ly-rebuild`** (`bb86190`, log `2026-10-19-ly-rebuild.md`). User item 3.
  `scripts/install-services-ly-place.sh`; a raised pin rebuilds, keeps
  config.ini, prunes stale paths, never restarts ly. 12 new checks in
  tests/ly-build.sh, 10/10 mutants, suite 94 OK, reviewer READY.

## 2026-10-20 — suite-host-hermetic (fast-forward)

- **`suite-host-hermetic`** (`324b6d6`, log `2026-10-20-suite-host-hermetic.md`).
  The suite failed 2 checks on the Arch dev host (CI green): dwm-display's
  tests reached the real autorandr, doctor's GTK3 case read /usr/share/themes.
  Sealed PATH + sandboxed XDG_DATA_DIRS. `--help` of install-void.sh and
  symlinks.sh prints the whole header (install-void.sh before its log tee);
  new tests/help-header.sh. Suite 95 OK on the host, 6/6 mutants, lint ✓,
  audit READY, reviewer READY. Nothing pushed.

## 2026-10-20 — CURRENT_AUDIT.md rotated

- Pre-rotation snapshot: `.claude/changes/CURRENT_AUDIT-2026-10-20.md`
  (2531 lines, every entry from 2026-08-05 on).
- Older entries are preserved there; this file now keeps only the
  trailing 5, oldest first as before.
- Same commit: the thirteen 2026-10-05 logs moved to `archive/` (14-day sweep).

## 2026-10-20 — update-upstream-gone (fast-forward)

- **`update-upstream-gone`** (`746330a`, log `2026-10-20-update-upstream-gone.md`).
  Found on the Void VM: its checkout tracked `void`, deleted on GitHub, and
  `dots update` said "nothing to pull" (fetch kept the stale ref). Now
  `fetch --prune` + `need_upstream` (preflight and after the fetch) refuses
  with the branch named and `git switch main`. 5/5 mutants, suite 95 OK,
  reviewer READY, verified on a copy of the VM checkout. VM's `~/dots` moved
  to main. Nothing pushed.

## 2026-10-20 — running-build-stale (fast-forward)

- **`running-build-stale`** (`2e6446a`, log `2026-10-20-running-build-stale.md`).
  Void VM finding: `dots update` under a live session replaced dwm and
  dwmblocks on disk; the running ones kept the old code silently. New
  `scripts/running-build.sh` (replaced + different = stale; removed = not);
  both installers end with the restart hint, `dots doctor` warns. 9/11
  mutants (one equivalent, removed; owner check untestable), suite 96 OK,
  reviewer READY, verified live on the VM (HUP kept pid and windows).
- **VM verification of the queued items, same day:** 0.4.0 → 0.5.0 upgrade
  via `dots update` (migration removed /usr/local nsxiv + row +
  suckless/nsxiv/; `nsxiv` = package 34_1; mimeapps.list refreshed; doctor
  all passed; a second update/migrate a no-op); dunst kept pid, history and
  pause level 100 across `dots theme nord` and a wallpaper change, queued
  notifications shown on unpause; xdg-open of a .jpg ran /usr/bin/nsxiv.

## 2026-10-20 — complete-stamp-cleared (fast-forward)

- **`complete-stamp-cleared`** (`848acac`, log `2026-10-20-complete-stamp-cleared.md`).
  Void VM finding: a Ctrl-C'd re-run of a commit that had finished before
  kept the old `complete` stamp = HEAD, so `dots update` said up to date. A
  full non-dry run now clears it after the pre stage. 4/4 mutants, suite 96
  OK, reviewer READY; on the VM a real SIGINT gave exit 130 + empty stamp,
  `dots update` re-ran and converged.
- **Also VM-checked:** the packaged nsxiv reads the theme's X resources
  (window background = `Nsxiv.window.background`, #2C2363).

## 2026-10-20 — theme-change-lock (fast-forward)

- **`theme-change-lock`** (`35313cc`, log `2026-10-20-theme-change-lock.md`).
  Void VM finding: two concurrent `dots wallpaper --random` left the second
  wallpaper with the first one's palette. New `scripts/theme/theme-lock.sh`
  re-runs wallpaper.sh / theme-apply.sh under `flock -o` (the daemons a
  change starts never hold it). 6/6 mutants, suite 97 OK, reviewer READY;
  VM: 3 concurrent rounds, palette always matches the final wallpaper.
  wallpaper.sh is now exactly at the 250-line cap.

## 2026-10-20 — xresources-cpp-safe, wallbash-choice-recorded (fast-forward)

- **`xresources-cpp-safe`** (`6b1910d`, log `2026-10-20-xresources-cpp-safe.md`).
  An apostrophe in an xresources.dcol comment made xrdb's cpp warn on every
  merge. Reworded; new tests/xresources-cpp-safe.sh bans `'` and `/*` in the
  template body and runs `cpp -P` when present.
- **`wallbash-choice-recorded`** (`864b2a7`, log
  `2026-10-20-wallbash-choice-recorded.md`). Void VM finding: `dots theme
  --wallbash` after a static theme never touched wall.set, so the next
  restore re-run re-applied the static theme. It now touches wall.set;
  tests/theme-active.sh runs the real theme-apply.sh. Suite 98 OK, reviewer
  READY; VM confirmed.
- **Also VM-checked, no finding:** `dots drivers` twice (manifest unchanged),
  `symlinks.sh --restore` with no backups, `dots update` with the network
  unreachable (rc=1, clear message, tree untouched).

## 2026-10-20 — help-render-aligned (fast-forward)

- **`help-render-aligned`** (`0626ec1`, log `2026-10-20-help-render-aligned.md`).
  `dots theme --help` wrapped a usage line that the DOTS_CMD swap left four
  columns off; theme and wallpaper help opened on a blank line. Unwrapped,
  sed ranges narrowed; tests/dots-dispatch.sh checks every subcommand. 3/3
  mutants, suite 98 OK, reviewer READY.
- **Same VM pass, no finding:** bad/traversal theme names refused; missing
  and non-image wallpapers refused before any state is written (feh runs
  first); a path with spaces and an apostrophe applies and round-trips
  through ~/.fehbg.

## 2026-10-20 — migrate-dryrun-current (fast-forward)

- **`migrate-dryrun-current`** (`a12240f`, log `2026-10-20-migrate-dryrun-current.md`).
  `install-void.sh --dry-run` aborted silently at `=== migrations ===` on
  every up-to-date install: migrate.sh ended on a false `[[ ]] && blue`.
  Fixed; tests/migrate.sh now checks dry-run exit codes. VM: dry run rc=0
  across all four stages, manifest and filesystem untouched. Suite 98 OK,
  reviewer READY.
- **Same VM pass, no finding:** `dots version --json` parses; `dots doctor
  --tsv` rows all have 4 fields.

## 2026-10-21 — uninstall-dryrun-preview (fast-forward)

- **`uninstall-dryrun-preview`** (`84ec6c7`, log `2026-10-21-uninstall-dryrun-preview.md`).
  `confirm()` answers yes under DRY_RUN, so `dots uninstall --dry-run`
  previews every category with no terminal (it printed "skipped" for all).
  `uninstall_state`'s trailing `[[ ]] && echo` is an if (y/N exited 1).
  New tests/uninstall-dry-run.sh; 5/5 mutants; suite 99 OK; reviewer READY
  after checking every confirm site honours DRY_RUN. **Not yet VM-run.**

## 2026-10-21 — theme-lock-scope (fast-forward)

- **`theme-lock-scope`** (`c5673a3`, log `2026-10-21-theme-lock-scope.md`).
  theme-lock.sh no longer locks `--list`, help, `--login-random` or
  `--select`; `--select` re-execs with the chosen path, so only the apply is
  locked. login_random moved to `scripts/theme/wallpaper-login-random.sh`
  (wallpaper.sh off the cap). 4/4 mutants, suite 99 OK, reviewer READY. Not
  yet VM-run (ssh agent).
- **Same pass, noted only:** `dots doctor` on a never-installed HOME lets
  flatpak and dconf create their own stores.

## 2026-10-21 — VM verification of uninstall-dryrun-preview and theme-lock-scope

- **uninstall-dryrun-preview, on the Void VM** (main `b7b5ed9` snapshot):
  `uninstall.sh --dry-run </dev/null` rc=0 previews every category
  (suckless `make uninstall`, `xbps-remove -Ry` of the installed set,
  service disable/re-enable, the ly build's files). No "skipped"/"kept"
  line. Manifest and /etc/ly/config.ini byte-identical, 0 files newer under
  HOME or /etc, /usr/local, /var/service, /usr/bin; services, 693 packages
  and the zsh login shell unchanged.
- **theme-lock-scope, on the Void VM**: with `~/.cache/dots/theme/.theme.lock`
  held by flock, `theme-apply.sh --list` and `--help` and `wallpaper.sh
  --login-random status` each returned rc=0 in 0 s.

## 2026-10-21 — Void VM, real dwm session (ly login), no finding

- **`dots update` 784d203 → ac0b3e1**: rc=0 in 17 s, nothing to migrate,
  every stage complete, dwm HUP'd in place; manifest `commit` and
  `complete` both ac0b3e1.
- **theme-lock-scope, in the session**: `theme-apply.sh --list` answered in
  6 ms while a `dots wallpaper --random` held the lock (still running after).
  With the real `--select` dmenu open, `--random` applied in 2 s; Escape then
  closed the picker (rc=0, nothing changed). Typing a name + Return applied
  that wallpaper through the re-exec (wall.set, ~/.fehbg; no wallpaper.sh
  left running; dwm, dunst, dwmblocks alive).
- **Round trip**: nord (#2E3440) → --wallbash (#171724) →
  `install-void.sh --only-restore` re-applied `--wallbash`, palette kept;
  dwm and dunst pids unchanged. `Super+Shift+t` via sxhkd opened the menu,
  gruvbox applied (#282828), `--wallbash` restored #171724.
- **Same session, keybind sweep, no finding**: `Super+w` x3 fast — final
  wallpaper, ~/.fehbg and palette agree. `Super+Alt+p` saved
  ~/Pictures/screenshots/dots-screenshot-*.png and put image/png on the
  clipboard. `Super+Shift+n` toggled dunst pause on/off. Every dmenu key
  (notify, display, keys, emoji, apps, clipmenu, powermenu, record,
  screenshot) opened its menu and left no process after Escape (dwm-emoji
  needs ~0.5 s to grab the keyboard — an Escape sent sooner is lost; human
  timing is fine). `Super+Shift+p` on a desktop/VM opens no menu and
  notifies that power profiles are laptop-only, as designed (an apparent
  5 s menu was the harness's wait-loop timeout).
- **Same session, dwm restart keeps placement**: st probeA sent to tag 3,
  probeB on tag 1; across two theme switches (tokyo-night, --wallbash; each
  a SIGHUP re-exec, dwm pid unchanged) A stayed on tag 3 and B on tag 1
  (xdotool geometry: x=0 on its own view, x=-3832 hidden elsewhere).
  dropterm's window id was unchanged across restarts. (_DWM_CLIENT_INFO
  exists only during the re-exec — saveclientinfo writes it, manage()
  consumes it — so placement is measured by behaviour, not the property.)
- **stale-port-text** (`23fa145`, ff; log `2026-10-21-stale-port-text.md`):
  `install-void.sh --help` said the port was in progress and the script
  worked on neither distro, and that --only-install installs dnf packages;
  dwm-record's error named `ffmpeg-free`; version.sh's header and two
  uninstall ordering comments still gave Fedora/rpm reasons. All fixed;
  new `tests/runtime-text-void.sh` runs every scripts/ `--help` (21, read
  from the code) and greps printed literals for Fedora-era tools. Suite 100 OK.
- **update-arg-check** (`9e05019`, ff; log `2026-10-21-update-arg-check.md`):
  `dots update --skip-sucless` fetched and fast-forwarded, then the
  installer rejected the flag — checkout updated, nothing installed.
  `installer_takes` now refuses a flag install-void.sh does not take (read
  from its case labels) before the fetch. VM check of every `dots <sub>
  --help`/`-h` (exit 0, HEAD and manifest unchanged) found it. Suite 100 OK.
- **palette-missing-keys** (`942ee41`, ff; log
  `2026-10-21-palette-missing-keys.md`): **a theme whose colors.dcol lacked
  a key the templates use logged the user out** — rendered anyway,
  `#<wallbash_pry1>` reached xresources, dwm's restart died in
  drw_clr_create, .xinitrc ended (ly.log, VM). The engine now refuses a
  palette with gaps before any write (`palette_gaps`, `--check`), and
  theme-apply checks before its identity/wallpaper steps. The VM cache was
  repaired headless; a re-login is still owed. Suite 101 OK.
- **version-columns** (`a599888`, MICRO): `dots version` values aligned.
- **clipmenud-match** (`db56814`, ff; log `2026-10-21-clipmenud-match.md`):
  Void's clipmenud is an env-bash script, so it runs as "bash" and
  `pkill -x clipmenud` at logout never matched — an orphan held ly's tty2
  on the VM. Now `-f '/clipmenud$'` in the stop and the autostart guard;
  old `.xinitrc` files are told the one line to replace. New
  tests/session-end-match.sh runs every shipped stop against real-shaped
  processes (pgrep only). Suite 102 OK. VM logout check pending a login.
- VM gained a second QXL head (heads=2, vgamem 32 MB) for multi-monitor
  testing; original XML kept in the session scratchpad.
- VM video memory raised to 128 MB (ram/vram 131072, vgamem 65536): at
  32 MB with two 1080p heads the qxl driver hung Xorg (qxl_fence_wait).
- **display-presets** (`2b0ad18`, ff; log `2026-10-21-display-presets.md`):
  first of the user's multi-monitor picks (they run 2×1080p). dwm-display's
  presets passed `--auto` to screens already on, resetting them to the
  preferred mode (VM: 1920x1080 → 850x1001), and took the first output as
  primary. Active screens now keep their mode, the real primary is kept,
  and a "save this layout as a profile" entry wraps `autorandr --save`
  (name check, overwrite confirm). VM: extend kept 1080p; a saved layout
  came back via `autorandr --change`. 9/9 mutants. Suite 103 OK.
  Focus-follows-mouse, also picked, already works across monitors (VM).
- **monitor-capture** (`0865a45`, ff; log `2026-10-21-monitor-capture.md`):
  second multi-monitor pick. `dwm-screenshot` and `dwm-record` gained a
  `monitor` mode — the screen under the pointer (new sourced
  `dwm-lib-monitor.sh`: xdotool position + `xrandr --listactivemonitors`),
  failing with a reason rather than guessing. VM: real tools picked the
  right 1920x1080 rectangle at all four edge positions; recording VP9
  1920x1080. 14/14 mutants. Suite 104 OK. Found: two shots in one second
  share a name and the second overwrites the first.
- **capture-name-clash** (ff; log `2026-10-21-capture-name-clash.md`):
  two screenshots in one second shared a seconds-resolution name and the
  second replaced the first; a recording restarted within a second made
  ffmpeg refuse the existing file. Both now reserve a free name with
  noclobber (`-2`, `-3` …); ffmpeg `-y` onto its own reservation. VM:
  three concurrent shots → three files; two real recordings in one pinned
  second → two valid files. 6/6 mutants. Suite 104 OK.
- **dwm-runtime-home** (ff; log `2026-10-21-dwm-runtime-home.md`):
  `tests/dwm-runtime.sh` ran dwm with the tester's HOME, so the autostart
  patch launched their real `autostart.sh` against the Xvfb display
  (dwm-audiowatch → real PipeWire). Now a sandbox HOME with a stand-in
  autostart, asserted by marker. Earlier suite runs today were safe only
  because worktrees had no built dwm (skip). Suite 104 OK with dwm-runtime
  really running.
- **status-all-mons** (ff; log `2026-10-21-status-all-mons.md`): third
  multi-monitor pick. dwm draws the status on every bar (local
  statusallmons diff); `traywidth(m)` keeps the status and statuscmd
  clicks aligned on bars without the tray. New tests/dwm-multimon.sh (two
  RandR monitors on one Xvfb screen), run by build-suckless. 3/3 mutants.
  Suite 105 OK. VM check pending login (idle lock up).
- **replug-windows** (ff; log `2026-10-21-replug-windows.md`): last
  multi-monitor pick. A vanished monitor's windows remember their home by
  geometry (dwm reuses Monitor structs by index, so a struct is no
  identity) and return with their view when it comes back, floating ones
  to their spot, across a restart too (_DWM_CLIENT_INFO 7 → 15 values).
  Stock dwm failed the test; mutants caught except the untestable sendmon
  clear. Suite 105 OK. VM check pending login.
- **VM-verify (2026-10-21, after `dots update` to 6e3f1f3 and a re-login):**
  `dots update` rebuilt dwm and HUP'd it onto the new binary (exit 0).
  statusallmons: both bars' status regions pixel-identical (same image
  signature), tray on Virtual-1. replug-windows: a tiled window on
  Virtual-2 tag 2 and a floating one went to Virtual-1 when Virtual-2
  was switched off and came back to the exact same positions when it was
  switched on; the same with `pkill -HUP -x dwm` while it was off. The
  left-screen unplug (the struct-reuse case) also came out right; there X
  moves the remaining screen to +0+0. clipmenud-match: the VM's
  user-owned ~/.xinitrc still has the old `-x` line (never rewritten), and
  the dry run prints the replacement; the fix itself is unverified until
  that line is applied and a logout follows. At login autorandr loaded
  the saved `vm-1080p` profile (Virtual-2 off) — by design.
- **brightness-follows-display** (ff; log
  `2026-10-21-brightness-follows-display.md`). On the plain xrandr gamma
  path, a screen that was off when the level was set came back at full
  gamma beside a dimmed one. The level is now recorded, and
  `dwm-brightness sync` (run by dwm-display and the new autorandr hook
  `20-dots-brightness`) re-applies it. `set` also no longer exits 1 while
  a connected screen is off, because `outputs()` now skips outputs that
  have no geometry. With the nightlight daemon running there was no bug,
  since gammastep writes every CRTC. Both fixes are VM-verified with the
  slot's script copied to /tmp. The hook under a real autorandr is
  pending a push. Suite 106 OK. The monitor-capture pixel check is still
  blocked by slock.
