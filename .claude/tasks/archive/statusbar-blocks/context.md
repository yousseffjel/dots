# Context — statusbar-blocks

## Background

Epic sub-task 7/11. Layout A was locked in the scope file: a single
right-aligned status region, left of dwm's native systray. No new dwm patch —
`extrabar` is not vendored, and dwm's tags/layout keep the left while the
window title keeps the middle.

Today `blocks.def.h` has three rows (cpu 1, ram 2, clock 3). The target is ten,
in this order left to right:

| # | Block | Interval | Sig | Source |
|---|-------|---------:|----:|--------|
| 1 | updates | 3600 | 1 | `dnf -C check-update` |
| 2 | disk | 300 | 2 | `df` on `/` |
| 3 | temp | 5 | 3 | `/sys/class/hwmon` |
| 4 | cpu | 2 | 4 | `/proc/stat` (exists, sig 1 -> 4) |
| 5 | ram | 10 | 5 | `/proc/meminfo` (exists, sig 2 -> 5) |
| 6 | brightness | **0** | 6 | `dwm-brightness get` |
| 7 | mic | **0** | 7 | `pamixer --default-source` |
| 8 | vol | **0** | 8 | `pamixer` |
| 9 | bluetooth | 30 | 9 | `bluetoothctl` |
| 10 | clock + date | 60 | 10 | `date` (exists, sig 3 -> 10) |

## Prior Decisions

- **Locked decision 9 — desktop, tuned for performance.** No battery block. It
  is also why blocks 6/7/8 sit at interval 0: signal-driven only, never
  polled. Sub-task 4 already ships the senders — `config/sxhkd/sxhkdrc` fires
  `pkill -RTMIN+6/7/8 dwmblocks` after every brightness, mic and volume
  change. Verified present; **this task must not renumber those three.**
- **Locked decision 12 — brightness is `xrandr --brightness` software gamma.**
  The block label must not imply a hardware backlight; there is no
  `/sys/class/backlight` on this target.
- Dropped from the candidate list and staying dropped: battery, now-playing,
  keyboard layout, weather, uptime/load, network.

## Decisions taken this session (user-chosen, 2026-08-07)

1. **`updates` uses `dnf -C check-update`, cache-only.** No network from
   inside the block. Fedora's own `dnf-makecache.timer` keeps the metadata
   fresh, so no systemd unit of ours is needed — the alternative (a user timer
   writing a count file) was rejected as scope beyond this sub-task, since it
   would also need installer and uninstaller wiring. Accepted cost: one rpmdb
   load per hour, and a count only as fresh as the system cache.
2. **New blocks use the generic `STATUS_*` names**, not per-block `COL_*`.
   `statusbar.dcol` already emits `STATUS_ACCENT1-4`, `STATUS_MUTED`,
   `STATUS_WARN`, `STATUS_URGENT` and `STATUS_RESET`, so `config/theme/`
   needs no edit at all. It also buys state-dependent colour — a hot CPU, a
   nearly-full disk and a muted mic can each say so. Cost: two conventions
   across the ten scripts, since cpu/mem/clock keep `COL_*`.
3. **One slot for all ten blocks.** `blocks.def.h`, the Makefile's name lists
   and `KEYBINDINGS.md` each change exactly once, and main never carries a
   half-populated bar.

## Notes

- **Naming hazard, discovered while planning.** Block scripts install to
  `~/.local/bin` (`SCRIPTDIR` in the Makefile) and `config/zsh/.zshenv` puts
  `$HOME/.local/bin` *before* `$XDG_CONFIG_HOME/dwm/bin` on `PATH`. A block
  named `dwm-brightness` would therefore shadow the control script of the same
  name, and `sxhkdrc`'s `dwm-brightness up` would start invoking the status
  block. Hence `dwm-brightness-block`. No other new name collides — checked
  against all seven scripts in `config/dwm/bin/`.
- **Clicks need no dwm change.** `suckless/dwm/config.def.h` already maps
  Button1/2/3 on `ClkStatusText` to `sigstatusbar` with `.i` = the button
  number; the statuscmd patch supplies the clicked block's own signal and sets
  `$BUTTON`. Any block with a non-zero signal is therefore clickable already.
  All ten signals are non-zero.
- **Colour sourcing idiom to copy** (from `dwm-cpu`): prefer
  `$XDG_CACHE_HOME/dots/theme/statusbar-colors.sh`, fall back to
  `${0%/*}/dwm-colors`, then `$HOME/.local/bin/dwm-colors`, then a hardcoded
  default per value — so a partial install degrades to right-ish colours
  rather than a blank bar.
- `dwm-cpu` is worth reading before writing anything new: it caches its
  previous `/proc/stat` sample, and deliberately reprints the last figure when
  a click refreshes the block milliseconds after a scheduled update, rather
  than reporting a truncated window.
- **This host cannot exercise any of it.** No `dnf`, no `pamixer`, no
  `bluetoothctl`, and `/sys/class/hwmon` here is Arch hardware, not the Fedora
  target. Fakes plus a synthetic hwmon tree, as in sub-tasks 5 and 6.
