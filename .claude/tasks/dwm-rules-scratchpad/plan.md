# Plan — dwm-rules-scratchpad

## Goal
Scope F slot 1. A dwm restart (every Super+w / `dots theme`) must keep each
window's tags, monitor, scratchpad stash and focus (F5, preserveonrestart).
Mod4+grave toggles a `dots-dropterm` alacritty scratchpad, spawning it if
absent (A1). The dead Firefox rule goes (F1); tools that open tiled get float
rules by their xprop-verified class (F2).

## Scope
- suckless/dwm/**
- suckless/dwmblocks/scripts/dwm-net
- tests/**
- KEYBINDINGS.md
- CLAUDE.md
- .claude/tasks/dwm-rules-scratchpad/**
- .claude/state/**

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. Red test first: tests/lib/dwm-runtime-restart.sh — tag, stash, focus and restart under Xvfb; assert state held. Must FAIL on today's dwm.
2. preserveonrestart in dwm.c (X property for tags+monitor, read in manage(); SCRATCHPAD_MASK kept; focused client restored) → step 1 green.
3. Dropterm: dwm function + Mod4+grave + dropterm cmd in config.def.h; Xvfb check (spawn, hide, show, single instance).
4. rules[]: drop Firefox; float pavucontrol, Gpick, org.gnome.FileRoller, Nm-connection-editor, dots-nmtui; dwm-net launches nmtui with that class (+ test); Xvfb check that a matching class floats.
5. Vendor both *-local.diff + PATCHES.md entries (rule 5); KEYBINDINGS.md row (dwm-keys reads it); CLAUDE.md roster 13 → 15.
6. Verify: rm config.h, tests/build.sh, tests/dwm-runtime.sh, tests/dwm-net.sh, tests/dwm-keys.sh, tests/lint.sh; mutation pass on copies.

## Out of scope
- Bar (slot 2), session/dunst/nm-applet/xdg-user-dirs (slot 3), VM checks (slot 4)
- Stopping reload.sh's restart (rejected, scope decision 6)

## Risks
- config.h stale build — rm it before make; nm the binary
- Xvfb test flakiness — reuse dwm-runtime-x.sh waits, never sleep-guess
- Scratchpad bit vs TAGMASK in the saved property — store full c->tags, test stash survives
