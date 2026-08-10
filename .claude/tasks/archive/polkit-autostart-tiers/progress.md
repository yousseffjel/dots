# Progress — polkit-autostart-tiers

## Status
`in-progress`

## Steps
- [x] 1. `install-session.sh`: launch the agent, probing both known paths.
- [x] 2. `install-session.sh`: matching `session_autostart_report()` branch.
- [x] 3. `tests/autostart-daemons.sh`: add polkit-gnome to DAEMONS; confirm the two-path launch still matches the backgrounded-command extractor.
- [x] 4. Move `polkit-gnome`, `thunar`, `firefox` to `desktop.lst` with consequence notes; drop from `extra.lst`; reconcile both headers.
- [x] 5. Docs: ROADMAP §5 auth-agent row, HANDOFF.md (bug shape + open decisions), docs/THUNAR.md, KEYBINDINGS.md.

## Deviations

- **Step 2 forced two refactors the plan did not name.** Adding a sixth daemon
  pushed `session_autostart_report()` to 64 lines and
  `session_autostart_template()` to 78, both over the 60-line cap in
  `rules/foundations/file-architecture.md` — a hard stop, and unavoidable:
  no version of "add a daemon" fits inside the old shape.
  - `session_autostart_report()` -> a `session_report_daemon()` helper plus six
    data-shaped calls (37 + 14). This removes the six-way duplication that was
    already there, so it is a net simplification rather than a workaround.
  - `session_autostart_template()` -> `session_autostart_daemons()` +
    `session_autostart_services()` (4 + 44 + 39). The seam is the distinction
    the file's own comments already drew: daemons found on `PATH` versus
    services that must be named by absolute path (polkit-gnome, dwm-lock).
  - Both proved output-identical: the generated `autostart.sh` and the report
    output each differ from `HEAD` only by the new polkit content.
  - In scope (`scripts/install-session.sh` is in `## Scope`), so no
    re-confirmation, but it changes what step 3's test must extract — hence
    the plan's ordering of "verify the extractor before step 4" mattering.

- **`install-session.sh` is now at exactly 250 lines, the cap.** Zero headroom:
  a seventh daemon forces a file split, not just a function split. Flagged as a
  follow-up rather than pre-emptively split here.

## Blockers
