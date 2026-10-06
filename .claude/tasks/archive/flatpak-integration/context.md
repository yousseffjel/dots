# Context — flatpak-integration

## Background
User request 2026-10-06 ("focus on flatpaks and integration") with a pasted
GNOME/Flatseal guide. Decisions locked in .claude/tasks/scope-e-flatpak-integration.md.

## Prior Decisions
- f831138 xdg-portal-gtk: write-unset / reset-unchanged DCONF rows; dark mode for GTK4 comes from the portal.
- Rule 4: third-party repo auto-enable needs an explicit ask — given for Flathub (scope-e decision 2).

## References
- scripts/install-restore-apps.sh:156-219 (apps_dconf_prefs), scripts/uninstall-apps.sh:84 (uninstall_dconf)
- scripts/global_fn.sh:85-117 manifest helpers; tests/color-scheme.sh, tests/lib/install-symmetry.sh:46-67
- scripts/doctor-session.sh:116-126 color-scheme check
- flatpak-run.c: user icons bound at /run/host/user-share/icons, fonts at /run/host/user-fonts
- gitlab.gnome.org/GNOME/gtk/-/issues/5661 (GTK_THEME breaks GTK4 flatpaks)

## Notes
- Cursor search path inside runtimes covers /run/host/user-share/icons only on newer runtimes (freedesktop-sdk MR 6777, unconfirmed) — the real-path grant works everywhere.
- Real cursor check must happen on the Fedora VM; sandbox cannot prove it.
