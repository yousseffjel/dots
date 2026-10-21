# Plan — monitor-capture

## Goal
Screenshot and recording of the monitor under the pointer (user's pick
"This-monitor capture", 2026-10-21; they run 2×1080p). "full" captures the
whole X screen — both monitors — and region needs a drag.

## Scope
- config/dwm/bin/dwm-lib-monitor.sh (new, sourced, 644)
- config/dwm/bin/dwm-screenshot, dwm-lib-screenshot.sh, dwm-record
- tests/dwm-monitor-geometry.sh (new), tests/dwm-screenshot.sh, tests/dwm-record.sh
- KEYBINDINGS.md, CHANGELOG.md, packages/desktop.lst (xdotool consequence), CLAUDE.md map line

## Steps
1. Test first: pointer → monitor geometry over fake xdotool/xrandr (two side by side, stacked, offset, pointer in a gap, missing xdotool).
2. dwm-lib-monitor.sh: `monitor_geometry` prints WxH+X+Y.
3. dwm-screenshot: `monitor` mode / --monitor (maim --geometry).
4. dwm-record: `monitor` mode / --monitor (-video_size + DISPLAY+X,Y, even dims).
5. Docs, CHANGELOG, desktop.lst consequence text, CLAUDE.md map.
6. VM: shot + recording of each monitor are 1920x1080.

## Out of scope
- New key chords (Print's menu offers the mode).

## Risks
- `--listactivemonitors` format — capture it from the VM; fixture matches it.
- Pointer between monitors (gapped layout) — fail loudly, capture nothing.
