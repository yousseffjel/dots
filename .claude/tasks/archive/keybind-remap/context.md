# Context — keybind-remap

## Background
User request 2026-10-13: explicit key list + GUI-only dmenu launcher.

## Prior Decisions
- Answers (AskUserQuestion): lock -> Super+Shift+L, Super+H/L keep mfact; exit dwm ->
  Super+Shift+Escape; random wallpaper -> Super+W; own dwm-apps script, no dmenu_run key.
- super-modkey (2026-10-12): dwm and sxhkd share the Super space; tests/key-collisions.sh guards it.

## References
- .claude/changes/2026-10-12-super-modkey.md

## Notes
- scratchpad_show already toggles (show, then same key re-stashes).
- dwm-screenshot supports --full|--region and --clipboard|--both.
