# calendar-cursor (scope K slots 6 and 7)
Date: 2026-10-27
Files: 13 | Lines: ~+330/-10 (two scripts, session template + report, package
list, two tests, docs; plus this log and the scope/plan records)

## What changed
- **Slot 6, calendar-popup.** `config/dwm/bin/dwm-calendar` (new, sh around a python3
  heredoc, PyGObject, GTK 3): a GtkCalendar under a "Tuesday, 27 October 2026" label
  in an undecorated dialog-type window, placed centred under the pointer and
  clamped to its monitor; dwm keeps it below the bar. A GtkApplication
  (`org.dots.Calendar`), so a second launch reaches the first over the
  session bus and closes it: the clock's toggle. Escape and focus-out close
  it too. Without a bus every launch opens its own window.
  `suckless/dwmblocks/scripts/dwm-clock` button 1 starts it through
  `block_bin` (so it is found off PATH, as under dwmblocks), backgrounded with
  output detached; without it, or without `gi`, the old `notify-send` of
  `cal` stays.
- **Slot 7, cursor-hide.** `unclutter --timeout 5` in
  `session_autostart_daemons`, its `session_report_daemon` line, and
  `unclutter` in `tests/autostart-daemons.sh`'s DAEMONS (rule 6). An X
  client, so nothing in `dots_session_end`. `dots doctor` picks it up from the
  report with no change (binary name = report name).
- `packages/extra.lst`: `python3-gobject`, `unclutter-xfixes` (A3: neither
  failure is silent in a way that matters — the clock falls back, the pointer
  simply stays).
- `tests/dwm-calendar.sh` (new): the real script on a private Xvfb + session
  bus; WM_CLASS matched against `rules[]` by the dwm-runtime parser, dialog
  type, toggle, no-bus fallback. Skips without Xvfb/xdotool/xprop/
  dbus-run-session/GTK 3 PyGObject. `tests/blocks-info.sh`: three new clock
  checks (popup; fallback without the script; fallback without python3).
- `docs/DESKTOP.md` § Calendar, § Hidden pointer; `KEYBINDINGS.md` clock row;
  `CHANGELOG.md`.

## Why
Scope K's last two slots. Slot 6 reverses locked decision 3's tool (yad), by
user decision: see the scope file.

## Verification method (rule 8)
- yad: `xbps-query -R -p run_depends yad` → `libwebkit2gtk41>=2.38.0_1`;
  `-p installed_size libwebkit2gtk41` → 122MB; the extracted `.xbps`'s binary
  `ldd`s `libwebkit2gtk-4.1.so.0`. zenity: `libwebkitgtk60`. gsimplecal: not
  in the index.
- python3-gobject 3.56.2 (671KB) is in main and the snapshot; gtk+3 ships
  `Gtk-3.0.typelib`.
- unclutter-xfixes 1.6: `.xbps` downloaded and extracted in the scratchpad;
  `/usr/bin/unclutter`, man page read for `--timeout`; run under Xvfb, its
  process name is `unclutter` (what the `pgrep -x` guard and doctor look for).
- dwm-calendar's WM_CLASS read with xprop under Xvfb:
  `"dots-float-calendar", "dots-float-calendar"` (Gdk.set_program_class +
  GLib.set_prgname).

## Test coverage
- `tests/dwm-calendar.sh` 7 checks, `tests/blocks-info.sh` (clock 5),
  `tests/autostart-daemons.sh` (19 daemons), `tests/doctor.sh`: pass.
- Full suite (`tests/run-tests.sh`): 116 of 116 OK, no skips. It first
  caught `tests/dwm-help.sh` running the then pure-Python script under bash,
  which is why it became sh around a heredoc. `tests/lint.sh` with CI's
  pinned shellcheck 0.11.0 and shfmt 3.13.1: pass. markdownlint not run (no
  node on the dev host).

## Follow-ups
- VM proof: click the clock → calendar under it, click again → gone; idle
  5 s → pointer hidden. An existing `autostart.sh` needs the unclutter line
  pasted (the installer prints it).
- First Python in the repo, a heredoc inside the sh script (so dwm-help.sh can
  run it under bash like every dwm-*). `tests/lint.sh` lints `*.sh` only, so it
  has no linter in CI; `py_compile` was run by hand.
