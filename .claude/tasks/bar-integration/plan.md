# Plan — bar-integration

## Goal
Scope F slot 2. Status-bar clicks match the keys: scroll/click on VOL, MIC
and GAMMA show dwm-osd (I2); GAMMA scrolls and toggles night light, cpu/mem/
temp open htop (I3); right-click on updates runs the upgrade, then refreshes
the block (I4). Every block script gets a test on a sealed PATH (A2).

## Scope
- suckless/dwmblocks/scripts/**
- suckless/dwm/config.def.h
- tests/**
- KEYBINDINGS.md
- CLAUDE.md
- .claude/tasks/bar-integration/**
- .claude/state/**

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. `dwm-blockutil` (sourced, like dwm-colors): block_bin <name> (PATH, then ~/.config/dwm/bin) and block_term <tool> <cmd…> (alacritty --class / st -c, class dots-float-<tool>). dwm-net + dwm-brightness-block use it.
2. config.def.h: one `dots-float-` rule replaces `dots-nmtui` (strstr prefix); dwm-net → dots-float-nmtui.
3. I2+I3: vol/mic clicks → dwm-osd (backgrounded); GAMMA scroll → dwm-brightness up/down + osd, left → dwm-nightlight toggle; cpu/mem/temp left → htop in a floating terminal.
4. I4: updates right-click → floating terminal: sudo dnf upgrade --refresh, hold open, then pkill -RTMIN+1 dwmblocks.
5. Test hooks: DOTS_PROC_ROOT for cpu/mem (precedent DOTS_HWMON_ROOT); capture real formats (pamixer, bluetoothctl, df -P locally; dnf check-update on the VM) for the fakes.
6. A2: tests/lib/blocks.sh + tests/blocks-{audio,system,info}.sh — output, guards (n/a, missing tool) and every click, on sealed PATH. KEYBINDINGS.md § Status bar clicks.
7. Verify: rm config.h + build, suite, lint, dwm-runtime float rules, mutations on copies.

## Out of scope
- dunst DND indicator block (slot 3), VM checks (slot 4)
- New blocks or interval changes

## Risks
- Block PATH lacks ~/.config/dwm/bin under dwmblocks — block_bin falls back to the install path
- Fakes drifting from real output — capture real formats, keep one real-binary cross-check where installed
- dwm-blockutil shadowing a config/dwm/bin name — grep both dirs first
