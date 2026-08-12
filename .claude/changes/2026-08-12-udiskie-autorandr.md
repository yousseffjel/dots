# udiskie-autorandr
Date: 2026-08-12
Files: 11 | Lines: +403/-125

## What changed

- **`udiskie` and `autorandr` declared in `packages/desktop.lst`** with their
  load-bearing consequence comments. Names verified against
  packages.fedoraproject.org: udiskie 2.6.2, autorandr 1.15, both 43/44/Rawhide.
- **udiskie autostarted** as `udiskie --automount --notify --smart-tray &`, so
  removable media mounts without Thunar resident.
- **autorandr autostarted** as `autorandr --change &` — a **one-shot**, not a
  daemon. The package ships an XDG autostart file for this, but nothing on this
  setup reads `/etc/xdg/autostart` (dwm has no session manager), the same reason
  the polkit agent is spelled out. The package's udev rule still covers hotplug.
- **Two structural splits, both forced by caps.** `session_autostart_daemons()`
  was at 57/60, so the body became `session_autostart_display()` (what paints
  the screen) + `session_autostart_daemons()` (interaction and devices), moving
  xsettingsd into the display half. `install-session.sh` then hit **254/250**,
  so the whole body moved to a new **`scripts/install-session-template.sh`**.
  97 + 179 + 107 across the three files.
- **A stale drift site removed.** `install_session_autostart()`'s dry-run and
  success strings enumerated the daemons by name and had *already* gone stale —
  xsettingsd was added last slot without updating them. Replaced with wording
  that cannot drift, and CLAUDE.md now forbids re-adding such a list.
- **Roster 7 -> 9** in `tests/autostart-daemons.sh`; **CLAUDE.md rule 6** gained
  the three-place obligation (launch line + report branch + test roster).

## Why

Scope C sub-task 3. Both rows were unmanned rather than merely absent: nothing
daemonises Thunar, so `thunar-volman` never fires and removable media had to be
mounted by hand; and no saved display profile was ever applied at session start.

The splits were not opportunistic. Each was a hard stop under
`file-architecture.md`, and each seam was chosen to mean something rather than
to land near a line count — "screen appearance" vs "interaction and devices"
for the function, "orchestration" vs "the content it writes" for the file. The
second seam is the one the reporting half already took at this same cap, so
`install-session.sh` is now consistently a dispatcher over three siblings.

## Assumptions

- **Type B — `autorandr --change` is backgrounded and carries no `pgrep`
  guard.** Backgrounded so it stays inside the launch/report pairing the test
  enforces and so autostart never blocks on an xrandr round-trip; no `pgrep`
  because a one-shot leaves no process to find, and re-running it after a dwm
  restart is idempotent. *If incorrect:* drop the `&` and remove `autorandr`
  from `DAEMONS`, but then nothing checks that its report branch exists.
- **Type B — `udiskie --automount --notify --smart-tray`.** `--automount` and
  `--notify` are defaults, named anyway so the behaviour is stated in the file
  the user reads and a future default change cannot silently disable either.
  `--smart-tray` shows an icon only while something is mounted.
- **Type C — no systemd unit of any kind.** A `--user` unit would not
  round-trip: `uninstall_steps.sh` disables SERVICE rows with
  `sudo systemctl disable`, which is system-level. The plan's `## Forbidden`
  block listed `install-services.sh` to make that structural rather than a
  remembered intention.

## Test coverage

Full suite via TESTING.md's runner — **10/10, exit 0** — plus
`tests/lint.sh --strict` separately. Daemons **7 -> 9**, annotated packages
**30 -> 32**; both counters moving is what shows the changes are covered.

- **The function split was proven output-equivalent by byte diff**, not by the
  suite staying green: 88 lines before and after, identical blank-line counts,
  `sort`ed content identical — pure reordering. That diff caught two things the
  passing test did not: a doubled blank line at the seam, and that xsettingsd
  was still in the interaction half while its new comment claimed otherwise.
- Final generated body: 10 backgrounded entries (8 + 2), the only additions
  being the two intended ones.
- **Three mutants, all caught** — dropping udiskie's report branch, dropping
  autorandr's report branch, and dropping autorandr's launch line each fail
  `tests/autostart-daemons.sh`. The guard is bidirectional.
- The generated `autostart.sh` parses under `/bin/sh` and carries no `set -e`,
  and both new entries are backgrounded, so a failing `autorandr --change` (no
  saved profile, say) cannot abort the rest of the session.
- `autostart-daemons.sh` passed across **both** restructures without itself
  changing — it calls only the two entry points and runs them rather than
  parsing. That property is now written into CLAUDE.md rule 6.

**Verification asymmetry, stated rather than smoothed over:** udiskie's flags
were checked against a real binary, but the local build is **2.7.0** while
Fedora ships **2.6.2**. **autorandr is not installed here at all**, and Fedora's
package pages list no files, so its shipped udev rule and XDG autostart file are
**assumed, not verified**. udiskie was deliberately never *run* — `--automount`
would have mounted real devices on this machine.

## Follow-ups

- **`--smart-tray` has never been exercised against dwm's systray.** If the icon
  never appears, automounting still works — the tray is the optional half.
  Worth a look on real hardware alongside the other X-dependent unknowns.
- **The reviewer caught CLAUDE.md contradicting its own diff.** Rule 6's new
  paragraph was written *before* the file split, so it attributed the
  `session_autostart_*` functions to `install-session.sh` after they had moved,
  and the project map omitted the new sibling. Both fixed before commit. The
  lesson generalises: docs written mid-task need re-reading after any late
  structural change in the same task.
- **`session_autostart_display()` is at 53 of 60.** Sub-task 4 adds no daemons,
  but whatever adds the next display-related one should expect to split again.
- Scope C sub-task 4 remains: `dwm-colorpicker` + `dwm-display`, their sxhkd
  binds, KEYBINDINGS.md, and the ROADMAP §3 corrections this Epic closes —
  including that `xcolor`, which §3 still names, does not exist in Fedora.
