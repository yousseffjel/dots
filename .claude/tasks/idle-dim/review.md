# Review — idle-dim

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0 open. The night light daemon stays the ONE gamma writer (dim file, pid-checked); without it the dimmer writes gamma AND brightness, since --brightness alone resets gamma. The 600 s lock time is unchanged. |
| 2 | Size/Performance | ✅ | 0 found. dwm-idle-dim 115 lines; 8 xrandr calls over 0.8 s, then a 2 s parent poll only while dimmed. |
| 3 | Types/Validation | ✅ | 2 found, 2 fixed: (a) with nothing to dim, restore ran `xrandr --output ""` (an empty here-string line); (b) a missing dim file printed an error from night light (the redirect order). Plus a guard: an unreported Brightness 0.0 restores as 1, not black. |
| 4 | Dependencies | ✅ | 0 found. xrandr, pgrep, awk are already required by dwm-brightness/nightlight; no new package. dwm-lock's launch line in autostart.sh is unchanged (no rule-6 edit). |

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** NOT READY → findings fixed (no second reviewer round; each fix mutation-checked)
**Notes:** Independent reviewer, given the code and not the audit. In a throwaway Xvfb with
stand-ins, it confirmed that noblank+noexpose still runs the -n notifier at ON and the locker
at the first cycle, and that input TERMs the notifier. Findings:
1. Medium, fixed: a brightness key (the very input that ends the dim) could read the dimmed
   level before the restore, then write and store ~45%. The dimmer now holds a pid marker
   ($XDG_RUNTIME_DIR/dots/idle-dim.pid) until its restore is done, and dwm-brightness
   up/down/set waits on it (1 s at most). Not pgrep: sealed test PATHs have no `id`, and
   night light's test pgrep fake always answers yes.
2. Low-medium, fixed: one xrandr call for every output, so an output that lost its CRTC
   aborted the rest, which stayed dim. Now one call per output.
3. Low, accepted: on the xrandr path (only when night light's daemon is NOT running), a
   gammastep ramp left by a dead daemon comes back as xrandr's power-curve estimate (2
   significant digits). The common cases (gamma 1.0, or the daemon running) are exact.
4. Low, intended: the restore when slock starts puts full brightness behind slock until DPMS.
5. Low, fixed in part: night light now deletes a dim file whose pid is dead, so pid reuse
   cannot revive it. A -9'd dimmer on the xrandr path stays dim until the next key (accepted;
   xss-lock never sends -9).
6. Tests, fixed: two outputs on (the reviewer's "first output only" mutation now fails 2 checks),
   SIGTERM mid-fade, stop() fails instead of hanging, the marker, and the brightness wait.
