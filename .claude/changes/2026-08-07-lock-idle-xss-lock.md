# lock-idle-xss-lock

Date: 2026-08-07
Files: 5 | Lines: +226/-21 (source only; +229/-24 incl. task folder + state)

Epic sub-task 6 of `.claude/tasks/scope-b-app-roster-finalization.md`.

## What changed

- **`config/dwm/bin/dwm-lock` (new, 140 lines).** One script owning every path
  to a locked screen, in two modes. `--daemon` arms X's idle timers
  (`xset s 600 600`, `xset dpms 0 0 660`) and then `exec`s `xss-lock -- slock`;
  bare `dwm-lock` locks immediately, routing through `loginctl lock-session`
  while the daemon is up and calling `slock` directly when it is not.
- **`scripts/install-session.sh`.** The autostart template gains one launch
  line and `session_autostart_report` gains a matching `dwm-lock` arm, so an
  `autostart.sh` that already exists gets the line printed rather than edited.
- **`config/sxhkd/sxhkdrc`.** `super + l` uncommented and pointed at
  `dwm-lock`. This was the file's last pending binding — every entry in it is
  now live.
- **`config/dwm/bin/dwm-powermenu`.** The `lock` entry moves from
  `exec slock` to `exec dwm-lock`, so the menu and the keybind share one path.
- **`KEYBINDINGS.md`.** New "Lock and idle" section covering the key, the two
  idle thresholds and the suspend case. Its "Not yet bound" section is gone —
  `super + l` was the only row left in it.
- No package changes: `xss-lock` and `xset` were both already declared in
  `packages/extra.lst` by sub-task 2.

## Why

Sub-task 4 built the sxhkd layer and deliberately shipped `super + l`
commented out so the key and the idle/suspend wiring would land together as
one documented feature. This is that landing. `xss-lock` over `xautolock`
because it hooks systemd-logind as well as X's screensaver and therefore also
fires on suspend — the target is a desktop (locked decision 9), so there is no
lid to close, but it still sleeps.

`config.def.h` is untouched, so no rebuild: `MODKEY` is `Mod1Mask`, making
dwm's `XK_l` binding `Alt+l` (setmfact), and dwm's only Super chords remain
`Super+Shift+x` and `Super+v`.

## Assumptions

- **(Type B) `--transfer-sleep-lock` is deliberately not passed.** xss-lock(1)
  says the fd "will only be set if the reason for locking is that the system is
  preparing to go to sleep. The locker should close this file descriptor to
  indicate it is ready." slock has never heard of `$XSS_SLEEP_LOCK_FD` and so
  never closes it, which would pin logind's delay inhibitor for the entire
  locked session; logind then waits `InhibitDelayMaxSec` (5s default) and
  suspends regardless. That is up to five seconds added to every suspend for
  nothing, since slock grabs the screen immediately and there is no readiness
  to wait on.
- **(Type B) The autostart line spells out the path in full** —
  `"${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-lock" --daemon &` — rather
  than relying on `PATH`, unlike the three system daemons above it.
  `~/.config/dwm/bin` reaches `PATH` through `config/zsh/.zshenv`, which only
  runs if the display manager starts the session through a login zsh. A
  powermenu that fails to spawn is noticed instantly; a lock daemon that fails
  to start is noticed the first time the screen doesn't lock, which is the
  wrong way round for a security control. `autostart.sh` is also user-owned
  the moment it exists (rule 6), so this line can never be corrected later.
- **(Type B) Manual lock prefers logind, with a fallback.** Routing through
  `loginctl lock-session` keeps logind's own `Locked` state truthful and gives
  one place to swap the locker. The fallback is the point though — a bare
  `loginctl` call would be a silent no-op the moment xss-lock died, which is
  the exact failure shape this repo keeps flagging. Offered to the user with
  all three options; they chose the fallback form.
- **(Type C) Timings chosen by the user: lock at 10 min, monitor off at 11.**
  The ordering carries the reasoning — lock must precede blank, or the display
  goes dark while still unlocked and a mouse wiggle lands on a live desktop.
  Both are named constants at the top of the script, not inline literals.

## Trade-offs

**The policy lives in the repo, not in `autostart.sh`.** Inlining the `xset`
calls would have matched how dwmblocks, clipmenud and sxhkd are already wired,
and cost a four-line paste for existing installs instead of one. It was
rejected because `autostart.sh` becomes user-owned on creation, so anything
written there is frozen — retuning 10 minutes to 20 would mean editing the
user's own file. The cost of the chosen shape is one more indirection between
the session and the daemon.

