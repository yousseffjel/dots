# Plan — gtk2-theme-template

## Goal
Theme GTK2 apps (chiefly lxpolkit, the polkit password prompt — it links
libgtk-x11-2.0) from the wallpaper palette. Fedora 44 retired
gnome-themes-extra, so no dark GTK2 theme is packaged; a palette-driven
~/.gtkrc-2.0 with plain rc styles (no engine) is the only route. User chose
this option 2026-10-06.

## Scope
- config/theme/templates/always/**
- scripts/install-restore-theme.sh
- tests/**
- docs/**, CLAUDE.md, CHANGELOG.md, .claude/tasks/gtk2-theme-template/**

## Allowed

## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. New template gtk2.dcol: render ${cacheDir}/gtkrc-2.0, post-command copies it to $HOME/.gtkrc-2.0
2. install-restore-theme.sh: claim ~/.gtkrc-2.0 (or back up a pre-existing one) — generalise theme_claim_gtk_css
3. tests/gtk2-template.sh: real engine, every shipped palette, post-command into a sandbox HOME
4. Extend install-uninstall-symmetry.sh: fresh (engine-written file removed) + lived-in (user's original restored)
5. Verify the rc really parses and renders dark: gtk2 in a fedora:44 container under Xvfb (scratchpad only)
6. Docs: templates README, THEMING.md, CLAUDE.md template list, CHANGELOG

## Out of scope
- GTK2 icon/font/cursor (xsettingsd already serves them to GTK2)
- Vendoring a GTK2 engine theme (needs building — rule 4)

## Risks
- rc syntax error only shows as a runtime Gtk-WARNING — step 5 checks it in a real GTK2
- post-command clobbers a gtkrc-2.0 created after install — same policy as gtk.css; document
