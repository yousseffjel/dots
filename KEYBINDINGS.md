# Keybindings

Two programs bind keys, and they own different halves of the keyboard:

| Owner | Source | Covers | Changing it costs |
| --- | --- | --- | --- |
| **dwm** | `suckless/dwm/config.def.h` | Window management — tags, layouts, focus, monitors, scratchpads, session — plus the terminal, app launcher, power menu and clipboard | A recompile |
| **sxhkd** | `config/sxhkd/sxhkdrc` | Media, volume, mic, brightness, theming, screenshots, screen lock, app launchers | `Super` + `Ctrl` + `r` |

Neither file is generated from the other, so an edit in one needs a matching
edit here — nothing keeps them in sync automatically.

**The two key sets must stay disjoint.** dwm and sxhkd both call `XGrabKey()`
on the root window. If both claim the same keysym and modifier, it goes to
whichever grabbed it first and the other silently gets nothing — no error, no
log line. `tests/key-collisions.sh` reads both files and fails the build on
an overlap, so run it after adding a binding to either one.

Every binding is on **Super** (`Mod4Mask`, the Windows/Command key):

- **Mod** = dwm's `MODKEY` = `Mod4Mask` = **Super** (`#define MODKEY Mod4Mask`).
  The dwm tables say `Mod` so they still read right if you change it.
- **Super** = the same key, written out in the sxhkd tables and for the three
  dwm chords `config.def.h` spells as `Mod4Mask`.

Alt is left to applications — tmux's `Alt` + `h`/`j`/`k`/`l`, `Alt` + `1`–`9`
and `Alt` + `Tab` used to be swallowed by dwm and now reach tmux. Until
2026-10-12 `MODKEY` was `Mod1Mask` (Alt).

> **Remapped 2026-10-13.** The launcher moved from `Super` + `p` to
> `Super` + `space`, and the terminal from `Super` + `Shift` + `Return` to
> `Super` + `Return`, swapping with zoom. Close window moved from `Shift` + `c`
> to `Shift` + `q`, and quit moved from `Shift` + `q` to `Shift` + `Escape`. The
> layout toggle moved to `Ctrl` + `space`, scratchpads from `-` to `s`, and lock
> from `Escape` to `Shift` + `l`. The wallpaper picker and random wallpaper
> swapped (`Shift` + `w` and `w`), and the theme menu moved from `Ctrl` + `w`
> to `Shift` + `t`. `Super` + `p` and `Super` + `Alt` + `p` are now screenshot keys.
> An existing install picks up the dwm half on its next build (see the note
> under Launching), then a logout.

dwm spawns programs with `execvp` and no shell, so its bindings use bare
command names resolved through `PATH`. `~/.config/dwm/bin` is on `PATH` via
`config/zsh/.zshenv`. sxhkd does run a shell, so its commands may use `&&`
and other operators.

## dwm

Compiled into `suckless/dwm/config.def.h`. Changing any of these needs a
rebuild — see the note under Launching.

### Launching

| Keys | Action |
| --- | --- |
| `Mod` + `space` | App launcher (`dwm-apps`) — installed graphical applications only |
| `Mod` + `Return` | Terminal (`alacritty`) |
| `Super` + `Shift` + `x` | Power menu (`dwm-powermenu`) |
| `Super` + `v` | Clipboard history (`dwm-clipmenu`) |
| `Super` + `grave` | Drop-down terminal (see Scratchpads) |

**`dwm-apps` lists applications, not commands** (2026-10-13). It reads the
`.desktop` entries under `~/.local/share/applications`, each
`$XDG_DATA_DIRS/applications` and the Flatpak export trees, and shows each by
its display name, the way rofi's drun mode does. Entries marked `NoDisplay` or
`Hidden`, or meant only for another desktop, are left out, and a copy in
`~/.local/share/applications` overrides or hides the system one with the same
file name. `Terminal=true` entries (htop, vim) open in alacritty, or
`$TERMINAL` if set. Plain `dmenu_run` (every binary on `PATH`) has no key any
more, but you can still run it from a terminal.

