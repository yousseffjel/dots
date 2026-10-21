# Context — display-presets

## Background
VM: dwm-display extend -> Virtual-1 850x1001 (its preferred = viewer window size), twice. Host: HDMI-1 + HDMI-2 1920x1080, HDMI-2 lists 100 Hz, prefers 60.

## Prior Decisions
- Scope C decision 4: dwm-display is a dmenu menu; presets derived from xrandr, never hardcoded.
- User 2026-10-21: add save-profile, this-monitor capture, status on all bars, windows return on replug.

## References
- /usr/lib/udev/rules.d/40-monitor-hotplug.rules (autorandr --batch --change --default default)
- tests/wallpaper-follows-display.sh (repaint after a layout)

## Notes
- tests/dwm-display.sh is 238 lines: new cases in a sibling.
