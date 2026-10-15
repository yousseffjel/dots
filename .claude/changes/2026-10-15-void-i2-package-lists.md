# void-i2-package-lists — I-2: packages/*.lst use Void names, checked by a test

## What changed
- `packages/*.lst` remapped to Void names. Highlights: `xorg-minimal` +
  `mesa-dri`, `xinit`, `glxinfo`, `ffmpeg6`, `NetworkManager` (moved to
  desktop.lst for nmtui), `noto-fonts-ttf`, `lxsession` (lxpolkit), `Thunar`,
  `clipmenu`/`clipnotify`, `dbus`/`elogind` (D2), `alsa-pipewire`,
  `libjack-pipewire`, `vim-huge`, `fd`, `wget`, `starship`,
  `power-profiles-daemon`, `pkgconf`. Dropped: ly (built from source, D1),
  Cascadia (vendored, D3 → new sub-task I-2b), jetbrains-mono,
  dnf-plugins-core.
- New `tests/void-pkgnames.sh` + `tests/fixtures/void-x86_64-pkgs.tsv`
  (14,890-package snapshot, main + nonfree). It fails on a non-Void name or a
  nonfree-only one; `--refresh` rebuilds the snapshot.
- Name-only test updates: fontconfig-stack (Cascadia `pending`),
  default-apps (Thunar), drivers laptop case, doctor ffmpeg-free cases
  removed. nmtui hint text in dwm-net, its test, and doctor-session.
- CLAUDE.md rule 8 rewritten for Void; CHANGELOG; scope file "I-2 outcome".

## Key Technical Decisions
- Offline snapshot, not a live fetch in the test, so CI stays deterministic
  and needs no network. Staleness is a warning after 90 days.
- A nonfree-only name fails, because the tier stages run before the repos
  step enables nonfree.
- `xorg-minimal` rather than `xorg-server`: the server alone has no input
  driver.
- lxsession rather than polkit-gnome: it keeps `/usr/bin/lxpolkit`, so
  autostart is unchanged.

## Assumptions Made
- (B) Void's Thunar installs `thunar.desktop` (upstream's id). The id was not
  read from the .xbps.
- (B) power-profiles-daemon serves the D-Bus API dwm-power uses. Still to be
  proven in I-7 or I-10.

## Test coverage
- Verified by downloading .xbps packages and listing their files: lxsession,
  polkit-gnome, unicode-emoji, NetworkManager, noto-fonts-ttf, pipewire,
  libavcodec6 (configure line). Dependencies read from repodata for
  xorg-minimal, brightnessctl and ffmpeg.
- void-pkgnames mutations on a scratch copy, 7/7 as expected: wrong case,
  nonfree name, Fedora name, a new 6th list, a truncated snapshot and a
  renamed parser all fail; a stale snapshot only warns.
- `tests/run-tests.sh` 75 OK, 1 SKIP (dwm-runtime, no binary).
  `tests/lint.sh --strict` passes. Reviewer READY.

## Follow-ups
- CI `install-dry-run` (Fedora container + dnf) will go red on Void names
  until I-9.
- Next: I-2b (Cascadia NF asset), then I-3 (xbps engine).