**st is still installed** as the fallback terminal for a machine with no
working GL — alacritty is GPU-accelerated and will refuse to start without
it. There is no keybinding for st; pick **st** in the launcher (`Mod` +
`space`) if alacritty ever fails to launch. st ships no `.desktop` file of its
own, so the installer deploys `config/applications/dots-st.desktop`. Both read the same wallpaper-derived
palette, so they look alike.

> **Changing the terminal, the fonts or a key requires a rebuild.**
> `suckless/*/config.h` is generated from `config.def.h`. Each build
> regenerates a `config.h` you never edited (it matches some past
> `config.def.h` in git) and keeps one you did, printing the command that
> shows what to merge — the old copy is kept as `config.h.pre-<timestamp>`:
>
> ```sh
> scripts/install-suckless.sh --skip-deps
> ```

### Window focus and layout

| Keys | Action |
| --- | --- |
| `Mod` + `j` / `k` | Focus next / previous window in the stack |
| `Mod` + `Shift` + `Return` | Promote the focused window to master (zoom) |
| `Mod` + `Tab` | Toggle back to the previously viewed tag |
| `Mod` + `Shift` + `q` | Close the focused window |
| `Mod` + `h` / `l` | Shrink / grow the master area |
| `Mod` + `i` / `d` | Increase / decrease the number of master windows |
| `Mod` + `b` | Toggle the status bar |
| `Mod` + `t` | Tiled layout |
| `Mod` + `f` | Floating layout |
| `Mod` + `m` | Monocle layout |
| `Mod` + `Ctrl` + `space` | Toggle between the last two layouts |
| `Mod` + `Shift` + `space` | Toggle floating for the focused window |
| `Mod` + `Shift` + `f` | Toggle real fullscreen (actualfullscreen patch) |

### Tags (workspaces)

| Keys | Action |
| --- | --- |
| `Mod` + `1`–`9` | View that tag |
| `Mod` + `Shift` + `1`–`9` | Move the focused window to that tag |
| `Mod` + `Ctrl` + `1`–`9` | Toggle that tag into the current view |
| `Mod` + `Ctrl` + `Shift` + `1`–`9` | Toggle that tag on the focused window |
| `Mod` + `0` | View all tags |
| `Mod` + `Shift` + `0` | Put the focused window on all tags |

### Monitors

| Keys | Action |
| --- | --- |
| `Mod` + `,` / `.` | Focus the previous / next monitor |
| `Mod` + `Shift` + `,` / `.` | Move the focused window to the previous / next monitor |

### Scratchpads

Dynamic, i3-style: stash **whichever window is focused**, whatever it is —
a terminal, a browser, anything. There is no pre-declared list of scratchpad
applications.

| Keys | Action |
| --- | --- |
| `Mod` + `Shift` + `s` | Stash the focused window into the scratchpad |
| `Mod` + `s` | Show / hide the current scratchpad window; keep pressing to cycle |
| `Mod` + `=` | Drop the current window out of the scratchpad set |
| `Super` + `grave` | Drop-down terminal: show / hide it; the first press starts it |

A stashed window is hidden from every tag — its whole tag set becomes a
single reserved bit above the nine real tags, so no ordinary tag view brings
it back and it is never drawn in the bar.

`Mod` + `s` is a single show/hide key, which is why there is no separate hide
binding. It works on one window at a time — the "current" one:

1. First press restores a stashed window onto the current tag and remembers
   it as the current one.
2. Press again and that same window is stashed away again.
3. Press a third time and the *next* stashed window is restored, wrapping
   round to the first.

So repeated presses go show → hide → show next → hide → …, and `Mod` + `s`
alone is enough to both summon a window and dismiss it. `Mod` + `=` breaks
the link instead — the window stays exactly where it is on screen and simply
stops being part of the rotation.

Two behaviours worth knowing, both inherited from the upstream patch:

