# Context — picom-perf-tuning

## Background

Epic sub-task 10, added at the user's request under locked decision 9 ("target
is a desktop PC, tuned for performance"). Independent of every other sub-task.
The baseline was already sane — `backend = "glx"`, `vsync = true`,
`use-damage = true`, no blur, no rounded corners — so this is trimming real
per-frame cost, not undoing cargo-cult settings.

## Prior Decisions

- Locked decision 9 — desktop, max performance. No battery/laptop concerns.
- `config/picom` is COPIED by the installer, never symlinked (CLAUDE.md), and
  `picom.dcol` regenerates `~/.config/picom/picom.conf` wholesale on every
  wallpaper change. That is the lockstep hazard this task must not trip.

## Research findings (verified this session)

1. **Both this host and Fedora 43/44 ship picom v13** (`v13`, revision
   d87a5ba; Fedora `13-1.fc43` / `13-1.fc44`). Local checks are therefore
   directly representative of the target, not a proxy.
2. **All 23 options in the current config are still valid in v13.** Checked
   each against the installed man page after normalising its troff escapes —
   the first attempt searched for literal `shadow-radius` while the page
   writes `\fB\-\-shadow\-radius\fP`, which made almost everything look
   missing. Nothing in the config has bit-rotted.
3. **`--unredir-if-possible` (v13 man page):** unredirects when the top-level
   window covers the entire screen (ALL monitors in multi-head), when there is
   no window, when a window is fullscreen per WM hints, or when a window sets
   `_NET_WM_BYPASS_COMPOSITOR`. Upstream states plainly it is "known to cause
   flickering when redirecting/unredirecting windows". Windows are unredirected
   unconditionally when monitors are powered off regardless of the setting.
4. **`--unredir-if-possible-exclude` is discouraged upstream** in favour of the
   WINDOW RULES `unredir` key (values `true`/`false`/`preferred`/`passive`/
   `forced`). If a specific window misbehaves under unredirection, that is the
   escape hatch — not the exclude list.
5. **`detect-rounded-corners` is pure cost here.** The man page: it "affects
   --shadow-ignore-shaped, --unredir-if-possible, and possibly others. You need
   to turn this on manually if you want to match against rounded_corners in
   conditions." Nothing in this config matches `rounded_corners`, and with
   shadows dropped the whole `shadow-exclude` list goes too.
6. **Target GPU is Intel UHD Graphics 770 / i915** (user confirmed this machine
   is the target). So `xrender-sync-fence` stays off — it is an NVIDIA
   tearing/corruption workaround that costs a sync round-trip elsewhere.
7. **`shadow-color = "#<wallbash_pry1>"` is the ONLY wallbash placeholder in
   picom.dcol.** Dropping shadows leaves the template with nothing to
   substitute. The user was offered deleting the template and chose to keep it
   placeholder-less — so the lockstep hazard stays, and step 3's test exists to
   make drift a hard failure rather than a silent revert.
8. **picom cannot be launched here to validate.** It is not running on this
   box, so starting it would begin compositing on the user's live desktop; and
   with `DISPLAY` pointed at a nonexistent server picom fails at "Can't open
   display" *before* parsing the config, so that trick yields nothing. No
   Xvfb/Xephyr available either.

## References

- `scripts/theme/apply-templates.sh` — discovers `*.dcol` generically, so
  nothing there needs to know about picom.
- `scripts/theme/reload.sh:181` — `reload_picom()`, and the hardcoded step list
  at line 209. Untouched: the template is being kept.
- `docs/THEMING.md:48` (pipeline diagram) and `:155` (target table) both list
  picom and need the "no wallpaper-derived content" note.

## Notes

The lockstep test compares settings only — the two files legitimately differ in
their header comments (one says "static fallback", the other "DO NOT EDIT,
generated"). Comparing whole files would fail for the wrong reason.
