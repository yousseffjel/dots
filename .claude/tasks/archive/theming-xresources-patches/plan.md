# Plan — theming-xresources-patches

## Goal
Add xresources runtime color support to dwm, st, dmenu, slock so the
upcoming theming engine can drive their colors from `~/.cache/dots/theme/xresources`.

## Scope
- suckless/dwm/{config.def.h,dwm.c,patches/*}
- suckless/st/{x.c,patches/*}
- suckless/dmenu/{config.def.h,dmenu.c,patches/*}
- suckless/slock/{config.def.h,slock.c,util.h,patches/*}

## Allowed
- suckless/dwm/, suckless/st/, suckless/dmenu/, suckless/slock/

## Forbidden
- suckless/dwmblocks/ (no xresources patch needed — uses status2d codes)
- HyDE/ (untracked reference clone, never touched)

## Steps
1. Hand-merge dwm xresources patch (6 color resources) against 10 existing patches
2. Apply st xresources-signal-reload patch (colors + USR1 live reload), clean apply
3. Hand-merge dmenu xresources patch (4 color resources) against 7 existing patches
4. Apply slock xresources patch (3 color resources), clean apply
5. Write PATCHES.md per tool documenting merge decisions
6. Verify `make` succeeds for all 4 tools

## Out of scope
- Font/geometry/timing X resources (borderpx, mfact, blinktimeout, etc.) — colors only
- dwm's Mod+F5 in-place reload hotkey — restartsig already covers reload
- slock capslock color (no capslock patch applied in this repo)

## Risks
- dwm hand-merge against 10 patches — mitigated: only touched colors[]/resources[],
  verified no other patch reads/writes those symbols before scheme creation
- dmenu CLI-flag vs Xresources precedence — mitigated: xresupdate() runs before
  arg parsing via its own temporary Display, matching upstream's own approach
