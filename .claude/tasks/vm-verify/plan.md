# Plan — vm-verify

## Goal
Scope F slot 4 (F4): prove slots 1-3 and the 2026-10-07 session fixes on the
Fedora 44 VM, in a live dwm session. Record pass/fail per item with evidence
(command output or a maim screenshot). Any defect found is fixed here, tested.

## Scope
- .claude/tasks/vm-verify/**
- .claude/state/**
- .claude/changes/**
- scripts/**
- config/**
- suckless/**
- tests/**
- docs/**
- *.md

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. Preflight (user: VM up, main 855d39b on it, dwm login, ssh agent): baseline `dots doctor --tsv`.
2. Rebuild: rm config.h + blocks.h, install-suckless.sh --skip-deps; paste the printed autostart/.xinitrc lines; re-login.
3. Slot 1: Super+w with windows on 3 tags + a stash + a float (nothing moves); Super+grave real alacritty; float rules; pkexec true (lxpolkit floats).
4. Slot 2: each block click in the session (BUTTON=n): pop-ups, htop/upgrade/nmtui terminals float, sudo prompt, UPD refresh.
5. Slot 3: nm-applet in tray; ~/Pictures etc. exist, screenshot lands there; Super+Shift+n → DND block, Super+Ctrl+n; doctor rows.
6. 2026-10-07 carry-overs: clean TTY + no clipmenud after logout; bar after quick re-login; cursor size across login; tray-icon owner.
7. Fix any defect (test + diff/docs as rules need), then log every result.

## Out of scope
- Bare metal, a real GPU, Workstation as target (still open in MASTER_PLAN)

## Risks
- Driving the live VM desktop — act only via the session's own DISPLAY/D-Bus env, kill what is launched
- Keys sent with xdotool can hit the wrong grabber — confirm with the effect, not the keypress
- "Passes on the VM" is still not bare metal — say so in the log