- **Stashing makes a window floating, and restoring does not undo that.**
  `Mod` + `Shift` + `s` sets the window floating so it comes back as an
  overlay rather than re-tiling. Nothing sets it back, so a window that was
  tiled before you stashed it stays floating afterwards — `Mod` + `Shift` +
  `space` re-tiles it.
- **The cycle is per-monitor.** Stashed windows are looked up in the current
  monitor's client list, so a window stashed on one monitor is not reachable
  by `Mod` + `s` from another. Stash and restore on the same monitor.

**The drop-down terminal** (`Super` + `grave`, the key left of `1`) is one
alacritty window with class `dots-dropterm`, hanging from the top of the
screen, 60% wide. The first press starts it; after that the same key stashes
it when it is showing and focused, and otherwise brings it to the current tag
— from any monitor — and focuses it. While stashed it is an ordinary
scratchpad window, so `Mod` + `s` cycles it with the others. Its size and the
terminal it runs are `droptermw`, `droptermh` and `droptermcmd` in
`config.def.h`.

**A dwm restart keeps all of this.** A wallpaper change or theme switch
restarts dwm (`kill -HUP`), and so does `Mod` + `Ctrl` + `Shift` + `q`. Each
window keeps its tags, monitor and floating size, stashed windows stay
stashed, and the tag you were viewing and the focused window come back
(`preserveonrestart`, 2026-10-07). Before that, every restart piled all
windows onto tag 1 and un-stashed the scratchpads. Since 2026-10-12 each tag
also keeps its own layout, master size (`Mod` + `h`/`l`), master count
(`Mod` + `i`/`d`) and bar visibility (`Mod` + `b`), and `Mod` + `Tab` still
returns to the tag you were on before (`preservepertag`).

> **Changed 2026-08-07.** This replaces three fixed scratchpads that spawned
> pre-declared commands: `Mod`+`y` (an `st` terminal), `Mod`+`u` (`ranger`)
> and `Mod`+`x` (`keepassxc`). Only the terminal one actually worked —
> neither `ranger` nor `keepassxc` is in `packages/*.lst`, so those two were
> dead keys. To get the old terminal behaviour, spawn a terminal normally and
> stash it with `Mod`+`Shift`+`s` (`Mod`+`Shift`+`-` until 2026-10-13).
> `Mod`+`y`, `Mod`+`u` and `Mod`+`x` are now unbound and free to reuse.
>
> **This needs a dwm rebuild.** The bindings live in `config.def.h`, and
> `config.h` is generated once and then left alone, so an existing install
> must delete it first:
>
> ```sh
> rm -f suckless/dwm/config.h
> scripts/install-suckless.sh --skip-deps
> ```
>
> A fresh install is unaffected.

### Session

| Keys | Action |
| --- | --- |
| `Mod` + `Shift` + `Escape` | Quit dwm (log out) |
| `Mod` + `Ctrl` + `Shift` + `q` | Restart dwm in place (restartsig) |

### Mouse

| Action | Effect |
| --- | --- |
| `Mod` + left-drag | Move a window (makes it floating) |
| `Mod` + right-drag | Resize a window |
| `Mod` + middle-click | Toggle floating |
| Drag the layout split | Adjust master/stack ratio (dragmfact) |
| Click a status block | Runs the block's click handler (statuscmd) |
| Scroll over a status block | Same, with `$BUTTON` 4 (up) or 5 (down) |

---

## Status bar

Twelve blocks, left to right, then dwm's native systray furthest right. Each is a
script in `suckless/dwmblocks/scripts/`, installed to `~/.local/bin` by
`make install-scripts` and listed in `suckless/dwmblocks/blocks.def.h`.

