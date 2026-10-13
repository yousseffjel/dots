# keybind-remap
Date: 2026-10-13
Files: 30 | Lines: +553/-103

## What changed
- `suckless/dwm/config.def.h` keys[]:
  - Super+space runs the launcher, Super+Return the terminal, and zoom moves to
    Super+Shift+Return.
  - Super+Shift+q is now killclient, so Super+Shift+c is freed. Quit moves to
    Super+Shift+Escape.
  - The layout toggle moves to Super+Ctrl+space, and the scratchpads move from
    minus to Super+s / Super+Shift+s.
  - `dmenucmd` keeps its name, because `spawn()` in dwm.c compares against it
    to fill in `dmenumon`. It now runs `dwm-apps` with the same `-m`/`-fn`
    args.
- Rule 5 records:
  - The dynamicscratchpads local diff's keys hunk and the dropterm comment were
    updated in both dwm.c and its local diff.
  - PATCHES.md gained a note: chords are config, and upstream diffs keep their
    published chords as context lines.
  - The `dwm.1` keyboard section was updated.
- `config/sxhkd/sxhkdrc`: picker on Super+Shift+w, random on Super+w, theme
  menu on Super+Shift+t (Super+Ctrl+w freed), lock on Super+Shift+l
  (Super+Escape freed). Super+p does region -> clipboard (Shift+Print kept) and
  Super+Alt+p does full -> both.
- New `config/dwm/bin/dwm-apps`: a launcher in the style of rofi's drun.
  - Reads `.desktop` files from XDG_DATA_HOME, XDG_DATA_DIRS and the Flatpak
    exports, with first-desktop-id-wins precedence.
  - Skips Type != Application, NoDisplay, Hidden, OnlyShowIn/NotShowIn
    mismatches and a missing TryExec. Only `[Desktop Entry]` is read.
  - Strips field codes and turns `%%` into `%`. Honours Path=, and opens
    Terminal=true entries via `$TERMINAL -e`, alacritty by default.
  - Tells duplicate names apart by id.
  - Fields are separated by \037, not tabs: a tab IFS collapses empty fields.
- New `config/applications/dots-st.desktop`, deployed by
  `install-restore-apps.sh` (manifest row via `deploy_app_file`).
- Tests:
  - New `tests/dwm-apps.sh` (28 checks).
  - `key-collisions.sh` sentinel is now MODKEY+j (p left dwm).
  - `dwm-keys.sh` dwm-row sentinel is now Super+space.
  - dwm-runtime presses super+s / super+shift+s, and the new
    `check_launch_keys` checks that Super+Shift+q closes the window with dwm
    still alive and that Super+Return runs termcmd.
  - The fake alacritty exits when it gets no args, so the bare termcmd is not
    adopted as the dropterm.
- Docs:
  - KEYBINDINGS.md: every table, a dwm-apps paragraph and a "Remapped
    2026-10-13" note.
  - Every live reference to a moved chord: dwm-lock, dwm-powermenu,
    dwm-screenshot, install-session-report-applets.sh, desktop.lst consequence
    text, THEMING.md, THUNAR.md, UNINSTALL.md, ROADMAP.md, CLAUDE.md, the
    .zshenv comment.
  - CHANGELOG `[Unreleased]` Added + Changed.

## Why
The user asked for an explicit key list and for a launcher that, like rofi's
drun, lists GUI applications rather than every package's binaries. Six of the
requested chords were already taken, so the displaced functions needed new
homes. Those were asked, not assumed.

## Assumptions
- Type A, asked (AskUserQuestion):
  - Lock goes on Super+Shift+l, and Super+h/l keep resizing. The user rejected
    moving the resize pair.
  - Quit goes on Super+Shift+Escape, and random wallpaper on Super+w.
  - The launcher is our own script, with no package added and no key left for
    dmenu_run.
- Type B: zoom moves to Super+Shift+Return (swapped with the terminal) and the
  layout toggle to Super+Ctrl+space. Both were shown in the plan and approved
  with "/code". If wrong, change config.def.h keys[], dwm.1 and
  KEYBINDINGS.md.
- Type B (deviation, logged in progress.md): `dots-st.desktop` was added.
  Without dmenu_run, st (the no-GL fallback terminal) was otherwise
  unreachable. If unwanted, drop the file and its deploy line.
- Type C: Flatpak export dirs are a built-in fallback (overridable by
  `DWM_APPS_EXTRA_DIRS`), because a dwm session may not source
  /etc/profile.d/flatpak.sh.
- Known limitation: desktop-file `\s`-style string escapes in Exec are not
  decoded. Exec runs through `sh -c`, which matches the spec's quoting rules
  for the common cases.

## Test coverage
- `tests/run-tests.sh`: 54/54 OK. `tests/lint.sh` clean. `tests/build.sh`
  builds all five.
- `tests/dwm-runtime.sh` passes against a dwm built from this tree under Xvfb
  (`strings` confirms `dwm-apps` is in the binary), including
  `check_launch_keys`.
- Mutations on copies:
  - dwm-apps: 20 caught out of 20. Three survivors in the first round led to a
    fixture fix (the Link entry needed an Exec) and to removing a redundant
    first-key-wins guard. The default Flatpak dir is tested without the
    override.
  - dwm: Super+Shift+q put back as quit is caught (three FAILs).
- Real host: dwm-apps lists 89 apps in 74 ms.
- Not tested: the Fedora VM, and a real keyboard on a live session.
- Reviewer: WARN (UNINSTALL.md and THUNAR.md omitted dots-st.desktop), then
  READY.

## Follow-ups
- On the VM after merge: run `dots update`, which should print
  `refresh suckless/dwm/config.h`, then log out and back in, and press each new
  chord.
- Optional: hide the stock `nvim.desktop`, since it and `dots-nvim.desktop`
  both show as "Neovim (…)". Not done.
