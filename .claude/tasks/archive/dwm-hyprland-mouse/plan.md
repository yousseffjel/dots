# Plan — dwm-hyprland-mouse

## Goal
Hyprland-style mouse window management in dwm (user choice 1+2+3+4, 2026-10-22):
resize from the grab point with no pointer warp, drag a tiled window into another
slot (stays tiled), resize tiled windows in both axes, snap to other windows' edges.

## Scope
- suckless/dwm/**
- tests/dwm-runtime.sh
- tests/lib/dwm-runtime-*.sh
- KEYBINDINGS.md
- CHANGELOG.md
- CLAUDE.md
- .claude/**

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. cfacts (bakkeby 6.6, 1st half of cfacts-dragcfact): Client.cfact, tile() weights, setcfact on Super+Shift+j/k/o; preserveonrestart carries cfact (16th value, 7/15 still read)
2. resizepoint (bakkeby 6.6): floating resize from the nearest corner, no warp, 4 corner cursors, hints ignored while dragging
3. local dragtile: Super+RMB on a tiled window, no warp — x moves the master split (mfact), y changes the grabbed edge's height (cfact); replaces dragmfact's warp
4. placemouse (bakkeby 6.6): Super+LMB = moveorplace {.i=1}; tiled stays tiled, floating moves freely
5. local snapwindows: floating move/resize snaps to visible windows' edges (snap px)
6. config.def.h: drop duplicate ClkTagBar MODKEY rows; PATCHES.md entries + .diff per patch; KEYBINDINGS.md; CLAUDE.md roster; CHANGELOG [Unreleased]
7. tests/lib/dwm-runtime-mouse.sh under Xvfb via xdotool: each behaviour + cfact across restart; tests/build.sh + lint

## Out of scope
- Border drag without Super, aspect-ratio resize, moveresize keys (item 5)
- Preserving client order across a restart

## Risks
- tile() change breaks pertag/preservepertag state — run dwm-runtime pertag + restart checks
- dwm.c hunks conflict with local patches — merge by hand, record in PATCHES.md
- xdotool drags flaky under Xvfb — wait on geometry with a timeout, not sleeps
