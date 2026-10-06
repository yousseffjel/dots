# xdg-portal-gtk
Date: 2026-10-06
Files: 15 | Lines: +380/-12 (two new files)

## What changed
- `packages/extra.lst`: `xdg-desktop-portal-gtk`, `dconf`, `dbus-daemon`,
  with a comment on why each is there.
- `config/xdg-desktop-portal/portals.conf` (new): `[preferred] default=gtk`.
  `scripts/symlinks.sh` links the directory (rule 7).
- `scripts/global_fn.sh`: `dconf_cmd` runs `dconf "$@"`, and if that fails
  (no session bus) runs `dbus-run-session -- dconf "$@"`.
- `scripts/install-restore-apps.sh`: `DCONF_PREFS` (one entry:
  `/org/gnome/desktop/interface/color-scheme|'prefer-dark'`) and
  `apps_dconf_prefs`, called at the end of `restore_apps`. It writes a key
  only when `dconf read` is empty, then appends a manifest row
  `DCONF dconf <key> <value>`.
- `scripts/uninstall-apps.sh` + `scripts/uninstall.sh`: `uninstall_dconf`
  resets each DCONF key while it still holds the recorded value. It runs
  before `uninstall_packages`, which may remove dconf.
- `tests/color-scheme.sh` (new, 12 checks, sealed PATH with a file-backed
  fake dconf). The round-trip test's sandbox gets the same fake. Fresh
  HOME: one DCONF row, and dconf is back to empty after uninstall.
  Lived-in HOME with `'default'` already set: no row, and the value is
  untouched.
- Docs: `docs/UNINSTALL.md` step 5a, `ROADMAP.md` §3 portal row,
  `CLAUDE.md` (project map + the "open by decision" paragraph, which was
  also stale about the blue-light filter), `CHANGELOG.md`.

## Why
Item 4 of "what is next" (2026-10-06). The user chose "package + dark pref"
and was told uninstall would reset the preference.

## Key Technical Decisions
- **DECISION REVERSAL — scope C locked decision 5** ("xdg-desktop-portal-gtk
  is OUT for now; only pays off with Flatpak"). Overridden at the user's
  explicit request. The payoff without Flatpak is the Settings portal: in
  xdg-desktop-portal-gtk 1.15.3 `src/settings.c`, `get_color_scheme` reads
  GSettings `org.gnome.desktop.interface color-scheme` and nothing else.
- **That decision's two technical claims were wrong, as checked against
  the sources:**
  - portals.conf(5): with `XDG_CURRENT_DESKTOP` unset, the
    desktop-independent `portals.conf` is read, so exporting it is
    unnecessary.
  - `desktop-portal/xdp-portal-config.c`: with no config at all, gtk is
    chosen "as a last-resort fallback" with a warning; nothing hangs.

  `portals.conf` is therefore about being explicit, not about working at
  all. The first draft of its comment claimed otherwise and was corrected.
- **Write only an unset key; reset only an unchanged one.** That makes the
  reset an exact undo, which is the reason the xfconf pass gave for never
  reverting. `'default'` counts as a user's choice.
- **dbus-run-session for headless installs.** The VM install ran over
  ssh, where there is no session bus. Fedora's xinitrc.d
  `50-systemd-user.sh` (systemd, f44) imports `DISPLAY` into the user
  manager, so the dbus-activated portal can open windows.

## Assumptions
- Type B: a dconf write made over a private bus is seen by the next login's
  apps. That is how dconf works (the writer replaces `~/.config/dconf/user`
  and readers mmap it), but it has not been run on the VM.
- Type B: dbus-daemon installs alongside dbus-broker. mdapi lists conflicts
  only with fedora-release < 30. Not run on the VM.

## Test coverage
- `bash tests/run-tests.sh`: 37/37 OK. `tests/lint.sh` passes.
- Mutation testing on scratch copies, 9/9 CAUGHT with specific FAIL lines:
  - overwriting the user's key;
  - no manifest row;
  - no dbus-run-session fallback;
  - always reset;
  - the install dry-run guard removed;
  - the uninstall dry-run guard removed;
  - `uninstall_dconf` not wired into uninstall.sh;
  - `apps_dconf_prefs` not called;
  - the symlink entry removed.
- The test harness had three bugs of its own before its first green:
  - global_fn.sh redefined the stubbed colour helpers;
  - `env -i` dropped `DRY_RUN`;
  - the row count was empty instead of 0.

  All three were fixed before any result was trusted.
- **Not verified:** real dconf, the portal starting, and Firefox or a
  libadwaita app actually turning dark on the VM.

## Follow-ups
- On the VM:
  - check the stored value with `dconf read /org/gnome/desktop/interface/color-scheme`;
  - check that the portal answers with `busctl --user call
    org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop
    org.freedesktop.portal.Settings ReadOne ss org.freedesktop.appearance
    color-scheme` (it should return 1).
- GTK4 apps that use neither libadwaita nor the portal read
  `~/.config/gtk-4.0/settings.ini`, which this repo does not write. Out of
  scope.
