# Review — statusbar-blocks

## Audit Loop

Tier: **Medium+** (12 files, +555/-10).

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1 found, 1 fixed — `dwm-updates` handed the whole `dnf` output to `notify-send`, so a neglected box would render a notification taller than the screen. Capped at 20 lines with an "… and N more" tail. Signal contract verified mechanically: sxhkd emits `RTMIN+6/7/8` and exactly the three interval-0 blocks carry signals 6/7/8; all ten signals unique and matching the locked table. |
| 2 | Size/Performance | ✅ | 1 found, 1 fixed — a bare `timeout 20` in `dwm-updates` became `DNF_TIMEOUT`, matching `BT_TIMEOUT` and the six other named thresholds. Largest script is `dwm-temp` at 74 lines; nothing near the 250 cap. |
| 3 | Types/Validation | ✅ | 0 found — every value crossing a process boundary is guarded by a `*[!0-9]*` case or an emptiness test before any numeric use. No block sets `-e`, so the `var="$(cmd)"` silent-abort class does not apply here at all. One suppression (`SC2086` in `dwm-disk`) for deliberate word-splitting, with a reason. |
| 4 | Dependencies | ✅ | 0 found — `thunar`, `pavucontrol`, `blueman`, `bluez`, `pamixer` and `libnotify` are all already declared in `packages/*.lst`; every `STATUS_*` fallback declared in a script is used by it. |

**Audit verdict:** ✅ READY

### Notes carried out of the sweeps

- **`SC1090` fires on all ten block scripts, old and new.** The colour palette
  is sourced from a runtime-resolved path, which shellcheck cannot follow. The
  three pre-existing scripts already have it, and these files sit outside
  `tests/lint.sh`'s `-maxdepth 2 -name '*.sh'` glob, so it is not enforced
  anywhere. Left matching the existing convention rather than adding the
  directive to only the new half — the queued glob-widening task should make
  one decision for all ten.
- **The Makefile's globbing claim was only half true** and is now honest. Its
  comment said adding a script needs no Makefile edit, but `chmod` and
  `uninstall-scripts` both hardcoded names. Both now derive their list from
  `scripts/` — deliberately not by globbing `${SCRIPTDIR}`, since that is
  `~/.local/bin` and `rm -f ${SCRIPTDIR}/dwm-*` would delete any `dwm-*` the
  user wrote themselves. Verified: a planted `dwm-mine` survives
  `uninstall-scripts`.
- **Colour semantics depend on the wallpaper.** `STATUS_WARN` and
  `STATUS_URGENT` come from wallbash slots, so on some wallpapers the "warning"
  colour is not a warm hue — on the current one `STATUS_WARN` resolves to a
  green. That is the theming engine's design, not something this task
  introduces, but it does mean the warn/urgent states read as *different*
  rather than reliably as *alarming*.

## Test Gate
**Command:** `bash tests/lint.sh && bash tests/pkglist.sh && bash tests/build.sh`
(repo convention — nothing auto-detectable at the root)
**Result:** ✅ PASSED — all three exit 0. Plus the task harness, 53/53.

Coverage detail:

- `tests/lint.sh` — shellcheck + shfmt + markdownlint, ok. **The ten block
  scripts are outside its glob** (`-maxdepth 2 -name '*.sh'`; these are at
  depth 3 with no extension), so all seven new ones were shellchecked and
  `sh -n`'d by hand.
- `tests/pkglist.sh` — format, duplicates, overlap ok. No package list changed;
  all six runtime deps were already declared.
- `tests/build.sh` — dwm, st, dmenu, dwmblocks and slock all build with no new
  warnings. `blocks.h` regenerated with 10 rows and `config.h` with the
  Button4/5 rows, both confirmed by inspection (both are gitignored).
- **Task harness, 53 assertions / 29 scenarios** against faked `dnf`, `df`,
  `bluetoothctl`, `pamixer`, `dwm-brightness`, `thunar`, `pavucontrol`,
  `blueman-manager` and `notify-send` on an isolated `PATH`, plus a synthetic
  hwmon tree. `XDG_CACHE_HOME` points at an empty dir so the themed palette is
  absent and every `STATUS_*` falls back to a known default, making the
  expected output deterministic.
- **Five mutants, all caught** (5/3/1/2/1 failing assertions): temp reading the
  first sensor instead of matching by name; mic reading the sink instead of the
  source; disk never reaching urgent; vol unmuting while lowering; updates
  counting the Obsoleting Packages section.
- **Two harness bugs found and fixed**, both of which had produced a false
  pass: a `\-C` pattern bash never matched literally, and a `${FAKE_BRIGHT:-70}`
  whose `:-` substituted the default for the deliberately-empty value, so the
  "xrandr returned nothing" case had never actually run.
- **Real-hardware checks the fakes cannot make:** `dwm-disk` against real `df`
  agrees with its own row (154G free, 68%); `dwm-temp` against real
  `/sys/class/hwmon` correctly skips `nvme`/`dell_ddv`/`dell_smm`/`iwlwifi_1`
  to reach `coretemp`; `dwm-bluetooth` against the real adapter reads
  `Powered: no` and prints `off`. `make install-scripts` / `uninstall-scripts`
  exercised against a temp `SCRIPTDIR`, confirming correct modes and that a
  planted `dwm-mine` survives uninstall.

**Not covered:** no `dnf`, no `pamixer`, no Fedora, and nothing has rendered in
an actual dwm status bar. Click routing, the systray's position relative to the
region, and the `$BUTTON` values dwm actually delivers are all verified by
construction only.

## Reviewer Gate
**Verdict:** READY
**Notes:** Clean on the first round — nothing raised, so nothing needed
resolving. Probed specifically for blocks that could print a wrong value
rather than `n/a` (`dwm-temp`'s name-based sensor selection, `dwm-mic` never
reading the sink), for any surviving reference to the old signals 1/2/3, for a
block able to hang the synchronous dwmblocks loop, for the Makefile uninstall
target deleting files it does not own, for click handlers mutating before
reading, and for the `dwm-updates` awk counting across the Obsoleting Packages
section.