| # | Block | Shows | Refreshes | Clicks |
| --- | --- | --- | --- | --- |
| 1 | `UPD` | Pending package updates | hourly | left → list them in a notification, right → `sudo dnf upgrade --refresh` in a terminal |
| 2 | `DISK` | Free space on `/` | 5 min | left → open `/` in thunar |
| 3 | `TEMP` | CPU package temperature | 5 s | left → htop |
| 4 | `CPU` | CPU utilisation | 2 s | left → htop |
| 5 | `MEM` | Used / total RAM | 10 s | left → htop |
| 6 | `BL` / `GAMMA` | Backlight (laptop) or screen gamma (desktop) level | **on change only** | left → night light on / off, scroll → brightness ±, with the pop-up |
| 7 | `MIC` | Microphone level, or `off` | **on change only** | left → toggle mute, with the pop-up |
| 8 | `VOL` | Output volume, or `mute` | **on change only** | left → mute, right → pavucontrol, scroll → ±5%; left and scroll show the pop-up |
| 9 | `NET` | Wi-Fi name and signal, `eth`, or `off` | 30 s | left → nmtui in a terminal (nm-connection-editor if nmtui is missing) |
| 10 | `BT` | Bluetooth state / connected count | 30 s | left → blueman-manager |
| 11 | `DND` | Shown **only** while notifications are paused; otherwise empty and takes no space | **on change only** | left → resume notifications |
| 12 | `` | Day, date and time | 60 s | left → this month's calendar |

**The bar behaves like the keys** (2026-10-07). A click or scroll that changes
a level shows the same `dwm-osd` pop-up as the volume, mic and brightness
keys. Every terminal a click opens (`nmtui`, `htop`, the upgrade) floats: its
class is `dots-float-<tool>`, and one `dots-float-` rule in `config.def.h`
matches them all. The terminal is alacritty, or st without it. The helpers
live in `dwm-blockutil`, sourced by the blocks the way `dwm-colors` is. The
upgrade terminal refreshes `UPD` the moment dnf finishes and stays open until
Enter, so a failed upgrade can be read.

> **Scroll on the bar needs a dwm rebuild on an existing install.** dwm bound
> `ClkStatusText` for Button1/2/3 only, so a scroll was discarded before any
> block saw it; `buttons[]` gained Button4/5 for this. Everything else in the
> table works after a dwmblocks rebuild alone. To pick up the scroll:
>
> ```sh
> rm -f suckless/dwm/config.h
> scripts/install-suckless.sh --skip-deps
> ```

**`NET` and `DND` need a dwmblocks rebuild with a fresh `blocks.h` on an
existing install.** The block list is compiled in, and `blocks.h` is generated from
`blocks.def.h` once and then left alone:

```sh
rm -f suckless/dwmblocks/blocks.h
scripts/install-suckless.sh --skip-deps
```

**`BL`/`GAMMA`, `MIC`, `VOL` and `DND` are never polled.** They run once at startup
and then only when something sends their signal — `config/sxhkd/sxhkdrc` fires
`pkill -RTMIN+6/7/8 dwmblocks` after every brightness, mic and volume change, and
`-RTMIN+12` after `Super` + `Shift` + `n`. That keeps them off the CPU
entirely (`tests/blocks-info.sh` holds every signal-only block in
`blocks.def.h` to a sender in `sxhkdrc`). The cost is that changing any of
those values by some *other* route (`pamixer` or `dunstctl` straight from a
shell, say) leaves the bar stale until the next keypress.

> **`BL` is a backlight, and `GAMMA` is not.** On a laptop, `dwm-brightness`
> dims the backlight with `brightnessctl` (installed only on laptops by
> `dots drivers`), and the block says `BL`. A desktop GPU has no
> `/sys/class/backlight`, so there it scales the output signal with
> `xrandr --brightness` while the monitor keeps drawing full power. The block
> then says `GAMMA` rather than `BRI` precisely so it does not promise a power
> saving it cannot deliver. The brightness keys are the same on both.

`TEMP` matches sensors **by name** (`coretemp`, `k10temp`, `zenpower`,
`cpu_thermal`), never by hwmon number — that numbering is assigned in probe
order and changes between boots. A machine whose CPU sensor is named something
else shows `n/a` rather than silently reporting an NVMe drive or the
motherboard; add the name to `CPU_SENSORS` in `dwm-temp` to fix it.

`UPD` runs `dnf -C check-update` — cache-only, never the network, since
dwmblocks runs blocks synchronously and one slow block stalls the whole bar.
The count is therefore as fresh as Fedora's own `dnf-makecache.timer` and no
fresher.

