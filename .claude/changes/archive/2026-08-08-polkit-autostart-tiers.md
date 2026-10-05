# polkit-autostart-tiers
Date: 2026-08-08
Files: 9 modified (+ the task folder) | Lines: +281/-154

Closes `MASTER_PLAN.md` queue items 1 and 2 together — they turned out to share
an edit surface, since `polkit-gnome` needed both an autostart line and a tier
move.

## What changed

**1. The polkit-gnome authentication agent is now launched.**

- `scripts/install-session.sh` — the generated `autostart.sh` starts it, and
  `session_autostart_report()` names it for existing installs (rule 6: the
  installer prints the line, never edits the file).
- **It is not launched the way the other five daemons are, and that matters.**
  The binary is not on `PATH` — it lives under `libexec`, and distributions
  disagree about where. Copying the `command -v picom` pattern would have
  produced a guard that silently never fires: the same bug being fixed, quietly
  reintroduced inside the fix. Two absolute paths are tried instead:

  ```sh
  if ! pgrep -f polkit-gnome-authentication-agent >/dev/null 2>&1; then
  	if [ -x /usr/libexec/polkit-gnome-authentication-agent-1 ]; then
  		/usr/libexec/polkit-gnome-authentication-agent-1 &
  	elif [ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]; then
  		/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
  	fi
  fi
  ```

**2. The three keybound packages moved to `desktop.lst`.**

- `polkit-gnome`, `thunar` (`super + e`) and `firefox` (`super + b`), each with
  its consequence note. `desktop.lst` 26 -> 29, `extra.lst` 61 -> 58, total
  unchanged at 102.
- Both list headers reconciled: `extra.lst` now says outright that *being an
  application is not on its own a reason to be there*, since its previous
  header used `thunar` and `firefox` as its examples.

**3. Two refactors in `install-session.sh`, forced by the 60-line cap.**

Adding a sixth daemon took `session_autostart_report()` to 64 lines and
`session_autostart_template()` to 78. Both over the cap, and unavoidable —
there is no version of "add a daemon" that fits the old shape.

- `session_autostart_report()` -> a `session_report_daemon()` helper plus six
  data-shaped calls (37 + 14). This removes a six-way duplication that was
  already there, so it is a simplification rather than a workaround.
- `session_autostart_template()` -> `session_autostart_daemons()` +
  `session_autostart_services()` (4 + 44 + 39). The seam is the one the file's
  own comments already drew: daemons found on `PATH` versus services named by
  absolute path (`polkit-gnome`, `dwm-lock`).

**4. `tests/autostart-daemons.sh` now RUNS both functions instead of parsing
them.** It executes `session_autostart_template` and scans the real generated
file, and executes `session_autostart_report` against a throwaway
`autostart.sh` that mentions nothing. The previous version sed-extracted
function bodies, which the refactor above would have broken outright.

**5. Docs:** ROADMAP §5 auth-agent row (partial -> have) and the §7 autostart
row (now lists the six wired daemons and what is still unwired); `HANDOFF.md`
(the third bug instance closed, its `PATH` twist recorded, open decisions
replaced by a settled note); `TESTING.md`; `docs/THUNAR.md`.

## Why

`polkit-gnome` was the third packaged-but-never-launched instance, after picom
and sxhkd. A desktop environment starts a polkit agent from
`/etc/xdg/autostart`; dwm has no session manager and nothing in this repo reads
that directory, so the `.desktop` file the package ships was inert. Every GUI
action needing privileges — mounting a system disk from Thunar, partition or
package tools — was denied with no password prompt and usually no error, so the
feature looked broken rather than unauthorized.

The tier question was open because I had applied an unwritten
infrastructure-vs-application filter on top of the criterion actually written at
the top of `desktop.lst`: *does its absence stay quiet?* `super + e` and
`super + b` both die silently, so the written rule already covered them. An
unwritten rule quietly overriding a written one is the exact drift this repo
keeps paying for, so the written one wins.

## Assumptions

- **Type B — probe two absolute paths rather than hardcode one.** Fedora's
  actual file list could not be retrieved: three fetches against
  packages.fedoraproject.org returned package metadata but never the installed
  paths. Arch (this host) uses `/usr/lib/polkit-gnome/`; Fedora conventionally
  uses `/usr/libexec/`. Both are tried, and the block degrades silently if
  neither exists, matching the other daemons. *If wrong:* the surviving branch
  still fires; add a third `elif`.
- **Type B — `thunar` and `firefox` are `desktop.lst`, reversing what
  `package-tiers` shipped one commit earlier.** Recorded as a DECISION REVERSAL
  against that log's Type B assumption. The user selected this queue item
  without specifying a direction after declining to answer twice, so the
  criterion in the file decided it.
- **Type C — the report advice for polkit is a multi-line paste block**, unlike
  the one-liners the other five print. The launch is genuinely nine lines; a
  one-line rendering would not be pasteable.

## Test coverage

- Full suite green, 8/8. The two tests this task touched both report new
  numbers: `autostart-daemons` pairs **6** daemons (was 5), `desktop-consequences`
  annotates **29** entries (was 26). dunst held PID 6788 throughout.
- **Both refactors proved behaviour-preserving by diff**, not by inspection: the
  generated `autostart.sh` and the report output were each regenerated from
  `HEAD`'s version and from the new one, and each differs only by the new polkit
  content.
- The generated `autostart.sh` is valid POSIX `sh` (`sh -n`) and
  `shellcheck -s sh` clean.
- **Six mutants against `tests/autostart-daemons.sh`, all caught**, each
  confirmed applied before judging: polkit dropped from the template; its report
  call removed; `sxhkd &` silently neutered; a 7th daemon launched but absent
  from `DAEMONS`; the report reworded so it names no daemon; and every
  backgrounded command stripped at once (which proved the empty-set guard fires
  cleanly rather than crashing on `set -u`). One mutant needed two attempts to
  land — the applied-check caught that rather than letting it be reported as
  "not caught".
- Sourcing `install-session.sh` from the test was proved safe by running it in a
  clean `env -i` shell: emits nothing, `rc=0`, defines exactly 8 functions, and
  defines no colour helpers, so the test's own output helpers survive.
- Re-tiering verified conservative by explicit diff: 102 packages before and
  after, none added, none dropped, `thunar-*` subpackages correctly left in
  `extra.lst`.
- **Nothing ran against a real `dnf`, a real Fedora box, or a live X session.**
  The agent was never actually started — this host is Wayland.

## Follow-ups

- **`scripts/install-session.sh` is now at exactly 250 lines, the cap.** A
  seventh daemon forces a *file* split, not just a function split. Not
  pre-empted here — that would be scope expansion — but it is the next
  structural cost, and the file is the natural home for a
  `install-session-report.sh` sibling.
- **Fedora's real path for the agent is still unverified.** Worth confirming on
  the first real Fedora box; if `/usr/libexec` is right, the Arch branch could
  eventually be dropped.
- `ROADMAP.md` §7 still lists `nm-applet`, `udiskie` and `redshift` as
  intended-but-unwired. None are packaged, so they are absent rather than
  silently broken — but that is exactly the state picom was in one step before
  the bug.
