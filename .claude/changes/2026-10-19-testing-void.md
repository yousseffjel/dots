# testing-void
Date: 2026-10-19
Files: 5 docs (+ state) | Lines: +36/-17

## What changed
- GTK decision recorded (user, 2026-10-19: "Keep both"): docs/THEMING.md
  (GTK 2 section and the theme.conf paragraph), assets/themes/README.md,
  the gtk2.dcol header comment, and CLAUDE.md's two "queued question"
  sentences now say the shim and the gtk2 template stay by decision.
- TESTING.md: the picom probe fakes cpuinfo + DMI (not
  systemd-detect-virt); the sbin layout is Void's (base-files 0.146
  `usr/sbin -> bin`) as well as Fedora's since 42; "disposable Fedora
  environment" → Void; the services anecdote marked pre-port.

## Why
User items 1 + 2. Void packages gnome-themes-extra(-gtk), but installing it
adds nothing for GTK3, and its GTK2 theme has fixed colours, while the
template follows the wallpaper.

## Assumptions
- Type C: no CHANGELOG line (docs only, nothing a user would notice;
  CONTRIBUTING "Record the change").

## Test coverage
- Facts read from the .xbps files (method per rule 8): gnome-themes-extra
  3.28_4 Adwaita-dark/gtk-3.0/gtk.css `cmp`-identical to the shim;
  gnome-themes-extra-gtk ships gtk-2.0/gtkrc + engines/libadwaita.so;
  base-files 0.146 `usr/sbin -> bin`.
- lint ✓; run-tests rc 0, 94 OK; reviewer READY.

## Follow-ups
- none
