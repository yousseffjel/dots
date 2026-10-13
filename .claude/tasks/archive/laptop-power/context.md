# Context — laptop-power

## Background
scope-h slot 5 (last). Locked decision 2: power profiles via tuned-ppd + switcher.

## Prior Decisions
- scope-h: laptop-only packages/setup; desktop unchanged.
- extra.lst header: "power-profiles-daemon — desktop, not laptop. Locked decision 9." (reversed by scope-h).

## References
- tuned-ppd (f44): /usr/bin/tuned-ppd, tuned-ppd.service (Requires/After tuned.service, Type=dbus, WantedBy graphical.target), D-Bus activated (SystemdService=tuned-ppd.service); Conflicts ppd-service. NO powerprofilesctl (only power-profiles-daemon ships it; no standalone pkg in f43/f44).
- tuned-ppd.policy: switch-profile/hold/release allow_active yes, inactive/any no.
- tuned consts: PPD_DBUS_BUS org.freedesktop.UPower.PowerProfiles, object /org/freedesktop/UPower/PowerProfiles; legacy net.hadess.PowerProfiles.
- VM (Fedora Server f44): tuned, tuned-ppd, power-profiles-daemon all absent.
- SERVICE rows: uninstall_services disables each.

## Notes
- super+shift+p free in sxhkdrc and dwm config.def.h.
