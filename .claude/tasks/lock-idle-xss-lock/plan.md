# Plan — lock-idle-xss-lock

## Goal
Epic sub-task 6/11. Wire idle + suspend + manual locking around the vendored,
already-themed slock. A new repo-managed `config/dwm/bin/dwm-lock` owns the
`xset` timers, the `xss-lock` launch and the manual lock; autostart gains one
line; `Super`+`l` and the powermenu's Lock entry both route through it.

## Scope
- config/dwm/bin/dwm-lock, config/dwm/bin/dwm-powermenu
- config/sxhkd/sxhkdrc
- scripts/install-session.sh
- KEYBINDINGS.md

## Allowed
- config/dwm/bin/, config/sxhkd/, scripts/install-session.sh, KEYBINDINGS.md

## Forbidden
- suckless/, packages/, scripts/symlinks.sh, docs/, ROADMAP.md, CLAUDE.md

## Steps
1. Write `config/dwm/bin/dwm-lock` — `--daemon` (xset s 600 600 / dpms 0 0 660,
   then guarded `exec xss-lock -- slock`), no-arg lock-now (loginctl when
   xss-lock runs, else slock), `-h`.
2. `install-session.sh`: add the `dwm-lock --daemon &` line to the autostart
   template and an xss-lock arm to `session_autostart_report`.
3. `sxhkdrc`: replace the commented pending block with a live `super + l`.
4. `dwm-powermenu`: lock entry -> `dwm-lock`.
5. `KEYBINDINGS.md`: Lock/idle section; drop the now-empty "Not yet bound".
6. Test: fake xset/xss-lock/slock/loginctl/pgrep on an isolated PATH; sxhkdrc
   parse; lint/pkglist/build.

## Out of scope
- docs/ + ROADMAP.md + CLAUDE.md staleness (sub-task 9); promoting
  xss-lock/xset out of extra.lst (standing follow-up); `xss-lock -n` notifier.

## Risks
- autostart.sh is user-owned once it exists — existing installs get a printed
  line, never an edit. Mitigate: report arm + KEYBINDINGS note.
- No xss-lock/xset/slock on this Arch/Wayland host — fakes only, flag it.
