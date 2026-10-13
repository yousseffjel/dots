# Plan — default-apps

## Goal
Choose a default app for each common file type, using the user's picks (2026-10-13): Sublime Text
(installed from Sublime HQ's official rpm repo, the third rule-4 exception, reverted on uninstall)
for text/code, mpv for video and audio (full HEVC/HDR codecs from RPM Fusion free+nonfree: ffmpeg swap
and intel-media-driver, also rule-4 exceptions), nsxiv (vendored v34 under suckless/, built with make) for
images, and Firefox kept for web and PDF. feh stays for wallpapers, nvim stays under Open With.

## Scope
- suckless/nsxiv/**
- packages/*.lst
- config/mimeapps.list
- config/theme/templates/always/xresources.dcol
- scripts/install-suckless.sh scripts/install-pkg*.sh scripts/install-restore-apps.sh
- scripts/uninstall*.sh scripts/global_fn.sh
- tests/*.sh
- CLAUDE.md CHANGELOG.md docs/*.md ROADMAP.md

## Allowed
## Forbidden
- HyDE/ dwm-titus/

## Steps
1. Vendor nsxiv v34 (sha256 eee8e947…) into suckless/nsxiv/ (PATCHES.md: none). imlib2-devel+libexif-devel to build.lst; nsxiv in PROGRAMS with desktop+icon installs and manifest rows; tests/build.sh.
2. Theme nsxiv through Nsxiv.* in xresources.dcol. Ship config/mpv/mpv.conf (gpu-next with fallback, hwdec, high-quality), symlinked.
3. New install-pkg-repos.sh: Sublime repo + sublime-text; RPM Fusion free+nonfree; swap ffmpeg-free for ffmpeg; intel-media-driver; REPO rows only for repos we added; failures in the summary. mpv in extra.lst; desktop tier treats ffmpeg-free as satisfied by ffmpeg.
4. Uninstall: remove a repo we added only while none of its packages are installed (same rule as Flathub).
5. mimeapps.list: video/audio → mpv, raster images → nsxiv (SVG stays on Firefox), text/code → sublime_text. Replace a deployed copy that is claimed and unchanged.
6. Tests: every mimeapps .desktop has a provider; repos add/revert, ffmpeg-free satisfied-by and mimeapps upgrade, all with fake binaries on PATH.
7. Docs: CLAUDE.md (rule 4, map, roster), desktop.lst comment, THUNAR.md, UNINSTALL.md, CHANGELOG.

## Out of scope
- Sublime config/theming + licence nag; an nsxiv whole-directory wrapper
- Browser/PDF changes; NVIDIA drivers; real HDR output (X11 can't — tone-mapped only)

## Risks
- Third-party repo trust — the user authorised it explicitly on 2026-10-13. Signed (gpgcheck=1), x86_64/aarch64 only.
- No dnf on the dev host — test with fakes. The real path is checked on the Fedora VM (192.168.122.2).
- Replacing an existing mimeapps.list could clobber user edits — only if manifest-claimed AND it hashes to the previously shipped version.
