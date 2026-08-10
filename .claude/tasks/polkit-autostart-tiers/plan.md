# Plan — polkit-autostart-tiers

## Goal
Close the third packaged-but-never-launched gap by autostarting the
polkit-gnome agent, and settle the tier question by moving the three
keybound packages (`polkit-gnome`, `thunar`, `firefox`) to `desktop.lst`
— what that file's own criterion already requires.

## Scope
- scripts/install-session.sh
- packages/*.lst
- tests/*.sh
- *.md, docs/*.md

## Forbidden
- config/
- suckless/
- scripts/install-pkg*.sh
- scripts/uninstall*.sh
- scripts/symlinks.sh
- .claude/changes/

## Steps
1. `install-session.sh`: launch the agent, probing both known paths.
2. `install-session.sh`: matching `session_autostart_report()` branch.
3. `tests/autostart-daemons.sh`: add polkit-gnome to DAEMONS; confirm the
   two-path launch still matches the backgrounded-command extractor.
4. Move `polkit-gnome`, `thunar`, `firefox` to `desktop.lst` with
   consequence notes; drop from `extra.lst`; reconcile both headers.
5. Docs: ROADMAP §5 auth-agent row, HANDOFF.md (bug shape + open
   decisions), docs/THUNAR.md, KEYBINDINGS.md.

## Out of scope
- An XDG autostart runner (dex); verifying against a live dnf.

## Risks
- Fedora's agent path is unverified (`/usr/libexec` vs `/usr/lib`) —
  mitigation: probe both explicitly, degrade silently like the others.
- The two-path launch may not match the test's `&`-suffix extractor —
  mitigation: step 3 verifies before step 4, not after.
