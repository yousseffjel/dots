# Plan — session-integration

## Goal
Scope F slot 3: nm-applet at login (I5); xdg-user-dirs at login + XDG dirs
for screenshots/recordings (F3); dunst DND/history keys, DND block, doctor (I1/I6).

## Scope
- scripts/install-session*.sh
- scripts/doctor*.sh
- config/dwm/bin/dwm-*
- config/sxhkd/sxhkdrc
- suckless/dwmblocks/**
- tests/**
- docs/**
- *.md
- .claude/tasks/session-integration/**
- .claude/state/**

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. Split install-session-template.sh + install-session-report.sh (238/239 ln) into a desktop-applets part; generated autostart.sh and report byte-identical; tests green.
2. I5 + F3 autostart: nm-applet (guard: NetworkManager running) and xdg-user-dirs-update — template, report call, DAEMONS; doctor daemon_applies / DAEMON_PROCESS; tests/doctor.sh.
3. F3: dwm-screenshot / dwm-record default dirs from xdg-user-dir (fallback ~/Pictures, ~/Videos); env overrides kept; tests.
4. I1: dwm-dnd block (signal 12, interval 0, empty unless paused, left-click unpauses) + blocks.def.h; sxhkd super+shift+n / super+ctrl+n.
5. I6: doctor check that dunst answers, warn while paused.
6. Tests (blocks-info DND, autostart, doctor, dwm-keys) + docs: KEYBINDINGS keys and 12-block table, blocks.h note, CLAUDE.md count.
7. Verify: rm blocks.h + build, suite, lint, mutations on copies.

## Out of scope
- VM checks (slot 4)

## Risks
- Split changes generated autostart.sh — diff it against HEAD's output
- dunstctl D-Bus-activates dunst — wrap in timeout, fine if it starts it
- Function cap check is heredoc-blind — measure template parts to EOF