**`window`-style overlap does not arise here, but a different redundancy does:**
`xset s 600` will blank the screen at ten minutes even with no locker present.
On a box where `xss-lock` failed to install, the display therefore still goes
dark on schedule and simply doesn't lock — which is why the daemon warns
loudly and exits 1 rather than staying quiet about it.

**One audit finding, one real fix.** Extra arguments were silently ignored, so
`dwm-lock --daemon --transfer-sleep-lock` would have started the daemon and
dropped the flag without a word. Given the file's own header explains at
length why that flag is absent, someone trying to add it is a realistic
mistake, and the failure would have been invisible. Now rejected with an
arity check. Notably, `dwm-lock` contains **no command substitutions at all**,
so the `var="$(cmd)"`-aborts-silently-under-`set -e` class that produced two
bugs in sub-task 4 is structurally absent rather than merely avoided.

## Test coverage

- `tests/lint.sh`, `tests/pkglist.sh`, `tests/build.sh` — all exit 0. All five
  suckless programs build with no new warnings, confirming this needs no
  rebuild.
- **64 assertions across 22 scenarios** in a scratchpad harness faking `xset`,
  `xss-lock`, `slock`, `loginctl` and `pgrep` on a `PATH` containing only the
  fake dir plus a symlinked real `bash`. Covered: cold start; re-run with the
  daemon already up; each of xss-lock/slock/xset absent; `xset s` and
  `xset dpms` each failing independently; lock-now with and without the daemon;
  `loginctl` failing mid-call; `loginctl` absent; slock absent; and the full
  argument surface including arity rejection.
- **The harness was mutation-tested before being believed.** A wrong
  `LOCK_SECS` and a disabled logind route were both injected and both caught
  (3 and 4 failures respectively), so 64/64 means something.
- **Four sandboxed `install_session_autostart` runs**, all four XDG vars
  redirected per the installer-sandbox memory: fresh write (0755, line
  present), re-run (all four daemons reported ok), pre-existing `autostart.sh`
  (**md5 identical afterwards** — rule 6 holds, and the paste line prints
  unexpanded), and `--dry-run` (zero files created).
- `sxhkdrc` parsed by real sxhkd 0.6.3, clean — proven meaningful first by
  feeding it `super + lll` and confirming `Unknown keysym name: 'lll'`.
- Generated `autostart.sh` extracted from the heredoc and checked with
  `sh -n`: valid POSIX sh.

**Not covered:** `xss-lock`, `xset` and `slock` are all absent from this
Arch/Wayland dev host, so nothing here observes an actual lock, an actual DPMS
transition, or an actual `XGrabKey` on `super + l`. Also not covered by CI —
`tests/lint.sh` globs `find . -maxdepth 2 -name '*.sh'`, so `dwm-lock` and the
six other `config/dwm/bin/*` scripts sit outside it; shellchecked and
`shfmt`'d by hand.

## Follow-ups

- **`procps-ng` (`pgrep`) is undeclared in `packages/*.lst`.** Found in audit
  iteration 1. Pre-existing — `autostart.sh` has used `pgrep` for dwmblocks,
  clipmenud and sxhkd since sub-task 4 — and `packages/` was Forbidden by this
  plan, so it was recorded rather than fixed. Without it, `dwm-lock --daemon`
  loses its duplicate-daemon guard and could start a second `xss-lock` on
  re-run.
- **The `extra.lst` promotion question is now four sub-tasks deep**
  (`alacritty`, `sxhkd`, `maim`/`slop`/`xprop`, and now this). Load-bearing
  roster packages sitting in a best-effort list means a silent install failure
  leaves keybinds dead. It may deserve its own slot rather than another
  follow-up line.
- **Widen `tests/lint.sh`'s glob to cover `config/dwm/bin/*`.** Carried from
  sub-tasks 4 and 5; there are now seven scripts there, two of them over 130
  lines.
- **`dwm-powermenu` fails `shfmt` at HEAD and still does.** Its aligned `case`
  arms are the file's own style, verified as pre-existing against
  `git show HEAD:`, so the alignment was matched rather than reformatted. It
  survives only because the file is outside the lint glob above.
- **Verify on real hardware:** that `super + l` actually grabs (`xev`), that
  the lock lands before the blank, and that suspend locks.
- **`CLAUDE.md` and `ROADMAP.md` §3 still say no lock/idle wiring exists.**
  Left deliberately — sub-task 9's declared scope covers that reconciliation,
  and this is ordinary staleness rather than misleading advice.
