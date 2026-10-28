# Session and Autostart

This page covers how a dots X session starts and ends, which files drive it, who owns them, and what to touch when
you add something that should run at login.

Both files described here are written by
[`scripts/install-session.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-session.sh), which the
suckless build stage sources.

## The order of things

```text
ly (tty2) or startx
   |
   v
~/.xinitrc
   1. no session bus?  re-run self under dbus-run-session
   2. source /etc/X11/xinit/xinitrc.d/*.sh
   3. theme: merge the cached xresources + cursor, run ~/.fehbg
            (first login after a headless install: dots theme dark + a wallpaper)
   4. trap dots_session_end on EXIT; turn HUP/INT/TERM into a normal exit
   5. hand DISPLAY to D-Bus activation (the desktop portal needs it)
   6. start pipewire in the background
   7. run dwm in the foreground (never exec'd)
          |
          v
      dwm's autostart patch runs ${XDG_DATA_HOME:-~/.local/share}/dwm/autostart.sh
      (on every dwm start, restarts included)
          |
          v
      daemons: bar, compositor, hotkeys, clipboard, applets, ...
   |
   v
dwm exits -> EXIT trap -> dots_session_end -> X stops
```

## ~/.xinitrc

**A session D-Bus bus.** Void has no systemd user manager, and neither ly nor `startx` starts a session bus. So the
script re-runs itself under `dbus-run-session` before anything else. Everything after that (the theme's dconf
writes, the desktop portal, PipeWire, notifications) shares one bus that ends with the session. It is not
`exec`'d: if the bus daemon cannot start, the session carries on without one instead of ending before dwm.

**The theme, before dwm.** dwm reads its colours from X resources once, at startup. So the cached `xresources` is
merged here, before dwm runs. On the first login after a headless install there is no cache yet (the installer can
only theme a running X session), so it runs `dots theme dark` and picks an initial wallpaper, each bounded by
`timeout`. dwm starts whether or not that succeeds.

This must **never** move into `autostart.sh`. Re-theming a running dwm sends it `SIGHUP`, it re-execs, and every
dwm start re-runs `autostart.sh`. A theme step there would loop the session.
[`tests/xinitrc-theme.sh`](https://github.com/YoussefFjel/dots/blob/main/tests/xinitrc-theme.sh) runs the
generated file with fakes to hold all of this.

**Sound.** `pipewire` is started here, not in `autostart.sh`, because it must end with the session. PipeWire then
starts WirePlumber and its PulseAudio server through two config links the restore stage puts in
`~/.config/pipewire`.

**dwm is not exec'd**, so the shell survives dwm to run its `EXIT` trap.

## dots_session_end

Most autostart programs hold an X connection and die with the server. Some don't, and they are stopped
explicitly when the session ends, on every exit path:

- **Programs with no X connection** keep running after logout. `clipmenud` is a shell loop over `clipnotify` and
  `xsel`; after X was gone it failed forever and flooded ly's TTY. PipeWire and WirePlumber hold no X connection
  either.
- **X clients that only notice the server is gone on their next write**, and shell-loop daemons. `dwmblocks`
  sleeps between bar updates, and the night-light daemon is a loop. If either survives into the next login,
  `autostart.sh` (which starts each only when it is not already running) finds the old copy, starts nothing, and
  the old copy then dies: an empty bar.
- **Programs that die badly.** `xss-lock` would abort with a core dump on every logout; a plain `SIGTERM` before X
  stops lets it exit cleanly.

Programs that block on their X connection (sxhkd, picom, xsettingsd, the GTK applets) die quietly with the server
and need nothing here. The audio watcher for the bar is deliberately not listed: it exits on its own once
PipeWire is gone, and PipeWire is already stopped here.

When you add a daemon, decide which group it is in. If it outlives X, it belongs in `dots_session_end` as well.
Changing that function means also changing the paste lines existing installs are given (in
[`scripts/install-session-report-xinitrc.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-session-report-xinitrc.sh))
and the matching block in [docs/THEMING.md](https://github.com/YoussefFjel/dots/blob/main/docs/THEMING.md).
[`tests/xinitrc-report.sh`](https://github.com/YoussefFjel/dots/blob/main/tests/xinitrc-report.sh) rebuilds older
generations of `~/.xinitrc` from the current template and checks each is told exactly what it lacks, with lines
that appear in the docs.

## autostart.sh

`${XDG_DATA_HOME:-~/.local/share}/dwm/autostart.sh` launches the daemons. Its body comes from the
`session_autostart_*` functions in
[`scripts/install-session-template.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-session-template.sh)
and the desktop-applet part in
[`scripts/install-session-template-applets.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-session-template-applets.sh).
The template is split into parts only to respect the 60-line function cap.

Each daemon is started only if it is not already running, because the file runs again on every dwm restart.

Logic that may need to change later belongs in a linked script under `config/dwm/bin/`, with the autostart line
just calling it. For example, picom is started through `dwm-picom`, which picks the rendering backend. When that
choice was pasted inline, no fix could ever reach an existing install.

## User-owned once they exist

`autostart.sh` and `~/.xinitrc` are written **only if absent**. Once either exists, it is the user's, and the
installer never edits or overwrites it. On an existing install it prints a report instead: which daemons the file
does not mention, and the exact lines to paste.

The report functions are in
[`scripts/install-session-report.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-session-report.sh)
and its `-applets.sh` and `-xinitrc.sh` siblings. Never change the build flow so that it rewrites either file.

## Adding an autostart daemon: three places

All three are enforced by a test, so skipping one fails the build.

1. **The launch line**, in the right `session_autostart_*` part of `install-session-template.sh`, or in
   `install-session-template-applets.sh` for a desktop applet.
2. **A matching `session_report_daemon` call** in `install-session-report.sh` (or its `-applets.sh` sibling), so
   existing installs, whose `autostart.sh` is never rewritten, are told what to paste. The daemon name is the
   second argument; the test reads it from there.
3. **The name in `DAEMONS`** in
   [`tests/autostart-daemons.sh`](https://github.com/YoussefFjel/dots/blob/main/tests/autostart-daemons.sh).

The test **runs** both sides instead of parsing them: it executes the template and scans the generated file for
backgrounded commands, and runs the report against an empty `autostart.sh` and collects every daemon it complains
about. The two sets must match each other and `DAEMONS`. That is why splitting or renaming the functions costs the
test nothing.

Then check:

- **`dots doctor`.** It reads the daemon list from `session_autostart_report`, so a new daemon is checked
  automatically, as a process whose command line names it. If yours runs once and exits, execs something with a
  different name, or only applies on some machines, add it to the exceptions or `daemon_applies` in
  [`scripts/doctor-daemons.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/doctor-daemons.sh).
  `tests/doctor.sh` holds those to the report.
- **Session end.** If it outlives X, add it to `dots_session_end` (see above).
- **Packages.** If the daemon's package missing would be silent, it belongs in `desktop.lst` with consequence text.
  See [Packages](Packages).

Do not add an enumerated daemon list anywhere else, including installer messages or docs. One used to exist in the
"wrote autostart.sh" message and went stale.

## What dots doctor checks

`dots doctor` is read-only. For the session it checks, among other things, that:

- each daemon `autostart.sh` should start is running on this machine;
- the session has a D-Bus bus, and the desktop portal actually answers on it (not just that a preference is
  stored);
- dunst answers and focus mode was not left on, and the Secret Service is unlocked;
- picom runs the backend `dwm-picom` would choose;
- the running dwm and dwmblocks are not stale copies of a binary an install has replaced.

Every list it walks is read from the place that declares it. Its checks live in `scripts/doctor-*.sh`, and
`dots doctor --tsv` gives one machine-readable line per check from the same code path.
