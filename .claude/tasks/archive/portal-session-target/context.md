# Context — portal-session-target

## Background
VM 2026-10-06: `gdbus call ... Settings.ReadOne org.freedesktop.appearance color-scheme` -> "Could not activate remote peer 'org.freedesktop.portal.Desktop': startup job failed". GTK4/libadwaita Flatpaks (Text Editor) render light. scope-e decisions 8-9.

## Prior Decisions
- f831138 xdg-portal-gtk installed the portal + prefer-dark but never exercised it under real systemd (its log listed "the portal answering color-scheme" as unverified).
- dots-doctor log: "the portal check was left out because the portal is D-Bus activated" — that was about checking for a running process; this slot checks that it ANSWERS over D-Bus, which is the activation path itself. Not a reversal.
- Rule 6: ~/.xinitrc is user-owned once it exists; only a report.

## References
- xdg-desktop-portal 1.22.1 src/xdg-desktop-portal.service.in: PartOf/Requisite/After=graphical-session.target
- systemd 262 graphical-session.target: RefuseManualStart=yes, StopWhenUnneeded=yes (pulled in via BindsTo from our unit)
- Fedora xinitrc.d 50-systemd-user.sh imports DISPLAY/XAUTHORITY (xdg-portal-gtk log)

## Notes
- ~/.xinitrc is written by install-session.sh (build stage), not restore.
