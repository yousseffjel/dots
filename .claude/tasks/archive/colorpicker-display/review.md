# Review — colorpicker-display

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1/1 fixed — CLAUDE.md's project map credited `$PATH` setup to `20-path.zsh`, **which does not exist**; the entry is in `config/zsh/.zshenv` (deliberately, since `conf.d` is interactive-only and dwm's autostart is not). Found by verifying the delivery path rather than assuming it. |
| 2 | Size/Performance | ✅ | 0 — 111 and 128 lines; no function over 60. |
| 3 | Types/Validation | ✅ | 0 — shellcheck clean on both. The single `SC2086` disable is one-line and justified (xrandr output names cannot contain whitespace), matching the scoped-disable practice `tests/tmux-tpm-lockstep.sh` already uses. |
| 4 | Dependencies | ✅ | 0 — every command invoked is declared: xdotool (added here), maim/xclip/xrandr/ImageMagick/libnotify (existing desktop.lst), autorandr (sub-task 3), dmenu (vendored). Both new names are free in `~/.local/bin`, which precedes `dwm/bin` on PATH. |

**Audit verdict:** ✅ READY

Tier: Medium+ (13 files, +451/-14) — full 4 sequential sweeps.

Evidence beyond reading:
- **The picker's hex path is genuinely proven**, not merely plumbed: the `maim`
  shim emitted a real 1×1 PNG of `#3fa9c2` and the script returned exactly
  `#3fa9c2` to both stdout and the (shimmed) clipboard, with the swatch
  notification built.
- All four picker failure paths produce a named error and exit 1 — dead X,
  garbage from xdotool, maim failing, unknown option. No silent aborts.
- `dwm-display` derives its menu correctly from a faked two-monitor xrandr:
  the disconnected output is excluded, each "only" entry disables the others in
  a **single** xrandr call (so the server never passes through a no-output
  state), a single-monitor setup offers no extend/mirror nonsense, and
  autorandr profiles are listed first when present.
- Selection dispatch verified end-to-end with a dmenu shim: choosing "mirror
  HDMI-1 onto eDP-1" ran exactly the matching xrandr command. Escape exits 0
  and runs nothing.
- Key freedom re-checked at code time as the plan required: sxhkd holds
  `b, c, ctrl+r, ctrl+w, d, e, l, shift+w, w`; dwm compiles only
  `Mod4Mask|ShiftMask XK_x` and `Mod4Mask XK_v`. No overlap, no duplicates
  within sxhkdrc.
- Delivery path confirmed: `symlinks.sh:46` links `config/dwm` as a directory
  so new files ride along, and `.zshenv:28` puts `dwm/bin` on `$PATH`.
- Suite 10/10 + `lint.sh --strict`; dunst held PID 2652.

**Unproven, and it cannot be proven here:** neither script has run against a
real pointer or a second monitor. Every external binary was shimmed. What is
tested is the logic, the command construction and the failure handling — not
that maim samples the right pixel on a live screen, nor that these xrandr
invocations produce the intended layout on real hardware.

**One process note:** an `sxhkd -c … -n` parse-check was attempted and turned
out not to be a dry-run flag — it launched the daemon against the live session
until the 2-minute timeout killed it. No stray process survived and this host
runs no sxhkd, so nothing was disturbed, but sxhkd has **no** parse-check mode
and that avenue should not be retried.

## Test Gate
**Command:** `for t in tests/*.sh; do bash "$t"; done` (TESTING.md:13)
**Result:** ✅ PASSED — 10/10, exit 0

Annotated packages **32 -> 33** (xdotool); the daemon count is unchanged at 9,
correctly, since this slot adds no daemons. dunst held PID 2652.

**Worth being blunt about what the suite does and does not cover here.** No test
in `tests/` exercises `config/dwm/bin/*` — the suite is green on this diff
largely because the two new scripts are outside its reach. What actually
verified them was the shimmed runs during `/code`, and one of those shims was
wrong in a way that hid a happy-path failure until the reviewer caught it.
Treat the green suite as necessary, not sufficient, for this particular slot.

## Reviewer Gate
**Verdict:** READY (round 2 — round 1 was BLOCK)

**Round 1 — BLOCK, and it was right.** `%[hex:p{0,0}]` emits eight hex digits
(RRGGBBAA) for maim's actual output, which is RGBA (`png:IHDR.color_type: 6`),
so the strict `^[0-9A-Fa-f]{6}$` validation rejected it. **The script failed on
its ordinary happy path, not an edge case.**

My own test passed because the fake `maim` wrote an RGB PNG — the shim was more
forgiving than the real tool. That is the lesson worth keeping: a shim has to
reproduce the real binary's *output format*, not merely its interface, or it
tests the code against a world that does not exist.

**Fix:** `-alpha off -depth 8` before `-format`. `-alpha off` covers the RGBA
case; `-depth 8` covers the 16-bit case the reviewer raised in the same breath,
which reproduced independently as twelve digits. The strict validation was
deliberately **kept** — a future format change should fail loudly rather than
copy a truncated colour to the clipboard — and the error now reports what it
actually received. Re-verified across PNG32/RGBA, PNG24/RGB, PNG48/16-bit and
PNG8/palette: all four give correct 6-digit hex.

**Round 2 notes.** The reviewer checked the thing that would have made the fix
worse than the bug — whether `-alpha off` *composites* rather than discards.
It does not: a semi-transparent `rgba(200,50,50,0.3)` pixel gives `C83232`
(the true source RGB), where `-alpha remove -background white` gives a
composited `EEC1C1`. So `-alpha off` was the correct variant. Grayscale
round-trips correctly; CMYK (which maim cannot produce) still trips the loud
failure path, as designed.
