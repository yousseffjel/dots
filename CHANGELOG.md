# Changelog

All notable changes to dots are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

What each kind of version bump means for an existing install is defined in
`README.md` under **Versioning**. `VERSION` is the source of truth: it is
what the install manifest records and what `scripts/migrate.sh` compares.
`tests/changelog-version.sh` fails the build when the newest released
heading below and `VERSION` disagree. How to cut a release is in
`CONTRIBUTING.md`.

The day-to-day record is `.claude/changes/`: one dated log per task, with the
reasoning. This file is the user-facing summary of those logs, not a copy.

## [Unreleased]

### Added

- A default wallpaper. A static theme apply renders a gradient from the
  theme's own colours, so a fresh install is no longer a black screen. A
  wallpaper you set yourself is never replaced, and no image is committed
  to the repo.
- Unfocused windows are slightly dimmed by picom. Shadows, rounded corners
  and blur stay off.
- The wallpaper is re-painted after every display change: an autorandr
  `postswitch` hook (at login, on hotplug, and on a profile load) and
  `dwm-display` (Super+d). Before, switching to a saved 1920x1080 layout at
  login left the wallpaper covering only the old 1280x800 corner.
- Inside a VM, `spice-vdagent` (new, in `extra.lst`) resizes the screen to
  the viewer window and shares the clipboard. It never starts on real
  hardware.
- The bluetooth tray icon (`blueman-applet`) starts at login when a
  bluetooth adapter exists. blueman was already installed, but its autostart
  entry is never read in a dwm session.
- A pop-up with a progress bar when the volume, mic or brightness keys are
  pressed (`dwm-osd`, a dunst notification that replaces itself). No new
  packages.

- `CHANGELOG.md` and `CONTRIBUTING.md`.
- Tests for the seven untested `config/dwm/bin/` scripts (brightness, lock,
  screenshot, powermenu, clipmenu, theme, wallpaper). All nine now have one.
- `tests/install-uninstall-symmetry.sh`: restore then uninstall must return a
  sandboxed home to exactly what it was.
- Dependabot for GitHub Actions and pre-commit hook versions. A bot bump of a
  linter stays red until CI's copy of that pin moves with it.

### Changed

- `tests/lint.sh` lints every tracked shell script at any depth.
  `scripts/theme/` and `scripts/migrations/` had never been linted.
- `tests/dwm-runtime.sh` was split under the 250-line cap, into
  `tests/lib/`.
- The markdownlint pre-commit hook reads `.markdownlintignore` rather than
  keeping a second copy of the same list.

### Fixed

- The login shell was recorded as `/usr/sbin/zsh` when the installer ran
  with sbin first on `PATH` (since Fedora 42 sbin is a symlink to bin). A
  later run under a different `PATH` then changed the shell again and
  recorded zsh as the previous one, so `dots uninstall` would have "restored"
  zsh. The path is now resolved first, and an install that already has
  `/usr/sbin/zsh` is corrected on its next services run.
- `dots wallpaper` wrote `~/.fehbg` with bash-only quoting, which a strict
  `/bin/sh` cannot run when the image path contains a tab or other control
  character. It now uses POSIX quoting.
- Uninstall now restores theme configs you had before installing (`dunstrc`,
  `picom.conf`, GTK files). Before, it left the theming engine's version in
  place and your original in `~/.dotfiles-backup/`. Installs made before this
  fix are reported rather than guessed at.
- Uninstall no longer leaves behind a `mimeinfo.cache` the installer created.
- tmux's resurrect directory and the command palette's resurrect entries now
  honour `$XDG_STATE_HOME` / `$XDG_DATA_HOME` instead of hardcoding
  `~/.local`.
- The documentation no longer claims the vendored suckless `.diff` files are
  applied at build time. The sources ship pre-patched; the diffs are a record.
- **Found by the first real install** (Fedora 44 Server VM):
  - The screen no longer freezes after login on a GPU without 3D
    acceleration, which includes most VMs. picom's glx backend stopped
    repainting there. `autostart.sh` now checks the GL renderer with
    `glxinfo` (new package `glx-utils`) and falls back to xrender.
  - A headless install now comes up themed. The installer cannot theme a
    desktop that is not running yet, and nothing used to do it at login;
    `~/.xinitrc` now applies the dark theme on the first login and restores
    it on every later one.
  - The login shell is now actually set to zsh. `chsh` needs your password
    on a terminal and failed silently from the script; the installer and
    uninstaller now use `sudo usermod -s`.
  - An existing `autostart.sh` or `~/.xinitrc` is still never edited. The
    installer prints the lines to add instead.

## [0.1.0] - 2026-09-03

The first version. It was never tagged, and everything up to this point
shipped as 0.1.0.

### Added

- **One Fedora installer**, `scripts/install-fedora.sh`, for a fresh Fedora
  Server or Workstation box. It installs Xorg itself. It runs four idempotent
  stages (pre, packages, restore, services), each runnable on its own, with
  `--dry-run` threaded through all of them.
- **A patched suckless desktop**: dwm (13 patches, including pertag, systray,
  status2d, restartsig, xresources and dynamic scratchpads), st, dmenu (8
  patches), dwmblocks (10 blocks plus the tray) and slock. All are vendored in
  `suckless/`, each with a `PATCHES.md` record. `ly` is the display manager.
- **A wallpaper-driven theming engine**: ImageMagick colour extraction, `.dcol`
  templates, and an ordered live reload of dwm, st, dmenu, slock, dwmblocks,
  dunst, picom, GTK, alacritty, starship, fastfetch and vim. There are four
  static themes (dark, gruvbox, nord, tokyo-night), and a theme switch also
  applies its GTK, icon, cursor and font identity.
- **The desktop roster**: alacritty (st as the no-GPU fallback), sxhkd for
  media, brightness, screenshot, lock and theme keys, maim+slop screenshots,
  xss-lock+slock, Thunar with archive and thumbnail support, picom, dunst,
  starship, fastfetch, xsettingsd, udiskie, autorandr, lxpolkit, a dmenu
  colour picker and a display menu, and a vendored Bibata cursor theme.
- **`dots`**, one command on `$PATH`: `dots theme`, `dots wallpaper`,
  `dots version` and `dots uninstall`, with zsh completion.
- **A four-tier package model** in `packages/*.lst` (core, build, desktop,
  extra). A failed desktop package is repeated in a red closing summary that
  says what it costs.
- **Manifest-driven uninstall and versioning**: `scripts/uninstall.sh`
  reverses what the installer recorded, restoring backups. `VERSION`,
  `scripts/version.sh` and the `scripts/migrations/` framework track installs.
- **zsh and tmux configuration** (zinit, TPM, resurrect/continuum, a command
  palette), all following XDG.
- **CI**: shellcheck, shfmt and markdownlint (all version-pinned), the test
  suite, the suckless build with dwm run under Xvfb, an installer dry run,
  and a full installer run in Fedora containers (latest plus oldest
  supported).

### Fixed

These were caught before 0.1.0 was ever tagged. They are listed because each
one affected real installs up to that point:

- No display manager was ever enabled: Fedora ships a templated
  `ly@.service`, so the installer now enables `ly@tty2.service`.
- The installer aborted under `set -u` when `$USER` was unset.
- `polkit-gnome` was retired from Fedora, which left a fresh install with no
  PolicyKit agent. It was replaced by `lxpolkit`.
- The CI matrix was pinned to an end-of-life Fedora release.
