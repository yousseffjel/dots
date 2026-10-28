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
> to `Shift` + `t`. `Super` + `p` and `Super` + `Alt` + `p` are now screenshot keys
> (the region key moved on to `Super` + `a` on 2026-10-22).
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
| `Mod` + `Shift` + `k` / `j` | Make the focused tiled window taller / shorter in its column (cfacts) |
| `Mod` + `Shift` + `o` | Reset its height share |
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

Every monitor shares the same nine tags, and a tag is on one monitor at a
time (`sharetags`). A tag belongs to the monitor showing it or holding its
windows: `Mod` + `1`–`9` shows it on THAT monitor and moves focus and the
pointer there. An empty tag opens on the monitor you are on.
`Mod` + `Shift` + `1`–`9` sends the window to the tag's monitor. Each tag
keeps its layout wherever it is shown. Unplug a monitor and its windows come
to the one left, on the same tags.

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
| `Mod` + `s` | Show / hide **all** stashed windows together, on this monitor |
| `Mod` + `=` | Drop the focused window out of the scratchpad set |
| `Super` + `grave` | Drop-down terminal: show / hide it; the first press starts it |

A stashed window is hidden from every tag — its whole tag set becomes a
single reserved bit above the nine real tags, so no ordinary tag view brings
it back and it is never drawn in the bar.

`Mod` + `s` is a single show/hide key for the whole set, like Hyprland's
special workspace (since 2026-10-22; until then it cycled one window at a
time):

- **None of them showing on this monitor:** every one comes out at once —
  stashed, or left showing on another monitor or another tag — onto the
  focused monitor's current tag, laid out master + stack
  under the bar: one fills the screen, two sit side by side, and with three
  or more the first takes the left half and the rest share the right half
  top to bottom. The first one is focused.
- **Any of them showing on this monitor:** all of them are stashed again.

They stay floating, on top of the tiled windows, so `Super` + drag still
moves and resizes them; the next `Mod` + `s` lays them out afresh. `Mod` +
`=` takes the focused one out of the set: it stays where it is, as an
ordinary floating window. Sending a shown one to a tag (`Mod` + `Shift` +
`<N>`, or `Mod` + `Ctrl` + `Shift` + `<N>` to add one) also takes it out of
the set, and tiles it (since 2026-10-22). A dwm restart (every wallpaper
change) keeps the set and what is stashed.

- **Stashing makes a window floating, and showing does not undo that.**
  `Mod` + `Shift` + `space` re-tiles a shown scratchpad (it stays in the set).

**The drop-down terminal** (`Super` + `grave`, the key left of `1`) is one
alacritty window with class `dots-dropterm`, hanging from the top of the
screen, 60% wide. The first press starts it; after that the same key stashes
it when it is showing and focused, and otherwise brings it to the current tag
— from any monitor — and focuses it. It is not in the `Mod` + `s` set, so
`Mod` + `s` neither shows nor hides it. Its size and the
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
| `Mod` + left-drag | Tiled: drop it into another window's slot, still tiled, on any monitor (placemouse). Floating: move it anywhere, snapping to screen and window edges |
| `Mod` + right-drag | Floating: resize from the corner nearest the grab, the pointer stays put (resizepoint). Tiled: left/right moves the master split, up/down the window's nearer edge (dragtile) |
| `Mod` + middle-click | Toggle floating (how to float a tiled window, since a drag keeps it tiled) |
| Click a status block | Runs the block's click handler (statuscmd) |
| Scroll over a status block | Same, with `$BUTTON` 4 (up) or 5 (down) |

---

## Status bar

Twelve blocks, left to right, then dwm's native systray furthest right. Each is a
script in `suckless/dwmblocks/scripts/`, installed to `~/.local/bin` by
`make install-scripts` and listed in `suckless/dwmblocks/blocks.def.h`.