---

## sxhkd

Everything below is bound in `config/sxhkd/sxhkdrc`, read from
`~/.config/sxhkd/sxhkdrc` (symlinked by `scripts/symlinks.sh`). The daemon is
started by the dwm autostart hook that `scripts/install-suckless.sh` writes.

Edits take effect on `Super` + `Ctrl` + `r` — no rebuild, no logout.

> **If none of these keys work, sxhkd is not running.** Check with
> `pgrep -x sxhkd`. `install-suckless.sh` will not add the launch line to an
> `autostart.sh` you already had — it prints the line for you to paste
> instead, because that file is treated as yours once it exists.
>
> The same applies to **picom**, added to the autostart template on
> 2026-08-07. Until then nothing started the compositor at all, so an
> `autostart.sh` written before that date has no picom line and you are
> running with no compositing — check `pgrep -x picom`, and paste:
>
> ```sh
> command -v picom >/dev/null && ! pgrep -x picom >/dev/null && picom &
> ```

### Media

Routed over MPRIS by `playerctl`, so they reach any compliant player
(firefox, spotify, mpv with the script) with no per-app setup, and no-op
quietly when nothing is playing.

| Keys | Action |
| --- | --- |
| `XF86AudioPlay` | Play / pause |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |
| `XF86AudioStop` | Stop |

### Volume and microphone

| Keys | Action |
| --- | --- |
| `XF86AudioRaiseVolume` | Volume +5% — also unmutes |
| `XF86AudioLowerVolume` | Volume −5% |
| `XF86AudioMute` | Toggle output mute |
| `XF86AudioMicMute` | Toggle microphone mute |

Raising unmutes, matching what a hardware volume key does elsewhere.
Lowering deliberately does not — turning a muted system down should not make
it audible.

Each of these also fires `pkill -RTMIN+<n> dwmblocks`. That is not a
cosmetic refresh: the volume and mic status blocks poll at interval 0, so
the signal is the *only* thing that updates them.

Every volume, mic and brightness key then runs `dwm-osd`, which shows a
dunst pop-up with the new level as a progress bar. Holding a key updates one
pop-up rather than stacking new ones. Without dunst running, the keys still
work and simply show nothing.

### Brightness

| Keys | Action |
| --- | --- |
| `XF86MonBrightnessUp` | Brightness +10% |
| `XF86MonBrightnessDown` | Brightness −10% |
| `Super` + `n` | Night light on / off (`dwm-nightlight`) |

> **This is not a backlight control.** The target is a desktop with no
> `/sys/class/backlight`, so `config/dwm/bin/dwm-brightness` scales the
> output signal with `xrandr --brightness` instead. The image gets darker;
> the monitor's lamp stays at full power. It never goes below 10% — a black
> screen has to be undone from a terminal you can no longer see.

**The night light** warms the screen from 19:00 to 20:00 and back from 06:00
to 07:00 (6500 K by day, 4000 K at night; the times are constants at the top
of `config/dwm/bin/dwm-nightlight`). Its daemon starts at login when
`gammastep` is installed. While it runs it is the only thing that sets the
screen's gamma, and the brightness keys go through it, because two programs
writing the same gamma would undo each other within seconds.

All connected outputs are set together, so displays that have drifted apart
converge on the next keypress. From a shell:

```sh
dwm-brightness get        # integer percent, for scripts
dwm-brightness up|down
dwm-brightness set 70
```

### Screenshot

| Keys | Action |
| --- | --- |
| `Print` | Screenshot menu — pick a mode, then a destination |
| `Super` + `p` | Drag a region straight to the clipboard, no prompts |
| `Shift` + `Print` | The same as `Super` + `p` |
| `Super` + `Alt` + `p` | Whole screen, to the clipboard **and** saved as a file, no prompts |

`Print` opens two dmenu prompts in sequence:

```text
screenshot>          dest>
  full                 clipboard
  window               file
  region               both
```

