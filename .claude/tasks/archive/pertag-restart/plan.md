# Plan — pertag-restart

## Goal
Scope G slot 2: a dwm restart (one per wallpaper change) keeps each tag's
layout, master size (mfact), master count and bar visibility, as it already
keeps tags, view, stash, floating size and focus (preserveonrestart).

## Scope
- suckless/dwm/**
- tests/**
- *.md
- .claude/tasks/pertag-restart/**
- .claude/state/**

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. Red test first (tests/lib/dwm-runtime-restart.sh, check_pertag_restart): tag 2 wider mfact, tag 3 monocle, tag 4 bar hidden; SIGHUP; each survives. Must FAIL today.
2. savestate(): root property _DWM_PERTAG — per monitor curtag, prevtag, and per tag nmaster, mfact x1000, sellt, both layout INDEXES, showbar.
3. restorestate(): read it BEFORE the view() loop; validate every value (bounds, layout index < LENGTH(layouts)); then apply the current tag's values directly — view() returns early when the saved view is the start view.
4. Rule 5: new patches/dwm-preservepertag-<date>-local.diff + PATCHES.md; CLAUDE.md roster 16 -> 17; KEYBINDINGS restart note; CHANGELOG [Unreleased].
5. Verify: rm config.h + build, dwm-runtime x3, suite, lint, mutations on copies.

## Out of scope
- Release / migration / dots update (slot 3)
- A live VM check (optional after merge + push)

## Risks
- view() early-return hides restored state — apply curtag's values explicitly; test the tag-1 case
- Layout pointers do not survive exec — store indexes, map back, reject out of range
- Property from a foreign client — same validation stance as _DWM_CLIENT_INFO