| # | Block | Shows | Refreshes | Clicks |
| --- | --- | --- | --- | --- |
| 1 | `󰋊` disk | Free space on `/` | 5 min | left → open `/` in thunar |
| 2 | `󰔏` temp | CPU package temperature, in °C | 15 s | left → htop |
| 3 | `󰻠` cpu | CPU utilisation | 2 s | left → htop |
| 4 | `󰍛` mem | RAM in use | 10 s | left → htop |
| 5 | `󰛨` / `󰃟` brightness | Backlight (laptop, the lamp) or screen gamma (desktop, the sun) level | **on change only** | left → night light on / off, scroll → brightness ±, with the pop-up |
| 6 | `󰍬` mic | Microphone level, or `󰍭` alone when muted | **on change only** | left → toggle mute, with the pop-up |
| 7 | `󰕿` `󰖀` `󰕾` vol | Output volume, the waves following the level, or `󰝟` alone when muted | **on change only** | left → mute, right → pavucontrol, scroll → ±5%; left and scroll show the pop-up |
| 8 | `󰤯`…`󰤨` net | Wi-Fi bars (no percent), `󰈀` wired, `󰤮` off, `󰛳` when only the kernel's link state is known. No SSID: nmtui shows it | 30 s | left → nmtui in a terminal (nm-connection-editor if nmtui is missing) |
| 9 | `󰂯` bt | Bluetooth: `󰂲` off, `󰂯` on, `󰂱` and the count while connected | 60 s | left → blueman-manager |
| 10 | `󰂚` / `󰂛 FOCUS` | The notification button, always shown: a bell and the number of notifications in dunst's history, or a crossed bell and `FOCUS` in focus mode, plus how many it is holding back | 30 s, and at once on a change | left → the notification centre, right → focus mode on / off |
| 11 | `󰂎`…`󰁹` battery | Battery percent, the icon filled to the nearest tenth, `󰂄` while charging. Shown **only** on a machine with a system battery (a laptop); empty on a desktop. Warn colour at 15 %, urgent at 5 %, each with one notification | 60 s | left → state, percent and time left / to full |
| 12 | `` | Day, date and time | 60 s | left → the month calendar under the clock, left again (or Escape) closes it (`dwm-calendar`); without python3-gobject, the month in a notification |

**The bar behaves like the keys** (2026-10-07). A click or scroll that changes
a level shows the same `dwm-osd` pop-up as the volume, mic and brightness
keys. Every terminal a click opens (`nmtui`, `htop`) floats: its
class is `dots-float-<tool>`, and one `dots-float-` rule in `config.def.h`
matches them all. The terminal is alacritty, or st without it. The helpers
live in `dwm-blockutil`, sourced by the blocks the way `dwm-colors` is.

> **Scroll on the bar needs a dwm rebuild on an existing install.** dwm bound
> `ClkStatusText` for Button1/2/3 only, so a scroll was discarded before any
> block saw it; `buttons[]` gained Button4/5 for this. Everything else in the
> table works after a dwmblocks rebuild alone. To pick up the scroll:
>
> ```sh
> rm -f suckless/dwm/config.h
> scripts/install-suckless.sh --skip-deps
> ```

**The network block, and the notification button's timed refresh, need a dwmblocks rebuild
with a fresh `blocks.h` on an existing install.** Without it the button still
works, but its count only moves when you click it or press a notification key.
The block list is compiled in, and `blocks.h` is generated from `blocks.def.h`
once and then left alone:

```sh
rm -f suckless/dwmblocks/blocks.h
scripts/install-suckless.sh --skip-deps
```

**The brightness, mic and volume blocks are never polled.** They run once at startup
and then only when something sends their signal — `config/sxhkd/sxhkdrc` fires
`pkill -RTMIN+6/7/8 dwmblocks` after every brightness, mic and volume change. That keeps them off the CPU
entirely (`tests/blocks-info.sh` holds every signal-only block in
`blocks.def.h` to a sender in `sxhkdrc`). The cost is that changing any of
those values by some *other* route (`pamixer` straight from a
shell, say) leaves the bar stale until the next keypress.

> **The lamp `󰛨` is a backlight, and the sun `󰃟` is not.** On a laptop, `dwm-brightness`
> dims the backlight with `brightnessctl` (installed only on laptops by
> `dots drivers`), and the block shows the lamp. A desktop GPU has no
> `/sys/class/backlight`, so there it scales the output signal with
> `xrandr --brightness` while the monitor keeps drawing full power. The block
> then shows the sun rather than the lamp precisely so it does not promise a power
> saving it cannot deliver. The brightness keys are the same on both.

