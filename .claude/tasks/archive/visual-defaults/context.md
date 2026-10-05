# Context — visual-defaults

## Background
User request 2026-10-05 after the VM re-test: "fix the wallpaper and picom and the resolution".
Answers: wallpaper generated from palette; picom "no visible effect" -> "make it simple and make it
stable" (interpreted as option C: cheap effects only = inactive dim; shadows/corners/blur stay off);
resolution: auto-fit the VM window.

## Prior Decisions
- 2026-08-07 picom-perf-tuning: no shadows, opacity 1.0 everywhere. PARTIAL DECISION REVERSAL here
  (inactive-dim only). Shadows/blur/corners unchanged.
- themes/dark/wallpapers/README.md: no wallpaper binaries in git — preserved (generated, not shipped).
- Rule 6: autostart entry = three-place change. Rule 10: tiering (spice-vdagent -> extra.lst: VM-only convenience).

## References
- picom v13 man: inactive-dim, mark-ovredir-focused, use-ewmh-active-win (all "discouraged" in favour of
  rules, still supported; rules would change how existing *-exclude options apply).
- packages.fedoraproject.org: spice-vdagent in f43/f44/rawhide.
- scripts/theme/wallpaper.sh writes ~/.fehbg as `feh --no-fehbg --bg-fill <path>`.
