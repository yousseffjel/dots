# statusbar-blocks

Date: 2026-08-07
Files: 11 | Lines: +552/-7 (source only; +555/-10 incl. task folder + state)

Epic sub-task 7 of `.claude/tasks/scope-b-app-roster-finalization.md`.

## What changed

- **Seven new block scripts** under `suckless/dwmblocks/scripts/`:
  `dwm-updates`, `dwm-disk`, `dwm-temp`, `dwm-brightness-block`, `dwm-mic`,
  `dwm-vol`, `dwm-bluetooth`. All follow `dwm-cpu`'s colour-sourcing idiom
  (themed palette -> static `dwm-colors` -> hardcoded default per value).
- **`blocks.def.h` rewritten to the locked ten-row order** —
  `UPD DISK TEMP CPU MEM GAMMA MIC VOL BT clock`, systray still furthest right
  — with the three existing blocks renumbered: cpu 1->4, ram 2->5, clock 3->10.
- **`suckless/dwm/config.def.h` gained Button4/Button5 on `ClkStatusText`.**
  Mid-task scope expansion, approved in-session — see Deviation below.
- **The dwmblocks Makefile's `install-scripts` / `uninstall-scripts` now derive
  their file lists from `scripts/`** instead of hardcoding names. The comment
  above them already claimed adding a script needed no Makefile edit; that was
  only true of the `cp`, not the `chmod` or the `rm`.
- **`KEYBINDINGS.md`** gained a Status bar section: the ten-block table with
  per-block click actions, the interval-0 explanation, the `GAMMA` labelling
  rationale, and the rebuild note for the scroll bindings.
- No package changes and no `config/theme/` changes — see Assumptions.

## Why

Layout A was locked in the scope file: one right-aligned status region left of
dwm's native systray, no new dwm patch. The bar shipped three blocks; this is
the remaining seven plus the renumbering that the locked signal table requires.

Blocks 6-8 sit at interval 0 — signal-driven only, never polled — which is the
"max performance" constraint (locked decision 9) applied to the three values
that change only on a keypress. Sub-task 4 already ships the senders:
`config/sxhkd/sxhkdrc` fires `pkill -RTMIN+6/7/8 dwmblocks` after every gamma,
mic and volume change. Verified mechanically that those three signals map to
exactly the three interval-0 blocks.

## Assumptions

- **(Type B) `updates` uses `dnf -C check-update`, cache-only.** User choice
  from three options. `-C` is load-bearing rather than an optimisation: without
  it dnf hits the network, and dwmblocks runs blocks synchronously, so one slow
  block stalls the whole bar. Fedora's own `dnf-makecache.timer` keeps the
  metadata fresh, so no systemd unit of ours is needed — the alternative (a
  user timer writing a count file) was rejected as scope beyond this sub-task,
  since it would need installer and uninstaller wiring too. Accepted cost: one
  rpmdb load per hour, and a count only as fresh as the system cache.
  **Unverified — there is no dnf on this Arch host.**
- **(Type B) New blocks use the generic `STATUS_*` names, not per-block
  `COL_*`.** User choice. `statusbar.dcol` already emits `STATUS_ACCENT1-4`,
  `STATUS_MUTED`, `STATUS_WARN`, `STATUS_URGENT` and `STATUS_RESET`, so
  `config/theme/` needed no edit at all, and the warn/urgent slots give
  state-dependent colour rather than mere identity. Cost: two conventions
  across the ten scripts, since cpu/mem/clock keep `COL_*`.
- **(Type B) The brightness block is named `dwm-brightness-block`.** Block
  scripts install to `~/.local/bin` and `config/zsh/.zshenv` puts that *ahead*
  of `~/.config/dwm/bin` on `PATH`, so a block named `dwm-brightness` would
  shadow the control script it calls — and sxhkd's `dwm-brightness up` would
  start invoking the status block. Checked all seven new names against
  `config/dwm/bin/`; this was the only collision.
- **(Type B) Its label is `GAMMA`, not `BRI`.** Locked decision 12 requires the
  label not imply a hardware backlight. `BRI`/`BL` is what every laptop applet
  uses and would promise power saving this cannot deliver — `xrandr` scales the
  output signal while the panel keeps drawing full power.
- **(Type C) `dwm-temp` matches sensors by name, never by hwmon number.**

## Trade-offs

**DEVIATION — `suckless/dwm/config.def.h` moved from Forbidden into Scope.**
Surfaced before writing `dwm-vol`, resolved by the user. The scope file's
locked table gives block 8 "scroll -> +/-5%", but dwm bound `ClkStatusText` for
Button1/2/3 only, so a scroll was discarded before any block saw it. Two rows
in `buttons[]` fix it for every block, not just vol. The user chose this over
dropping scroll, accepting the consequence: **this now needs a dwm rebuild, not
just a dwmblocks one**, so existing installs need the `rm -f config.h`
handling sub-task 3 established. `KEYBINDINGS.md` documents that inline. A
fresh install is unaffected — both generated headers were confirmed to
regenerate correctly here.

