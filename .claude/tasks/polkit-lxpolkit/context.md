# Context — polkit-lxpolkit

## Background
Top item on `MASTER_PLAN.md`'s queue, filed 2026-08-13 by the new
`install-container` job on its first run. `polkit-gnome` no longer resolves, so
`install-dry-run` goes red independently of the container job. It sits in
`desktop.lst`, so the install does not abort — it prints the red consequence
line and carries on, which is the tier working as designed. A fresh install
today therefore has **no PolicyKit agent**: any GUI action needing privileges
is denied with no password prompt and often no error at all.

## Prior Decisions
- **`lxpolkit`** chosen by the user 2026-08-13 from four candidates
  (`lxpolkit`, `mate-polkit`, `xfce-polkit`, `polkit-kde`). Lightest, GTK, no
  desktop-suite dependency tail. `polkit-kde` was ruled out by the GTK-only
  roster (scope-B locked decision 3).
- **2026-08-08 (`polkit-autostart-tiers`)** established the current wiring:
  launched from `autostart.sh` by absolute path, and moved to `desktop.lst` in
  a documented DECISION REVERSAL. The absolute-path part is what this task
  undoes — it was a consequence of polkit-gnome's binary, not a house rule.
- CLAUDE.md rule 6: adding or changing an autostart entry is a **three-place**
  change (template, report, `DAEMONS`), all three enforced by a test that RUNS
  both sides rather than parsing them.

## References
- `scripts/install-session-template.sh` — the launch block and the comment
  explaining why polkit was *not* `command -v`-guarded.
- `scripts/install-session-report.sh:90-101` — the paste-this-yourself block for
  existing installs, whose `autostart.sh` is user-owned and never rewritten.
- `tests/autostart-daemons.sh:62` — the `DAEMONS` array.
- `packages/desktop.lst:90` — the entry plus its load-bearing `#` consequence.
- ROADMAP `:196` (§3 auth agent), `:239` (§4.1 list), `:313` (stale count).
- `HANDOFF.md:89`.

## Notes
**Verified against Fedora's mdapi on 2026-08-13** (no dnf on this Arch host):

- `lxpolkit` **0.5.6-3.fc43** and **0.5.6-4.fc44** — both CI matrix legs.
  Built from the `lxsession` source, which is why
  `packages.fedoraproject.org/pkgs/lxpolkit/lxpolkit/` 404s. Provides
  `PolicyKit-authentication-agent`.
- **File list: `/usr/bin/lxpolkit`** — on `PATH`, so the `command -v` guard the
  other daemons use *will* fire. It also ships
  `/etc/xdg/autostart/lxpolkit.desktop`, which stays irrelevant here: dwm has no
  session manager and nothing reads that directory.
- **`polkit-gnome` is absent from f43 as well as f44**, so both matrix legs are
  affected — the queue entry said "Fedora 44" only. Confirmed with a control:
  `git`, `bash`, `picom`, `lxpolkit` all resolve on f43 through the same
  endpoint, so the negative is real rather than an endpoint artefact.
- Its `packages.fedoraproject.org` page still returns **HTTP 200** and looks
  alive while listing only **EPEL 9** — the exact failure mode recorded in
  memory as "Fedora package page vs search page".

Process matcher: the old guard was `pgrep -f polkit-gnome-authentication-agent`
because the binary name differed from the package. `lxpolkit`'s binary *is*
`lxpolkit`, so `pgrep -x lxpolkit` matches the other daemons' idiom.