The temperature block matches sensors **by name** (`coretemp`, `k10temp`, `zenpower`,
`cpu_thermal`), never by hwmon number — that numbering is assigned in probe
order and changes between boots. A machine whose CPU sensor is named something
else shows `n/a` rather than silently reporting an NVMe drive or the
motherboard; add the name to `CPU_SENSORS` in `dwm-temp` to fix it.

**The polled blocks run as rarely as their value is worth** (2026-10-28):
every poll forks a shell and its tools, so the intervals above are a CPU
budget, not a refresh rate to raise. There is no pending-updates block any
more (it was dropped then): `dots update`, or `xbps-install -Su`, tells you.

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
it audible. Both play a short tick (`dwm-sound off` silences it, with every
other desktop sound); mute plays none.

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
converge on the next keypress. A screen turned back on gets the last level
by itself: `dwm-display` and an autorandr hook run `dwm-brightness sync`
after every display switch. From a shell:

```sh
dwm-brightness get        # integer percent, for scripts
dwm-brightness up|down
dwm-brightness set 70
dwm-brightness sync       # the last level again, after a raw xrandr
```

### Screenshot

| Keys | Action |
| --- | --- |
| `Print` | Screenshot menu — pick a mode, then a destination |
| `Super` + `a` | Drag a region straight to the clipboard, no prompts; an open dropdown or menu stays open |
| `Super` + `Shift` + `a` | The same after 3 seconds, for the rare menu that `Super` + `a` still closes |
| `Shift` + `Print` | The same as `Super` + `a` |
| `Super` + `Alt` + `p` | Whole screen, to the clipboard **and** saved as a file, no prompts |

`Print` opens two dmenu prompts in sequence:

```text
screenshot>          dest>
  full                 clipboard
  monitor              file
  window               both
  region
```

On more than one screen, `full` is all of them in one image; `monitor` is
just the one under the pointer, at its exact edges (the same rectangle dwm
lays its bar out on), found with `xdotool` and `xrandr`.

Escape at either prompt aborts and captures nothing. `file` and `both` write
to `screenshots/` inside your pictures folder — `xdg-user-dir PICTURES`,
so a localised or moved one is honoured, else `~/Pictures` — overridable
with `DOTS_SCREENSHOT_DIR`, named
`dots-screenshot-YYYYmmdd-HHMMSS.png`.

`Super` + `a` deliberately does **not** also keep a file. Region grabs are
overwhelmingly paste-once, and a keybind that quietly fills a directory is one
you end up cleaning up after — press `Print` (or `Super` + `Alt` + `p` for
the whole screen) when you want the shot kept.

Every one of these keys runs `config/dwm/bin/dwm-screenshot`, which drives `maim` for the
capture and `xclip` for the clipboard. A region is selected by
`config/dwm/bin/dwm-shotselect`: it reads the whole screen into memory the
moment it starts, shows that frozen frame full-screen, and you drag on the
picture, so whatever was open at the keypress is in the shot even if it
closes after. Escape or the right button cancels. Without python3-gobject it
falls back to `maim` + `slop`. The selector rectangle is drawn in
`dwm.selbordercolor` read live from `xrdb`, so it matches the border dwm puts
around the focused window and re-themes with the wallpaper.

**`Super` + `a` is not a normal hotkey.** Every other key here is grabbed
(by sxhkd or dwm), and a grab takes the keyboard focus off the window while
the key is held. A browser treats that as losing focus and closes an open
dropdown before any screenshot code runs. So `Super` + `a` is read without a
grab by `config/dwm/bin/dwm-shotkey`, a small listener started by
`autostart.sh`. An open dropdown holds the pointer grab itself, so the
selector photographs it first and only then sends it Escape to free the
pointer for the drag. Three consequences:

- With no grab, the focused window gets `Super` + `a` too. Firefox ignores it;
  st and alacritty are configured to ignore it rather than type an "a".
- It fires only with nothing but `Super` held, so it never clashes with
  `Super` + `Shift` + `a`.
- An install older than this has an `autostart.sh` without the listener: the
  installer prints the line to add.

