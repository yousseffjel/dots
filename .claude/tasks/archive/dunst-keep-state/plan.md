# Plan — dunst-keep-state

## Goal
A theme apply (every wallpaper change) must not end focus mode or wipe the
notification history, and OSD popups must not fill the notification centre.

## Scope
- scripts/theme/reload.sh
- config/theme/templates/always/dunst.dcol
- config/dunst/dunstrc
- tests/*.sh
- docs/THEMING.md
- *.md
- .claude/**

## Forbidden
- HyDE/**

## Steps
1. reload.sh reload_dunst: running dunst -> save pause level, `dunstctl
   reload`, restore level; reload failure -> old kill; not running -> skip.
2. dunst.dcol post-command -> `true` (reload.sh is the one owner); header text.
3. `[dots_osd]` rule (appname dwm-osd, history_ignore) in dunst.dcol + the
   static dunstrc, kept identical.
4. tests/dunst-reload.sh: real reload.sh on a sealed PATH with fakes; a
   lockstep check that both dunst configs carry the rule; fix stale test comments.
5. docs/THEMING.md (diagram + table), KEYBINDINGS note, CHANGELOG [Unreleased].
6. Verify: real dunst on a private bus (WAYLAND_DISPLAY unset) — reload.sh
   keeps history + pause; full suite + lint.

## Out of scope
- Persisting history across logout.

## Risks
- Tests touching the live dunst — fakes only; private bus with WAYLAND_DISPLAY unset.
- reload resets pause (dunst 1.13.2) — restore explicitly, tested.
