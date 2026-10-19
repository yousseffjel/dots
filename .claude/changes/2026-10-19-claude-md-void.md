# claude-md-void — CLAUDE.md stops stating Fedora facts as current
Date: 2026-10-19
Files: 1 (CLAUDE.md; + state, this log) | Lines: +31/-24 in CLAUDE.md

## What changed
CLAUDE.md, statements of current behaviour only (history kept and marked):
- Intro: "parts below still describe Fedora" → Fedora remains as history;
  current-behaviour statements reconciled with the Void scripts on 2026-10-19.
- Verification line:
  - package names are checked against Void's index (rule 8), not
    packages.fedoraproject.org;
  - install-container runs in a Void container ("Fedora until the port"), and
    a runit link is not a running service (was `systemctl enable`);
  - "nothing on real Fedora hardware" → nothing on bare metal; the Fedora
    VM run is marked as such;
  - the live-ISO VM matrix is added.
- Map: Bibata — neither Fedora nor Void packages it (checked in the index
  snapshot).
- Roadmap status:
  - "a single Fedora installer" → a single installer (Fedora's until the
    port);
  - xcolor "was not" a Fedora package, Void packages it, and the script stays
    (user, 2026-10-19);
  - laptop power profiles: power-profiles-daemon, tuned-ppd before the
    port; "no Fedora laptop" → no laptop;
  - the "still pending: never on a Fedora box" bullet → VMs only (the Void
    runs, the live-ISO matrix, the container job).
- Theming:
  - the GTK3 Adwaita-dark shim and the gtk2 template keep their Fedora
    reasons as history;
  - added that Void packages `gnome-themes-extra` (GTK3 Adwaita-dark) and
    `gnome-themes-extra-gtk` (GTK2), read from the 3.28_4 .xbps files, and
    that neither is installed.
- dwm-titus: "the same platform contract" → the one dots had until the
  port. "dots pins oldest-supported" → there is no version to pin on Void.
  dots has its own live-ISO installer, though it builds no ISO.
- Rule 10: core.lst names are checked against the index snapshot and CI's
  package-names job, not "never against a live dnf". install_deps: the
  `xbps` branch reads build.lst, not the `dnf` branch.

## Why
User 2026-10-19, item 6 ("CLAUDE.md still describes Fedora in places").
Type B assumption stated then: correct the stale claims, keep history
markers, no restructure. CLAUDE.md is loaded into every session, so a
Fedora statement read as current steers work wrong.

## Assumptions
- Type B (above). Code is unchanged: whether the shim and the gtk2
  template should give way to Void's gnome-themes-extra(-gtk) is a design
  question, queued at the fold rather than decided here.

## Test coverage
- `tests/lint.sh` ✓ (markdownlint). `tests/run-tests.sh` rc 0 (93 OK).
- Every new factual sentence was checked against the repo; the reviewer
  re-checked them (READY).

## Follow-ups
- Queue: Void packages `gnome-themes-extra` (+ `-gtk`). Install it and
  retire the vendored GTK3 shim and the gtk2 template, or keep both? (Both
  work today.)
- TESTING.md still carries Fedora-era sections (a "disposable Fedora
  environment", the Fedora services row). This was not item 6; queue it.
