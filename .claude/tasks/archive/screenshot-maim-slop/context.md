# Context — screenshot-maim-slop

## Background

Roster Epic sub-task 5 of `.claude/tasks/scope-b-app-roster-finalization.md`.
Locked decision 2 chose **maim + slop** wrapped in a dmenu-driven
`config/dwm/bin/dwm-screenshot`, matching the `dwm-powermenu` pattern.
flameshot was rejected *because* it is Qt (locked decision 3 — GTK only).

Unblocked by sub-task 4, which created `config/sxhkd/sxhkdrc` and reserved
`Print` / `shift + Print` there, commented out, waiting on this script.

## Prior Decisions

- **Locked decision 2** — maim + slop, dmenu wrapper, no flameshot.
- **Locked decision 3** — GTK only. Nothing here may pull Qt.
- Sub-task 4 — dwm and sxhkd both `XGrabKey()`; the loser of a collision
  silently gets nothing. `Print` is unbound in `config.def.h`, so sxhkd may
  claim it. **No dwm rebuild is needed and `config.def.h` must not change.**
- dmenu reads its colours from the X resource database, so passing explicit
  `-nb/-nf/-sb/-sf` would *override* the theme — `dwm-powermenu` documents
  this and deliberately passes none. Same rule applies here.

## Decisions taken this session (user-answered)

1. **`xprop`, not `xdotool`**, for the active-window ID. Verified on
   packages.fedoraproject.org (F43/F44/rawhide). `maim -i` accepts the hex
   form `xprop` prints, confirmed by invocation — no decimal conversion.
2. **Two-level dmenu** — mode prompt, then destination prompt. Mirrors
   `dwm-powermenu`'s `confirm()` second-prompt shape; Escape aborts at either
   level.
3. **Theme the slop rectangle.** Source is `xrdb -query`'s
   `dwm.selbordercolor` — semantically "the selected thing's border", the
   same colour dwm draws around the focused window. slop's `-c` wants float
   RGBA, so a hex -> float conversion is needed; fall back to slop's default
   grey when xrdb is unthemed or absent.

## References

- `config/dwm/bin/dwm-powermenu` — the dmenu wrapper pattern to match.
- `config/dwm/bin/dwm-wallpaper` — the `readlink -f` repo-resolution pattern
  (not needed here: this script calls no repo script).
- `scripts/theme/wallpaper.sh` — `~/Pictures/wallpapers` + `DOTS_WALLPAPER_DIR`
  is the directory convention to mirror as `DOTS_SCREENSHOT_DIR`, and its
  `notify()` helper is the "notifications are a nicety, never a dependency"
  pattern.
- `.claude/changes/2026-08-07-sxhkd-keybind-split.md` — sub-task 4's log.

## Notes

- Versions on this host: maim 5.8.2, slop 7.7. Both present, so the script is
  genuinely testable here — but this box is Arch/Xwayland, not Fedora/X11.
- `slop -t` defaults to 2, so a plain click inside region mode already snaps
  to a window. Region and window modes therefore overlap; window mode earns
  its place by being mouse-free.
- `maim -i <id>` captures the window's screen area, so an overlapping window
  shows through. Normal X behaviour, worth a comment rather than a fix.
- `tests/lint.sh` globs `find . -maxdepth 2 -name '*.sh'`, so this script sits
  outside CI exactly like the other five `config/dwm/bin/*`. Shellcheck and
  shfmt it by hand.
