# Plan — scratchpad-group

## Goal
Super+s shows every stashed scratchpad at once, gathered to the focused
monitor, laid out master + stack (1 = full, 2 = side by side, 3+ = first
left half, rest stacked right), floating; the next Super+s hides them all.
User choices 2026-10-22 (layout "Master + stack", monitors "gather").

## Scope
- suckless/dwm/**
- tests/dwm-runtime.sh
- tests/dwm-multimon.sh
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
1. Client.isscratchpad (set by Super+Shift+s, cleared by Super+=; dropterm never); drop the scratchpad_last_showed cycle
2. scratchpad_show: hide all visible members, or gather stashed members from every monitor to selmon and lay them out master + stack
3. preserveonrestart record value 17 = isscratchpad; a MASK-tagged non-dropterm from an older record is a member
4. Records: dwm-scratchpadgroup-20261022-local.diff; retire scratchpadfill (subsumed); PATCHES/KEYBINDINGS/CHANGELOG/CLAUDE roster
5. Tests: group layout, toggle hide, survives restart (dwm-runtime); gather across monitors (dwm-multimon); mutation-check; suite

## Out of scope
- Per-tag scratchpad sets; a ratio other than half for the master

## Risks
- check_preserve's stash checks rely on Super+s — keep one-window behaviour identical
- dropterm stashed via its own key must stay out of the group — assert it
