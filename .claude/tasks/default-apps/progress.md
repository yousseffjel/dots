# Progress — default-apps

## Status
`in-progress`

## Steps
- [x] 1. Vendor nsxiv v34 (sha256 eee8e947…) into suckless/nsxiv/ (PATCHES.md: none). imlib2-devel+libexif-devel to build.lst; nsxiv in PROGRAMS with desktop+icon installs and manifest rows; tests/build.sh.
- [x] 2. Theme nsxiv through Nsxiv.* in xresources.dcol. Ship config/mpv/mpv.conf (gpu-next with fallback, hwdec, high-quality), symlinked.
- [x] 3. New install-pkg-repos.sh: Sublime repo + sublime-text; RPM Fusion free+nonfree; swap ffmpeg-free for ffmpeg; intel-media-driver; REPO rows only for repos we added; failures in the summary. mpv in extra.lst; desktop tier treats ffmpeg-free as satisfied by ffmpeg.
- [x] 4. Uninstall: remove a repo we added only while none of its packages are installed (same rule as Flathub).
- [x] 5. mimeapps.list: video/audio → mpv, raster images → nsxiv (SVG stays on Firefox), text/code → sublime_text. Replace a deployed copy that is claimed and unchanged.
- [x] 6. Tests: every mimeapps .desktop has a provider; repos add/revert, ffmpeg-free satisfied-by and mimeapps upgrade, all with fake binaries on PATH.
- [x] 7. Docs: CLAUDE.md (rule 4, map, roster), desktop.lst comment, THUNAR.md, UNINSTALL.md, CHANGELOG.

## Deviations
- 2026-10-13: RPM Fusion codecs + Intel driver added after the user asked about HDR (Reclassification, still Large).

## Blockers
