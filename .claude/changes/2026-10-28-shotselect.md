# shotselect
Date: 2026-10-28
Files: 9 (one new script, the capture lib, its test, three docs, extra.lst comment, CLAUDE.md map, this log)

## What changed
- New `config/dwm/bin/dwm-shotselect` (sh around a Python heredoc, like
  dwm-calendar): reads the root window into a cairo ImageSurface with GDK
  BEFORE importing GTK or grabbing anything, maps a full-screen
  override-redirect window showing that frozen frame, seat-grabs pointer +
  keyboard once mapped, and saves the dragged rectangle as PNG with cairo.
  Escape / right button cancel (exit 2); exit 3 = python3-gobject/GTK/display
  missing. Partial redraws (old ∪ new rectangle) keep the drag cheap at 4K.
- If the grab fails with ALREADY_GRABBED (an open popup holds it), it sends
  `xdotool key --clearmodifiers Escape` ONCE and retries every 50 ms (20
  tries). Escape is never sent otherwise: with no popup it would reach the
  focused window.
- `dwm-lib-screenshot.sh` region mode calls it first (`DOTS_SHOTSELECT`
  overrides the path, for tests); 3/126/127 fall back to the old maim + slop
  + magick path, 1 notifies and fails, 0/2 return as-is.
- Comments in dwm-screenshot and dwm-shotkey, KEYBINDINGS.md, CHANGELOG,
  CLAUDE.md map, extra.lst's python3-gobject comment.

## Why
User: Super+a "takes time to be ready", and an open dropdown still closed.
Measured on the user's machine (Ryzen 5 PRO 215, 3840x2280): `maim` PNG
encode of the frozen frame 4.3 s, then the magick crop 2.5 s — slop appeared
only after the first. Reproduced the dropdown in Xvfb + dwm with a GTK combo:
the popup holds the POINTER grab, so slop printed "Couldn't grab the mouse
after 10 tries" and the user's click (meant for the drag) closed the menu.
The 2026-10-22 fix had measured page `blur`, not an open popup, so it missed
this. No client can take another's grab, so the frame is taken first and the
popup is dismissed after.

## Assumptions Made
- Type B: all region shots use the selector (Shift+Print, the delayed key),
  not only Super+a — same behaviour, and faster everywhere.
- Type B: python3-gobject stays in extra.lst (graceful slop fallback).
- Type B: a click with no drag (< 2 px) is ignored, not "select a window"
  as slop does.

## Test coverage
- Xvfb + dwm: GTK ComboBox popup, GTK Menu popup, no popup — all captured
  (popup visible in the PNG), rc 0. Firefox `<select>` open: captured, and the
  full chain (dwm-shotkey → dwm-screenshot → dwm-shotselect → xclip) put an
  image/png with the dropdown on the clipboard.
- Startup on the real 4K display: imports ~0.55 s + frame ~0.45 s ≈ 1 s to
  the frozen frame (was ~4.3 s before slop appeared). Not instant: a
  pre-warmed selector kept by dwm-shotkey would cut ~0.5 s (follow-up).
- tests/dwm-screenshot.sh: four new cases (selected, cancel, failure is not a
  slop retry, 127 falls back); the existing slop cases run with the fake
  answering 3. tests/dwm-help.sh passes (26 commands).
- shellcheck is not on the dev host; CI's lint job is the check.
- Firefox context menu untested (kiosk mode opened none).

## Follow-ups
- User confirms on the real desktop (no reinstall needed: config/dwm/bin is
  symlinked, so the next Super+a uses it).
- Optional pre-warm (see above).
