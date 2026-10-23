# Plan — desktop-sounds

## Goal
Scope K slot 4: event sounds from sound-theme-freedesktop through pw-play — a
login chime (once per session), a notification sound (normal: message-new-
instant, critical: dialog-warning, low: silent), a volume tick on the raise/
lower keys, and a shutter on a delivered screenshot. One switch (`dwm-sound
off|on`). Focus mode mutes notifications for free: dunst runs a rule script
only when it SHOWS a notification (probed, dunst 1.13.2), and our pause
holds critical ones too. One sound of each kind at a time (flock -n), so a held key or
the burst after focus mode ends plays once.

## Scope
- config/dwm/bin/*, config/dunst/dunstrc, config/theme/templates/always/dunst.dcol
- config/sxhkd/sxhkdrc, packages/desktop.lst
- scripts/install-session-template-applets.sh, scripts/install-session-report-applets.sh
- scripts/doctor-daemons.sh, scripts/doctor-desktop.sh, scripts/doctor.sh
- tests/**, docs/*.md, CHANGELOG.md, CLAUDE.md, KEYBINDINGS.md

## Allowed

## Forbidden
- scripts/install-session-template.sh

## Steps
1. desktop.lst sound-theme-freedesktop; dwm-lib-session.sh (session_key lifted from dwm-xdg-autostart, which sources it)
2. dwm-sound (<event>, --login, on/off/status) + dwm-sound-notify (the dunst script)
3. dunst: always_run_script=false + [dots_sound] rule in dunstrc and dunst.dcol, held identical by tests/dunst-reload.sh
4. Hooks: sxhkd raise/lower tick; dwm-screenshot shutter + its success notifications go low (silent); rule-6 three places for --login + doctor one-shot
5. doctor check_sounds (off / no pw-play / no theme / dunstrc without the rule)
6. tests/desktop-sounds.sh (fake pw-play, sealed PATH) + doctor cases; docs DESKTOP.md § Sounds, CHANGELOG, CLAUDE.md, KEYBINDINGS
7. Full suite + lint

## Out of scope
- logout sound (the audio server dies with the session); per-event switches; a GUI toggle

## Risks
- a test playing audio on the dev host — pw-play is always a fake; sealed PATH
- existing installs keep an old dunstrc until the next theme change — doctor says so
