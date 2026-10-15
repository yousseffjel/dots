# notify-center — notification centre + always-visible focus-mode button

Date: 2026-10-15
Files: 18 | Lines: +905/-58

## What changed
- `config/dwm/bin/dwm-notify` (new): dmenu notification centre over
  `dunstctl history` (jq). Entries: focus mode on/off, `Clear all (N)`, then the
  history newest first (`app: summary — body`, markup stripped, entities decoded
  once, cut at 72 chars). Per item: open / delete / back. open = `history-pop
  <id>` + `xdg-open` of the first `urls` link (http/https/ftp/mailto only); in
  focus mode it resumes dunst first. delete = `history-rm`, then the list is
  re-read and shown again. `dwm-notify toggle` = focus mode. Every change sends
  signal 12.
- `suckless/dmenu`: `dmenu-xyw-20261015-local.diff` — upstream xyw (`-x -y -z`)
  rewritten as `placexyw()` on top of center+border; negative `-x` = gap from
  the RIGHT edge; result clamped to the monitor. `dmenu.c`, `dmenu.1`,
  `PATCHES.md`.
- `suckless/dwmblocks/scripts/dwm-dnd`: always visible — `󰂚 N` (history
  count) or `󰂛 FOCUS [held]`; left = `dwm-notify menu` (backgrounded via
  block_bin), right = `set-paused toggle`; muted bell when dunst does not
  answer. `blocks.def.h`: interval 0 → 5.
- `config/sxhkd/sxhkdrc`: `Super+Ctrl+n` → `dwm-notify` (was `dunstctl
  history-pop`). `Super+Shift+n` unchanged.
- `packages`: `jq` moved extra.lst → desktop.lst, with consequence text.
- `tests/notify-center.sh` (new, 31 checks), `tests/fixtures/dunst-history-1.13.2.json`
  (captured from real dunst), `tests/blocks-info.sh` DND section rewritten.
- Docs: KEYBINDINGS.md (bar table, signal-only paragraph, Notifications),
  CHANGELOG [Unreleased] Added/Changed, CLAUDE.md project map, doctor-notify.sh
  wording.

## Why
User request: a button to switch between notification mode and focus mode,
and a macOS-like list of notifications at the top right with open, delete and
clear all. DND already existed (Super+Shift+n, a block shown only while
paused); there was no way to browse or manage history.

## Key Technical Decisions
- User decisions (2026-10-15): top-right via a vendored xyw patch, not `-c`;
  bell left = centre, right = focus; jq promoted to desktop.lst.
- **Open cannot run the app's action.** Probed on a private D-Bus + Xvfb with
  dunst 1.13.2: after `close-all`, `history-pop` and `dunstctl action 0` emit
  only `NotificationClosed`, never `ActionInvoked`; history JSON has no actions.
  User re-decided: re-show + open the first link; in focus mode resume first
  (a popped notification only queues while paused).
- Block polled (5 s) as well as signalled: history grows on popup timeout and
  nothing signals then.
- Super+Shift+n kept inline — tests/blocks-info.sh requires each signal's pkill
  in sxhkdrc.
- jq output read into a variable, not a process substitution, so a jq failure
  (changed dunst format) says "cannot read dunst's history" instead of showing
  "No notifications".
- Block name `dwm-dnd` kept (deploy paths, manifest, blocks.def.h unchanged).

## Assumptions Made
- (B) Focus mode = `dunstctl set-paused` (pause level 1), as before.
- (B) Width 560, -x -12, -y 36 match dunstrc `offset = (12, 36)`; a larger bar
  font needs both moved.
- (B) Duplicate display lines resolve to the newest notification.
- (C) xdg-open reachable in the session; it is not declared in any list
  (pre-existing gap, shared with dunstrc `browser`). Open question to user.

## Test coverage
- `tests/run-tests.sh`: 73/73 (dwm-runtime included); `tests/lint.sh --strict`
  and `tests/build.sh` (all suckless programs, config.h removed first) pass.
- Mutations on scratch copies (never the worktree): 13 caught, including
  resume-in-focus, scheme whitelist, refresh on delete, sort, entity order,
  placement flags, loop, decoding, id mapping, empty-record guard.
- dmenu geometry under Xvfb (xwininfo): new flags place/clamp as documented;
  old vs new binary identical for `-l 5`, `-nc`, `-b -nc`, `-c -bw 3`, `-b -l 4`.
- End to end on a private D-Bus: real dunst + rebuilt dmenu + xdotool — list at
  x=1344 y=36 w=560 on 1920 px; delete, open (xdg-open fake logged the link),
  right-click → `FOCUS 1`, open in focus resumed, clear all → bare bell.
- Reviewer: WARN (stray `suckless/dmenu/d.pid` from the first test run) — removed.
- **Not verified:** the live dev desktop, the Fedora VM, a real app's link.

## Follow-ups
- Next release migration (0.4.0 → 0.5.0) must refresh an unedited
  `suckless/dwmblocks/blocks.h` (as 0.1.0 → 0.2.0 did), or existing installs
  keep the bell at interval 0.
- Decide whether `xdg-utils` goes into desktop.lst.
- Try it on the F44 VM (192.168.122.172) after merge.
