# Context — stale-port-text

## Background
Void VM keybind sweep 2026-10-21: dwm-record source read showed ffmpeg-free; sweep of rendered --help found install-void.sh PORT IN PROGRESS paragraph.

## Prior Decisions
- Void port merged 2026-10-15 (CLAUDE.md).

## References
- scripts/install-void.sh --help (sed range 2,/^[^#]/)

## Notes
- uninstall_ly runs before uninstall_ly_build, which removes /etc/ly/config.ini when dots built ly.
