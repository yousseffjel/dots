# dwm-rules-scratchpad
Date: 2026-10-07
Files: 21 | Lines: +1157/-59 (before this log)

Scope F slot 1 of 4 (`.claude/tasks/scope-f-desktop-integration.md`, on main):
survey items F1, F2, F5 and A1.

## What changed
- **preserveonrestart** (`suckless/dwm/dwm.c`, new
  `patches/dwm-preserveonrestart-20261007-local.diff` + PATCHES.md entry).
  On the restart path only, `savestate()` writes `_DWM_CLIENT_INFO` on every
  client (tags, monitor, floating flag, floating geometry) and `_DWM_VIEW` on
  the root (selected monitor, focused window, each monitor's view).
  `manage()` reads the client record via `loadclientinfo()`; `main()` calls
  `restorestate()` after `scan()`, restoring the view through `view()` so
  pertag follows. Both properties are deleted as they are read. Private atoms,
  not advertised in `_NET_SUPPORTED`.
- **dropterm** (`dwm.c` + `config.def.h`, new
  `patches/dwm-dropterm-20261007-local.diff` + PATCHES.md entry).
  `Mod4+grave` spawns `alacritty --class dots-dropterm` when none is running.
  When it is showing and focused it stashes it into SCRATCHPAD_MASK;
  otherwise it brings it to the focused monitor's view, top-centre, 0.6 x
  0.45 of the window area, and focuses it. `applyrules()` marks it by class
  OR instance and floats it without a rule.
- **rules[]**: the stock `Firefox` rule is deleted. Its class is
  `org.mozilla.firefox`, so it never matched. Float rules were added for
  `pavucontrol`, `Gpick`, `org.gnome.FileRoller`, `Nm-connection-editor` and
  `dots-nmtui`, each read with xprop on the Fedora 44 VM.
  `dwmblocks/scripts/dwm-net` opens nmtui with that class (`--class` for
  alacritty, `-c` for st).
- Tests:
  - New `tests/lib/dwm-runtime-restart.sh` (`check_preserve`).
  - New `tests/lib/dwm-runtime-floating.sh` (`check_float_rules`, which
    reads rules[] from config.def.h, and `check_dropterm`, which uses a fake
    `alacritty` on dwm's PATH).
  - `restart_dwm`, `is_shown` and `win_width` were added to
    `dwm-runtime-x.sh`.
  - A left-click section was added to `tests/dwm-net.sh`.
- Docs:
  - `KEYBINDINGS.md`: the Super+grave rows and the restart behaviour.
  - CLAUDE.md: dwm roster 13 → 15 diffs, plus a restart note.
  - `sxhkdrc` comments: dwm now owns three Super chords.
  - The F5 note in the `tests/dwm-runtime.sh` header is resolved.

## Why
The 2026-10-06 log recorded F5 as "windows recovered by scan() after a
restart lose dwm's selected client", not investigated. Exploration found a
bigger cause. `scripts/theme/reload.sh` SIGHUPs dwm on every wallpaper change
and theme switch, and the restartsig re-exec carried no state. After every
Super+w, all windows were piled onto the starting view, stashed scratchpads
came back out, floating windows were re-tiled and focus was lost. The user
chose to fix this with upstream-style preserveonrestart (scope decision 6).
They chose a dwm-side dropterm over an sxhkd + xdotool script (decision 7),
so the terminal joins the dynamicscratchpads cycle and survives restarts. F1
and F2 come from the desktop survey.

## Assumptions
- Type B: preserveonrestart state is saved once, just before `execvp()`,
  not on every tag change as upstream does. It survives SIGHUP and
  Mod+Ctrl+Shift+q, but not a crash. The alternative was half a dozen call
  sites with dynamicscratchpads, and every future mutator would need
  remembering.
- Type B: private atoms `_DWM_CLIENT_INFO` / `_DWM_VIEW` instead of
  upstream's `_NET_CLIENT_INFO`, which is not EWMH.
- Type B: dropterm is matched by class OR instance, because alacritty's
  `--class` sets the class and st's `-c` sets the class as well.
- Type C: blueman-manager and the lxpolkit prompt get no rule. They are
  `_NET_WM_WINDOW_TYPE_DIALOG`, which `updatewindowtype()` already floats.
  blueman was observed on the VM; lxpolkit was not, because it cannot be
  raised over ssh.
- Pertag's per-tag mfact and layout are not saved. A restart restores the
  view, but each tag's layout falls back to its default. This is out of
  scope and not recorded anywhere else.

## Test coverage
- `tests/run-tests.sh`: 43/43 OK, 0 skipped, `dwm-runtime.sh` included and
  run against this slot's build.
- `check_preserve` failed 7/7 on the pre-fix tree and passes 7/7 after.
- dwm-runtime ran 3x and then 2x after the audit refactor, all green.
- Mutation pass on tree copies, never the worktree: 13/13 caught. M8 (no
  re-placement on show) survived the first round, and the test was
  strengthened by dragging the terminal away before re-showing it.
- Both diffs applied to HEAD in order reproduce `dwm.c` byte for byte.
- Not exercised by any test: the two defensive guards in the C code
  (restored geometry ≤ 0, empty saved view). The real alacritty was not
  tested either, because it cannot start without GL on the dev host's Xvfb.
- Reviewer: READY.

## Follow-ups
- Slot 4 (VM): after merge, run `git pull && scripts/install-suckless.sh`
  and re-login. Then check:
  - Super+grave with the real alacritty;
  - Super+w with windows spread over tags (nothing moves);
  - pkexec true (the lxpolkit prompt floats);
  - the NET block's left-click opens a floating nmtui.
- Possible later: persist pertag's per-tag mfact/layout across a restart.
- Next: slot 2 `bar-integration` (I2 I3 I4 A2).
