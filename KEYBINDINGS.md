# Keybindings

Two programs bind keys, and they own different halves of the keyboard:

| Owner | Source | Covers | Changing it costs |
| --- | --- | --- | --- |
| **dwm** | `suckless/dwm/config.def.h` | Window management — tags, layouts, focus, monitors, scratchpads, session — plus the terminal, dmenu, power menu and clipboard | A recompile |
| **sxhkd** | `config/sxhkd/sxhkdrc` | Media, volume, mic, brightness, theming, screenshots, screen lock, app launchers | `Super` + `Ctrl` + `r` |

Neither file is generated from the other, so an edit in one needs a matching
edit here — nothing keeps them in sync automatically.

**The two key sets must stay disjoint.** dwm and sxhkd both call `XGrabKey()`
on the root window. If both claim the same keysym and modifier, it goes to
whichever grabbed it first and the other silently gets nothing — no error, no
log line. Check the tables below before adding a binding to either file.

Two modifiers are in play:

- **Mod** = `Mod1Mask` = **Alt** (`#define MODKEY Mod1Mask`)
- **Super** = `Mod4Mask` = the Windows/Command key

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
| `Mod` + `p` | `dmenu_run` application launcher |
| `Mod` + `Shift` + `Return` | Terminal (`alacritty`) |
| `Super` + `Shift` + `x` | Power menu (`dwm-powermenu`) |
| `Super` + `v` | Clipboard history (`dwm-clipmenu`) |

**st is still installed** as the fallback terminal for a machine with no
working GL — alacritty is GPU-accelerated and will refuse to start without
it. There is no keybinding for st; run `st` from dmenu (`Mod` + `p`) if
alacritty ever fails to launch. Both read the same wallpaper-derived
palette, so they look alike.

> **Changing the terminal or the fonts requires a rebuild, and one extra
> step.** `suckless/*/config.h` is generated from `config.def.h` on the
> first build and then left alone, so an existing install keeps its old
> values. Delete the stale headers first:
>
> ```sh
> rm -f suckless/{dwm,dmenu,st}/config.h
> scripts/install-suckless.sh --skip-deps
> ```

### Window focus and layout

| Keys | Action |
| --- | --- |
| `Mod` + `j` / `k` | Focus next / previous window in the stack |
| `Mod` + `Return` | Promote the focused window to master (zoom) |
| `Mod` + `Tab` | Toggle back to the previously viewed tag |
| `Mod` + `Shift` + `c` | Close the focused window |
| `Mod` + `h` / `l` | Shrink / grow the master area |
| `Mod` + `i` / `d` | Increase / decrease the number of master windows |
| `Mod` + `b` | Toggle the status bar |
| `Mod` + `t` | Tiled layout |
| `Mod` + `f` | Floating layout |
| `Mod` + `m` | Monocle layout |
| `Mod` + `space` | Toggle between the last two layouts |
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

| Keys | Action |
| --- | --- |
| `Mod` + `y` | Terminal scratchpad (`st -n spterm`) |
| `Mod` + `u` | File manager scratchpad (`ranger`) |
| `Mod` + `x` | KeePassXC scratchpad |

### Session

| Keys | Action |
| --- | --- |
| `Mod` + `Shift` + `q` | Quit dwm |
| `Mod` + `Ctrl` + `Shift` + `q` | Restart dwm in place (restartsig) |

### Mouse

| Action | Effect |
| --- | --- |
| `Mod` + left-drag | Move a window (makes it floating) |
| `Mod` + right-drag | Resize a window |
| `Mod` + middle-click | Toggle floating |
| Drag the layout split | Adjust master/stack ratio (dragmfact) |
| Click a status block | Runs the block's click handler (statuscmd) |

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

### Brightness

| Keys | Action |
| --- | --- |
| `XF86MonBrightnessUp` | Brightness +10% |
| `XF86MonBrightnessDown` | Brightness −10% |

> **This is not a backlight control.** The target is a desktop with no
> `/sys/class/backlight`, so `config/dwm/bin/dwm-brightness` scales the
> output signal with `xrandr --brightness` instead. The image gets darker;
> the monitor's lamp stays at full power. It never goes below 10% — a black
> screen has to be undone from a terminal you can no longer see.

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
| `Shift` + `Print` | Drag a region straight to the clipboard, no prompts |

`Print` opens two dmenu prompts in sequence:

```text
screenshot>          dest>
  full                 clipboard
  window               file
  region               both
```

Escape at either prompt aborts and captures nothing. `file` and `both` write
to `~/Pictures/screenshots`, overridable with `DOTS_SCREENSHOT_DIR`, named
`dots-screenshot-YYYYmmdd-HHMMSS.png`.

`Shift` + `Print` deliberately does **not** also keep a file. Region grabs are
overwhelmingly paste-once, and a keybind that quietly fills a directory is one
you end up cleaning up after — press `Print` when you want the shot kept.

Both keys run `config/dwm/bin/dwm-screenshot`, which drives `maim` for the
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

### Lock and idle

| Keys | Action |
| --- | --- |
| `Super` + `l` | Lock the screen now |

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
do. That is also why `Super` + `l` goes through `loginctl lock-session` when
the daemon is up — logind's own record of whether the session is locked stays
truthful, and every trigger ends in the same locker. With no daemon running it
calls `slock` directly instead, so the key never silently does nothing.

> **If the screen never locks on its own, the daemon is not running.** Check
> with `pgrep -x xss-lock`. As with sxhkd, `install-suckless.sh` will not add
> the launch line to an `autostart.sh` you already had — it prints the line
> for you to paste. `Super` + `l` keeps working either way.

### Applications

| Keys | Action |
| --- | --- |
| `Super` + `b` | Firefox |
| `Super` + `e` | Thunar |

Only the two daily drivers get a dedicated key — everything else is one
`Mod` + `p` away through dmenu.

### Theming engine

| Keys | Action |
| --- | --- |
| `Super` + `w` | Pick a wallpaper from a dmenu list, then re-theme |
| `Super` + `Shift` + `w` | Random wallpaper from the wallpaper dir, then re-theme |
| `Super` + `Ctrl` + `w` | Theme menu — pick a static theme or `wallbash` |

These were previously shipped commented out in `config.def.h` under `Mod` +
`w`, needing a rebuild to enable. As sxhkd bindings they are live on install
and cost a reload to change.

### sxhkd itself

| Keys | Action |
| --- | --- |
| `Super` + `Ctrl` + `r` | Reload `sxhkdrc` in place (`pkill -USR1 -x sxhkd`) |

### Theming from a shell

The theming commands also work without any keybinding:

```sh
scripts/theme/wallpaper.sh --select      # or --random, or a path
scripts/theme/theme-apply.sh --list
scripts/theme/theme-apply.sh --wallbash  # re-derive from current wallpaper
```

Wallpapers are read from `~/Pictures/wallpapers` by default; override with
`DOTS_WALLPAPER_DIR`.
