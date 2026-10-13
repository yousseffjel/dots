# default-apps
Date: 2026-10-13
Files: 70 (33 ours + 37 vendored suckless/nsxiv) | Lines: +9430/-107 (ours: +1180/-107)

## What changed
- `config/mimeapps.list`: video/audio → `mpv.desktop`; raster images →
  `nsxiv.desktop` (SVG stays on firefox); text/code →
  `sublime_text.desktop;dots-nvim.desktop;` (nvim is the fallback and stays in
  Open With). Firefox (web/PDF), file-roller (archives) and thunar unchanged.
- `suckless/nsxiv/`: upstream nsxiv v34, vendored unpatched (tarball sha256
  `eee8e947…a96474`), with `patches/PATCHES.md`. Built by `install-suckless.sh`
  (`PROGRAMS` + new `PROGRAM_INSTALL_TARGETS` for `install-desktop install-icon`).
  Build deps `imlib2-devel` and `libexif-devel` go in `build.lst` and the
  pacman/apt fallbacks. Themed via native `Nsxiv.*` resources in
  `xresources.dcol`.
- `config/mpv/mpv.conf` (symlinked): `vo=gpu-next,` (with fallback), `hwdec=auto`,
  `profile=high-quality`, `force-window=yes`. `mpv` added to `extra.lst`.
- New `scripts/install-pkg-repos.sh` (sourced by `install-pkg.sh` after the
  tiers): adds Sublime HQ's rpm repo and installs sublime-text (x86_64/aarch64
  only); enables RPM Fusion free + nonfree; `dnf swap ffmpeg-free ffmpeg
  --allowerasing`; installs `intel-media-driver`. `REPO` manifest rows
  (`file` / `release` / `swap`) only for changes this run made. Failures go to
  the yellow summary tier.
- `install-pkg-tiers.sh`: `SATISFIED_BY=(["ffmpeg-free"]=ffmpeg)`, so a
  re-run neither reinstalls ffmpeg-free over RPM Fusion's build nor reports a
  false red failure.
- New `scripts/uninstall-repos.sh`: `uninstall_repo_swaps` (before
  `uninstall_packages`) swaps ffmpeg back. `uninstall_repos` (after it) removes
  the repo file while sublime-text is gone, and the RPM Fusion release packages
  while nothing installed comes from `rpmfusion*`. Both are kept together,
  because nonfree's release requires free's. It fails closed if
  `dnf repoquery` fails.
- `deploy_app_file` (`install-restore-apps.sh`): a manifest-claimed copy that
  is byte-identical to a committed version of its source is replaced, so
  existing installs get the new mimeapps.list and edited copies are kept.
  `file_matches_history`/`dots_git` moved from `install-suckless-headers.sh`
  into `global_fn.sh` and are shared by both.
- `tests/build.sh` reads `PROGRAMS` from the installer instead of restating it,
  and fails when a `suckless/*/Makefile` is not in it.
- New tests: `default-apps.sh` (every handler has a provider),
  `pkg-repos.sh` (repo add/re-run/revert/fail-closed against stateful fake
  rpm/dnf on a sealed PATH), `app-file-upgrade.sh` (upgrade rule against a
  real throwaway git repo).
- Docs: CLAUDE.md (stack, map, rule 4: third/fourth repo exceptions + the
  nsxiv vendoring exception, xresources consumers), THUNAR.md (defaults table,
  HDR, upgrade rule), UNINSTALL.md (steps 5d/6b, kept keys), THEMING.md,
  TESTING.md, ROADMAP.md §4.3, desktop.lst ffmpeg-free comment, CHANGELOG
  [Unreleased].

## Why
The user asked for default apps (browser, zip/rar, images, video, Sublime
Text). Choices made through AskUserQuestion: Sublime from the official repo as
the default editor, mpv, nsxiv, and Firefox unchanged. They then asked whether
mpv handles HDR episodes. It does, but Fedora's `ffmpeg-free` has no HEVC
decoder (checked against `enable_decoders` on src.fedoraproject.org, f43 and
rawhide), so they picked RPM Fusion's full codecs and an Intel GPU. nsxiv is
not packaged by Fedora (mdapi 400 on f43/f44/rawhide), so the user chose to
build it from source over sxiv, imv or keeping feh.

## Assumptions
- Type B: an Intel GPU means `intel-media-driver` from RPM Fusion **nonfree**.
  The Intel option said so, so enabling nonfree counts as authorised. Locked
  decision 8 (RAR via unar) is not reopened.
- Type B: rule 4's "don't vendor anything that needs building" collided with
  the user's explicit nsxiv choice. Recorded as a named exception in rule 4
  (option B, with documentation) rather than silently.
- Type B: the swap is reverted with `dnf swap` back to ffmpeg-free, never by
  removing ffmpeg (that could remove its dependents).
- Type C: rpm signing keys imported for the repos are left on uninstall
  (documented in UNINSTALL.md).
- Verified only against docs and fakes, not live: dnf5 `swap`,
  `config-manager addrepo --from-repofile`, and `repoquery --queryformat
  '%{from_repo}'` (dnf5 docs). The Fedora VM rejected the SSH key this session.

## Test coverage
- `tests/run-tests.sh`: exit 0, 60/60 OK. `tests/lint.sh`: passed.
  `tests/build.sh`: all six programs build (nsxiv reports `nsxiv 34
  +inotify +statusbar +exif +multiframe`).
- Real `gio mime` in a sandboxed XDG tree resolves mkv/flac → mpv, png/ppm/heic
  → nsxiv (with the binary on PATH), svg → firefox, python/json → sublime_text.
- Mpv config parsed by mpv 0.41 with no errors.
- Mutations caught: missing REPO swap row, swap attempted after a failed RPM
  Fusion, ignored pre-existing repo file, per-repo (not family) in-use check,
  `-release` filter removed, sublime-text-installed guard removed, SATISFIED_BY
  emptied, fail-closed flipped, upgrade without history check, upgrade without
  claim check, mpv dropped from extra.lst, nsxiv without install-desktop.
- Audit (Medium+): 13 issues found and fixed. Reviewer: READY.

## Follow-ups
- On the Fedora VM: `dots update`, then `gio mime video/x-matroska`,
  `image/png`, `text/x-python`; play an HEVC file with `mpv -v` and confirm
  `hwdec` picks vaapi; then `dots uninstall --dry-run` to see the repo revert.
- `install-container` CI will now enable RPM Fusion and Sublime HQ in the
  container. Watch its first run.
- An nsxiv wrapper that opens the whole directory when one image is picked is
  not done (out of scope).