Region mode selects on a frozen frame of the whole screen, taken when you
press the key, so what is in the image is what was on screen then (the slop
fallback does the same with ImageMagick's crop). From a shell, `--delay N`
waits before any mode.

> **`window` means the *focused* window, not one you click.** It resolves
> `_NET_ACTIVE_WINDOW` via `xprop`, so it needs no mouse — that is the only
> thing it does that region mode cannot. (A plain click in the region
> selector selects nothing: drag instead. Only the slop fallback snaps a
> click to the window under the pointer.) maim
> captures the window's screen rectangle, so anything stacked on top of it
> appears in the image.

From a shell, both prompts can be skipped:

```sh
dwm-screenshot                        # both prompts
dwm-screenshot --region               # region, then ask where it goes
dwm-screenshot --full --both          # no prompts at all
dwm-screenshot --monitor --clipboard  # this monitor, no prompts
```

### Screen recording

| Keys | Action |
| --- | --- |
| `Super` + `r` | Start a recording (pick full screen, the monitor under the pointer, or a region), or stop the one running (`dwm-record`) |

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
| 9 min 45 s idle | The screen fades to 40% brightness; any key or mouse movement brings it back |
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

`--daemon` sets `xset s 585 15` (`xset s noblank noexpose` too) and
`xset dpms 0 0 660`, then execs `xss-lock -n dwm-idle-dim -- slock`. xss-lock
runs the dimmer when X's screensaver activates, 15 seconds before the lock,
and kills it on input or when slock starts. The dimmer puts back the
brightness and tint the screen had, night light included. It is started once
per session from `~/.local/share/dwm/autostart.sh`. To change the timings, edit
`LOCK_SECS`, `DIM_SECS` (0 turns the fade off) and `DPMS_OFF_SECS` at the top
of the script — not `autostart.sh`, which only holds the one launch line.
A session that was running before this change keeps an xss-lock with no
dimmer until the next login; until then it locks at 9 min 45 s, undimmed.

**`noblank noexpose` matters.** By default X "blanks" at screensaver
activation, which on a modesetting driver turns every output off (DPMS). That
would hide the fade, and it powered the monitor down at the lock rather than
a minute later, as the table says it should.

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

### Power profile

| Keys | Action |
| --- | --- |
| `Super` + `Shift` + `p` | Power profile menu: power-saver, balanced or performance, with the current one marked |

Laptops only. dots installs `power-profiles-daemon` there, and the power
menu (`Super` + `Shift` + `x`) gains a `profile` entry wherever a profile
service answers. On a desktop the key says profiles need
`power-profiles-daemon` instead of doing nothing.

### Notifications

| Keys | Action |
| --- | --- |
| `Super` + `Shift` + `n` | Focus mode on / off (do not disturb: dunst holds notifications, shows them when it ends) |
| `Super` + `Ctrl` + `n` | Notification centre |

The **notification centre** (`dwm-notify`) is a dmenu list that drops down
under the right end of the bar, where the popups appear. It lists dunst's
history, newest first, under two entries: focus mode on / off, and
**Clear all**. Pick a notification to **open** it or **delete** it; after a
delete the list comes back. A left-click on the bell opens it too.

**Open** shows the notification again and opens the first link in it, if it
has one. It cannot run the app's own action ("reply", "show"): once a
notification has left the screen, dunst no longer sends actions back to the
app. In focus mode, opening one ends focus mode first, so anything held back
shows as well.

In focus mode the bar shows `󰂛 FOCUS`, and `dots doctor` warns, because focus
mode left on silently holds back every notification. dunst keeps the last 20
(`history_length` in `config/dunst/dunstrc`), and only until you log out.
A theme or wallpaper change keeps both the list and focus mode. The volume,
mic and brightness pop-ups never enter the list.
`Super` + `Ctrl` + `n` used to re-show the last closed notification;
**open** in the centre now does that for any of them.

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
profile you curated beats anything generated. A screen that is already on
keeps its mode in every preset (only a screen that is off gets `--auto`), and
the presets are built around the output `xrandr` marks primary. The last entry,
**save this layout as a profile**, asks for a name and runs `autorandr --save`
(asking first before overwriting one): plugging the same screens in again then
restores the layout by itself, through Void's autorandr udev rule, and every
login re-applies it. Both also run from a shell —
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