**Interval 0 means the bar can be stale.** Changing volume, mic or gamma by any
route other than the keybinds — `pamixer` straight from a shell — leaves the
block showing the old figure until the next keypress. That is inherent to the
design the scope file locked, and it is what keeps three of ten blocks off the
CPU entirely. Documented in `KEYBINDINGS.md` rather than papered over.

**Warn/urgent colours are only as alarming as the wallpaper.** `STATUS_WARN`
and `STATUS_URGENT` come from wallbash slots, so on the current wallpaper the
"warning" colour resolves to a green. States read as *different* rather than
reliably as *alarming*. That is the theming engine's design, not something this
task introduces, but choosing `STATUS_*` over fixed `COL_*` inherits it.

**`dwm-temp` reports `n/a` rather than guessing.** A machine whose CPU sensor
is not one of `coretemp`/`k10temp`/`zenpower`/`cpu_thermal` shows nothing
instead of falling back to the first available sensor. Silently reporting an
NVMe drive as CPU temperature is the failure you would never notice, and this
host demonstrates the risk concretely: its `hwmon0` *is* the NVMe drive.

## Test coverage

- `tests/lint.sh`, `tests/pkglist.sh`, `tests/build.sh` — all exit 0. All five
  suckless programs build with no new warnings; `blocks.h` regenerated with ten
  rows and `config.h` with the Button4/5 rows (both gitignored, both confirmed
  by inspection).
- **53 assertions across 29 scenarios** in a scratchpad harness faking `dnf`,
  `df`, `bluetoothctl`, `pamixer`, `dwm-brightness`, `thunar`, `pavucontrol`,
  `blueman-manager` and `notify-send` on an isolated `PATH`, plus a synthetic
  hwmon tree. `XDG_CACHE_HOME` points at an empty dir so every `STATUS_*` falls
  back to a known default and the expected output is deterministic.
- **Five mutants, all caught** (5/3/1/2/1 failing assertions): temp reading the
  first sensor instead of matching by name; mic reading the sink instead of the
  source; disk never reaching urgent; vol unmuting while lowering; updates
  counting the Obsoleting Packages section.
- **Two harness bugs found mid-run, both of which had produced a false pass:**
  a `\-C` pattern bash never matched literally, and a `${FAKE_BRIGHT:-70}`
  whose `:-` substituted the default for the deliberately-empty value, so the
  "xrandr returned nothing" case had never actually run.
- **Real-hardware checks the fakes cannot make:** `dwm-disk` against real `df`
  agrees with its own row (154G free, 68%); `dwm-temp` against real
  `/sys/class/hwmon` skips `nvme`, `dell_ddv`, `dell_smm` and `iwlwifi_1` to
  reach `coretemp`; `dwm-bluetooth` against the real adapter reads
  `Powered: no` and prints `off`. `make install-scripts`/`uninstall-scripts`
  run against a temp `SCRIPTDIR`: correct modes, and a planted `dwm-mine`
  survives uninstall.

**Not covered by CI:** `tests/lint.sh` globs `find . -maxdepth 2 -name '*.sh'`,
so all ten block scripts (depth 3, no extension) are outside it — the seven new
ones were shellchecked and `sh -n`'d by hand. **Not covered at all:** no `dnf`,
no `pamixer`, no Fedora, and nothing has rendered in a real dwm bar. Click
routing, the systray's position relative to the region, and the `$BUTTON`
values dwm actually delivers are verified by construction only.

## Follow-ups

- **`SC1090` fires on all ten block scripts**, old and new — the palette is
  sourced from a runtime-resolved path. Left matching the existing convention
  rather than adding the directive to only the new half; the queued
  `tests/lint.sh` glob-widening should decide once for all ten.
- **Widen `tests/lint.sh`'s glob.** Now the third sub-task to raise it, and the
  most acute: this one adds 452 lines of shell that CI never sees.
- **`dwm-updates` is unverified end to end.** The counting awk was written
  against dnf's documented three-column format and tested against a fake; the
  real `dnf5` output on Fedora 43/44 has not been seen.
- **Verify on real hardware:** that scroll reaches `dwm-vol` after the rebuild,
  that the CPU sensor is named `coretemp`/`k10temp` on the target box, and that
  ten blocks plus the systray actually fit the bar width.
- **`CLAUDE.md`'s project map still lists four `config/dwm/bin` scripts** and
  does not mention the block set. Sub-task 9 owns that reconciliation.
