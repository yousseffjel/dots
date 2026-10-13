# Context — laptop-touchpad

## Background
scope-h slot 4. User 2026-10-13: Xorg snippet (not xinput at session start); all four behaviours on: tap-to-click, natural scrolling, disable-while-typing, two-finger right-click (ClickMethod clickfinger).

## Prior Decisions
- scope-h: laptop-only, manifest-tracked, desktop unchanged.
- APP rows: replace/remove only while unedited (file_matches_history) — the model for SYSFILE.

## References
- Fedora: xorg-x11-server-Xorg Requires xorg-x11-drv-libinput (VM: rpm -q --whatrequires).
- VM: /usr/share/X11/xorg.conf.d/40-libinput.conf; /etc/X11/xorg.conf.d/00-keyboard.conf.
- Arch wiki libinput: /etc/X11/xorg.conf.d/30-touchpad.conf with Identifier, MatchIsTouchpad, Driver "libinput", Option "Tapping" "on".

## Notes
- Preview offered to the user had MatchDriver; changed to Driver (told the user).
