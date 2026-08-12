# Context — udiskie-autorandr

## Background
Scope C sub-task 3. These are two of the four ROADMAP §3 rows the Epic exists to
close. Both were chosen over alternatives in the 2026-08-12 comparison pass; the
reasoning is locked in the scope file and must not be re-litigated.

## Prior Decisions
- `.claude/tasks/scope-c-roster-gap-fill.md` locked decisions 3 and 4.
  **udiskie over thunar-volman**: volman only auto-mounts while Thunar runs, and
  nothing daemonises Thunar — `autostart.sh` has no `thunar --daemon` line — so
  that row is unmanned today. Adding `thunar --daemon` was the alternative and
  was rejected. `udevil`/`devmon` rejected as unmaintained.
  **autorandr in, arandr OUT**: only autorandr reacts to hotplug; arandr is a
  one-time layout GUI a dmenu script (sub-task 4) replaces.
- CLAUDE.md rule 10 — `desktop.lst`'s trailing `#` is load-bearing consequence
  text; `tests/desktop-consequences.sh` fails the build without it.
- CLAUDE.md rule 6 — `autostart.sh` is user-owned once it exists; the installer
  only *reports* the needed line to an existing install. That report is what
  `install-session-report.sh` exists for, and the pairing is enforced.
- 2026-08-08 polkit-gnome precedent: dwm has **no session manager**, so nothing
  runs `/etc/xdg/autostart`. Anything relying on an XDG autostart file needs an
  explicit `autostart.sh` line. autorandr ships exactly such a file.

## References
- `scripts/install-session.sh` — `session_autostart_daemons()` is at **57 of 60
  lines**; this sub-task adds two more entries and must split it first. The
  file's own comment already documents the last split's seam ("daemons found on
  PATH, then services named by absolute path") — this one needs a new seam.
- `scripts/install-session-report.sh` — every daemon needs a matching
  `session_report_daemon` call or existing installs are never told.
- `tests/autostart-daemons.sh` — `DAEMONS=(…)` roster, currently 7. It RUNS both
  sides and has an explicit "daemons this test does not know about" check that
  caught the unpaired xsettingsd entry unprompted last slot.
- `scripts/uninstall_steps.sh:166-180` — SERVICE rows are disabled with
  `"${SUDO[@]}" systemctl disable`, i.e. system-level. This is why no `--user`
  unit is added here.

## Notes
- **udiskie 2.6.2 IS installed locally** (`/usr/bin/udiskie`) — verify its flags
  against the real binary the way xsettingsd was, rather than assuming. Worth
  checking: whether it needs `--tray`/`--no-tray`, and what it does with no
  systray present, since dwm's systray only exists once dwm is running.
- **autorandr is NOT installed locally**, and per the `fedora-package-page-vs-search`
  memory the Fedora package pages give no file lists. Its shipped udev rule and
  XDG autostart file are therefore **assumed**. Upstream README confirms the
  Makefile installs udev/systemd/pm-utils/XDG-autostart hooks but does not say
  which are user vs system units. Record this as unverified in the change log.
- `autorandr --change` is a **one-shot**, unlike every current entry in the
  daemon set. `tests/autostart-daemons.sh` detects launches by matching
  backgrounded commands (`… &`), so decide deliberately in step 4 whether it is
  backgrounded and therefore in `DAEMONS`, or handled as a separate category.
  Do not let it silently fall outside both the launch check and the unknown-
  daemon check.
- Memory: `dots-testing-via-fake-binary-on-path` for shimming, and
  `dots-theming-engine-test-hazard` — pkill-based tests reach the whole system.
