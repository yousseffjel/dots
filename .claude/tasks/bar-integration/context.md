# Context — bar-integration

## Background
Scope F slot 2 (main: `.claude/tasks/scope-f-desktop-integration.md`, items
I2 I3 I4 A2). Slot 1 merged at 2b7b794.

## Prior Decisions
- Blocks are interval-0 signal-driven for vol (8), mic (7), gamma (6); a click
  re-runs the block, so mutate before reading (dwm-vol header).
- dwm-brightness-block must not be renamed (shadows dwm-brightness).
- Gamma, not backlight; night light daemon owns gamma (dwm-nightlight header).
- updates block uses `dnf -C` + timeout; signal 1.

## References
- install-suckless.sh:178 installs dwmblocks/scripts/dwm-* to ~/.local/bin
- tests/dwm-net.sh (sealed-PATH pattern), tests/lib/sealed-path.sh

## Notes
- Design (Type B, stated in /plan output): shared sourced helper rather than a
  third copy of the terminal-pick loop; prefix float rule instead of one rule
  per pop-up tool.
