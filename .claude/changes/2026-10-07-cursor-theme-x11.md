# cursor-theme-x11
Date: 2026-10-07
Files: 15 (+ task folder) | Lines: +356/-16

## What changed
- `scripts/install-restore-theme-identity.sh`: two new identity writers.
  `theme_write_cursor_default` writes `${XDG_DATA_HOME}/icons/default/index.theme`
  (`Inherits=<cursor_theme>`) and claims the **directory** as a THEME row;
  `theme_write_xcursor_resources` writes `~/.cache/dots/theme/xcursor`
  (`Xcursor.theme`, `Xcursor.size`), unclaimed because the cache is wholly ours.
- Both are called by `install-restore-theme.sh` (installer) and by
  `theme-apply.sh`'s `apply_identity` (every switch, CLOBBER=1).
- `scripts/theme/reload.sh`: merges the xcursor file right after `xresources`,
  before the dwm HUP — dwm sets the root-window cursor once, at startup.
- `scripts/install-session.sh`: the generated `~/.xinitrc` merges it at login.
  `install-session-report.sh`: a fourth marker (`/xcursor`); a themed `.xinitrc`
  without it gets one paste line, an un-themed one gets it inside the theme block.
- `scripts/doctor-session.sh`: `check_cursor` compares GTK's
  `gtk-cursor-theme-name` with X's merged `Xcursor.theme`, falling back to the
  `index.theme` `Inherits=` — the order libXcursor uses.
- Tests: new `tests/cursor-x11.sh`; `tests/xinitrc-theme.sh` gained a
  cache+cursor merge-order case; `tests/doctor.sh` + `tests/lib/doctor-sandbox.sh`
  gained four cursor cases (the healthy fixture now runs the installer's writer,
  and `FAKE_XCURSOR` passes through `run_doctor`).
- Docs: `docs/THEMING.md` § The cursor outside GTK, `CHANGELOG.md` Fixed,
  `TESTING.md` entry.

## Why
User report: the mouse cursor changes shape between Firefox and the dwm
wallpaper. Root cause: `theme.conf`'s `cursor_theme`/`cursor_size` were rendered
into `gtk-3.0/settings.ini` and `xsettingsd.conf` only. libXcursor — used by dwm
(root window, bar), st, alacritty — reads neither; it consults the `Xcursor.*`
X resources, `XCURSOR_THEME`, then the XDG `default` icon theme. None was set, so
everything non-GTK drew the distro default. User chose to set both (A) the XDG
default theme and (B) the X resources over env vars in `.xinitrc` (option C),
which would not follow a theme switch and needs a hand edit on existing installs.

## Assumptions
- Type B: libXcursor on Fedora searches `~/.local/share/icons` (added in
  libXcursor 1.2.1; Fedora 43/44 ship 1.2.3). Not verified on a Fedora box.
  If wrong, (A) does nothing for libXcursor, and (B) still carries the theme
  wherever the `.xinitrc` merges it.
- Type B: the xcursor file lives in the cache, not under `~/.config`, so the
  existing `.xinitrc` cache-path variable covers it and uninstall's cache removal
  takes it. Alternative considered: `#include` from `xresources.dcol` — rejected,
  a missing include fails the whole xrdb merge and loses the colours too.
- Type B: index.theme claims the directory, not the file, so uninstall's
  `rm -rf` leaves no empty `icons/default/` behind (symmetry test passes).

## Test coverage
- `tests/run-tests.sh`: 42 OK, 1 SKIP (`dwm-runtime.sh` — no built dwm binary on
  the dev host; CI's `build-suckless` job runs it). `tests/lint.sh` passes
  (shellcheck, shfmt, markdownlint).
- Mutation on scratch copies, all caught: no `theme_identity_may_write` guard,
  claiming the file instead of the dir, dropping the size line, `theme-apply.sh`
  missing a writer call, the report's cursor branch disabled, the `.xinitrc`
  merge replaced by `true` (valid sh — not caught by a syntax error).
- Inconclusive: a doctor mutation (fallback reads `/dev/null`) — the scratch copy
  failed unrelated doctor checks, so the result proves nothing. The healthy
  fixture's "no warn" passes only through the `index.theme` fallback, which
  covers that branch indirectly.
- Not tested: a real dwm session. Nothing here has run on the Fedora VM yet.

## Follow-ups
- On the VM after merge: `dots theme dark` inside dwm, confirm the wallpaper
  cursor matches Firefox, `dots doctor` shows `cursor` ok; paste the `.xinitrc`
  line and re-login to confirm the size survives a login.
