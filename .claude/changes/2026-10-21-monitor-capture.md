# monitor-capture
Date: 2026-10-21
Files: 12 | Lines: +277/-28

## What changed
- New sourced `config/dwm/bin/dwm-lib-monitor.sh` (644): `monitor_geometry`
  prints WxH+X+Y of the monitor holding the pointer — `xdotool
  getmouselocation --shell` for the position, `xrandr --listactivemonitors`
  for the rectangles (the RandR monitors dwm lays out on). Half-open edges,
  first match only (mirrored screens), and a pointer on no monitor, an
  unreadable position or a missing xdotool fail with a reason; it never
  guesses.
- `dwm-screenshot`: `monitor` mode / `--monitor` (menu `full monitor window
  region`), `maim --geometry`; a failure is also a critical notification.
- `dwm-record`: `monitor` mode / `--monitor` (menu `full monitor region`),
  x11grab `-video_size` (rounded to even) + `$DISPLAY+x,y`; no monitor is a
  reported failure, not a silent cancel.
- Both scripts define a stand-in `monitor_geometry` when the lib is missing,
  so only `--monitor` fails then.
- New tests/dwm-monitor-capture.sh; tests/dwm-record.sh monitor cases (its
  fake xrandr now answers `--listactivemonitors` in the real format).
- KEYBINDINGS.md, sxhkdrc comments, desktop.lst xdotool consequence text,
  CLAUDE.md map line, CHANGELOG [Unreleased] Added.

## Why
The user runs two 1080p screens and picked "This-monitor capture" from the
multi-monitor options. `full` captures the whole X screen (3840x1080) and a
region drag rarely lands on a monitor's exact edges.

## Assumptions
- Type B: the monitor under the pointer, not the focused window's: an empty
  monitor has no window, and dwm focuses by pointer here. Alternative: the
  active window's monitor (xprop + xwininfo) — rejected for that reason.
- Type B: no new key chord; `Print` and `Super+r` menus offer the mode.

## Test coverage
- Test written first and failed; 14/14 mutants caught (two survivors —
  the missing-xdotool and position checks — pinned by message asserts).
- Full suite 104 OK; lint passed; reviewer READY.
- VM (2×1920x1080, real xdotool + xrandr + maim + ffmpeg6): pointer at
  10,10 and 1919,1079 → 1920x1080+0+0, at 1920,0 and 3839,1079 →
  1920x1080+1920+0; shots 1920x1080 (full 3840x1080); recording VP9
  1920x1080. Not verified: that the pixels differ per screen — slock's
  idle lock was up and paints both screens alike.

## Follow-ups
- Two screenshots in the same second share a file name; the second
  overwrites the first (found here, pre-existing).
- Remaining multi-monitor picks: status on every bar, windows return on
  replug.
