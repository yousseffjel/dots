# Context — dunst-keep-state

## Background
VM screenshots 2026-10-15 after notify-center: list empty after `dots update`; FOCUS on the bar while the centre offered "Turn on focus mode"; a dwm-osd Volume entry in history.

## Prior Decisions
- User: "apply fix both" (2026-10-15).

## References
- .claude/changes/2026-10-15-notify-center.md

## Notes
- Private-bus probes: reload keeps pid+history, applies colours, resets pause level to 0; history_ignore rule hides OSD from history but still shows it; OSD while paused waits, lands in history on resume.
- Root cause not yet confirmed on the VM (ssh agent gone).
