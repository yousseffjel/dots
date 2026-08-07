# Context — lock-idle-xss-lock

## Background

Epic sub-task 6/11 of `.claude/tasks/scope-b-app-roster-finalization.md`.
Sub-task 4 built the sxhkd layer and reserved `super + l`, shipping it
commented out precisely so the key and the idle/suspend wiring would land
together as one documented feature. This is that landing.

`packages/extra.lst` already carries `xss-lock` (with a comment giving the
xautolock rationale) and `xset` — both added by sub-task 2, so no package
work is needed here. slock is vendored, built by `install-suckless.sh` and
xresources-themed since the theming Epic's sub-task 1.

## Prior Decisions

- **Locked decision 9 (desktop, not laptop).** No lid-close handling. But
  desktops do suspend, which is why `xss-lock` beats `xautolock`: it bridges
  both X's screensaver timer and systemd-logind, so it also fires on suspend —
  something xautolock structurally cannot do.
- **CLAUDE.md rule 6** — `install-suckless.sh` treats `autostart.sh` as
  user-owned once it exists. It is never edited, patched or backed up; the
  missing line gets printed for the user to paste. Same caveat sub-task 4 hit
  with the sxhkd launch line.
- **sxhkdrc ownership rule (sub-task 4).** dwm and sxhkd both `XGrabKey()` on
  the root window and the loser silently gets nothing. `super + l` must not
  appear in dwm's `keys[]`. Verified: it does not.

## Decisions taken this session (user-chosen, 2026-08-07)

1. **Idle policy: lock at 10 min, screen off at 11 min.** `xset s 600 600`
   plus `xset dpms 0 0 660`. The ordering is the point — lock always precedes
   blank, so the display is never dark-but-unlocked. (Offered: 5/6 min, 10/11,
   blank-before-lock, and no idle lock at all.)
2. **Manual lock routes through logind with a fallback.** `loginctl
   lock-session` when `xss-lock` is running, else `slock` directly. Keeps
   logind's session `Locked` state accurate and gives one place to swap the
   locker, without the silent no-op that a bare `loginctl` would produce if
   xss-lock had died.
3. **A repo-managed `config/dwm/bin/dwm-lock` owns the wiring**, and
   `autostart.sh` gets a single `dwm-lock --daemon &` line. Because
   autostart.sh is user-owned once created, anything inlined there could never
   be updated by a later install — retuning the timings would mean editing the
   user's own file. One line to paste, policy in the repo.

## References

- `scripts/install-session.sh` — autostart template + `session_autostart_report`,
  extracted in sub-task 4 when `install-suckless.sh` crossed the 250-line cap.
- `config/dwm/bin/dwm-powermenu` — its `lock)` arm currently `exec slock`.
- `KEYBINDINGS.md` — `### Not yet bound` holds only the `super + l` row, so
  the whole section goes away here.
- xss-lock(1): https://man.archlinux.org/man/xss-lock.1.en

## Notes

- **`--transfer-sleep-lock` is deliberately NOT used.** The man page: the fd
  "will only be set if the reason for locking is that the system is preparing
  to go to sleep. The locker should close this file descriptor to indicate it
  is ready." slock knows nothing about `$XSS_SLEEP_LOCK_FD` and never closes
  it, so the delay inhibitor would be held for the whole locked session —
  capped by logind's `InhibitDelayMaxSec` (5s default), i.e. up to 5 seconds
  added to every suspend for no benefit. slock grabs essentially instantly, so
  there is nothing to wait for.
- **The locker must not fork** (man page: "xss-lock waits for the locker to
  exit ... so the command should not fork"). slock does not fork. Good.
- **Nothing here can be exercised on this host.** `xss-lock`, `xset` and
  `slock` are all absent (Arch/Wayland dev box); only `loginctl` exists.
  Verification is fakes on an isolated PATH plus construction, exactly as in
  sub-task 5.