Escape at either prompt aborts and captures nothing. `file` and `both` write
to `screenshots/` inside your pictures folder — `xdg-user-dir PICTURES`,
so a localised or moved one is honoured, else `~/Pictures` — overridable
with `DOTS_SCREENSHOT_DIR`, named
`dots-screenshot-YYYYmmdd-HHMMSS.png`.

`Super` + `p` deliberately does **not** also keep a file. Region grabs are
overwhelmingly paste-once, and a keybind that quietly fills a directory is one
you end up cleaning up after — press `Print` (or `Super` + `Alt` + `p` for
the whole screen) when you want the shot kept.

Every one of these keys runs `config/dwm/bin/dwm-screenshot`, which drives `maim` for the
capture, `slop` for the region selector and `xclip` for the clipboard. The
selector rectangle is drawn in `dwm.selbordercolor` read live from `xrdb`, so
it matches the border dwm puts around the focused window and re-themes with
the wallpaper. Unthemed, it falls back to slop's own grey.

> **`window` means the *focused* window, not one you click.** It resolves
> `_NET_ACTIVE_WINDOW` via `xprop`, so it needs no mouse — that is the only
> thing it does that region mode cannot, since a plain click inside a region
> selection already snaps to whatever window is under the pointer. maim
> captures the window's screen rectangle, so anything stacked on top of it
> appears in the image.

From a shell, both prompts can be skipped:

```sh
dwm-screenshot                        # both prompts
dwm-screenshot --region               # region, then ask where it goes
dwm-screenshot --full --both          # no prompts at all
```

### Screen recording

| Keys | Action |
| --- | --- |
| `Super` + `r` | Start a recording (pick full screen or a region), or stop the one running (`dwm-record`) |

Recordings are VP9 video in WebM, with no audio, saved to `recordings/`
inside your videos folder (`xdg-user-dir VIDEOS`, else `~/Videos`;
`DOTS_RECORD_DIR` overrides). Fedora's `ffmpeg-free` cannot encode H.264, so
convert one if a site insists on MP4. Stopping lets ffmpeg finish the file
cleanly, so it plays even if you stop mid-motion.

### Lock and idle

| Keys | Action |
| --- | --- |
| `Super` + `Shift` + `l` | Lock the screen now |

The screen also locks by itself:

| After | What happens |
| --- | --- |
| 10 minutes idle | `slock` takes the screen |
| 11 minutes idle | The monitor powers down (already locked) |
| Any suspend | `slock` takes the screen before the machine sleeps |

**The order is the point.** Locking is set to land a minute *before* DPMS
blanks the display, so the screen is never dark-but-unlocked — a state where
wiggling the mouse would drop you straight onto a live desktop.

All of it is `config/dwm/bin/dwm-lock`, which the power menu's `lock` entry
also calls. It runs in two modes:

```sh
dwm-lock                              # lock now
dwm-lock --daemon                     # arm the timers, then run the daemon
```

`--daemon` sets `xset s 600 600` and `xset dpms 0 0 660`, then execs
`xss-lock -- slock`. It is started once per session from
`~/.local/share/dwm/autostart.sh`. To change the timings, edit `LOCK_SECS` and
`DPMS_OFF_SECS` at the top of the script — not `autostart.sh`, which only
holds the one launch line.

**Why `xss-lock` and not `xautolock`:** it hooks systemd-logind as well as X's
screensaver, so it also locks on suspend, which xautolock structurally cannot
do. That is also why `Super` + `Shift` + `l` goes through `loginctl lock-session` when
the daemon is up — logind's own record of whether the session is locked stays
truthful, and every trigger ends in the same locker. With no daemon running it
calls `slock` directly instead, so the key never silently does nothing.

> **If the screen never locks on its own, the daemon is not running.** Check
> with `pgrep -x xss-lock`. As with sxhkd, `install-suckless.sh` will not add
> the launch line to an `autostart.sh` you already had — it prints the line
> for you to paste. `Super` + `Shift` + `l` keeps working either way.

### Notifications

