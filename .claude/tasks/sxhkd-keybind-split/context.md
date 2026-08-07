# Context — sxhkd-keybind-split

## Background

Roster Epic sub-task 4 of `.claude/tasks/scope-b-app-roster-finalization.md`.
Locked decision 7 keeps sxhkd in the roster: "dwm retains its base keybinds in
`config.def.h`; everything else moves to sxhkd." `sxhkd` has been packaged since
sub-task 2 but there is no `config/sxhkd/` in the repo — the package installs a
daemon that never starts and reads a config that does not exist.

Unblocks sub-tasks 5 (screenshot), 6 (lock/idle) and 11 (dynamic scratchpads),
all of which add bindings and need an owner for them.

## Prior Decisions

- **Locked decision 7** — sxhkd kept; dwm keeps its base window-management binds.
- **Locked decision 9** — desktop, not laptop, tuned for performance. No battery,
  no lid handling, no power daemons.
- **Locked decision 12** — brightness is `xrandr --brightness` (software gamma),
  not `ddcutil` and not `brightnessctl`. A desktop GPU exposes no
  `/sys/class/backlight`. The block label must not imply hardware brightness.
- **Sub-task 7's interval discipline** — brightness, mic and volume blocks run at
  interval 0, signal-driven only. Signals: brightness **6**, mic **7**, vol **8**.
  Every binding that changes one of those values must fire
  `pkill -RTMIN+<sig> dwmblocks` or the block never updates.
- **CLAUDE.md rule 6** — `install-suckless.sh` treats `autostart.sh` as user-owned
  once it exists. Never overwrite it.
- **CLAUDE.md rule 7** — `symlinks.sh` links directories and backs up conflicts.

## User decisions taken this session (2026-08-07)

Asked as a four-part option block, per the "present options before choosing
tools" convention:

1. **Split line: dwm keeps all its current binds.** sxhkd takes only bindings
   that do not exist yet. Rejected: moving powermenu/clipmenu out, and moving
   everything out. Consequence — and the reason this is a good outcome —
   `config.def.h` needs no *active* change, so existing installs get the whole
   sxhkd layer without the `rm -f config.h` + rebuild step that sub-task 3 had
   to document in KEYBINDINGS.md.
2. **App launcher keys: firefox and thunar only.** pavucontrol and
   blueman-manager were offered and declined — both are reachable as statusbar
   click actions in sub-task 7, and dmenu covers everything else.
3. **Screenshot and lock bind now, commented out**, each annotated with the
   sub-task that activates it. No dead keys; 5 and 6 become an uncomment.
4. **`brightnessctl` is dropped from `packages/extra.lst`** and documented under
   the NOT LISTED HERE header. It contradicted locked decision 12 — it cannot
   work on this target.

## References

- `suckless/dwm/config.def.h` — `keys[]` at line 149; commented theming block at
  lines ~122–147 (`wallselcmd` / `wallrandcmd` / `thememenucmd`).
- `scripts/install-suckless.sh` lines 158–204 — the autostart template and its
  grep-based "kept, add this yourself" branches for dwmblocks and clipmenud.
- `scripts/symlinks.sh` lines 29–45 — `LINKS` array and the comment explaining
  which categories may be symlinked.
- `packages/extra.lst` — `sxhkd` at line 58, `brightnessctl` at line 105,
  NOT LISTED HERE header at lines ~16–28.
- `KEYBINDINGS.md` — 133 lines; "Theming engine — not bound by default" section.
- `.claude/changes/2026-08-07-alacritty-main-terminal.md` — the config.h staleness
  caveat this task avoids needing.

## Notes

- **sxhkd and dwm both `XGrabKey` on the root window.** A keysym+modifier claimed
  by both goes to whichever grabbed first; the loser silently gets nothing. The
  two sets must be disjoint. dwm currently owns: `Mod`+p/b/j/k/i/d/h/l/Return/
  Tab/t/f/m/space/0/comma/period/y/u/x, `Mod+Shift`+Return/c/space/f/0/comma/
  period/q, `Mod+Ctrl+Shift`+q, TAGKEYS 1–9 (Mod, Mod+Shift, Mod+Ctrl,
  Mod+Ctrl+Shift), `Super+Shift`+x, `Super`+v.
- Free for sxhkd: every `XF86*` key, `Print`, and the whole `Super` space except
  `Super+v` and `Super+Shift+x`.
- `sxhkd` 0.6.3 is installed on this Arch dev host, so the sxhkdrc can be
  parse-tested for real. There is no `--check` flag; run the daemon briefly and
  read stderr instead.
- `pkill -USR1 sxhkd` reloads the config without restarting the daemon.
- Packaged and available: `pamixer`, `playerctl`, `xrandr`, `maim`, `slop`,
  `xss-lock`, `firefox`, `thunar`, `feh`, `xclip`.
- `config/sxhkd/` is safe to symlink — the theming engine does not touch it,
  unlike `config/dunst` and `config/picom`.
