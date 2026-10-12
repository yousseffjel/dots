# Plan — polish-bundle

## Goal
Scope G slot 1: an existing .xinitrc gets only its missing lines; the doctor
names the one skip reason that applies; the wallpaper keys use the XDG
pictures dir, seed it, and never fail silently; dwm-screenshot drops under
the cap; the stale CI queue item is struck. CHANGELOG lines for each.

## Scope
- scripts/install-session*.sh
- scripts/doctor*.sh
- scripts/theme/**
- config/dwm/bin/**
- tests/**
- docs/**
- *.md
- .claude/tasks/polish-bundle/**
- .claude/state/**

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. session_xinitrc_report: with dots_session_end present, print only the missing pkill lines (no whole block); test cases updated.
2. doctor: daemon_applies' skip names its own reason (no VM / no adapter / no NetworkManager); test.
3. wallpaper.sh: dir = xdg_dir PICTURES /wallpapers (DOTS_WALLPAPER_DIR wins); create + seed from the generated default; failures notify; tests + KEYBINDINGS/THEMING.
4. Split dwm-screenshot (250 ln) — helpers to a sourced lib; tests unchanged and green.
5. CHANGELOG [Unreleased] lines (the MASTER_PLAN queue strike is main-side: post-merge sync).
6. Verify: suite, lint, mutations on copies.

## Out of scope
- Per-tag restart (slot 2), release/migration/dots update (slot 3)

## Risks
- wallpaper tests may use the real HOME — sandbox all four XDG vars (memory)
- Seeding copies an image the user never chose — only into a dir we created
- Report change for existing users — keep the full block when dots_session_end is absent