| Keys | Action |
| --- | --- |
| `Super` + `Shift` + `n` | Do not disturb on / off (dunst holds notifications, shows them on resume) |
| `Super` + `Ctrl` + `n` | Re-show the last closed notification; repeat to go further back |

While do-not-disturb is on, the bar shows `DND` (click it to resume), and
`dots doctor` warns — a pause left on silently swallows every notification.
dunst keeps the last 20 (`history_length` in `config/dunst/dunstrc`).

### Applications

| Keys | Action |
| --- | --- |
| `Super` + `Shift` + `b` | Firefox |
| `Super` + `e` | Thunar |

Only the two daily drivers get a dedicated key — everything else is one
`Mod` + `space` away through the launcher.

### Theming engine

| Keys | Action |
| --- | --- |
| `Super` + `Shift` + `w` | Pick a wallpaper from a dmenu list, then re-theme |
| `Super` + `w` | Random wallpaper from the wallpaper dir, then re-theme |
| `Super` + `Shift` + `t` | Theme menu — pick a static theme or `wallbash` |

These were previously shipped commented out in `config.def.h` under `Mod` +
`w`, needing a rebuild to enable. As sxhkd bindings they are live on install
and cost a reload to change.

### Colour and displays

| Keys | Action |
| --- | --- |
| `Super` + `c` | Sample the pixel under the pointer — hex to the clipboard, swatch via dunst |
| `Super` + `Shift` + `d` | Monitor layout menu — autorandr profiles, then presets from the connected outputs |

`Super` + `c` is `config/dwm/bin/dwm-colorpicker`: `xdotool` reads the pointer
position, `maim` grabs a 1×1 capture there, and ImageMagick reads the hex out
of it. There is no `xcolor` package in Fedora — only `texlive-xcolor`, which is
a LaTeX package — so the script *is* the picker. `gpick` is in
`packages/extra.lst` for when you want a full palette tool instead.

`Super` + `Shift` + `d` is `config/dwm/bin/dwm-display`. Its presets are derived from
`xrandr` at run time, never hardcoded, because output names differ per machine
(`eDP-1` vs `eDP1` vs `LVDS-1`). With a single monitor connected it offers only
that monitor; the extend/mirror entries appear when there is something to
arrange. When `autorandr` has saved profiles they are listed first, since a
profile you curated beats anything generated. Both also run from a shell —
`dwm-display --list` prints the menu and the exact `xrandr` command behind each
entry without applying anything.

### Help

| Keys | Action |
| --- | --- |
| `Super` + `/` | This list, searchable, in dmenu (`dwm-keys`) |

`dwm-keys` reads this file at runtime, so a binding missing here is missing
from the cheat sheet too. `tests/dwm-keys.sh` fails the build when a key in
`sxhkdrc` has no row here.

### Emoji

| Keys | Action |
| --- | --- |
| `Super` + `;` | Emoji picker — search by name or group; the pick is copied to the clipboard (`dwm-emoji`) |

The list is Unicode's own, from the `unicode-emoji` package, so it matches
the installed release. Colour glyphs need `google-noto-emoji-fonts`
(`extra.lst`); without it the names still show and the copy still works.

### sxhkd itself

| Keys | Action |
| --- | --- |
| `Super` + `Ctrl` + `r` | Reload `sxhkdrc` in place (`pkill -USR1 -x sxhkd`) |

### Theming from a shell

The theming commands also work without any keybinding, through the `dots`
command the installer puts on `$PATH`:

```sh
dots wallpaper --select      # or --random, or a path
dots theme --list
dots theme --wallbash        # re-derive from current wallpaper
```

Each is a passthrough to the script that implements it
(`scripts/theme/wallpaper.sh`, `scripts/theme/theme-apply.sh`), which can still
be run directly. `dots --help` lists every subcommand.

Wallpapers are read from `wallpapers/` in your pictures folder (`xdg-user-dir PICTURES`, so a
localised or moved one is honoured; else `~/Pictures`) by default; override with
`DOTS_WALLPAPER_DIR`. The default folder is created on first use with the
theme's generated wallpaper in it, and a problem shows as a notification.
