# Context — ly-theme

## Background
User request 2026-10-12 "work on ly theme". Decisions: install + static theme
switch (one sudo per switch); look = clean, no animation, bigclock on.

## Prior Decisions
- Theme identity is rendered on a switch, never on wallpaper change.
- Uninstall is manifest-driven; reverts only what we changed.

## References
- VM ly-1.4.0-2.fc44: /etc/ly/config.ini, %config, `key = value`, colours
  0xSSRRGGBB (style byte; 0x00000000 = terminal default), full_color = true.
- f43/f44/f45 all ship ly 1.4.0; rawhide 1.5.0~rc1.

## Notes
- Linux VT quantises truecolor to its 16-colour palette.
